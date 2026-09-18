#!/bin/bash
# allow-comment: PreToolUse:Bash guard. Denies a recursive file search (find, bfs, fd, rg, grep -r, ag, ack, tree, du, ls -R) rooted at the filesystem root, the users directory, the home directory, or the home Library and its app-container directories. Such a walk reads other apps' data, which on macOS raises one privacy prompt per app for the operator, and it runs for many minutes where a package-manager or index query answers in a second. The helpers below are shared with the no-root-search-tool guard.

DD_NRS_SEP=$'\037'
DD_NRS_HIT=""
DD_NRS_CWD=""
DD_NRS_GLOB_CHILDREN=0

dd_nrs_home() {
  local home="${HOME%/}"
  printf '%s\n' "${home:-/}"
}

# allow-comment: dd_nrs_normalize <word> <cwd> prints the lexically resolved absolute path and returns 1 for a word it cannot resolve (unknown variable, command substitution, a glob that names specific entries), because an unresolvable root is not evidence of a whole-disk walk. A trailing /* or /** is stripped and flagged, since the shell expands it to every child of the parent.
dd_nrs_normalize() {
  local word="$1" cwd="$2" home part out=""
  home="$(dd_nrs_home)"
  DD_NRS_GLOB_CHILDREN=0

  case "$word" in
    '~') word="$home" ;;
    '~/'*) word="$home/${word#\~/}" ;;
    '$HOME'*) word="$home${word#\$HOME}" ;;
    '${HOME}'*) word="$home${word#\$\{HOME\}}" ;;
    '$PWD'*) [ -n "$cwd" ] || return 1; word="$cwd${word#\$PWD}" ;;
    '${PWD}'*) [ -n "$cwd" ] || return 1; word="$cwd${word#\$\{PWD\}}" ;;
  esac

  case "$word" in
    */'**') word="${word%/\*\*}"; DD_NRS_GLOB_CHILDREN=1 ;;
    */'*') word="${word%/\*}"; DD_NRS_GLOB_CHILDREN=1 ;;
    */'.*') word="${word%/.\*}"; DD_NRS_GLOB_CHILDREN=1 ;;
    '*'|'**') word="."; DD_NRS_GLOB_CHILDREN=1 ;;
  esac
  [ -z "$word" ] && word="/"

  case "$word" in
    *'$'*|*'`'*|*'*'*|*'?'*|*'['*) return 1 ;;
  esac

  case "$word" in
    /*) ;;
    *) [ -n "$cwd" ] || return 1; word="$cwd/$word" ;;
  esac

  local IFS='/'
  local -a parts=() kept=()
  read -ra parts <<< "$word"
  for part in "${parts[@]}"; do
    case "$part" in
      ''|.) ;;
      ..) [ ${#kept[@]} -gt 0 ] && unset "kept[$(( ${#kept[@]} - 1 ))]" && kept=("${kept[@]}") ;;
      *) kept+=("$part") ;;
    esac
  done
  out="/${kept[*]}"
  case "$out" in
    /System/Volumes/Data) out="/" ;;
    /System/Volumes/Data/*) out="${out#/System/Volumes/Data}" ;;
  esac
  printf '%s\n' "$out"
}

# allow-comment: dd_nrs_root_limit <absolute path> prints the deepest -maxdepth that still stays out of other apps' data for a guarded root, and returns 1 for a path that is not guarded. Depth 2 from / or the users directory lists home directories without opening them; depth 1 from the home directory, its Library, or a container directory only lists names.
dd_nrs_root_limit() {
  local path="$1" home parent
  home="$(dd_nrs_home)"
  parent="${home%/*}"
  [ -z "$parent" ] && parent="/"
  case "$path" in
    /|/Users|/home) echo 2; return 0 ;;
    /Volumes) echo 1; return 0 ;;
  esac
  [ "$path" = "$parent" ] && { echo 2; return 0; }
  [ "$home" = "/" ] && return 1
  case "$path" in
    "$home"|"$home/Library"|"$home/Library/Containers"|"$home/Library/Group Containers") echo 1; return 0 ;;
  esac
  return 1
}

# allow-comment: dd_nrs_judge <word> <cwd> <depth> records a hit when the word resolves to a guarded root and the search is not shallow enough to stay out of app data.
dd_nrs_judge() {
  local word="$1" cwd="$2" depth="$3" path limit
  path=$(dd_nrs_normalize "$word" "$cwd") || return 0
  limit=$(dd_nrs_root_limit "$path") || return 0
  [ "$DD_NRS_GLOB_CHILDREN" = "1" ] && limit=$((limit - 1))
  case "$depth" in
    ''|*[!0-9]*) ;;
    *) [ "$depth" -le "$limit" ] && return 0 ;;
  esac
  if [ "$word" = "$path" ]; then
    DD_NRS_HIT="$path"
  else
    DD_NRS_HIT="$word (resolves to $path)"
  fi
}

dd_nrs_in_list() {
  case " $2 " in
    *" $1 "*) return 0 ;;
    *) return 1 ;;
  esac
}

dd_nrs_emit_command() {
  [ ${#words[@]} -eq 0 ] && { piped="$next_piped"; return 0; }
  local IFS="$DD_NRS_SEP"
  printf '%s%s%s\n' "$piped" "$DD_NRS_SEP" "${words[*]}"
  words=()
  piped="$next_piped"
}

dd_nrs_emit_word() {
  if [ "$has" = "1" ]; then
    if [ "$redirect" = "1" ]; then
      redirect=0
    else
      words+=("${word//$'\n'/ }")
    fi
  fi
  word=""
  has=0
}

# allow-comment: dd_nrs_substitution_end <text> <index after the opening parenthesis> prints the index of the matching closing parenthesis, skipping single-quoted spans.
dd_nrs_substitution_end() {
  local text="$1" i="$2" n=${#1} depth=1 ch in_single=0
  while [ "$i" -lt "$n" ]; do
    ch="${text:i:1}"
    if [ "$in_single" = "1" ]; then
      [ "$ch" = "'" ] && in_single=0
    else
      case "$ch" in
        "'") in_single=1 ;;
        '(') depth=$((depth + 1)) ;;
        ')') depth=$((depth - 1)); [ "$depth" -eq 0 ] && break ;;
      esac
    fi
    i=$((i + 1))
  done
  echo "$i"
}

# allow-comment: dd_nrs_scan <shell text> prints one simple command per line as "<piped flag><SEP><word><SEP><word>...", with quotes removed from words, redirect targets and heredoc bodies dropped, comments skipped, and command substitutions scanned as commands of their own. Quoted text stays inside its word, so a search command named in a commit message or an echo is data and never a command. The piped flag is 1 when the command reads the previous command's output, because a pattern search without a path then reads stdin instead of walking the current directory.
dd_nrs_scan() {
  local text="$1" n=${#1} i=0 ch next word="" has=0 quote="" redirect=0 piped=0 next_piped=0 end inner tag line
  local -a words=() tags=()
  local LC_ALL=C run plain_in_double='^[^"\$]+' plain_unquoted='^[A-Za-z0-9_./:=,@%+~-]+'
  n=${#text}

  while [ "$i" -lt "$n" ]; do
    ch="${text:i:1}"
    next="${text:i+1:1}"

    if [ "$quote" = "'" ]; then
      run="${text:i}"
      run="${run%%\'*}"
      word+="$run"; quote=""
      i=$((i + ${#run} + 1)); continue
    fi

    if [ "$quote" = '"' ]; then
      if [[ "${text:i}" =~ $plain_in_double ]]; then
        word+="${BASH_REMATCH[0]}"
        i=$((i + ${#BASH_REMATCH[0]})); continue
      fi
      if [ "$ch" = '\' ]; then
        word+="$next"; i=$((i + 2)); continue
      fi
      if [ "$ch" = '"' ]; then quote=""; i=$((i + 1)); continue; fi
      if [ "$ch" = '$' ] && [ "$next" = '(' ]; then
        end=$(dd_nrs_substitution_end "$text" $((i + 2)))
        inner="${text:i+2:end-i-2}"
        dd_nrs_scan "$inner"
        word+='$()'; i=$((end + 1)); continue
      fi
      word+="$ch"; i=$((i + 1)); continue
    fi

    if [[ "${text:i}" =~ $plain_unquoted ]]; then
      word+="${BASH_REMATCH[0]}"; has=1
      i=$((i + ${#BASH_REMATCH[0]})); continue
    fi

    case "$ch" in
      '\')
        if [ "$next" = $'\n' ]; then i=$((i + 2)); continue; fi
        word+="$next"; has=1; i=$((i + 2)); continue
        ;;
      "'"|'"')
        quote="$ch"; has=1
        ;;
      '#')
        if [ "$has" = "0" ]; then
          while [ "$i" -lt "$n" ] && [ "${text:i:1}" != $'\n' ]; do i=$((i + 1)); done
          continue
        fi
        word+="$ch"
        ;;
      '$')
        if [ "$next" = '(' ]; then
          end=$(dd_nrs_substitution_end "$text" $((i + 2)))
          inner="${text:i+2:end-i-2}"
          dd_nrs_scan "$inner"
          word+='$()'; has=1; i=$((end + 1)); continue
        fi
        word+="$ch"; has=1
        ;;
      '<'|'>')
        if [ "$ch" = '<' ] && [ "$next" = '<' ] && [ "${text:i+2:1}" != '<' ]; then
          dd_nrs_emit_word
          i=$((i + 2))
          [ "${text:i:1}" = '-' ] && i=$((i + 1))
          while [ "${text:i:1}" = ' ' ] || [ "${text:i:1}" = $'\t' ]; do i=$((i + 1)); done
          tag=""
          while [ "$i" -lt "$n" ]; do
            case "${text:i:1}" in
              ' '|$'\t'|$'\n'|';'|'&'|'|'|')'|'<'|'>') break ;;
              "'"|'"'|'\') ;;
              *) tag+="${text:i:1}" ;;
            esac
            i=$((i + 1))
          done
          [ -n "$tag" ] && tags+=("$tag")
          continue
        fi
        case "$word" in
          ''|*[!0-9]*) dd_nrs_emit_word ;;
          *) word=""; has=0 ;;
        esac
        i=$((i + 1))
        while :; do
          case "${text:i:1}" in
            '<'|'>'|'&'|'|'|' '|$'\t') i=$((i + 1)) ;;
            *) break ;;
          esac
        done
        redirect=1
        continue
        ;;
      ' '|$'\t')
        dd_nrs_emit_word
        ;;
      $'\n')
        dd_nrs_emit_word
        next_piped=0
        dd_nrs_emit_command
        i=$((i + 1))
        for tag in ${tags[@]+"${tags[@]}"}; do
          while [ "$i" -lt "$n" ]; do
            line="${text:i}"
            line="${line%%$'\n'*}"
            i=$((i + ${#line} + 1))
            while [ "${line:0:1}" = $'\t' ]; do line="${line:1}"; done
            [ "$line" = "$tag" ] && break
          done
        done
        tags=()
        continue
        ;;
      '|')
        dd_nrs_emit_word
        if [ "$next" = '|' ]; then
          next_piped=0; i=$((i + 1))
        else
          next_piped=1
          [ "$next" = '&' ] && i=$((i + 1))
        fi
        dd_nrs_emit_command
        ;;
      ';'|'&'|'('|')'|'`')
        dd_nrs_emit_word
        next_piped=0
        dd_nrs_emit_command
        ;;
      *)
        word+="$ch"; has=1
        ;;
    esac
    i=$((i + 1))
  done
  dd_nrs_emit_word
  next_piped=0
  dd_nrs_emit_command
}

# allow-comment: dd_nrs_collect reads the caller's args array for one search tool and fills roots, depth and has_pattern. valopts take a value, patopts carry the search pattern, pathopts carry a search root, depthopts carry the recursion limit, stopopts end option parsing because the rest is a command template.
dd_nrs_collect() {
  local valopts="$1" patopts="$2" patflags="$3" pathopts="$4" depthopts="$5" stopopts="$6"
  local idx=0 count=${#args[@]} arg name value short only_positional=0
  while [ "$idx" -lt "$count" ]; do
    arg="${args[idx]}"
    idx=$((idx + 1))
    if [ "$only_positional" = "1" ]; then roots+=("$arg"); continue; fi
    case "$arg" in
      --) only_positional=1; continue ;;
      --*=*)
        name="${arg%%=*}"; value="${arg#*=}"
        dd_nrs_in_list "$name" "$depthopts" && depth="$value"
        dd_nrs_in_list "$name" "$pathopts" && explicit_roots+=("$value")
        dd_nrs_in_list "$name" "$patopts" && has_pattern=1
        continue
        ;;
      -?*)
        dd_nrs_in_list "$arg" "$stopopts" && return 0
        name="$arg"
        case "$arg" in
          --*) ;;
          -??*) short="-${arg: -1}"; name="$short" ;;
        esac
        dd_nrs_in_list "$name" "$patflags" && has_pattern=1
        if dd_nrs_in_list "$name" "$patopts"; then
          has_pattern=1; idx=$((idx + 1)); continue
        fi
        if dd_nrs_in_list "$name" "$pathopts"; then
          [ "$idx" -lt "$count" ] && explicit_roots+=("${args[idx]}")
          idx=$((idx + 1)); continue
        fi
        if dd_nrs_in_list "$name" "$depthopts"; then
          [ "$idx" -lt "$count" ] && depth="${args[idx]}"
          idx=$((idx + 1)); continue
        fi
        dd_nrs_in_list "$name" "$valopts" && idx=$((idx + 1))
        continue
        ;;
    esac
    roots+=("$arg")
  done
}

dd_nrs_collect_find() {
  local idx=0 count=${#args[@]} arg
  while [ "$idx" -lt "$count" ]; do
    arg="${args[idx]}"
    case "$arg" in
      -H|-L|-P|-E|-X|-d|-s|-x|-O*) idx=$((idx + 1)) ;;
      -D|-S) idx=$((idx + 2)) ;;
      -f) [ $((idx + 1)) -lt "$count" ] && roots+=("${args[idx+1]}"); idx=$((idx + 2)) ;;
      -*|'('|'!') break ;;
      *) roots+=("$arg"); idx=$((idx + 1)) ;;
    esac
  done
  while [ "$idx" -lt "$count" ]; do
    if [ "${args[idx]}" = "-maxdepth" ] && [ $((idx + 1)) -lt "$count" ]; then
      depth="${args[idx+1]}"
    fi
    idx=$((idx + 1))
  done
}

# allow-comment: dd_nrs_check_command <piped flag> <word>... inspects one simple command: it follows cd so a later relative search resolves against the right directory, unwraps sh -c style strings, and judges every search root of a recursive search tool.
dd_nrs_check_command() {
  local piped="$1"; shift
  local -a args=() roots=() explicit_roots=()
  local tool depth="" has_pattern=0 pattern_first=0 stdin_capable=0 root resolved idx

  while [ $# -gt 0 ]; do
    case "$1" in
      [A-Za-z_]*=*) [[ "$1" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]] || break; shift ;;
      '{'|'!'|then|do|else|elif|if|while|until|time|command|exec|nohup|builtin|noglob) shift ;;
      nice) shift; [ "${1:-}" = "-n" ] && shift 2 ;;
      sudo|doas|env)
        shift
        while [ $# -gt 0 ]; do
          case "$1" in
            -*) shift ;;
            *) break ;;
          esac
        done
        ;;
      *) break ;;
    esac
  done
  [ $# -eq 0 ] && return 0

  tool="${1##*/}"; shift
  args=("$@")

  case "$tool" in
    cd|pushd)
      [ "${1:-}" = "--" ] && shift
      if [ $# -eq 0 ]; then
        DD_NRS_CWD="$(dd_nrs_home)"
      elif [ "$1" != "-" ]; then
        resolved=$(dd_nrs_normalize "$1" "$DD_NRS_CWD") && DD_NRS_CWD="$resolved" || DD_NRS_CWD=""
      fi
      return 0
      ;;
    bash|sh|zsh|dash|ksh)
      idx=0
      while [ "$idx" -lt ${#args[@]} ]; do
        if [[ "${args[idx]}" =~ ^-[A-Za-z]*c$ ]] && [ $((idx + 1)) -lt ${#args[@]} ]; then
          dd_nrs_inspect "${args[idx+1]}"
          return 0
        fi
        idx=$((idx + 1))
      done
      return 0
      ;;
    eval)
      dd_nrs_inspect "$*"
      return 0
      ;;
    find|gfind|bfs)
      dd_nrs_collect_find
      ;;
    rg|ripgrep)
      pattern_first=1; stdin_capable=1
      dd_nrs_collect "-g -t -T -A -B -C -m -j -M -r -E --glob --iglob --type --type-not --type-add --max-count --context --after-context --before-context --threads --sort --sortr --color --colors --encoding --engine --max-filesize --max-columns --path-separator --pre --pre-glob --replace --ignore-file" "-e --regexp -f --file" "--files --type-list" "" "-d --max-depth" ""
      ;;
    grep|egrep|fgrep|ggrep|zgrep)
      local recursive=0
      for root in ${args[@]+"${args[@]}"}; do
        case "$root" in
          --recursive|--dereference-recursive) recursive=1 ;;
          --*) ;;
          -*[rR]*) recursive=1 ;;
        esac
      done
      [ "$recursive" = "1" ] || return 0
      pattern_first=1; stdin_capable=1
      dd_nrs_collect "-A -B -C -m -d -D --include --exclude --exclude-dir --context --after-context --before-context --max-count --color --colour --label" "-e --regexp -f --file" "" "" "" ""
      ;;
    ag)
      pattern_first=1; stdin_capable=1
      dd_nrs_collect "-A -B -C -m -G -p --ignore --ignore-dir --file-search-regex --path-to-ignore --max-count --after --before --context --workers --pager" "-g" "" "" "--depth" ""
      ;;
    ack)
      pattern_first=1; stdin_capable=1
      dd_nrs_collect "-A -B -C -m --type --ignore-dir --ignore-file --max-count --context --after-context --before-context --output --pager" "-g --match" "-f" "" "" ""
      ;;
    fd|fdfind)
      pattern_first=1
      dd_nrs_collect "-e -t -E -S -o -j -c --extension --type --exclude --min-depth --exact-depth --size --owner --changed-within --changed-before --newer --older --color --threads --max-results --path-separator --format --ignore-file --and" "" "" "--search-path --base-directory" "-d --max-depth --maxdepth" "-x -X --exec --exec-batch"
      ;;
    tree)
      dd_nrs_collect "-P -I -o -H -T --charset --filelimit --sort --timefmt" "" "" "" "-L" ""
      ;;
    du)
      dd_nrs_collect "-d -I -t -B --max-depth --exclude --threshold --block-size --time-style" "" "" "" "" ""
      ;;
    ls|gls)
      local lists_recursively=0
      for root in ${args[@]+"${args[@]}"}; do
        case "$root" in
          --recursive) lists_recursively=1 ;;
          --*) ;;
          -*R*) lists_recursively=1 ;;
        esac
      done
      [ "$lists_recursively" = "1" ] || return 0
      dd_nrs_collect "-D -w -I --ignore --hide --color --block-size --time-style" "" "" "" "" ""
      ;;
    *)
      return 0
      ;;
  esac

  if [ "$pattern_first" = "1" ] && [ "$has_pattern" = "0" ] && [ ${#roots[@]} -gt 0 ]; then
    roots=("${roots[@]:1}")
  fi
  roots+=(${explicit_roots[@]+"${explicit_roots[@]}"})
  if [ ${#roots[@]} -eq 0 ]; then
    [ "$stdin_capable" = "1" ] && [ "$piped" = "1" ] && return 0
    roots=(".")
  fi

  for root in "${roots[@]}"; do
    dd_nrs_judge "$root" "$DD_NRS_CWD" "$depth"
    if [ -n "$DD_NRS_HIT" ]; then
      DD_NRS_HIT="$tool on $DD_NRS_HIT"
      return 0
    fi
  done
}

dd_nrs_inspect() {
  local text="$1" line piped
  local -a fields=()
  while IFS= read -r line; do
    [ -n "$DD_NRS_HIT" ] && continue
    piped="${line%%"$DD_NRS_SEP"*}"
    line="${line#*"$DD_NRS_SEP"}"
    IFS="$DD_NRS_SEP" read -ra fields <<< "$line"
    [ ${#fields[@]} -eq 0 ] && continue
    dd_nrs_check_command "$piped" "${fields[@]}"
  done < <(dd_nrs_scan "$text")
}

DD_NRS_ADVICE="Walking it reads other apps' private data (on macOS one privacy prompt per app for the operator) and runs for many minutes. Search the specific directory that can hold the answer. To locate an installed dependency, ask its package manager: bundle show <gem>, gem contents <gem>, npm ls <pkg>, pip show -f <pkg>, go list -m -f '{{.Dir}}' <module>. To find a file by name anywhere, query the file index: mdfind -name <file> on macOS, locate <file> elsewhere."

guard_no_root_search() {
  local input="$1" cmd
  cmd=$(jq -r '.tool_input.command // empty' <<< "$input" 2>/dev/null)
  [ -z "$cmd" ] && return 0

  grep -Eq '(^|[^[:alnum:]_.-])(find|gfind|bfs|fd|fdfind|rg|ripgrep|e?grep|fgrep|ggrep|zgrep|ag|ack|tree|du|g?ls)([[:space:]]|$)' <<< "$cmd" || return 0
  grep -q -- '# allow-root-search' <<< "$cmd" && return 0

  DD_NRS_HIT=""
  DD_NRS_CWD=$(jq -r '.cwd // .tool_input.cwd // empty' <<< "$input" 2>/dev/null)
  DD_NRS_CWD=$(dd_nrs_normalize "${DD_NRS_CWD:-/nonexistent-cwd}" "") || DD_NRS_CWD=""
  [ "$DD_NRS_CWD" = "/nonexistent-cwd" ] && DD_NRS_CWD=""

  dd_nrs_inspect "$cmd"
  [ -z "$DD_NRS_HIT" ] && return 0

  dd_emit_deny no-root-search "Whole-disk search blocked: $DD_NRS_HIT. $DD_NRS_ADVICE A shallow listing (-maxdepth 1) passes. Append '# allow-root-search' only when the operator asked for a search of that whole tree."
}
