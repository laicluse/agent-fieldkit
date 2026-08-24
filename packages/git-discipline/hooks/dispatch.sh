#!/bin/bash
# allow-comment: Single entry point for git-discipline hooks. PreToolUse:Bash carries safety locks (dash-c, config-override, repo-deny), the push-time gates (wip + body), the rotation-reminder layer (commit-subject), and the commit-message nudge layer (commit-format, commit-body, commit-trailers). The nudge layer emits additionalContext via dd_emit_pre_context instead of denying so the commit lands and Claude amends silently.

DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/lib/common.sh"
source "$DIR/lib/version-skew.sh"

INPUT=$(cat)
EVENT=$(dd_event "$INPUT")

case "$EVENT" in
  PreToolUse)
    TOOL=$(dd_tool_name "$INPUT")
    [ "$TOOL" = "Bash" ] || exit 0

    dd_git_discipline_version_skew "$INPUT"

    dd_cd_to_bash_target "$INPUT"

    source "$DIR/lib/lock-info.sh"
    source "$DIR/guards/git-dash-c.sh"
    source "$DIR/guards/git-config-override.sh"
    source "$DIR/guards/repo-deny.sh"
    source "$DIR/guards/sentinel-protect.sh"
    source "$DIR/guards/merge-conflict-markers.sh"
    guard_git_dash_c "$INPUT"
    guard_git_config_override "$INPUT"
    guard_repo_deny "$INPUT"
    guard_sentinel_protect "$INPUT"
    # allow-comment: a half-resolved merge must not land even when the
    # allow-comment: commit-discipline nudges are toggled off, so the
    # allow-comment: conflict-marker guard sits with the safety locks above the
    # allow-comment: session/global disable check. Its own env/magic-comment
    # allow-comment: escape is the intended bypass.
    guard_merge_conflict_markers "$INPUT"

    SESSION_ID=$(dd_session_id "$INPUT")
    if [[ -n "$SESSION_ID" ]] && [[ -f "${LAICLUSE_HOME:-$HOME/.laicluse}/git-discipline/git-discipline-disabled-$SESSION_ID" ]]; then
      exit 0
    fi
    if [[ -f "${LAICLUSE_HOME:-$HOME/.laicluse}/git-discipline/git-discipline-disabled-global" ]]; then
      exit 0
    fi

    source "$DIR/lib/validate-body.sh"
    source "$DIR/lib/example-synth.sh"

    # allow-comment: snapshot HEAD before any commit-graph writer runs so the
    # allow-comment: PostToolUse commit-body net can validate exactly the commits
    # allow-comment: this command writes, including the rebase/cherry-pick/merge/
    # allow-comment: amend paths the PreToolUse string-parsing guard cannot see.
    source "$DIR/guards/commit-body-posttool.sh"
    commit_body_snapshot_head "$INPUT"

    source "$DIR/guards/git-first-contact.sh"
    guard_git_first_contact "$INPUT"

    source "$DIR/guards/push-wip-gate.sh"
    source "$DIR/guards/push-body-gate.sh"
    guard_push_wip_gate "$INPUT"
    guard_push_body_gate "$INPUT"

    source "$DIR/guards/commit-subject.sh"
    source "$DIR/guards/commit-format.sh"
    source "$DIR/guards/commit-body.sh"
    source "$DIR/guards/commit-trailers.sh"
    # allow-comment: run the commit-message guards via _dd_run_collect so a
    # allow-comment: deny from one guard does not short-circuit the others;
    # allow-comment: all four pass against the same commit message and the
    # allow-comment: operator sees subject + format + body issues in one
    # allow-comment: aggregated deny block (eliminates per-violation amend
    # allow-comment: cycles that the old short-circuit imposed).
    DD_DENY_MESSAGES=()
    _dd_run_collect guard_commit_subject "$INPUT"
    _dd_run_collect guard_commit_format "$INPUT"
    _dd_run_collect guard_commit_body "$INPUT"
    _dd_run_collect guard_commit_trailers "$INPUT"
    if [ "${#DD_DENY_MESSAGES[@]}" -gt 0 ]; then
      for _dd_deny_msg in "${DD_DENY_MESSAGES[@]}"; do
        printf '%s\n' "$_dd_deny_msg" >&2
      done
      exit 2
    fi
    ;;

  PostToolUse)
    TOOL=$(dd_tool_name "$INPUT")
    [ "$TOOL" = "Bash" ] || exit 0

    SESSION_ID=$(dd_session_id "$INPUT")
    if [[ -n "$SESSION_ID" ]] && [[ -f "${LAICLUSE_HOME:-$HOME/.laicluse}/git-discipline/git-discipline-disabled-$SESSION_ID" ]]; then
      exit 0
    fi
    if [[ -f "${LAICLUSE_HOME:-$HOME/.laicluse}/git-discipline/git-discipline-disabled-global" ]]; then
      exit 0
    fi

    source "$DIR/guards/commit-subject.sh"
    guard_commit_subject_posttool "$INPUT"

    # allow-comment: validate the bodies of commits a commit-graph writer just
    # allow-comment: wrote (rebase/cherry-pick/merge/amend); the shared
    # allow-comment: vb_validate_commit and wip-gate ours filter keep the verdict
    # allow-comment: identical to push-body-gate. Blocks via exit 2 so the body is
    # allow-comment: fixed at creation time, before any push (remote-less repos
    # allow-comment: never reach the push gate).
    dd_cd_to_bash_target "$INPUT"
    source "$DIR/lib/validate-body.sh"
    source "$DIR/lib/wip-gate.sh"
    source "$DIR/guards/commit-body-posttool.sh"
    guard_commit_body_posttool "$INPUT"
    ;;

  UserPromptExpansion)
    source "$DIR/lib/lock-info.sh"
    source "$DIR/handlers/toggle-commands.sh"
    handle_toggle_commands "$INPUT"
    ;;
esac

exit 0
