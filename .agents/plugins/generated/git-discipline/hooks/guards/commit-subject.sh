#!/bin/bash
# packages/git-discipline/hooks/guards/commit-subject.sh
# PreToolUse:Bash guard. On every git commit, parse the subject from -m /
# --message / HEREDOC; check rules 1 (activity-word start) and 2 (trigger
# phrasing); otherwise serve a rotating thematic reminder. Blocks until an
# appropriate '# ack-rule<N>:<password>' token appears, where the
# password must match the mnemonic for that rule. The mnemonics live in
# hooks/lib/rotation-rules.sh and are documented in the
# /git-discipline:commit-discipline skill (section "Rotation reminders").
#
# State file: key=value text (pv, pr, rp, ack_pending_sha) at
# $GIT_DISCIPLINE_COMMIT_RULE_STATE_FILE, falling back to
# ${LAICLUSE_HOME:-$HOME/.laicluse}/git-discipline/git-discipline-commit-rule-state-<8char-hex-of-toplevel>.
# Written atomically via temp-file rename. The reader also accepts the
# two legacy positional formats (three-line and four-line) so existing
# installations migrate seamlessly on first read.
#
# Migration chain: when the per-toplevel file does not exist, copy from
# the global git-discipline file (${LAICLUSE_HOME:-$HOME/.laicluse}/git-discipline/git-discipline-commit-rule-state)
# if present, otherwise from the dont-do-that legacy file. The global
# source is renamed to *.migrated after the first successful copy so
# subsequent new repos start fresh instead of inheriting stale state.

# Source the password mnemonics; provides DD_RULE_PASSWORD[].
_DD_HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$_DD_HERE/../lib/rotation-rules.sh"

# Rule 3 (idx 2) is owned by commit-format structurally and stays out of
# the rotation so it does not double up as an ack-bypassable reminder.
_DD_ROTATION_SLOTS=(3 4 5 6 7 8 9 10 11 12 13 14)

_dd_read_state_line() {
  local file="$1" line_no="$2" default="$3"
  local v
  v=$(sed -n "${line_no}p" "$file" 2>/dev/null)
  if [[ "$v" =~ ^-?[0-9]+$ ]]; then
    echo "$v"
  else
    echo "$default"
  fi
}

# Loads state into DD_LOADED_* globals. Reads the canonical key=value
# format and degrades gracefully to the two legacy positional formats
# (three-line: pv/pr/rp; four-line: pv/pr/rp/ack_pending_sha). The next
# write converges any legacy file to the key=value format.
_dd_load_state() {
  local file="$1"
  DD_LOADED_PV=-1
  DD_LOADED_PR=-1
  DD_LOADED_RP=0
  DD_LOADED_ACK_SHA=""
  [[ -f "$file" ]] || return 0
  if grep -qE '^[a-z_]+=' "$file" 2>/dev/null; then
    local key val
    while IFS='=' read -r key val; do
      [[ -z "$key" ]] && continue
      case "$key" in
        pv) [[ "$val" =~ ^-?[0-9]+$ ]] && DD_LOADED_PV="$val" ;;
        pr) [[ "$val" =~ ^-?[0-9]+$ ]] && DD_LOADED_PR="$val" ;;
        rp) [[ "$val" =~ ^-?[0-9]+$ ]] && DD_LOADED_RP="$val" ;;
        ack_pending_sha) DD_LOADED_ACK_SHA=$(printf '%s' "$val" | tr -cd '0-9a-f') ;;
        *) : ;; # forward-compat: unknown keys are ignored
      esac
    done < "$file"
  else
    DD_LOADED_PV=$(_dd_read_state_line "$file" 1 -1)
    DD_LOADED_PR=$(_dd_read_state_line "$file" 2 -1)
    DD_LOADED_RP=$(_dd_read_state_line "$file" 3 0)
    DD_LOADED_ACK_SHA=$(sed -n '4p' "$file" 2>/dev/null | tr -cd '0-9a-f')
  fi
  # allow-comment: clamp the loaded values into valid ranges before returning
  # allow-comment: so every caller reads pre-validated state. Used to be
  # allow-comment: duplicated verbatim in guard_commit_subject and
  # allow-comment: guard_commit_subject_posttool; folded in here to keep the
  # allow-comment: invariant in one place.
  [[ "$DD_LOADED_PV" -ne -1 && "$DD_LOADED_PV" -ne 0 && "$DD_LOADED_PV" -ne 1 ]] && DD_LOADED_PV=-1
  if [[ "$DD_LOADED_PR" -ne -1 ]]; then
    local _dd_in_rot=0 _dd_slot
    for _dd_slot in "${_DD_ROTATION_SLOTS[@]}"; do
      [[ "$_dd_slot" -eq "$DD_LOADED_PR" ]] && { _dd_in_rot=1; break; }
    done
    [[ "$_dd_in_rot" -eq 0 ]] && DD_LOADED_PR=-1
  fi
  [[ "$DD_LOADED_RP" -lt 0 || "$DD_LOADED_RP" -ge "${#_DD_ROTATION_SLOTS[@]}" ]] && DD_LOADED_RP=0
}

