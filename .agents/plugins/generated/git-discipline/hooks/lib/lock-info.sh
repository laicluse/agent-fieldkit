#!/bin/bash
# packages/git-discipline/hooks/lib/lock-info.sh
# Shared reader for the per-repo lock sentinel (.git/git-discipline-deny).
# Sourced by the PreToolUse guard (guards/repo-deny.sh), by the git-native
# CLI hooks through lib/deny-check.sh, and by the UserPromptExpansion handler
# that writes the file. Keeping the format in one place means the reason a
# repo was locked reads the same whichever path reports it.
#
# File format:
#   line 1  the reason the operator gave (required since the toggle enforces it)
#   line 2  "locked-at: YYYY-MM-DD"
#
# Sentinels written by older versions carry only a reason, or nothing at all;
# both still parse, they just report less.

# dd_lock_suffix <sentinel-path>
# Emits the sentence fragment appended to a deny message: the reason and the
# date it was set, whichever of the two the file carries. Empty when the file
# holds neither, so a bare sentinel still denies without a dangling phrase.
dd_lock_suffix() {
  local sentinel="$1"
  [[ -f "$sentinel" ]] || return 0

  local reason date_line date=""
  reason=$(head -n1 "$sentinel" 2>/dev/null)
  date_line=$(sed -n '2p' "$sentinel" 2>/dev/null)
  if [[ "$date_line" == locked-at:* ]]; then
    date="${date_line#locked-at:}"
    date="${date#"${date%%[![:space:]]*}"}"
  fi

  if [[ -n "$reason" && -n "$date" ]]; then
    printf ' Reason: %s (locked %s).' "$reason" "$date"
  elif [[ -n "$reason" ]]; then
    printf ' Reason: %s.' "$reason"
  elif [[ -n "$date" ]]; then
    printf ' Locked %s.' "$date"
  fi
}
