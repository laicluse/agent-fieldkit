#!/bin/bash
# packages/git-discipline/hooks/guards/merge-conflict-markers.sh
# PreToolUse:Bash guard. Blocks a command that finalizes a conflict resolution
# (any git commit, or git merge/rebase/cherry-pick/am/revert --continue) while one
# or more tracked files still hold a leftover conflict marker, so a half-resolved
# merge can never land in a live checkout. The deny names the files. A clean tree
# passes silently.
#
# Detection is shared with the git-native commit-msg hook via
# hooks/lib/conflict-markers.sh; both layers reach the same verdict.
#
# Escape (rare, e.g. markers deliberately present in a fixture):
#   export GIT_DISCIPLINE_ALLOW_CONFLICT_MARKERS=1   (env, both layers)
#   git commit ...   # allow-conflict-markers        (magic comment, this layer only)
#
# Requires: hooks/lib/common.sh (dd_is_git_commit_command, dd_strip_commit_message),
# already sourced by dispatch.sh before this guard. Mirrors push-wip-gate.sh.

# _mcm_is_finalizing_command <bash-command>
# True for any `git commit` or a `git (merge|rebase|cherry-pick|am|revert) ...
# --continue`. The message body is stripped first so a marker phrase in it does
# not count. The --continue match anchors `git` to a command position and requires
# --continue as a discrete token; like dd_is_git_push_command it does not chase a
# git command quoted as an argument (`echo git merge --continue`) -- an accepted
# limitation shared across the git-discipline command predicates.
_mcm_is_finalizing_command() {
  local command="$1"
  dd_is_git_commit_command "$command" && return 0
  local stripped
  stripped=$(dd_strip_commit_message "$command")
  local pre='(^|[[:space:];&|(])'
  local opts='((-[^[:space:]]+)([[:space:]]+[^-][^[:space:]]*)?[[:space:]]+)*'
  [[ "$stripped" =~ ${pre}git[[:space:]]+${opts}(merge|rebase|cherry-pick|am|revert)[[:space:]].*--continue([[:space:];&|]|$) ]] && return 0
  return 1
}

guard_merge_conflict_markers() {
  local input="$1"
  local command
  command=$(jq -r '.tool_input.command // empty' <<< "$input" 2>/dev/null)
  [[ -z "$command" ]] && return 0

  _mcm_is_finalizing_command "$command" || return 0

  local DIR
  DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  # shellcheck disable=SC1091
  source "$DIR/lib/conflict-markers.sh"

  conflict_markers_escape_active "$command" && return 0

  local files
  files=$(conflict_markers_find_files)
  [[ -z "$files" ]] && return 0

  local msg
  msg=$(conflict_markers_format_message "$files")
  dd_emit_deny "merge-conflict-markers" "$msg"
}