_dd_write_state() {
  local file="$1" pv="$2" pr="$3" rp="$4" ack_sha="${5:-}"
  local tmp="${file}.tmp.$$"
  printf 'pv=%d\npr=%d\nrp=%d\nack_pending_sha=%s\n' \
    "$pv" "$pr" "$rp" "$ack_sha" > "$tmp"
  mv "$tmp" "$file"
}

# Returns 0 when the parsed ack matches the expected rule and password.
# All inputs are explicit so the caller can be reasoned about without
# tracing into the helper's enclosing scope.
_dd_ack_matches() {
  local target_idx="$1" ack_idx="$2" ack_password="$3" expected="$4"
  [[ "$ack_idx" -ne "$target_idx" ]] && return 1
  [[ -z "$ack_password" ]] && return 1
  [[ "$ack_password" != "$expected" ]] && return 1
  return 0
}

_dd_essence_for_rule() {
  local idx="$1"
  if [[ "$idx" -ge 0 && "$idx" -lt "${#DD_RULE_ESSENCE[@]}" ]]; then
    printf '%s' "${DD_RULE_ESSENCE[$idx]}"
  fi
}

# allow-comment: parent-of helper for amend detection. git rev-parse with a
# allow-comment: trailing ^ fails AND echoes the input to stdout when the
# allow-comment: argument cannot be resolved (root commit, unknown sha), so
# allow-comment: piping through tr would falsely fill the parent with bytes
# allow-comment: from the original sha. Use the exit code as the truth signal:
# allow-comment: on success print the resolved parent sha, on failure print
# allow-comment: nothing. Empty string is the correct sentinel for "no
# allow-comment: parent" so equal-comparison can detect root-amend (both
# allow-comment: empty) without special-casing.
_dd_parent_sha() {
  local sha="$1"
  [[ -z "$sha" ]] && return 0
  local out
  if out=$(git rev-parse --verify --quiet "${sha}^" 2>/dev/null); then
    printf '%s' "$out"
  fi
}

# Writes the new state and then exits the dispatcher with code 2 via
# dd_emit_deny. Never returns; any code following a call to this
# function in the same branch is unreachable.
_dd_deny_and_exit() {
  local rule_idx="$1" msg="$2" pv="$3" pr="$4" rp="$5" state_file="$6" ack_sha="${7:-}"
  local num=$((rule_idx + 1))
  _dd_write_state "$state_file" "$pv" "$pr" "$rp" "$ack_sha"
  dd_emit_deny commit-subject "Rule ${num}/15: ${msg}"
}

# allow-comment: 8-char hex hash with portable-shasum fallback. Tries
# allow-comment: shasum, then md5sum, then macOS md5 -q; echoes nothing on
# allow-comment: total failure so callers can fall back to a default path.
# allow-comment: Used twice (toplevel hash, session-id hash) inside the
# allow-comment: state-file resolution.
_dd_short_hash() {
  local input="$1" out=""
  out=$(printf '%s' "$input" | shasum 2>/dev/null | cut -c1-8)
  [[ -z "$out" ]] && out=$(printf '%s' "$input" | md5sum 2>/dev/null | cut -c1-8)
  [[ -z "$out" ]] && out=$(printf '%s' "$input" | md5 -q 2>/dev/null | cut -c1-8)
  printf '%s' "$out"
}

