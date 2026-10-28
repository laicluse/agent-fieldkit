#!/bin/bash
# allow-comment: PreToolUse:Bash guard. Denies a command substitution nested inside another one, such as echo "$(cmd "$(inner)")". Claude Code's permission check cannot statically resolve such a command and asks the operator, even in bypass mode, so an unattended session stalls on a prompt nobody needed. Single-quoted spans and the bodies of quoted heredocs (<<'EOF') are data and are skipped, because writing a script file through such a heredoc is the way out.

# allow-comment: dd_ns_has_nested <text> returns 0 when a $( opens while another $( is still open. The paren stack tells a substitution (S) from arithmetic (A), a case statement (C) and a subshell or group (P): only the ) that closes an S lowers the depth, the )) that closes an A is consumed whole, and a ) above a C ends a case pattern. S and A each start their own quoting context, so the double-quote state is kept per level. Comments and quoted heredoc bodies are skipped; the rest of a heredoc opener line is still code.
dd_ns_has_nested() {
  local text="$1" n=${#1} i=0 ch next prev depth=0 lvl=0 in_single=0 line tag top
  local -a dq=(0) stack=() tags=()
  while [ "$i" -lt "$n" ]; do
    ch="${text:i:1}"
    next="${text:i+1:1}"
    if [ "$in_single" = "1" ]; then
      [ "$ch" = "'" ] && in_single=0
      i=$((i + 1)); continue
    fi
    if [ "$ch" = '$' ] && [ "$next" = '(' ]; then
      if [ "${text:i+2:1}" = '(' ]; then
        stack+=(A); lvl=$((lvl + 1)); dq[lvl]=0; i=$((i + 3)); continue
      fi
      [ "$depth" -ge 1 ] && return 0
      stack+=(S); depth=$((depth + 1)); lvl=$((lvl + 1)); dq[lvl]=0; i=$((i + 2)); continue
    fi
    if [ "${dq[lvl]}" = "1" ]; then
      case "$ch" in
        '\') i=$((i + 2)); continue ;;
        '"') dq[lvl]=0 ;;
      esac
      i=$((i + 1)); continue
    fi
    case "$ch" in
      '\') i=$((i + 2)); continue ;;
      '"') dq[lvl]=1 ;;
      "'") in_single=1 ;;
      '#')
        prev="${text:i-1:1}"
        if [ "$i" -eq 0 ] || [[ "$prev" =~ [[:space:]\;\&\|\(] ]]; then
          line="${text:i}"; line="${line%%$'\n'*}"
          i=$((i + ${#line})); continue
        fi
        ;;
      $'\n')
        i=$((i + 1))
        for tag in ${tags[@]+"${tags[@]}"}; do
          while [ "$i" -lt "$n" ]; do
            line="${text:i}"; line="${line%%$'\n'*}"
            i=$((i + ${#line} + 1))
            while [ "${line:0:1}" = $'\t' ]; do line="${line:1}"; done
            [ "$line" = "$tag" ] && break
          done
        done
        tags=()
        continue
        ;;
      '<')
        if [ "$next" = '<' ] && [[ "${text:i+2}" =~ ^(-?[[:space:]]*[\'\"]([A-Za-z_][A-Za-z0-9_]*)[\'\"]) ]]; then
          tags+=("${BASH_REMATCH[2]}")
          i=$((i + 2 + ${#BASH_REMATCH[1]})); continue
        fi
        ;;
      c|e)
        prev="${text:0:i}"
        prev="${prev%"${prev##*[![:blank:]]}"}"
        if [ -z "$prev" ] || [[ "${prev: -1}" =~ [\;\&\|\(\{$'\n'] ]] || [[ "$prev" =~ (^|[[:space:]\;])(do|then|else)$ ]]; then
          if [[ "${text:i}" =~ ^case[[:space:]] ]]; then
            stack+=(C); i=$((i + 4)); continue
          fi
          if [[ "${text:i}" =~ ^esac([[:space:]\;\&\|\)]|$) ]] && [ ${#stack[@]} -gt 0 ] && [ "${stack[${#stack[@]}-1]}" = "C" ]; then
            unset 'stack[${#stack[@]}-1]'; i=$((i + 4)); continue
          fi
        fi
        ;;
      '(') stack+=(P) ;;
      ')')
        if [ ${#stack[@]} -gt 0 ] && [ "${stack[${#stack[@]}-1]}" != "C" ]; then
          top="${stack[${#stack[@]}-1]}"
          unset 'stack[${#stack[@]}-1]'
          case "$top" in
            S) depth=$((depth - 1)); lvl=$((lvl - 1)) ;;
            A) lvl=$((lvl - 1)); i=$((i + 2)); continue ;;
          esac
        fi
        ;;
    esac
    i=$((i + 1))
  done
  return 1
}

guard_nested_substitution() {
  local input="$1" cmd
  cmd=$(jq -r '.tool_input.command // empty' <<< "$input" 2>/dev/null)
  [ -z "$cmd" ] && return 0
  case "$cmd" in *'$('*'$('*) ;; *) return 0 ;; esac
  grep -q -- '# allow-nested-substitution' <<< "$cmd" && return 0
  dd_ns_has_nested "$cmd" || return 0

  dd_emit_deny nested-substitution "Nested command substitution blocked: a \$( inside another \$( makes Claude Code ask the operator for permission, even in bypass mode. Assign the inner result to a variable first, or write the loop as a script through a quoted heredoc (cat > script.sh <<'EOF' ... EOF) and run it with bash."
}
