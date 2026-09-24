#!/bin/bash
# packages/git-discipline/hooks/handlers/toggle-commands.sh
# UserPromptExpansion handler for the four sentinel toggle commands:
# enable-git, disable-git, enable-discipline, disable-discipline.
#
# These sentinels are operator territory: the PreToolUse sentinel-protect
# guard denies any agent-driven Bash mutation of them, unconditionally, so a
# Claude-authored Bash call can never flip the lock itself. Historically that
# meant the skill printed a ready-to-paste `! ...` command for the operator
# to run by hand. UserPromptExpansion fires directly off the operator's own
# keystroke, before Claude ever sees the prompt, so this handler performs the
# mutation itself and blocks the expansion with a one-line confirmation. The
# skill's own SKILL.md content never runs; sentinel-protect is untouched and
# still denies every agent-driven attempt exactly as before.

_tc_repo_sentinel() {
  local common_dir
  common_dir=$(git rev-parse --git-common-dir 2>/dev/null) || return 1
  printf '%s/git-discipline-deny' "$common_dir"
}

_tc_session_sentinel_dir() {
  printf '%s/git-discipline' "${LAICLUSE_HOME:-$HOME/.laicluse}"
}

handle_toggle_commands() {
  local input="$1"
  local command_name
  command_name=$(jq -r '.command_name // empty' <<< "$input" 2>/dev/null)
  [ -z "$command_name" ] && return 0

  case "$command_name" in
    *disable-discipline*) _tc_disable_discipline "$input" ;;
    *enable-discipline*)  _tc_enable_discipline "$input" ;;
    *disable-git*)        _tc_disable_git "$input" ;;
    *enable-git*)          _tc_enable_git ;;
    *) return 0 ;;
  esac
}

_tc_enable_git() {
  local sentinel
  sentinel=$(_tc_repo_sentinel) \
    || dd_emit_deny "enable-git" "Not inside a git repository; nothing to unlock."

  [ -f "$sentinel" ] \
    || dd_emit_deny "enable-git" "No git lock was active for this repo."

  # allow-comment: read the lock before deleting it, so the message says which
  # allow-comment: lock was lifted rather than only that one was.
  local lifted
  lifted=$(dd_lock_suffix "$sentinel")

  rm -f "$sentinel"
  dd_emit_deny "enable-git" "Lock lifted ($sentinel).${lifted} Git write commands work again in this repo."
}

_tc_disable_git() {
  local input="$1"
  local reason sentinel
  reason=$(jq -r '.command_args // empty' <<< "$input" 2>/dev/null)
  reason="${reason#"${reason%%[![:space:]]*}"}"
  reason="${reason%"${reason##*[![:space:]]}"}"

  # allow-comment: a lock outlives the session that set it, so the operator who
  # allow-comment: meets it weeks later needs the why from the file itself.
  # allow-comment: Refusing here is cheaper than an unexplained lock; sentinels
  # allow-comment: written by earlier versions may still carry no reason and
  # allow-comment: keep denying on their own terms.
  [ -n "$reason" ] \
    || dd_emit_deny "disable-git" "A reason is required. Type: /git-discipline:disable-git <why this repo is locked>. It is stored with the lock and quoted back on every denied git command, including weeks from now."

  sentinel=$(_tc_repo_sentinel) \
    || dd_emit_deny "disable-git" "Not inside a git repository; nothing to lock."

  dd_lock_write "$sentinel" "$reason" "$(date +%Y-%m-%d)"

  dd_emit_deny "disable-git" "Repo locked ($sentinel). Reason: $reason. Run /git-discipline:enable-git to lift."
}

_tc_enable_discipline() {
  local input="$1"
  local session_id dir sentinel
  session_id=$(dd_session_id "$input")
  [ -n "$session_id" ] \
    || dd_emit_deny "enable-discipline" "Could not determine the session id; nothing changed."

  dir=$(_tc_session_sentinel_dir)
  sentinel="$dir/git-discipline-disabled-$session_id"

  [ -f "$sentinel" ] \
    || dd_emit_deny "enable-discipline" "Guards were already active for this session."

  rm -f "$sentinel"

  local extra=""
  if [ -f "$dir/git-discipline-disabled-global" ]; then
    extra=" A separate GLOBAL disable is still active and affects every session; run /git-discipline:discipline-status to see it."
  fi
  dd_emit_deny "enable-discipline" "Guards active again for this session.${extra}"
}

_tc_disable_discipline() {
  local input="$1"
  local session_id dir sentinel
  session_id=$(dd_session_id "$input")
  [ -n "$session_id" ] \
    || dd_emit_deny "disable-discipline" "Could not determine the session id; nothing changed."

  dir=$(_tc_session_sentinel_dir)
  sentinel="$dir/git-discipline-disabled-$session_id"

  mkdir -p "$dir"
  touch "$sentinel"
  dd_emit_deny "disable-discipline" "Guards disabled for this session ($sentinel). Run /git-discipline:enable-discipline to restore."
}
