#!/bin/sh
set -eu

plugin_root="${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT:-}}"
[ -n "$plugin_root" ] || exit 0

node "$plugin_root/bin/vaultsync" runtime install >/dev/null
