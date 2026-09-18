#!/bin/bash
# allow-comment: PreToolUse guard for the host's built-in Grep and Glob tools. They walk the same tree as a shell search and default to the session directory, so a session started in the home directory searches all of it without naming a path. Root classification is shared with the no-root-search Bash guard.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/no-root-search.sh"

# allow-comment: dd_nrs_glob_split <pattern> sets DD_NRS_GLOB_PREFIX to the literal directory prefix and DD_NRS_GLOB_DEPTH to how many levels the rest descends, or "" when a ** makes it unbounded.
dd_nrs_glob_split() {
  local pattern="$1" part prefix="" rest_depth=0 in_rest=0
  local IFS='/'
  local -a parts=()
  read -ra parts <<< "$pattern"
  [ "${pattern:0:1}" = "/" ] && prefix="/"
  for part in "${parts[@]}"; do
    [ -z "$part" ] && continue
    if [ "$in_rest" = "0" ]; then
      case "$part" in
        *'*'*|*'?'*|*'['*|*'{'*) in_rest=1 ;;
        *) prefix="${prefix}${part}/"; continue ;;
      esac
    fi
    case "$part" in
      *'**'*) rest_depth=""; break ;;
    esac
    rest_depth=$((rest_depth + 1))
  done
  DD_NRS_GLOB_PREFIX="${prefix%/}"
  [ "$prefix" = "/" ] && DD_NRS_GLOB_PREFIX="/"
  [ "$in_rest" = "0" ] && rest_depth=0
  DD_NRS_GLOB_DEPTH="$rest_depth"
}

guard_no_root_search_tool() {
  local input="$1" tool cwd path pattern root depth=""
  tool=$(dd_tool_name "$input")
  cwd=$(jq -r '.cwd // empty' <<< "$input" 2>/dev/null)
  path=$(jq -r '.tool_input.path // empty' <<< "$input" 2>/dev/null)
  pattern=$(jq -r '.tool_input.pattern // empty' <<< "$input" 2>/dev/null)
  root="${path:-.}"

  if [ "$tool" = "Glob" ] && [ -n "$pattern" ]; then
    dd_nrs_glob_split "$pattern"
    depth="$DD_NRS_GLOB_DEPTH"
    case "$pattern" in
      /*|'~'*) root="${DD_NRS_GLOB_PREFIX:-/}" ;;
      *) [ -n "$DD_NRS_GLOB_PREFIX" ] && root="$root/$DD_NRS_GLOB_PREFIX" ;;
    esac
  fi

  DD_NRS_HIT=""
  [ -n "$cwd" ] && cwd=$(dd_nrs_normalize "$cwd" "")
  dd_nrs_judge "$root" "$cwd" "$depth"
  [ -z "$DD_NRS_HIT" ] && return 0

  dd_emit_deny no-root-search "Whole-disk search blocked: $tool on $DD_NRS_HIT. $DD_NRS_ADVICE$(dd_nrs_start_hint) Pass a 'path' that names the project or directory to search. When the operator asked for a search of that whole tree, run it as a shell command that ends in '# allow-root-search'."
}
