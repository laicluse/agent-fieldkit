#!/bin/bash
# allow-comment: PreToolUse:Bash guard. Surfaces Co-Authored-By: anthropic.com in the commit message and instructs an amend that strips the trailer. Bypass with GIT_DISCIPLINE_ALLOW_AI_COAUTHOR=1 when the AI co-author trailer is genuinely desired.

guard_commit_trailers() {
  local input="$1"
  local command
  command=$(jq -r '.tool_input.command // empty' <<< "$input" 2>/dev/null)
  dd_is_git_commit_command "$command" || return 0

  [[ "${GIT_DISCIPLINE_ALLOW_AI_COAUTHOR:-0}" = "1" ]] && return 0

  local message
  message=$(dd_extract_commit_message "$command")
  [[ -z "$message" ]] && return 0

  if grep -qiE '^[[:space:]]*Co-Authored-By:[[:space:]].*@anthropic\.com' <<< "$message"; then
    dd_emit_pre_context "commit-trailers" "Co-Authored-By: anthropic.com trailer in commit message. The commit will land regardless; amend afterwards to strip the trailer (git commit --amend -F <new-message-file>). Set GIT_DISCIPLINE_ALLOW_AI_COAUTHOR=1 if the anthropic co-author trailer is genuinely desired here."
  fi
}
