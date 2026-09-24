#!/bin/bash
# packages/git-discipline/hooks/guards/push-wip-gate.sh
# PreToolUse:Bash guard. Blocks `git push` when the push range contains one or
# more commits whose body carries `Slice: wip`.
#
# The shared logic lives in hooks/lib/wip-gate.sh and is also driven by the
# git-native pre-push hook installed by /git-discipline:install-hooks. Both paths feed
# the same parser; whichever fires first stops the push.
#
# Parsing simplification.
#   `git push` accepts a great variety of refspecs, options, and remote
#   shorthands. Re-implementing git's own parser here is out of scope. The
#   guard handles the two common shapes:
#     1. Bare `git push` (no remote, no refspec)         -> scope to the default branch.
#     2. `git push <remote>` (no refspec)                -> scope to the default branch.
#     3. `git push <remote> <branch>`                    -> also exclude <remote>/<branch>.
#     4. `git push <remote> <local>:<remote-branch>`     -> also exclude <remote>/<remote-branch>.
#   wip_gate_resolve_push_range in hooks/lib/wip-gate.sh owns the exact ranges.
#   allow-comment: workaround for the 50-commit fallback that re-validated already-pushed commits and tripped parallel sessions; exotic forms now scan HEAD~1..HEAD only.
#
# Bypass paths.
#   - GIT_DISCIPLINE_ALLOW_WIP_PUSH=1 in the bash command (or shell env).
#   - The literal string "# allow-wip-push" anywhere in the bash command.
#   - --force, --force-with-lease do NOT bypass; force-vs-non-force is
#     orthogonal to wip-vs-clean.

guard_push_wip_gate() {
  local input="$1"
  local command
  command=$(jq -r '.tool_input.command // empty' <<< "$input" 2>/dev/null)
  [[ -z "$command" ]] && return 0

  dd_is_git_push_command "$command" || return 0

  # Source the shared lib.
  local DIR
  DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  # shellcheck disable=SC1091
  source "$DIR/lib/wip-gate.sh"

  # ---------------------------------------------------------------------------
  # Determine the range to scan.
  # ---------------------------------------------------------------------------

  local current_branch
  current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)

  local range
  range=$(wip_gate_resolve_push_range "$command")

  [[ -z "$range" ]] && return 0

  # ---------------------------------------------------------------------------
  # Find wip commits and decide.
  # ---------------------------------------------------------------------------

  local wip_list
  wip_list=$(wip_gate_find_wip_commits "$range")

  local wip_count=0
  if [[ -n "$wip_list" ]]; then
    wip_count=$(printf '%s\n' "$wip_list" | grep -c .)
  fi

  if wip_gate_should_block "$command" "$wip_count"; then
    local msg
    msg=$(wip_gate_format_message "$wip_list")
    dd_emit_deny "push-wip-gate" "$msg"
    return 0  # unreached; dd_emit_deny exits 2.
  fi

  # If we are here either there were no wip commits, or a bypass was active.
  if [[ "$wip_count" -gt 0 ]]; then
    local mechanism=""
    if [[ "${GIT_DISCIPLINE_ALLOW_WIP_PUSH:-0}" = "1" ]]; then
      mechanism="env"
    elif grep -qF '# allow-wip-push' <<< "$command"; then
      mechanism="magic-comment"
    else
      # wip_gate_should_block returned 1 (allow) without a known bypass.
      # This should not happen; log a BUG notice to stderr and skip the log.
      printf '[git-discipline/push-wip-gate] BUG: bypass without recognised mechanism\n' >&2
      return 0
    fi
    local sha_csv
    sha_csv=$(printf '%s' "$wip_list" | tr '\n' ',' | sed 's/,$//')
    wip_gate_log_bypass "$sha_csv" "${current_branch:-unknown}" "$mechanism"
  fi

  return 0
}
