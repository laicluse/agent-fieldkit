#!/bin/bash
# Entry point for all dont-do-that hooks; routes by hook_event_name and tool_name. Guard membership and order per lane come from hooks/guards.json (the registry), filtered by the agent the manifest signalled via DD_AGENT. allow-comment: this file owns event/tool routing and per-lane execution semantics only, never a guard enumeration; add or re-scope a guard by editing the registry.

DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/lib/common.sh"

INPUT=$(cat)
EVENT=$(dd_event "$INPUT")

# run_direct_lane <lane> <event>: guards run in-process and may exit the dispatcher themselves (PreToolUse dd_emit_deny exits 2; Stop mutex dd_emit_block exits 0); a guard that does not fire returns and the next runs. allow-comment: documents the deny/block control flow.
run_direct_lane() {
  local lane="$1" event="$2" id fn
  while IFS=$'\t' read -r id fn; do
    [ -n "$id" ] || continue
    dd_guard_enabled "$id" "$event" || continue
    source "$DIR/guards/$id.sh"
    "$fn" "$INPUT"
  done < <(dd_registry_lane_guards "$lane")
}

# run_capture_lane <lane> <event>: each guard runs in a subshell, first non-empty stdout wins and is emitted with exit 0, but every guard still runs so per-session line trackers update on each fire. allow-comment: preserves the independent lifecycles of dash/land and false-claims/tool-error.
run_capture_lane() {
  local lane="$1" event="$2" id fn out="" emitted
  while IFS=$'\t' read -r id fn; do
    [ -n "$id" ] || continue
    dd_guard_enabled "$id" "$event" || continue
    source "$DIR/guards/$id.sh"
    emitted=$( "$fn" "$INPUT" )
    [ -z "$out" ] && out="$emitted"
  done < <(dd_registry_lane_guards "$lane")
  if [ -n "$out" ]; then
    echo "$out"
    exit 0
  fi
}

case "$EVENT" in
  PreToolUse)
    TOOL=$(dd_tool_name "$INPUT")
    # allow-comment: fail closed so a missing or corrupt guards.json cannot silently disarm the PreToolUse safety gates; the manifest only routes edit/shell tools to this hook.
    dd_registry_readable || dd_emit_deny registry "guards.json missing or not valid JSON; refusing the tool call until the registry is restored (run bin/validate-registry)"
    case "$TOOL" in
      Bash)
        run_direct_lane pre-bash PreToolUse
        ;;
      Edit|Write|MultiEdit|apply_patch)
        run_direct_lane pre-edit PreToolUse
        ;;
      Grep|Glob)
        run_direct_lane pre-search PreToolUse
        ;;
    esac
    ;;

  PostToolUse)
    TOOL=$(dd_tool_name "$INPUT")
    case "$TOOL" in
      Edit|Write|MultiEdit|apply_patch)
        run_capture_lane post PostToolUse
        ;;
    esac
    ;;

  Stop)
    # allow-comment: headless `claude -p` returns its last turn as the result, so any Stop-block forces a nudge-turn that overwrites it; DD_HEADLESS opts the whole Stop set out while PreToolUse safety stays on.
    [ -n "$DD_HEADLESS" ] && exit 0
    run_capture_lane stop-tracked Stop
    # allow-comment: if a prior Stop fire already blocked, skip the mutex guards so the same text is not re-blocked across consecutive fires.
    if ! dd_stop_active "$INPUT"; then
      run_direct_lane stop-mutex Stop
    fi
    ;;
esac

exit 0
