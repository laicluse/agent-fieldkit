#!/bin/bash
# PreToolUse:Bash guard. Denies inline code in a language the project does not use, such as a python3 heredoc in a Go repository. allow-comment: a helper written in the project's own language can grow into its real code; one in another language is thrown away, and prose rules did not stop the reflex.

dd_manifest_languages_up_to_toplevel() {
  local dir top
  dir=$(cd "$1" 2>/dev/null && pwd -P) || return 0
  top=$(cd "$dir" && git rev-parse --show-toplevel 2>/dev/null) && top=$(cd "$top" && pwd -P) || top="$dir"
  while :; do
    [ -e "$dir/go.mod" ] && echo Go
    [ -e "$dir/Cargo.toml" ] && echo Rust
    [ -e "$dir/Package.swift" ] && echo Swift
    [ -e "$dir/Gemfile" ] && echo Ruby
    [ -e "$dir/mix.exs" ] && echo Elixir
    { [ -e "$dir/package.json" ] || [ -e "$dir/deno.json" ]; } && echo JavaScript
    { [ -e "$dir/pyproject.toml" ] || [ -e "$dir/setup.py" ] || [ -e "$dir/setup.cfg" ] || [ -e "$dir/requirements.txt" ] || [ -e "$dir/Pipfile" ]; } && echo Python
    { [ "$dir" = "$top" ] || [ "$dir" = "/" ]; } && break
    dir=$(dirname "$dir")
  done
}

dd_command_with_opaque_quotes() {
  local seg="$1" out="" quote="" ch i
  for (( i=0; i<${#seg}; i++ )); do
    ch="${seg:i:1}"
    if [ -n "$quote" ]; then
      if [ "$ch" = '\' ] && [ "$quote" = '"' ]; then
        i=$((i + 1))
        out+="xx"
      elif [ "$ch" = "$quote" ]; then
        quote=""
        out+="x"
      else
        out+="x"
      fi
      continue
    fi
    case "$ch" in
      \'|\") quote="$ch"; out+="x" ;;
      *) out+="$ch" ;;
    esac
  done
  printf '%s\n' "$out"
}

dd_language_of_inline_program() {
  local -a words
  read -r -a words <<< "$1"
  local i=0 lang="" inline_flag=""
  while [ $i -lt ${#words[@]} ]; do
    case "${words[$i]}" in
      *=*|env|nice|exec|command|time|sudo) i=$((i + 1)) ;;
      *) break ;;
    esac
  done
  case "${words[$i]##*/}" in
    python|python3|python3.*) lang=Python; inline_flag=-c ;;
    ruby) lang=Ruby; inline_flag=-e ;;
    node|bun|deno) lang=JavaScript; inline_flag=-e ;;
    *) return 0 ;;
  esac
  local word option_takes_value=""
  for word in "${words[@]:$((i + 1))}"; do
    if [ -n "$option_takes_value" ]; then
      option_takes_value=""
      continue
    fi
    case "$word" in
      "$inline_flag"*|-|-p|"<"*) echo "$lang"; return 0 ;;
      -W|-X) [ "$lang" = Python ] && option_takes_value=1 ;;
      -I|-r|--require) [ "$lang" != Python ] && option_takes_value=1 ;;
      --version|-V|--help|-h) return 0 ;;
      -*) ;;
      *) return 0 ;;
    esac
  done
  echo "$lang"
}

guard_project_language() {
  local input="$1" cmd hook_cwd target seg lang languages
  cmd=$(jq -r '.tool_input.command // empty' <<< "$input" 2>/dev/null)
  [ -z "$cmd" ] && return 0
  [[ "$cmd" == *"# other-language:"* ]] && return 0

  hook_cwd=$(jq -r '.cwd // .tool_input.cwd // empty' <<< "$input" 2>/dev/null)
  { [ -n "$hook_cwd" ] && [ -d "$hook_cwd" ]; } || hook_cwd="$PWD"
  target="$hook_cwd"
  if [[ "$cmd" =~ ^[[:space:]]*cd[[:space:]]+(\"[^\"]+\"|\'[^\']+\'|[^[:space:]\&]+)[[:space:]]*\&\& ]]; then
    target="${BASH_REMATCH[1]}"
    target="${target#\"}"; target="${target%\"}"
    target="${target#\'}"; target="${target%\'}"
    target="${target/#\~/$HOME}"
    [[ "$target" == /* ]] || target="$hook_cwd/$target"
  fi

  while IFS= read -r seg; do
    lang=$(dd_language_of_inline_program "$(dd_command_with_opaque_quotes "$seg")")
    [ -n "$lang" ] || continue
    languages=$(dd_manifest_languages_up_to_toplevel "$target" | sort -u)
    [ -n "$languages" ] || return 0
    grep -qx "$lang" <<< "$languages" && continue
    dd_emit_deny project-language "Inline ${lang} in a $(paste -sd/ - <<< "$languages") project. Write this helper in $(head -n1 <<< "$languages") instead, where it can grow into the project's own code (a test, a cmd tool or the feature itself); shape JSON with jq or gh --jq. Only when this step has no route in the project's language at all, append '# other-language: <reason>' to the command."
  done < <(dd_command_segments "$cmd")
}
