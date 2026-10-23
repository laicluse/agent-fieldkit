#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
circus_bin="$repo_root/packages/circus/bin/circus"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

repo="$tmp/repo"
mkdir -p "$repo/.claude-plugin" "$repo/packages/probe/.claude-plugin" \
         "$repo/packages/probe/skills/probe" "$repo/.agents/skills/update-ai-models"
cat > "$repo/.claude-plugin/marketplace.json" <<'JSON'
{"name":"probe","owner":{"name":"Probe"},"plugins":[{"name":"probe","source":"./packages/probe"}]}
JSON
cat > "$repo/packages/probe/.claude-plugin/plugin.json" <<'JSON'
{"name":"probe","version":"1.0.0","description":"Probe plugin."}
JSON
cat > "$repo/packages/probe/skills/probe/SKILL.md" <<'MD'
---
name: probe
description: Probe skill.
user-invocable: true
---

# Probe
MD
cat > "$repo/.agents/skills/update-ai-models/SKILL.md" <<'MD'
---
name: update-ai-models
description: Project-only model review.
---

# Update AI models
MD

"$circus_bin" plugins build "$repo" >/dev/null
test -f "$repo/.agents/skills/update-ai-models/SKILL.md"
"$circus_bin" plugins check "$repo" >/dev/null
printf 'ok: project skill survives plugin adapter build\n'
