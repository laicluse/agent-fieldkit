#!/bin/bash
set -euo pipefail

plugin_root="${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT:-}}"
[[ -n "$plugin_root" && -x "$plugin_root/bin/git-discipline" ]] || exit 0
node "${plugin_root}/bin/git-discipline" runtime install >/dev/null
