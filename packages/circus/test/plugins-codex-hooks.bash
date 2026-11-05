#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
circus_bin="$repo_root/packages/circus/bin/circus"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

repo="$tmp/repo"
mkdir -p "$repo/.claude-plugin"
mkdir -p "$repo/packages/probe/.claude-plugin"
mkdir -p "$repo/packages/probe/skills/probe"
mkdir -p "$repo/packages/probe/hooks/guards"

cat > "$repo/.claude-plugin/marketplace.json" <<'JSON'
{
  "name": "probe-marketplace",
  "owner": { "name": "Probe Marketplace" },
  "plugins": [
    { "name": "probe", "description": "Probe plugin.", "source": "./packages/probe" }
  ]
}
JSON

cat > "$repo/packages/probe/.claude-plugin/plugin.json" <<'JSON'
{ "name": "probe", "version": "1.0.0", "description": "Probe plugin." }
JSON

cat > "$repo/packages/probe/skills/probe/SKILL.md" <<'MD'
---
name: probe
description: Probe skill.
---

# probe
MD

cat > "$repo/packages/probe/hooks/hooks.json" <<'JSON'
{
  "description": "Claude-only hook description.",
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|resume",
        "hooks": [
          { "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/dispatch.sh" }
        ]
      }
    ]
  }
}
JSON

if "$circus_bin" plugins build "$repo" >"$tmp/build.out" 2>"$tmp/build.err"; then
  echo "expected direct Codex source with a Claude-style hook manifest to fail" >&2
  exit 1
fi
grep -q "top-level hooks key" "$tmp/build.err"

cat > "$repo/packages/probe/hooks/hooks.codex.json" <<'JSON'
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|resume",
        "hooks": [
          { "type": "command", "command": "${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT}}/hooks/dispatch.sh" }
        ]
      }
    ],
	"PreToolUse": [
	  {
	    "matcher": "Bash",
	    "hooks": [
	      { "type": "command", "command": "PROBE_PREFIX=kept ${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT}}/hooks/dispatch.sh trailing" }
	    ]
	  }
    ]
  }
}
JSON
printf '#!/bin/sh\n[ -z "${PROBE_ROOT_OUTPUT:-}" ] || printf "%%s\\n%%s\\n" "$PLUGIN_ROOT" "$CLAUDE_PLUGIN_ROOT" > "$PROBE_ROOT_OUTPUT"\n[ -z "${PROBE_ARGUMENT_OUTPUT:-}" ] || printf "%%s\\n%%s\\n" "$PROBE_PREFIX" "$1" > "$PROBE_ARGUMENT_OUTPUT"\necho dispatch\n' > "$repo/packages/probe/hooks/dispatch.sh"
printf '#!/bin/sh\necho guard\n' > "$repo/packages/probe/hooks/guards/probe.sh"
chmod +x "$repo/packages/probe/hooks/dispatch.sh"
chmod +x "$repo/packages/probe/hooks/guards/probe.sh"

"$circus_bin" plugins build "$repo" >/dev/null

gen="$repo/.agents/plugins/generated/probe"
test -f "$gen/hooks/hooks.json"
test -f "$gen/hooks/dispatch.sh"
test -f "$gen/hooks/guards/probe.sh"
test ! -f "$gen/hooks/hooks.codex.json"
test "$(jq -r '.version' "$gen/.codex-plugin/plugin.json")" = "1.0.0+codex.hooks.3"
grep -q 'PLUGIN_ROOT' "$gen/hooks/hooks.json"
grep -q '"path": "./.agents/plugins/generated/probe"' "$repo/.agents/plugins/marketplace.json"
loaded_command="$(jq -r '.hooks.SessionStart[0].hooks[0].command' "$gen/hooks/hooks.json")"
cache_root="$tmp/plugin root with spaces"
cp -R "$gen" "$cache_root"
root_output="$tmp/hook roots"
output="$(PLUGIN_ROOT="$cache_root" PROBE_ROOT_OUTPUT="$root_output" sh -c "$loaded_command")"
test "$output" = "dispatch"
test "$(sed -n '1p' "$root_output")" = "$cache_root"
fallback_output="$(PLUGIN_ROOT= CLAUDE_PLUGIN_ROOT="$cache_root" sh -c "$loaded_command")"
test "$fallback_output" = "dispatch"
pretool_command="$(jq -r '.hooks.PreToolUse[0].hooks[0].command' "$gen/hooks/hooks.json")"
argument_output="$tmp/arguments"
pretool_output="$(PLUGIN_ROOT="$cache_root" PROBE_ARGUMENT_OUTPUT="$argument_output" sh -c "$pretool_command")"
test "$pretool_output" = "dispatch"
test "$(sed -n '1p' "$argument_output")" = "kept"
test "$(sed -n '2p' "$argument_output")" = "trailing"

set +e
missing_output="$(PLUGIN_ROOT="$tmp/missing root" sh -c "$pretool_command" 2>&1)"
missing_status=$?
set -e
test "$missing_status" -eq 2
case "$missing_output" in *'hook entry is unavailable'*) ;; *) exit 1 ;; esac
warning_output="$(PLUGIN_ROOT="$tmp/missing root" sh -c "$loaded_command")"
printf '%s' "$warning_output" | jq -e '.systemMessage | contains("hook entry is unavailable")' >/dev/null
chmod -x "$cache_root/hooks/dispatch.sh"
set +e
PLUGIN_ROOT="$cache_root" sh -c "$pretool_command" >"$tmp/non-executable.out" 2>&1
non_executable_status=$?
set -e
test "$non_executable_status" -eq 2

"$circus_bin" plugins check "$repo" >/dev/null
