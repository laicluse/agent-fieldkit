#!/usr/bin/env bats

DISPATCH="$BATS_TEST_DIRNAME/../hooks/dispatch.sh"

pre_bash_payload() {
  jq -cn --arg cwd "$1" --arg cmd "$2" --arg mode "${3:-default}" \
    '{hook_event_name:"PreToolUse", tool_name:"Bash", cwd:$cwd, permission_mode:$mode, tool_input:{command:$cmd}}'
}

run_guard() {
  run bash -c 'printf "%s" "$1" | DD_AGENT=claude DD_ONLY_PRETOOLUSE_GUARDS=plugin-mutation bash "$2"' _ "$1" "$DISPATCH"
}

@test "updating an installed plugin is ordinary work, in any permission mode" {
  for mode in default auto bypassPermissions; do
    for command in "claude plugins update dibs@example"; do
      run_guard "$(pre_bash_payload "$BATS_TEST_TMPDIR" "$command" "$mode")"
      [ "$status" -eq 0 ]
      [ -z "$output" ]
    done
  done
}

@test "codex plugin add refreshes an installed plugin without asking" {
  mkdir -p "$BATS_TEST_TMPDIR/codex/plugins/cache/example/dibs"
  payload="$(pre_bash_payload "$BATS_TEST_TMPDIR" "codex plugin add dibs@example" "bypassPermissions")"
  run bash -c 'printf "%s" "$1" | CODEX_HOME="$3" DD_AGENT=claude DD_ONLY_PRETOOLUSE_GUARDS=plugin-mutation bash "$2"' _ "$payload" "$DISPATCH" "$BATS_TEST_TMPDIR/codex"

  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "codex plugin add of a plugin that is not installed stays gated" {
  mkdir -p "$BATS_TEST_TMPDIR/codex/plugins/cache/example"
  payload="$(pre_bash_payload "$BATS_TEST_TMPDIR" "codex plugin add dibs@example" "bypassPermissions")"
  run bash -c 'printf "%s" "$1" | CODEX_HOME="$3" DD_AGENT=claude DD_ONLY_PRETOOLUSE_GUARDS=plugin-mutation bash "$2"' _ "$payload" "$DISPATCH" "$BATS_TEST_TMPDIR/codex"

  [ "$status" -ne 0 ] || [ -n "$output" ]
  [[ "$output" == *"plugin-mutation"* ]]
}

@test "enabling an installed plugin is ordinary work" {
  run_guard "$(pre_bash_payload "$BATS_TEST_TMPDIR" "claude plugins enable dibs@example" "bypassPermissions")"

  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "registering a marketplace asks the operator when the prompt is shown" {
  run_guard "$(pre_bash_payload "$BATS_TEST_TMPDIR" "claude plugins marketplace add /tmp/example" "default")"

  [ "$status" -eq 0 ]
  [ "$(jq -r '.hookSpecificOutput.permissionDecision' <<< "$output")" = "ask" ]
}

@test "removing protection is gated even where a prompt would be answered for you" {
  for command in "claude plugins uninstall dont-do-that@example" "claude plugins disable dont-do-that@example" "codex plugin marketplace add /tmp/example"; do
    run_guard "$(pre_bash_payload "$BATS_TEST_TMPDIR" "$command" "bypassPermissions")"
    [ "$status" -eq 2 ]
    [[ "$output" == *"DD_PLUGIN_MUTATION=asked"* ]]
  done
}

@test "the operator escape lets the gated command through without a prompt" {
  run_guard "$(pre_bash_payload "$BATS_TEST_TMPDIR" "DD_PLUGIN_MUTATION=asked claude plugins marketplace add /tmp/example" "bypassPermissions")"

  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "the escape only counts on the segment that carries the mutation" {
  for command in \
    "echo DD_PLUGIN_MUTATION=asked ; claude plugins uninstall dibs@example" \
    "echo DD_PLUGIN_MUTATION=asked && claude plugins uninstall dibs@example" \
    "claude plugins uninstall dibs@example # DD_PLUGIN_MUTATION=asked" ; do
    run_guard "$(pre_bash_payload "$BATS_TEST_TMPDIR" "$command" "bypassPermissions")"
    [ "$status" -eq 2 ]
    [[ "$output" == *"DD_PLUGIN_MUTATION=asked"* ]]
  done
}

@test "the escape still counts when earlier commands precede the mutation" {
  run_guard "$(pre_bash_payload "$BATS_TEST_TMPDIR" "git status && DD_PLUGIN_MUTATION=asked claude plugins uninstall dibs@example" "bypassPermissions")"

  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "an agent without an ask channel gets the deny with the same escape" {
  payload="$(pre_bash_payload "$BATS_TEST_TMPDIR" "claude plugins uninstall dibs@example" "default")"

  run bash -c 'printf "%s" "$1" | DD_AGENT=codex DD_ONLY_PRETOOLUSE_GUARDS=plugin-mutation bash "$2"' _ "$payload" "$DISPATCH"

  [ "$status" -eq 2 ]
  [[ "$output" == *"DD_PLUGIN_MUTATION=asked"* ]]
}

@test "naming a gated command inside a quoted string is not running it" {
  for command in \
    "echo 'claude plugins uninstall dibs@example'" \
    "printf '%s\\n' \"codex plugin marketplace add /tmp/example\"" \
    "git commit -m 'document why claude plugins uninstall is gated'" \
    "echo 'first ; claude plugins uninstall dibs@example'" \
    "for c in \"a && claude plugins uninstall dibs@example\"; do echo \"\$c\"; done" ; do
    run_guard "$(pre_bash_payload "$BATS_TEST_TMPDIR" "$command" "bypassPermissions")"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
  done
}

@test "plugin mutation guard does not block read-only plugin inspection" {
  run_guard "$(pre_bash_payload "$BATS_TEST_TMPDIR" "codex plugin list --json" "default")"

  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
