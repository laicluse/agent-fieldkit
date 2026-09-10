#!/usr/bin/env bats
# trailer-line-exempt.bats
# commit-format applies the 72-char line ceiling to prose body lines.
# Trailer lines (Key: Value form) carry machine-readable values that
# routinely exceed 72 chars (Red-then-green paths with line+name, long
# Tests paths) and are exempt: they are not narrative, the 72-char rule
# does not improve their readability, and enforcing it forced an amend
# cycle that punished operators for valid input.

setup() {
  TMPDIR_TEST="$(mktemp -d)"
  export TMPDIR_TEST
  COMMON="$BATS_TEST_DIRNAME/../../hooks/lib/common.sh"
  GUARD="$BATS_TEST_DIRNAME/../../hooks/guards/commit-format.sh"
}

teardown() {
  rm -rf "$TMPDIR_TEST"
}

invoke_guard() {
  local cmd="$1"
  local json
  json=$(jq -n --arg cmd "$cmd" '{tool_input:{command:$cmd}}')
  bash -c "
    source '$COMMON'
    dd_emit_pre_context() { printf 'EMITTED:\n%s\n' \"\$2\"; }
    source '$GUARD'
    guard_commit_format '$json'
  " 2>&1
}

@test "long Red-then-green trailer line passes commit-format silently" {
  local msg
  msg='Settings page works on Windows

Body that fits within 72 chars per line.
Second body line that also fits comfortably.

Slice: short
Tests: spec/foo.rb
Red-then-green: packages/git-discipline/test/migrated-hooks/commit-subject-pointer.bats:11 # rotation reminder names a SKILL.md path that resolves to the file
Verified: red-then-green'

  local cmd="git commit -m \"\$(cat <<MSG
${msg}
MSG
)\""
  run invoke_guard "$cmd"
  [[ "$output" != *'max 72'* ]] || {
    printf 'commit-format flagged a long trailer line that should be exempt; output: %s\n' "$output" >&2
    return 1
  }
}

@test "long Verified-how trailer line passes commit-format silently" {
  local msg
  msg='Settings page works on Windows

Body that fits within 72 chars per line.
Second body line that also fits comfortably.

Slice: short
Tests: spec/foo.rb
Red-then-green: n/a (copy-only change to a string, no branch moved)
Verified: agent-confirmed
Verified-how: Due to no operator being at the keyboard for this run, this was confirmed by running the full bats suite and seeing 578 tests pass with no failures.'

  local cmd="git commit -m \"\$(cat <<MSG
${msg}
MSG
)\""
  run invoke_guard "$cmd"
  [[ "$output" != *'max 72'* ]] || {
    printf 'commit-format flagged a long Verified-how line that should be exempt; output: %s\n' "$output" >&2
    return 1
  }
}

@test "long prose body line still triggers commit-format 72-char warning" {
  local msg
  msg='Settings page works on Windows

This commit body has one prose line that is intentionally very long indeed for testing the 72-char ceiling check.

Slice: short
Tests: spec/foo.rb
Red-then-green: yes
Verified: operator-confirmed'

  local cmd="git commit -m \"\$(cat <<MSG
${msg}
MSG
)\""
  run invoke_guard "$cmd"
  [[ "$output" == *'max 72'* ]] || {
    printf 'commit-format did not flag a long prose body line; output: %s\n' "$output" >&2
    return 1
  }
}

@test "long prose line starting with Note prefix still triggers the warning" {
  local msg
  msg='Settings page works on Windows

Normal body line.
Note: this is a long narrative sentence that starts with the Note prefix and exceeds the 72-char ceiling because it is prose, not a trailer.

Slice: short
Tests: spec/foo.rb
Red-then-green: yes
Verified: operator-confirmed'

  local cmd="git commit -m \"\$(cat <<MSG
${msg}
MSG
)\""
  run invoke_guard "$cmd"
  [[ "$output" == *'max 72'* ]] || {
    printf 'commit-format did not flag a long Note: prose line; the trailer allowlist must not exempt mid-body keywords; output: %s\n' "$output" >&2
    return 1
  }
}

@test "long Cucumber trailer line passes commit-format silently" {
  local msg
  msg='Settings page works on Windows

Normal body line.
Another normal body line.

Slice: short
Tests: spec/foo.rb
Red-then-green: yes
Verified: operator-confirmed
Cucumber: n/a (no Cucumber feature file in this slice; the next commit will add the feature scenario alongside the implementation)'

  local cmd="git commit -m \"\$(cat <<MSG
${msg}
MSG
)\""
  run invoke_guard "$cmd"
  [[ "$output" != *'max 72'* ]] || {
    printf 'commit-format flagged a long Cucumber trailer that should be exempt; output: %s\n' "$output" >&2
    return 1
  }
}

@test "Co-Authored-By trailer with long email passes silently" {
  local msg
  msg='Settings page works on Windows

Normal body.
More body.

Slice: short
Tests: spec/foo.rb
Red-then-green: yes
Verified: operator-confirmed
Co-Authored-By: A Very Long Name With Many Words <averylongemailaddress@example.org>'

  local cmd="git commit -m \"\$(cat <<MSG
${msg}
MSG
)\""
  run invoke_guard "$cmd"
  [[ "$output" != *'max 72'* ]] || {
    printf 'commit-format flagged a long Co-Authored-By trailer that should be exempt; output: %s\n' "$output" >&2
    return 1
  }
}
