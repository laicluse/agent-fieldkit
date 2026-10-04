#!/bin/bash
# Shared library for the dont-do-that dispatcher and its guard functions.
# Sourced by dispatch.sh and guards/*.sh; never executed directly.
#
# Public helpers:
#   dd_event          - hook event from input JSON
#   dd_tool_name      - tool name from input JSON
#   dd_tool_patch     - patch/diff payload from input JSON
#   dd_stop_active    - 0/1 based on stop_hook_active
#   dd_session_id     - session id from input JSON
#   dd_transcript     - transcript path, resolving session fallback
#   dd_state_file     - per-session guard state under LAICLUSE_HOME
#   dd_assistant_text - last-turn assistant text, optional line-tracking
#   dd_is_wip         - 0 if the assistant text contains 🚧
#   dd_emit_block     - Stop-style block JSON with mnemonic prefix
#   dd_emit_deny      - PreToolUse stderr + exit 2, mnemonic prefix
#   dd_emit_ask       - PreToolUse permissionDecision ask, deny where unsupported (allow-comment: keeps the public helper index complete)
#   dd_emit_context   - PostToolUse additionalContext JSON, mnemonic prefix
#
# Every emit helper prefixes the message with "[dont-do-that/<mnemonic>] ".
# That prefix is the stable code the operator and agent can recognise at a
# glance without reading the whole reason.

dd_event() {
  jq -r '.hook_event_name // empty' <<< "$1" 2>/dev/null
}

dd_tool_name() {
  jq -r '.tool_name // empty' <<< "$1" 2>/dev/null
}

dd_tool_patch() {
  jq -r '
    if (.tool_input | type) == "string" then
      .tool_input
    else
      .tool_input.patch
      // .tool_input.diff
      // .tool_input.input
      // .tool_input.command
      // .tool_input.content
      // .tool_input.cmd
      // empty
    end
  ' <<< "$1" 2>/dev/null
}

dd_stop_active() {
  local v
  v=$(jq -r '.stop_hook_active // false' <<< "$1" 2>/dev/null)
  [ "$v" = "true" ]
}

dd_session_id() {
  jq -r '.session_id // .sessionId // empty' <<< "$1" 2>/dev/null
}

dd_transcript() {
  local input="$1"
  local t
  t=$(jq -r '.transcript_path // empty' <<< "$input" 2>/dev/null)
  if [ -n "$t" ] && [ -f "$t" ]; then
    echo "$t"
    return 0
  fi
  local sid
  sid=$(dd_session_id "$input")
  [ -z "$sid" ] && return 1
  local base found
  for base in "$HOME/.claude/projects" "$HOME/.codex/sessions"; do
    [ -d "$base" ] || continue
    found=$(find "$base" -name "*${sid}.jsonl" -type f 2>/dev/null | head -1)
    if [ -n "$found" ]; then
      echo "$found"
      return 0
    fi
  done
  return 1
}