# allow-comment: pure path math, no I/O beyond the mkdir -p that gives the
# allow-comment: dirname a safe home. Returns the per-toplevel state file
# allow-comment: path for this repo, or the global default when no repo is
# allow-comment: detected. Override via GIT_DISCIPLINE_COMMIT_RULE_STATE_FILE.
_dd_state_file_per_toplevel() {
  if [[ -n "${GIT_DISCIPLINE_COMMIT_RULE_STATE_FILE:-}" ]]; then
    printf '%s' "$GIT_DISCIPLINE_COMMIT_RULE_STATE_FILE"
    return 0
  fi
  local global_state="${LAICLUSE_HOME:-$HOME/.laicluse}/git-discipline/git-discipline-commit-rule-state"
  local toplevel
  toplevel=$(git rev-parse --show-toplevel 2>/dev/null)
  if [[ -z "$toplevel" ]]; then
    printf '%s' "$global_state"
    return 0
  fi
  local toplevel_hash
  toplevel_hash=$(_dd_short_hash "$toplevel")
  if [[ -z "$toplevel_hash" ]]; then
    printf '%s' "$global_state"
    return 0
  fi
  printf '%s' "${LAICLUSE_HOME:-$HOME/.laicluse}/git-discipline/git-discipline-commit-rule-state-${toplevel_hash}"
}

# allow-comment: one-shot migration from the legacy global state file (or
# allow-comment: the even-older dont-do-that location) into the per-toplevel
# allow-comment: file. No-op when per_toplevel already exists or no migration
# allow-comment: source is available. The source is renamed to *.migrated
# allow-comment: after a successful copy so subsequent repos do not also
# allow-comment: inherit from it.
_dd_state_file_migrate() {
  local per_toplevel="$1"
  [[ -z "$per_toplevel" ]] && return 0
  [[ -f "$per_toplevel" ]] && return 0
  local global_state="${LAICLUSE_HOME:-$HOME/.laicluse}/git-discipline/git-discipline-commit-rule-state"
  local migration_src=""
  if [[ "$per_toplevel" != "$global_state" && -f "$global_state" ]]; then
    migration_src="$global_state"
  fi
  if [[ -z "$migration_src" ]]; then
    local old_state_file="${CLAUDE_COMMIT_RULE_STATE_FILE:-${LAICLUSE_HOME:-$HOME/.laicluse}/git-discipline/commit-rule-state}"
    [[ -f "$old_state_file" ]] && migration_src="$old_state_file"
  fi
  [[ -z "$migration_src" ]] && return 0
  local migr_tmp="${per_toplevel}.tmp.$$"
  if cp "$migration_src" "$migr_tmp" && mv "$migr_tmp" "$per_toplevel"; then
    mv "$migration_src" "${migration_src}.migrated" 2>/dev/null || true
  fi
}

# allow-comment: derive the per-session state file path from the per-toplevel
# allow-comment: path and a session id. When the session id cannot be
# allow-comment: hashed, returns the per-toplevel path so the dispatcher
# allow-comment: shares state across all unidentified sessions (the
# allow-comment: shell-driven git-native hook case). On first creation of a
# allow-comment: per-session file, inherits the rp pointer from per-toplevel
# allow-comment: so the new session continues at the next slot in the cycle,
# allow-comment: and opportunistically prunes per-session files older than
# allow-comment: seven days so the directory scan stays bounded.
_dd_state_file_session_fork() {
  local per_toplevel="$1" input="$2"
  [[ -n "${GIT_DISCIPLINE_COMMIT_RULE_STATE_FILE:-}" ]] && { printf '%s' "$per_toplevel"; return 0; }
  [[ -z "$per_toplevel" ]] && { printf ''; return 0; }
  local global_state="${LAICLUSE_HOME:-$HOME/.laicluse}/git-discipline/git-discipline-commit-rule-state"
  [[ "$per_toplevel" = "$global_state" ]] && { printf '%s' "$per_toplevel"; return 0; }

  local session_id session_key
  session_id=$(dd_session_id "$input")
  [[ -z "$session_id" ]] && { printf '%s' "$per_toplevel"; return 0; }
  session_key=$(_dd_short_hash "$session_id")
  [[ -z "$session_key" ]] && { printf '%s' "$per_toplevel"; return 0; }

  local state_file="${per_toplevel}-${session_key}"
  if [[ ! -f "$state_file" ]]; then
    if [[ -f "$per_toplevel" ]]; then
      _dd_load_state "$per_toplevel"
      _dd_write_state "$state_file" -1 -1 "$DD_LOADED_RP" ""
    fi
    find "$(dirname "$per_toplevel")" \
      -maxdepth 1 -type f \
      -name "$(basename "$per_toplevel")-*" \
      -mtime +7 \
      -delete 2>/dev/null || true
  fi
  printf '%s' "$state_file"
}

