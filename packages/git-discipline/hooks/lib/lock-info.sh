#!/bin/bash
# packages/git-discipline/hooks/lib/lock-info.sh
# Shared reader and writer for the per-repo lock sentinel
# (.git/git-discipline-deny). Sourced by the PreToolUse guard
# (guards/repo-deny.sh), by the git-native CLI hooks through
# lib/deny-check.sh, and by the UserPromptExpansion handler that writes the
# file. Keeping the format in one place means the reason a repo was locked
# reads the same whichever path reports it.
#
# The file opens with a "#" comment block (see dd_lock_header) and then
# carries "reason:" and "locked-at:" fields, because the reader who finds it
# may be a coding agent that never saw a deny message and has no idea what set
# it. Sentinels written before those labels existed put the reason on the
# first line instead, with or without a "locked-at:" line after it; the
# readers below fall back to that shape so an older lock keeps denying and
# keeps reporting whatever it does carry.

# dd_lock_header
# Emits the comment block that makes the sentinel self-explanatory to whoever
# opens it. Every line starts with "#" so the readers below skip it.
dd_lock_header() {
  cat <<'EOF'
# git-discipline repo lock (coding-agent plugin: git-discipline).
# Git write commands are refused in this repo while this file exists.
# Read-only git (status, log, diff, show, blame) keeps working.
# Lifting it is the operator's call: they type /git-discipline:enable-git in
# their coding-agent session, or delete this file from their own terminal.
# An agent cannot remove it; the sentinel-protect guard denies that.
EOF
}

# dd_lock_write <sentinel-path> <reason> <date>
dd_lock_write() {
  local sentinel="$1" reason="$2" date="$3"
  {
    dd_lock_header
    printf 'reason: %s\n' "$reason"
    printf 'locked-at: %s\n' "$date"
  } > "$sentinel"
}

# _dd_lock_field <sentinel-path> <label>
# Echoes the value of a "label: value" line, ignoring comments.
_dd_lock_field() {
  local sentinel="$1" label="$2" line value
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" == \#* ]] && continue
    if [[ "$line" == "$label":* ]]; then
      value="${line#"$label":}"
      value="${value#"${value%%[![:space:]]*}"}"
      printf '%s' "$value"
      return 0
    fi
  done < "$sentinel"
  return 1
}

# _dd_lock_first_content_line <sentinel-path>
# The pre-label fallback: the first line that is neither a comment nor a
# labeled field is the reason an older version wrote.
_dd_lock_first_content_line() {
  local sentinel="$1" line
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" == \#* ]] && continue
    [[ -z "$line" ]] && continue
    [[ "$line" == locked-at:* ]] && continue
    [[ "$line" == reason:* ]] && continue
    printf '%s' "$line"
    return 0
  done < "$sentinel"
  return 1
}

# dd_lock_reason <sentinel-path>
dd_lock_reason() {
  local sentinel="$1"
  [[ -f "$sentinel" ]] || return 1
  _dd_lock_field "$sentinel" reason && return 0
  _dd_lock_first_content_line "$sentinel"
}

# dd_lock_date <sentinel-path>
dd_lock_date() {
  local sentinel="$1"
  [[ -f "$sentinel" ]] || return 1
  _dd_lock_field "$sentinel" locked-at
}

# dd_lock_suffix <sentinel-path>
# Emits the sentence fragment appended to a deny message: the reason and the
# date it was set, whichever of the two the file carries. Empty when the file
# holds neither, so a bare sentinel still denies without a dangling phrase.
dd_lock_suffix() {
  local sentinel="$1"
  [[ -f "$sentinel" ]] || return 0

  local reason date
  reason=$(dd_lock_reason "$sentinel")
  date=$(dd_lock_date "$sentinel")

  if [[ -n "$reason" && -n "$date" ]]; then
    printf ' Reason: %s (locked %s).' "$reason" "$date"
  elif [[ -n "$reason" ]]; then
    printf ' Reason: %s.' "$reason"
  elif [[ -n "$date" ]]; then
    printf ' Locked %s.' "$date"
  fi
}