# dd_command_segments <command>. allow-comment: load-bearing. Prints one top-level shell segment per line, splitting on unquoted && || ; | & and newlines while leaving quoted text intact, so a guard that classifies "what this command does" reads every subcommand instead of only the head. Without it a gate is bypassed by putting the interesting call second, and a quoted separator inside a commit message or PR title is not mistaken for one.
dd_command_segments() {
  local cmd="$1" seg="" quote="" ch i
  for (( i=0; i<${#cmd}; i++ )); do
    ch="${cmd:i:1}"
    if [ -n "$quote" ]; then
      seg+="$ch"
      if [ "$ch" = '\' ] && [ "$quote" = '"' ]; then
        i=$((i + 1))
        seg+="${cmd:i:1}"
        continue
      fi
      [ "$ch" = "$quote" ] && quote=""
      continue
    fi
    case "$ch" in
      \'|\")
        quote="$ch"
        seg+="$ch"
        ;;
      '&'|'|'|';'|$'\n')
        printf '%s\n' "$seg"
        seg=""
        ;;
      *)
        seg+="$ch"
        ;;
    esac
  done
  printf '%s\n' "$seg"
}

# dd_command_unquoted <segment>. allow-comment: load-bearing. Prints the segment with every quoted span blanked out, so a matcher sees only what the shell would execute as words. Command text quoted inside an echo, a commit message or a test fixture is data, and a gate that fires on it blocks writing about the command instead of running it.
dd_command_unquoted() {
  local seg="$1" out="" quote="" ch i
  for (( i=0; i<${#seg}; i++ )); do
    ch="${seg:i:1}"
    if [ -n "$quote" ]; then
      if [ "$ch" = '\' ] && [ "$quote" = '"' ]; then
        i=$((i + 1))
        out+="  "
        continue
      fi
      if [ "$ch" = "$quote" ]; then
        quote=""
        out+=" "
      else
        out+=" "
      fi
      continue
    fi
    case "$ch" in
      \'|\")
        quote="$ch"
        out+=" "
        ;;
      *)
        out+="$ch"
        ;;
    esac
  done
  printf '%s\n' "$out"
}

dd_state_file() {
  local name="$1" sid="$2"
  [ -n "$name" ] || return 1
  [ -n "$sid" ] || return 1

  local root safe
  root="${LAICLUSE_HOME:-$HOME/.laicluse}/dont-do-that/state"
  mkdir -p "$root" 2>/dev/null || return 1
  safe=$(printf '%s' "$sid" | tr -c 'A-Za-z0-9._-' '_')
  printf '%s/%s-%s\n' "$root" "$name" "$safe"
}

dd_is_wip() {
  grep -q '🚧' <<< "$1"
}

dd_host_will_resume_session() {
  jq -e '
    ([.background_tasks[]? | select((.status // "running") | test("^(running|pending)$"))] | length > 0)
    or ([.session_crons[]? | select(.recurring == false)] | length > 0)
  ' <<< "$1" >/dev/null 2>&1
}

dd_without_quoted_spans() {
  python3 -c '
import re, sys
text = sys.stdin.read()
fenced_code = r"```.*?```"
inline_code = r"`[^`\n]*`"
url = r"https?://\S+"
straight_quote = r"\"[^\"\n]*\""
curly_quote = "[“„][^“”„\n]*”"
text = re.sub(fenced_code, " ", text, flags=re.S)
for span in (inline_code, url, straight_quote, curly_quote):
    text = re.sub(span, " ", text)
sys.stdout.write(text)
' <<< "$1" 2>/dev/null || printf '%s' "$1"
}

dd_external_irreversible_gate() {
  local text="$1"
  grep -qiE '(gh[[:space:]]+repo[[:space:]]+(create|fork)|git[[:space:]]+remote[[:space:]]+(add|set-url)|git[[:space:]]+push|npm[[:space:]]+publish)' <<< "$text" && return 0
  grep -qiE '\b(force[ -]?push|merge[[:space:]]+(to|into)[[:space:]]+(main|master|default))\b' <<< "$text" && return 0
  grep -qiE '\bpush(en|ed|ing)?\b[^?]{0,80}\b(change|changes|wijziging|wijzigingen)\b([[:space:]]*[?]|[^?]{0,40}\b(to|naar|origin|remote|repo|github|production|productie|prod|staging|branch)\b)' <<< "$text" && return 0
  grep -qiE '\b(push(en|ed|ing)?|publish(es|ed|ing)?|deploy(s|ed|ing)?)\b[^?]{0,80}\b(branch|commit|origin|remote|repo|pr|pull request|tag|image|package|registry|release|production|productie|prod|staging|cluster|server|shared infra|shared infrastructure)\b' <<< "$text" && return 0
  grep -qiE '\b(remote repo|github repo|public repo|account-bound|external irreversible|app store|dns|shared infra|shared infrastructure)\b' <<< "$text" && return 0
  return 1
}

# dd_assistant_text <input-json> <char-budget> [guard-name]
# Returns the tail of the current turn's assistant text.
# When guard-name is set, tracks last-seen transcript line count under
# ${LAICLUSE_HOME:-~/.laicluse}/dont-do-that/state/, scanning only new lines. This matches
# the pre-refactor behavior of the individual scripts.
dd_assistant_text() {
  local input="$1"
  local chars="${2:-1000}"
  local guard="${3:-}"

  local msg
  msg=$(jq -r '.last_assistant_message // empty' <<< "$input" 2>/dev/null)
  if [ -n "$msg" ]; then
    echo "$msg" | tail -c "$chars"
    return 0
  fi

  local sid
  sid=$(dd_session_id "$input")
  [ -z "$sid" ] && return 1

  local tr
  tr=$(dd_transcript "$input")
  [ -z "$tr" ] || [ ! -f "$tr" ] && return 1

  local tail_lines=50
  if [ -n "$guard" ]; then
    local line_file
    line_file=$(dd_state_file "$guard" "$sid") || return 1
    local total last
    total=$(wc -l < "$tr" | tr -d ' ')
    if [ -f "$line_file" ]; then
      last=$(cat "$line_file")
    else
      last=$((total > 30 ? total - 30 : 0))
    fi
    echo "$total" > "$line_file"
    tail_lines=$((total - last))
    [ "$tail_lines" -le 0 ] && return 1
  fi

  tail -"$tail_lines" "$tr" \
    | jq -s -r '
        . as $all
        | ([$all | to_entries[] | select(.value.type == "user") | .key] | last // -1) as $lu
        | $all[$lu + 1:]
        | map(select(.type == "assistant") | .message.content[]? | select(.type == "text") | .text)
        | join("\n")
      ' 2>/dev/null \
    | tail -c "$chars"
}

# dd_emit_block <mnemonic> <message>
# Stop hook: print one-line JSON and exit 0. The reason carries the mnemonic
# prefix so the transcript shows e.g. [dont-do-that/cache] Cache is ...
dd_emit_block() {
  local mnemonic="$1"
  local msg="$2"
  jq -cn --arg r "[dont-do-that/${mnemonic}] ${msg}" '{decision:"block", reason:$r}'
  exit 0
}

# dd_emit_deny <mnemonic> <message>
# PreToolUse hook: print one-line stderr and exit 2 (blocks the tool).
dd_emit_deny() {
  local mnemonic="$1"
  local msg="$2"
  printf '[dont-do-that/%s] %s\n' "$mnemonic" "$msg" >&2
  exit 2
}

# dd_emit_ask <mnemonic> <message>. allow-comment: load-bearing. PreToolUse hook that routes the decision to the operator through the host's own permission prompt, which shows them the exact pending command. Use it instead of inferring approval from the operator's wording: the host owns the question, the guard only decides which commands deserve one. The ask needs an explicit DD_AGENT=claude rather than dd_agent's claude default, because an unset or unknown agent has no proven ask channel and would silently proceed on JSON it cannot read; everything except a signalled Claude falls back to the hard deny with the same reason. Emitting exit 0 keeps stdout a single JSON object, which only holds while this remains the last guard in its lane.
dd_emit_ask() {
  local mnemonic="$1"
  local msg="$2"
  local input="${3:-}"
  local mode
  mode=$(jq -r '.permission_mode // empty' <<< "$input" 2>/dev/null)
  case "$mode" in
    default|acceptEdits) ;;
    *) dd_emit_deny "$mnemonic" "$msg Refused rather than asked: this session runs in permission mode '${mode:-unknown}', where the prompt is resolved without the operator seeing it." ;;
  esac
  if [ "${DD_AGENT:-}" = "claude" ]; then
    jq -cn --arg r "[dont-do-that/${mnemonic}] ${msg}" '{hookSpecificOutput:{hookEventName:"PreToolUse", permissionDecision:"ask", permissionDecisionReason:$r}}'
    exit 0
  fi
  dd_emit_deny "$mnemonic" "$msg"
}

# dd_emit_context <mnemonic> <message>
# PostToolUse hook: print additionalContext JSON (does not block, surfaces text).
dd_emit_context() {
  local mnemonic="$1"
  local msg="$2"
  jq -cn --arg c "[dont-do-that/${mnemonic}] ${msg}" \
    '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $c}}'
}

# dd_emit_pre_context <mnemonic> <message>
# PreToolUse hook: print additionalContext JSON (does not block, surfaces text
# to the agent in the next turn so it can adjust subsequent calls).
dd_emit_pre_context() {
  local mnemonic="$1"
  local msg="$2"
  jq -cn --arg c "[dont-do-that/${mnemonic}] ${msg}" \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", additionalContext: $c}}'
}

dd_guard_list_has() {
  local list="$1" guard="$2" normalised
  normalised=$(printf '%s' "$list" | tr '[:space:]' ',' | sed -E 's/,+/,/g')
  case ",$normalised," in
    *",$guard,"*) return 0 ;;
    *) return 1 ;;
  esac
}

dd_guard_list_empty() {
  [ -z "$(printf '%s' "$1" | tr -d '[:space:],')" ]
}

dd_guard_enabled() {
  local guard="$1" event="$2" suffix skip_var only_var skip_event only_event skip only
  suffix=$(printf '%s' "$event" | tr '[:lower:]' '[:upper:]' | tr -cd 'A-Z0-9_')
  skip_var="DD_SKIP_${suffix}_GUARDS"
  only_var="DD_ONLY_${suffix}_GUARDS"
  skip_event="${!skip_var-}"
  only_event="${!only_var-}"
  skip="${DD_SKIP_GUARDS:-} ${skip_event}"
  only="${DD_ONLY_GUARDS:-} ${only_event}"

  if dd_guard_list_has "$skip" "$guard"; then
    return 1
  fi
  if dd_guard_list_empty "$only"; then
    return 0
  fi
  dd_guard_list_has "$only" "$guard"
}

# hooks/guards.json is the source of truth for which guard runs on which lane for which agent; DD_REGISTRY overrides it for tests. allow-comment: BASH_SOURCE[0] resolves to common.sh so the registry path stays anchored to the plugin regardless of caller cwd.
dd_registry_file() {
  printf '%s\n' "${DD_REGISTRY:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../guards.json}"
}

# dd_registry_readable: 0 when the registry exists and parses as JSON, else 1. allow-comment: lets the dispatcher fail closed on the PreToolUse safety gates instead of silently running no guards when guards.json is missing or corrupt.
dd_registry_readable() {
  local registry
  registry="$(dd_registry_file)"
  [ -f "$registry" ] || return 1
  jq -e . "$registry" >/dev/null 2>&1
}

# dd_agent defaults to claude so a direct dispatch run and any manifest without DD_AGENT run the full stack. allow-comment: the default is load-bearing, not decorative.
dd_agent() {
  printf '%s' "${DD_AGENT:-claude}"
}

# dd_registry_lane_guards <lane> prints "<id><TAB><function>" per enabled guard, ascending by order; absence in a guard's agents map defaults to enabled so future agents run the full stack. allow-comment: the enabled-by-default policy is non-obvious.
dd_registry_lane_guards() {
  local lane="$1" registry
  registry="$(dd_registry_file)"
  [ -f "$registry" ] || return 0
  jq -r --arg lane "$lane" --arg agent "$(dd_agent)" '
    .guards
    | to_entries
    | map(select(.value.lane == $lane))
    | map(select((.value.agents[$agent] // "enabled") == "enabled"))
    | sort_by(.value.order)
    | .[] | "\(.key)\t\(.value.function)"
  ' "$registry" 2>/dev/null
}