# allow-comment: orchestrator: compute the per-toplevel path, ensure the
# allow-comment: directory exists, run a one-shot migration if applicable,
# allow-comment: then fork to per-session if a session id is available.
# allow-comment: Returns the resolved state file path.
_dd_resolve_commit_subject_state_file() {
  local input="$1"
  local per_toplevel
  per_toplevel=$(_dd_state_file_per_toplevel)
  mkdir -p "$(dirname "$per_toplevel")" 2>/dev/null || true
  _dd_state_file_migrate "$per_toplevel"
  _dd_state_file_session_fork "$per_toplevel" "$input"
}

guard_commit_subject() {
  local input="$1"
  local command
  command=$(jq -r '.tool_input.command // empty' <<< "$input" 2>/dev/null)
  dd_is_git_commit_command "$command" || return 0

  # Direct pointer to the SKILL.md so Claude can Read the file without
  # grep-fishing through the plugin cache. The lookup itself stays
  # required: this only points at the door, the password still lives
  # behind it. When the absolute path cannot be resolved (broken
  # install, layout regression, stale cache), surface the failure
  # loudly via dd_emit_deny instead of silently degrading to the
  # slash-command form, which would re-introduce the grep-fishing
  # this fix exists to prevent.
  local skill_dir skill_path skill_pointer
  skill_dir=$(cd "$_DD_HERE/../../skills/commit-discipline" 2>/dev/null && pwd)
  skill_path="${skill_dir}/SKILL.md"
  if [[ -z "$skill_dir" || ! -f "$skill_path" ]]; then
    dd_emit_deny commit-subject "install appears broken: cannot resolve SKILL.md path. Reinstall git-discipline@laicluse-agent-fieldkit."
  fi
  [[ -n "$HOME" && "$skill_path" == "$HOME"/* ]] && skill_path="~${skill_path#$HOME}"
  skill_pointer="${skill_path}, section 'Rotation reminders'"

  # Subject extraction: delegate to dd_extract_commit_message (shared parser),
  # then take the first line as the subject. This deduplicates the heredoc-first
  # / -m-fallback logic that commit-format.sh and commit-body.sh also use.
  local full_message
  full_message=$(dd_extract_commit_message "$command")
  local subject=""
  if [[ -n "$full_message" ]]; then
    subject=$(printf '%s' "$full_message" | head -1)
  fi

  # Strip heredoc body + quoted strings from the command for ack-token
  # detection, so an ack buried in the message itself does not count as
  # approval. dd_strip_commit_message lives in common.sh; it shares the
  # heredoc grammar with dd_extract_commit_message so the two parsers
  # cannot drift.
  local cmd_clean
  cmd_clean=$(dd_strip_commit_message "$command")

  # Optional :<password> suffix. Bare `# ack-rule<N>` is still recognised as
  # "user tried to ack" (drives the "still violates" branch when their subject
  # is still violating); only the suffixed form actually clears state.
  local ack_idx=-1
  local ack_password=""
  if [[ "$cmd_clean" =~ (^|[[:space:]])\#[[:space:]]*ack-rule([0-9]+)(:([a-z]+))? ]]; then
    ack_idx=$((${BASH_REMATCH[2]} - 1))
    ack_password="${BASH_REMATCH[4]}"
  fi

  # Rule 1 (idx 0) / Rule 2 (idx 1) violation detection on the subject.
  local activity_re='^(Fix|Improve|Update|Change|Refactor|Add|Extract|Move|Remove|Rename|Drop|Create|Clear|Land|Make|Work|Do|Get|Tweak|Surface|Address|Apply|Plant|Place|Pin|Lay|Anchor|Set|Stand|Mount|Install)[[:space:]]'
  local trigger_re='^(Address|Apply)[[:space:]]+.*(review|feedback|findings|comments|pride)'
  local violation_idx=-1
  shopt -s nocasematch
  if [[ -n "$subject" ]] && [[ "$subject" =~ $trigger_re ]]; then
    violation_idx=1
  elif [[ -n "$subject" ]] && [[ "$subject" =~ $activity_re ]]; then
    violation_idx=0
  fi
  shopt -u nocasematch

  local state_file
  state_file=$(_dd_resolve_commit_subject_state_file "$input")

  _dd_load_state "$state_file"
  local pv="$DD_LOADED_PV" pr="$DD_LOADED_PR" rp="$DD_LOADED_RP"
  local ack_pending_sha="$DD_LOADED_ACK_SHA"

  # Resolve any pending ack from a previous PreToolUse pass: if HEAD has
  # advanced since the ack was matched, the commit actually landed and the
  # rotation slot is consumed. If HEAD is unchanged, the commit failed at
  # commit-msg, pre-commit, or never ran; the slot stays so the operator
  # acks the same rule again on the next attempt. Either way, clear the
  # pending sha so this resolution only runs once per ack.
  if [[ -n "$ack_pending_sha" ]]; then
    local current_sha
    current_sha=$(git rev-parse HEAD 2>/dev/null | tr -cd '0-9a-f')
    if [[ -z "$current_sha" ]]; then
      # Empty repo (no commits yet) or detached state where rev-parse
      # returned nothing. The pending ack cannot be resolved against a
      # missing HEAD; clear it without advancing and let the next ack
      # resolve once the repo has commits. Treating empty as "no
      # advance" is the safe choice; the alternative would burn the
      # rotation slot on a state we cannot prove succeeded.
      :
    elif [[ "$current_sha" != "$ack_pending_sha" ]]; then
      # allow-comment: amend detection via parent comparison; equal parents
      # allow-comment: (including both empty for root-amend) keep the slot.
      # allow-comment: Known false-positive: a cherry-pick whose parent
      # allow-comment: matches ack_pending_sha's parent is misread as amend.
      local new_parent old_parent
      new_parent=$(_dd_parent_sha "$current_sha")
      old_parent=$(_dd_parent_sha "$ack_pending_sha")
      if [[ "$new_parent" != "$old_parent" ]]; then
        rp=$(( (rp + 1) % ${#_DD_ROTATION_SLOTS[@]} ))
        # allow-comment: the acked commit landed and consumed its slot; drop the pending slot so the next commit gets a fresh phase-1 reminder for the advanced rule. The HEAD-unchanged path below keeps pr so a commit that never landed re-uses the ack on retry instead of re-serving.
        pr=-1
      fi
    fi
    ack_pending_sha=""
    _dd_write_state "$state_file" "$pv" "$pr" "$rp" ""
  fi

  # Editor-mode commit: no subject parseable, rules 1/2 cannot be checked.
  if [[ -z "$subject" ]]; then
    dd_emit_deny commit-subject "Editor-mode commit hides the subject. Pass inline: git commit -m \"...\"."
  fi

  # Fresh violation: always deny with rule 1 or 2.
  if [[ "$violation_idx" -ge 0 ]]; then
    local rn=$((violation_idx + 1))
    local v_essence
    v_essence=$(_dd_essence_for_rule "$violation_idx")
    local v_row_pointer="${skill_pointer}, row ${rn}"
    if [[ "$ack_idx" -eq "$violation_idx" ]]; then
      _dd_deny_and_exit "$violation_idx" \
        "subject \"${subject}\" still violates: ${v_essence}. The ack matched but the subject still does. Rewrite the subject (keep the ack), then re-run." \
        "$violation_idx" "$pr" "$rp" "$state_file"
    else
      _dd_deny_and_exit "$violation_idx" \
        "subject \"${subject}\": ${v_essence}. Rewrite, then append '# ack-rule${rn}:<password>' to the bash command (lookup: ${v_row_pointer})." \
        "$violation_idx" "$pr" "$rp" "$state_file"
    fi
  fi

  # Pending violation from a previous call: subject must be clean AND ack
  # must carry the right password.
  if [[ "$pv" -ge 0 ]]; then
    if _dd_ack_matches "$pv" "$ack_idx" "$ack_password" "${DD_RULE_PASSWORD[$pv]}"; then
      _dd_write_state "$state_file" -1 "$pr" "$rp"
      return 0
    fi
    local pv_essence pv_row_pointer
    pv_essence=$(_dd_essence_for_rule "$pv")
    pv_row_pointer="${skill_pointer}, row $((pv + 1))"
    _dd_deny_and_exit "$pv" \
      "${pv_essence}. Password missing or wrong for \"${subject}\". Paste '# ack-rule$((pv + 1)):<password>' (lookup: ${pv_row_pointer})." \
      "$pv" "$pr" "$rp" "$state_file"
  fi

  # No pending rotation: serve the next slot as a rotating thematic reminder.
  if [[ "$pr" -lt 0 ]]; then
    local selected="${_DD_ROTATION_SLOTS[$rp]}"
    local sel_essence sel_row_pointer
    sel_essence=$(_dd_essence_for_rule "$selected")
    sel_row_pointer="${skill_pointer}, row $((selected + 1))"
    _dd_deny_and_exit "$selected" \
      "reminder: ${sel_essence}. Paste '# ack-rule$((selected + 1)):<password>' (lookup: ${sel_row_pointer})." \
      -1 "$selected" "$rp" "$state_file"
  fi

  # Pending rotation: ack must match exactly with the right password.
  # Rotation only advances on confirmed commit success, not on PreToolUse
  # pass: record the current HEAD sha so the next dispatcher entry can
  # detect whether the commit actually landed (HEAD moved) or failed at
  # commit-msg / pre-commit (HEAD unchanged).
  if _dd_ack_matches "$pr" "$ack_idx" "$ack_password" "${DD_RULE_PASSWORD[$pr]}"; then
    local head_sha
    head_sha=$(git rev-parse HEAD 2>/dev/null | tr -cd '0-9a-f')
    # allow-comment: workaround for empty-repo Catch-22 (first commit on `git init`)
    [[ -z "$head_sha" ]] && head_sha="0"
    # allow-comment: keep pr at the acked slot (not -1) so a commit that passes the ack but never lands (HEAD unchanged) re-uses the ack on retry via the pending-resolution above, instead of dropping to a fresh phase-1 reminder. On a landed commit the posttool hook (or the resolution's parents-differ branch) advances rp and clears pr.
    _dd_write_state "$state_file" -1 "$pr" "$rp" "$head_sha"
    return 0
  fi
  local pr_essence pr_row_pointer
  pr_essence=$(_dd_essence_for_rule "$pr")
  pr_row_pointer="${skill_pointer}, row $((pr + 1))"
  _dd_deny_and_exit "$pr" \
    "${pr_essence}. Password missing or wrong. Paste '# ack-rule$((pr + 1)):<password>' (lookup: ${pr_row_pointer})." \
    -1 "$pr" "$rp" "$state_file"
}

guard_commit_subject_posttool() {
  local input="$1"
  local command
  command=$(jq -r '.tool_input.command // empty' <<< "$input" 2>/dev/null)
  dd_is_git_commit_command "$command" || return 0

  local state_file
  state_file=$(_dd_resolve_commit_subject_state_file "$input")

  _dd_load_state "$state_file"
  local pv="$DD_LOADED_PV" pr="$DD_LOADED_PR" rp="$DD_LOADED_RP"
  local ack_pending_sha="$DD_LOADED_ACK_SHA"

  [[ -z "$ack_pending_sha" ]] && return 0

  local current_sha
  current_sha=$(git rev-parse HEAD 2>/dev/null | tr -cd '0-9a-f')
  [[ -z "$current_sha" ]] && return 0
  [[ "$current_sha" = "$ack_pending_sha" ]] && return 0

  # allow-comment: amend detection (mirrors the PreToolUse-entry logic).
  # allow-comment: Equal parents (including both empty for root-amend) means
  # allow-comment: the commit object is a rewrite of the just-acked one.
  local new_parent old_parent
  new_parent=$(_dd_parent_sha "$current_sha")
  old_parent=$(_dd_parent_sha "$ack_pending_sha")
  if [[ "$new_parent" = "$old_parent" ]]; then
    return 0
  fi

  rp=$(( (rp + 1) % ${#_DD_ROTATION_SLOTS[@]} ))
  local next_slot="${_DD_ROTATION_SLOTS[$rp]}"
  local next_num=$((next_slot + 1))

  _dd_write_state "$state_file" -1 "$next_slot" "$rp" ""

  local skill_dir skill_path skill_pointer
  skill_dir=$(cd "$_DD_HERE/../../skills/commit-discipline" 2>/dev/null && pwd)
  skill_path="${skill_dir}/SKILL.md"
  if [[ -z "$skill_dir" || ! -f "$skill_path" ]]; then
    skill_pointer="SKILL.md, section 'Rotation reminders'"
  else
    [[ -n "$HOME" && "$skill_path" == "$HOME"/* ]] && skill_path="~${skill_path#$HOME}"
    skill_pointer="${skill_path}, section 'Rotation reminders'"
  fi

  local next_essence next_row_pointer
  next_essence=$(_dd_essence_for_rule "$next_slot")
  next_row_pointer="${skill_pointer}, row ${next_num}"

  dd_emit_context "commit-subject" "Next-commit rotation reminder, rule ${next_num}: ${next_essence}. Include '# ack-rule${next_num}:<password>' on the very next commit (lookup: ${next_row_pointer})."
}
