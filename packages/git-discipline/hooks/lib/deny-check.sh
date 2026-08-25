#!/bin/bash
# packages/git-discipline/hooks/lib/deny-check.sh
# Shared deny-check helper for the git-native CLI hooks (commit-msg,
# pre-push). Mirrors the PreToolUse:Bash guard at hooks/guards/repo-deny.sh
# so the verdict is identical regardless of which path fires first.
#
# Sourced by hooks; never executed directly. Callers invoke
# `deny_check <action>` where <action> is the user-visible verb in the deny
# message ("commit", "push", ...). The function exits 1 when the per-repo
# sentinel is present so the calling hook never returns to its main flow.

deny_check() {
  local action="${1:-operation}"
  local common_dir
  common_dir=$(git rev-parse --git-common-dir 2>/dev/null || true)
  if [[ -z "$common_dir" || ! -f "$common_dir/git-discipline-deny" ]]; then
    return 0
  fi

  # allow-comment: the lock format lives in lib/lock-info.sh so the CLI hooks
  # allow-comment: quote the reason exactly as the PreToolUse guard does. Sourced
  # allow-comment: relative to this file, which the installed hooks reference by
  # allow-comment: absolute plugin path; soft-fails so an older install that
  # allow-comment: predates the helper still denies, just without the reason.
  local reason_part=""
  local lock_lib
  lock_lib="$(dirname "${BASH_SOURCE[0]}")/lock-info.sh"
  if [[ -f "$lock_lib" ]]; then
    # shellcheck disable=SC1090
    . "$lock_lib"
    reason_part=$(dd_lock_suffix "$common_dir/git-discipline-deny")
  fi

  # allow-comment: this path serves a plain terminal and any agent whose host
  # allow-comment: has no PreToolUse guard, so it cannot assume the reader has a
  # allow-comment: /git-discipline slash command. Name the mechanism, then give
  # allow-comment: both routes, and say whose call lifting it is.
  printf '[git-discipline/disable-git] %s blocked by %s/git-discipline-deny.%s This lock is set by the git-discipline plugin for coding agents; it refuses git write commands in this repo until the file is gone. Lifting it is the operator'"'"'s call: type /git-discipline:enable-git in a coding-agent session that has the plugin, or delete %s/git-discipline-deny from your own terminal.\n' \
    "$action" "$common_dir" "$reason_part" "$common_dir" >&2
  exit 1
}
