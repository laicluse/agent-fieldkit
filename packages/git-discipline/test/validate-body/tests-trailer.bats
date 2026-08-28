#!/usr/bin/env bats
# Tests trailer: presence, absence, path validation, multiple paths.

load helpers

# ---------------------------------------------------------------------------
# Helper: body with custom Tests / Slice / RTG values
# ---------------------------------------------------------------------------

_body_with_trailers() {
  local tests_line="$1"
  local slice_line="${2:-Slice: handler + service + spec}"
  local rtg_line="${3:-Red-then-green: n/a (test fixture, no spec applies)}"
  cat <<MSG
Expose session boundary on transaction events

When StartTransaction or StopTransaction messages arrive with a
meter reading that fails domain validation, we previously rejected
the entire event, which masked session starts and stops in analytics.

${tests_line}
${slice_line}
${rtg_line}
MSG
}

# ---------------------------------------------------------------------------
# Tests trailer cases (4 cases)
# ---------------------------------------------------------------------------

@test "valid Tests path present in HEAD tree passes" {
  export GIT_SHIM_LS_TREE_OUTPUT="spec/services/session_spec.rb"
  use_trailers "Tests: spec/services/session_spec.rb"$'\n'"Slice: handler + service + spec"$'\n'"Red-then-green: n/a (test fixture, no spec applies)"$'\n'"Verified: operator-confirmed"

  local file
  file=$(write_fixture "tests-found.txt" "$(_body_with_trailers "Tests: spec/services/session_spec.rb")")

  run invoke_validator "$file"
  [ "$status" -eq 0 ]
}

@test "Rust Tests path present in staged diff passes" {
  export GIT_SHIM_LS_TREE_OUTPUT=""
  export GIT_SHIM_DIFF_CACHED_OUTPUT="codex-rs/core/src/tools/handlers/unified_exec_tests.rs"
  use_trailers "Tests: codex-rs/core/src/tools/handlers/unified_exec_tests.rs"$'\n'"Slice: handler + spec"$'\n'"Red-then-green: n/a (fixture verifies Tests path parsing)"$'\n'"Verified: operator-confirmed"

  local file
  file=$(write_fixture "rust-tests-found.txt" "$(_body_with_trailers "Tests: codex-rs/core/src/tools/handlers/unified_exec_tests.rs")")

  run invoke_validator "$file"
  [ "$status" -eq 0 ]
}

@test "absent Tests trailer when Slice is not opt-out fails with missing-tests" {
  use_trailers "Slice: handler + service + spec"$'\n'"Red-then-green: n/a (test fixture, no spec applies)"$'\n'"Verified: operator-confirmed"

  local body
  body="$(cat <<'MSG'
Expose session boundary on transaction events

When StartTransaction or StopTransaction messages arrive with a
meter reading that fails domain validation.

Slice: handler + service + spec
Red-then-green: n/a (test fixture, no spec applies)
Verified: operator-confirmed
MSG
)"
  local file
  file=$(write_fixture "no-tests.txt" "$body")

  run invoke_validator "$file"
  [ "$status" -eq 1 ]
  [[ "$output" == *"missing-tests"* ]]
}

@test "Tests path not in HEAD tree or staged diff fails with tests-path-not-found" {
  export GIT_SHIM_LS_TREE_OUTPUT=""
  export GIT_SHIM_DIFF_CACHED_OUTPUT=""
  use_trailers "Tests: spec/services/session_spec.rb"$'\n'"Slice: handler + service + spec"$'\n'"Red-then-green: n/a (test fixture, no spec applies)"$'\n'"Verified: operator-confirmed"

  local file
  file=$(write_fixture "tests-missing.txt" "$(_body_with_trailers "Tests: spec/services/session_spec.rb")")

  run invoke_validator "$file"
  [ "$status" -eq 1 ]
  [[ "$output" == *"tests-path-not-found"* ]]
}

@test "multiple Tests paths pass when at least one exists in HEAD tree" {
  export GIT_SHIM_LS_TREE_OUTPUT="spec/services/session_spec.rb"$'\n'"spec/models/user_spec.rb"
  use_trailers "Tests: spec/services/session_spec.rb, spec/models/user_spec.rb"$'\n'"Slice: handler + service + spec"$'\n'"Red-then-green: n/a (test fixture, no spec applies)"$'\n'"Verified: operator-confirmed"

  local file
  file=$(write_fixture "multi-tests.txt" "$(_body_with_trailers "Tests: spec/services/session_spec.rb, spec/models/user_spec.rb")")

  run invoke_validator "$file"
  [ "$status" -eq 0 ]
}
