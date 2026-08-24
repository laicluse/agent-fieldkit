#!/usr/bin/env bash
# Shared setup for the toggle-commands BATS suite.
#
# The four toggle commands run as UserPromptExpansion hooks, so these tests
# feed dispatch.sh a UserPromptExpansion payload rather than a PreToolUse one.
# A real git repo inside BATS_TEST_TMPDIR gives `git rev-parse
# --git-common-dir` a real path; $HOME is redirected so session sentinels land
# in the temp directory and never touch the operator's real
# ${LAICLUSE_HOME:-~/.laicluse}.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DISPATCH="$SCRIPT_DIR/../../hooks/dispatch.sh"

setup() {
  export HOME="$BATS_TEST_TMPDIR"
  unset LAICLUSE_HOME
  cd "$BATS_TEST_TMPDIR"
  git init -q
  git -c user.email=t@t.com -c user.name=t commit --allow-empty -q -m "init"
}

# expansion_json <command-name> [args] [session-id]
expansion_json() {
  local name="$1" args="${2:-}" sid="${3:-test-session}"
  jq -cn --arg n "$name" --arg a "$args" --arg s "$sid" \
    '{hook_event_name:"UserPromptExpansion",command_name:$n,command_args:$a,session_id:$s}'
}

# run_expansion <command-name> [args] [session-id]
run_expansion() {
  local json
  json=$(expansion_json "$@")
  run bash "$DISPATCH" <<< "$json"
}

repo_sentinel() {
  printf '%s/.git/git-discipline-deny' "$BATS_TEST_TMPDIR"
}

session_sentinel() {
  printf '%s/.laicluse/git-discipline/git-discipline-disabled-%s' \
    "$BATS_TEST_TMPDIR" "${1:-test-session}"
}
