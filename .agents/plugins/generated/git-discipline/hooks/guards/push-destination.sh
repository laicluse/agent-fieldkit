#!/bin/bash
# allow-comment: PreToolUse:Bash guard. Hands a pending push to bin/judge-push, which reads where the push goes and what that means for this repository, and denies a push whose consequence needs the operator's agreement (or that the repository's agreement rules out). A push that belongs to ordered work passes without a word. Fails open when node is missing, so a broken toolchain never blocks all pushes.

guard_push_destination() {
  local input="$1"

  [[ "${GIT_DISCIPLINE_PUSH_DESTINATION_DISABLED:-0}" = "1" ]] && return 0

  local command
  command=$(jq -r '.tool_input.command // empty' <<< "$input" 2>/dev/null)
  [[ -z "$command" ]] && return 0
  dd_is_git_push_command "$command" || return 0

  local guard_dir judge node_bin verdict reason result
  guard_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  judge="$guard_dir/../../bin/judge-push"
  node_bin=$(command -v node 2>/dev/null) || return 0
  [[ -f "$judge" ]] || return 0

  result=$(printf '%s' "$input" | "$node_bin" "$judge" 2>/dev/null) || return 0
  verdict=$(jq -r '.verdict // "allow"' <<< "$result" 2>/dev/null)
  reason=$(jq -r '.reason // empty' <<< "$result" 2>/dev/null)

  case "$verdict" in
    agree) dd_emit_deny "push-destination" "Push held for agreement. $reason" ;;
    never) dd_emit_deny "push-destination" "Push refused. $reason" ;;
  esac
  return 0
}
