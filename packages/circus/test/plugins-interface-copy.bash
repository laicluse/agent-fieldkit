#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
circus_bin="$repo_root/packages/circus/bin/circus"
fixture="$(mktemp -d)"
trap 'rm -rf "${fixture:?}"' EXIT
mkdir -p "$fixture/.claude-plugin"
cat > "$fixture/.claude-plugin/marketplace.json" <<'JSON'
{"name":"probe-marketplace","owner":{"name":"Probe"},"plugins":[{"name":"direct","source":"./packages/direct"},{"name":"generated","source":"./packages/generated"}]}
JSON
for plugin in direct generated; do
  mkdir -p "$fixture/packages/$plugin/.claude-plugin" "$fixture/packages/$plugin/skills/inspect"
  jq -n --arg name "$plugin" '{name:$name,version:"1.0.0",description:"Observe connected devices and capture screenshots and logs."}' > "$fixture/packages/$plugin/.claude-plugin/plugin.json"
  cat > "$fixture/packages/$plugin/skills/inspect/SKILL.md" <<'MD'
---
name: inspect
description: Inspect connected devices.
---
Read the device state.
MD
done
python3 - "$fixture/packages/generated/skills/inspect/SKILL.md" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
p.write_text(p.read_text().replace('description: Inspect connected devices.', 'description: Inspect connected devices.\nuser-invocable: true'))
PY

"$circus_bin" plugins build "$fixture" >/dev/null
for manifest in "$fixture/packages/direct/.codex-plugin/plugin.json" "$fixture/.agents/plugins/generated/generated/.codex-plugin/plugin.json"; do
  jq -e '.interface.shortDescription == .description and .interface.longDescription == .description' "$manifest" >/dev/null
done

for plugin in direct generated; do
  printf '%s\n' '{"shortDescription":"Inspect connected devices"}' > "$fixture/packages/$plugin/interface.codex.json"
done
"$circus_bin" plugins build "$fixture" >/dev/null
for manifest in "$fixture/packages/direct/.codex-plugin/plugin.json" "$fixture/.agents/plugins/generated/generated/.codex-plugin/plugin.json"; do
  jq -e '.interface.shortDescription == "Inspect connected devices" and .interface.longDescription == "Observe connected devices and capture screenshots and logs." and .description == .interface.longDescription' "$manifest" >/dev/null
done
"$circus_bin" plugins check "$fixture" >/dev/null

printf '%s\n' '{"shortDescription":42}' > "$fixture/packages/direct/interface.codex.json"
if "$circus_bin" plugins build "$fixture" > "$fixture/error.log" 2>&1; then
  echo 'invalid interface copy was accepted' >&2
  exit 1
fi
grep -q 'interface.codex.json' "$fixture/error.log"
echo 'ok: distinct interface copy, compatible fallback, invalid input'
