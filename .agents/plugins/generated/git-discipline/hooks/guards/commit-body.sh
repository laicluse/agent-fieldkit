#!/bin/bash
# allow-comment: PreToolUse:Bash guard. Validates the commit message against
# allow-comment: the body schema and BLOCKS the commit on any hard violation
# allow-comment: via dd_emit_deny (exit 2). Previous design emitted a
# allow-comment: non-blocking nudge and let push-body-gate block at push time;
# allow-comment: that turned every gate violation into an amend cycle. Blocking
# allow-comment: at PreToolUse means the operator fixes the body before the
# allow-comment: commit object is ever created. amend commits validate against
# allow-comment: HEAD (the to-be-rewritten state); normal commits validate
# allow-comment: against the staged area. Validates every git commit command,
# allow-comment: --no-verify included; the layer split is documented in the
# allow-comment: commit-discipline SKILL.md section "--no-verify".
# allow-comment: This guard only sees a body it can parse from a direct
# allow-comment: `git commit -m`/heredoc string (dd_extract_commit_message). A
# allow-comment: commit written by a rebase, cherry-pick, merge --continue, or an
# allow-comment: --amend that reuses the message leaves no parseable string here;
# allow-comment: commit-body-posttool (PostToolUse) catches those by validating
# allow-comment: the commits the command actually wrote.

guard_commit_body() {
  local input="$1"

  local command
  command=$(jq -r '.tool_input.command // empty' <<< "$input" 2>/dev/null)
  dd_is_git_commit_command "$command" || return 0

  local message
  message=$(dd_extract_commit_message "$command")
  [[ -z "$message" ]] && return 0

  local subject
  subject=$(printf '%s' "$message" | head -1)
  if validate_body_classify_skip "$subject"; then
    return 0
  fi

  local validate_ctx="staged"
  if [[ "$command" == *--amend* ]]; then
    validate_ctx="HEAD"
  fi

  local shortstat file_count insertion_count
  shortstat=$(GIT_DISCIPLINE_VALIDATE_CONTEXT="$validate_ctx" _vb_delta_shortstat)
  file_count=$(GIT_DISCIPLINE_VALIDATE_CONTEXT="$validate_ctx" _vb_delta_files | grep -c . | tr -d ' ')

  insertion_count=0
  if [[ "$shortstat" =~ ([0-9]+)[[:space:]]+insertion ]]; then
    insertion_count="${BASH_REMATCH[1]}"
  fi

  # allow-comment: trivial-ok travels as an inline env-var on the validator
  # allow-comment: call rather than an exported global; the scope ends with
  # allow-comment: the subshell of the $() capture so no leakage into sibling
  # allow-comment: guards or later loop iterations.
  local trivial_ok=0
  if [[ "$file_count" -le 1 && "$insertion_count" -le 5 ]]; then
    trivial_ok=1
  fi

  local tmpfile
  tmpfile=$(mktemp /tmp/git-discipline-commit-msg-XXXXXX)
  printf '%s' "$message" > "$tmpfile"

  local violation_output exit_code
  violation_output=$(GIT_DISCIPLINE_VALIDATE_CONTEXT="$validate_ctx" GIT_DISCIPLINE_TRIVIAL_OK="$trivial_ok" validate_body "$tmpfile" 2>&1)
  exit_code=$?

  rm -f "$tmpfile"

  if [[ "$exit_code" -ne 1 ]]; then
    return 0
  fi

  local violation_line
  violation_line=$(printf '%s' "$violation_output" | head -1)
  local violation_code
  violation_code=$(printf '%s' "$violation_line" | cut -d':' -f1)

  local logfile="${GIT_DISCIPLINE_SHADOW_LOG:-${LAICLUSE_HOME:-$HOME/.laicluse}/git-discipline/git-discipline-shadow.log}"
  mkdir -p "$(dirname "$logfile")"

  local timestamp branch short_sha subject_50
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || printf 'unknown')
  short_sha=$(git rev-parse --short HEAD 2>/dev/null || printf 'staging')
  subject_50="${subject:0:50}"
  subject_50="${subject_50//|/-}"
  branch="${branch//|/-}"
  violation_code="${violation_code//|/-}"

  printf '%s|%s|%s|%s|%s\n' \
    "$timestamp" "$short_sha" "$branch" "$violation_code" "$subject_50" \
    >> "$logfile"

  local example
  example=$(GIT_DISCIPLINE_VALIDATE_CONTEXT="$validate_ctx" git_discipline_synthesize_example 2>/dev/null || printf '<example unavailable>')

  local opt_out_list="docs-only, config-only, migration-only, spec-only, chore-deps, revert, merge, wip"

  local stage_hint=""
  if dd_stages_before_commit "$command" \
     && printf '%s' "$violation_output" | grep -qE 'tests-path-not-found|red-then-green-path-not-in-staged'; then
    stage_hint=$(printf 'This command stages with git add/git stage and commits in one call. The gate runs before the command, so those files are not in the index yet, which is why a Tests or Red-then-green path reads as missing. Stage in a separate call first, then rerun the commit.\n\n')
  fi

  local deny_msg
  deny_msg=$(printf '%s%s\n\nRewrite the commit message and rerun the same git commit call; the commit object has not been created yet. Expected body format:\n\n%s\n\nOpt-out tokens for Slice: %s\n\nNo bypass flag exists at this layer (--no-verify only skips git-native hooks). Lifting the gate is operator-only: /git-discipline:disable-discipline.' \
    "$stage_hint" \
    "$violation_output" \
    "$example" \
    "$opt_out_list")

  dd_emit_deny "commit-body" "$deny_msg"
}
