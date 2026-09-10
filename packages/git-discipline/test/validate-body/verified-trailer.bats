#!/usr/bin/env bats
# Verified trailer: self-assessment of how the behaviour change was verified.
# Closed set of forms: operator-confirmed, agent-confirmed (+ Verified-how),
# <artefact path>, red-then-green, n/a (reason). Forces an explicit answer to
# "did the operator see this work, did the agent run it, is there a screenshot,
# or was there a red-then-green test" so a commit cannot slip through on bare
# attestation. build-only was removed.

load helpers

# ---------------------------------------------------------------------------
# Helper: body with given Verified value (RTG defaults to an anchored form)
# ---------------------------------------------------------------------------

_body_with_verified() {
  local verified_value="$1"
  local rtg_value="${2:-n/a (test fixture, no spec applies)}"
  cat <<MSG
Expose session boundary on transaction events

When StartTransaction or StopTransaction messages arrive with a
meter reading that fails domain validation, we previously rejected
the entire event, which masked session starts and stops.

Tests: spec/services/session_spec.rb
Slice: handler + service + spec
Red-then-green: ${rtg_value}
Verified: ${verified_value}
MSG
}

_trailers_with_verified() {
  local verified_value="$1"
  local rtg_value="${2:-n/a (test fixture, no spec applies)}"
  printf 'Tests: spec/services/session_spec.rb\nSlice: handler + service + spec\nRed-then-green: %s\nVerified: %s' "$rtg_value" "$verified_value"
}

# Helpers for agent-confirmed, which needs a companion Verified-how trailer.

_body_with_agent_confirmed() {
  local how_value="$1"
  cat <<MSG
Expose session boundary on transaction events

When StartTransaction or StopTransaction messages arrive with a
meter reading that fails domain validation, we previously rejected
the entire event, which masked session starts and stops.

Tests: spec/services/session_spec.rb
Slice: handler + service + spec
Red-then-green: n/a (test fixture, no spec applies)
Verified: agent-confirmed
Verified-how: ${how_value}
MSG
}

_trailers_with_agent_confirmed() {
  local how_value="$1"
  printf 'Tests: spec/services/session_spec.rb\nSlice: handler + service + spec\nRed-then-green: n/a (test fixture, no spec applies)\nVerified: agent-confirmed\nVerified-how: %s' "$how_value"
}

# ---------------------------------------------------------------------------
# Accepted forms
# ---------------------------------------------------------------------------

@test "Verified: operator-confirmed is accepted" {
  export GIT_SHIM_LS_TREE_OUTPUT="spec/services/session_spec.rb"
  use_trailers "$(_trailers_with_verified "operator-confirmed")"

  local file
  file=$(write_fixture "verified-operator.txt" "$(_body_with_verified "operator-confirmed")")

  run invoke_validator "$file"
  [ "$status" -eq 0 ]
}

@test "Verified: <path that exists> is accepted" {
  export GIT_SHIM_LS_TREE_OUTPUT="spec/services/session_spec.rb"
  local artefact
  artefact=$(write_visual_path "doc/evidence/start-intent.png")
  # Use a repo-relative path in the trailer; the validator resolves against
  # rev-parse --show-toplevel, which the shim points at TMPDIR_TEST.
  local rel="doc/evidence/start-intent.png"
  use_trailers "$(_trailers_with_verified "$rel")"

  local file
  file=$(write_fixture "verified-path-ok.txt" "$(_body_with_verified "$rel")")

  run invoke_validator "$file"
  [ "$status" -eq 0 ]
}

@test "Verified: <path that does not exist> fails verified-path-not-found" {
  export GIT_SHIM_LS_TREE_OUTPUT="spec/services/session_spec.rb"
  use_trailers "$(_trailers_with_verified "doc/evidence/missing.png")"

  local file
  file=$(write_fixture "verified-path-missing.txt" "$(_body_with_verified "doc/evidence/missing.png")")

  run invoke_validator "$file"
  [ "$status" -eq 1 ]
  [[ "$output" == *"verified-path-not-found"* ]]
}

@test "Verified: <spec path> fails verified-path-is-source even when the file exists" {
  export GIT_SHIM_LS_TREE_OUTPUT="spec/services/session_spec.rb"
  local artefact
  artefact=$(write_visual_path "test/support/plugin-manifest.test.sh")
  local rel="test/support/plugin-manifest.test.sh"
  use_trailers "$(_trailers_with_verified "$rel")"

  local file
  file=$(write_fixture "verified-path-source.txt" "$(_body_with_verified "$rel")")

  run invoke_validator "$file"
  [ "$status" -eq 1 ]
  [[ "$output" == *"verified-path-is-source"* ]]
}

@test "Verified: <artefact path> stays accepted alongside the source guard" {
  export GIT_SHIM_LS_TREE_OUTPUT="spec/services/session_spec.rb"
  local artefact
  artefact=$(write_visual_path "doc/evidence/run.log")
  local rel="doc/evidence/run.log"
  use_trailers "$(_trailers_with_verified "$rel")"

  local file
  file=$(write_fixture "verified-path-log.txt" "$(_body_with_verified "$rel")")

  run invoke_validator "$file"
  [ "$status" -eq 0 ]
}

@test "Verified: <artefact older than the previous commit> fails verified-path-stale" {
  export GIT_SHIM_LS_TREE_OUTPUT="spec/services/session_spec.rb"
  local artefact
  artefact=$(write_visual_path "doc/evidence/old-run.log")
  touch -t 202001010000 "$artefact"
  local rel="doc/evidence/old-run.log"
  use_trailers "$(_trailers_with_verified "$rel")"

  local file
  file=$(write_fixture "verified-path-stale.txt" "$(_body_with_verified "$rel")")

  run invoke_validator "$file"
  [ "$status" -eq 1 ]
  [[ "$output" == *"verified-path-stale"* ]]
}

@test "Verified: <artefact captured after the previous commit> is accepted" {
  export GIT_SHIM_LS_TREE_OUTPUT="spec/services/session_spec.rb"
  local artefact
  artefact=$(write_visual_path "doc/evidence/fresh-run.log")
  local rel="doc/evidence/fresh-run.log"
  use_trailers "$(_trailers_with_verified "$rel")"

  local file
  file=$(write_fixture "verified-path-fresh.txt" "$(_body_with_verified "$rel")")

  run invoke_validator "$file"
  [ "$status" -eq 0 ]
}

@test "Verified: red-then-green is accepted when Red-then-green names a staged spec" {
  export GIT_SHIM_LS_TREE_OUTPUT="spec/services/session_spec.rb"
  export GIT_SHIM_DIFF_CACHED_OUTPUT="spec/services/session_spec.rb"
  local rtg="spec/services/session_spec.rb"
  use_trailers "$(_trailers_with_verified "red-then-green" "$rtg")"

  local file
  file=$(write_fixture "verified-rtg-path.txt" "$(_body_with_verified "red-then-green" "$rtg")")

  run invoke_validator "$file"
  [ "$status" -eq 0 ]
}

@test "Verified: red-then-green fails when Red-then-green is n/a" {
  export GIT_SHIM_LS_TREE_OUTPUT="spec/services/session_spec.rb"
  use_trailers "$(_trailers_with_verified "red-then-green" "n/a (adding log line only, no logic change)")"

  local file
  file=$(write_fixture "verified-rtg-na.txt" "$(_body_with_verified "red-then-green" "n/a (adding log line only, no logic change)")")

  run invoke_validator "$file"
  [ "$status" -eq 1 ]
  [[ "$output" == *"verified-red-then-green-mismatch"* ]]
}

@test "Verified: build-only is rejected with verified-build-only-removed" {
  export GIT_SHIM_LS_TREE_OUTPUT="spec/services/session_spec.rb"
  use_trailers "$(_trailers_with_verified "build-only")"

  local file
  file=$(write_fixture "verified-build-only.txt" "$(_body_with_verified "build-only")")

  run invoke_validator "$file"
  [ "$status" -eq 1 ]
  [[ "$output" == *"verified-build-only-removed"* ]]
}

@test "Verified: agent-confirmed with a Verified-how sentence is accepted" {
  export GIT_SHIM_LS_TREE_OUTPUT="spec/services/session_spec.rb"
  local how="Due to no operator at the keyboard, this was confirmed by running the helper against live agents"
  use_trailers "$(_trailers_with_agent_confirmed "$how")"

  local file
  file=$(write_fixture "verified-agent-ok.txt" "$(_body_with_agent_confirmed "$how")")

  run invoke_validator "$file"
  [ "$status" -eq 0 ]
}

@test "Verified: agent-confirmed without Verified-how fails missing-verified-how" {
  export GIT_SHIM_LS_TREE_OUTPUT="spec/services/session_spec.rb"
  use_trailers "$(_trailers_with_verified "agent-confirmed")"

  local file
  file=$(write_fixture "verified-agent-nohow.txt" "$(_body_with_verified "agent-confirmed")")

  run invoke_validator "$file"
  [ "$status" -eq 1 ]
  [[ "$output" == *"missing-verified-how"* ]]
}

@test "Verified: agent-confirmed with a too-short Verified-how fails missing-verified-how" {
  export GIT_SHIM_LS_TREE_OUTPUT="spec/services/session_spec.rb"
  use_trailers "$(_trailers_with_agent_confirmed "ran it")"

  local file
  file=$(write_fixture "verified-agent-short.txt" "$(_body_with_agent_confirmed "ran it")")

  run invoke_validator "$file"
  [ "$status" -eq 1 ]
  [[ "$output" == *"missing-verified-how"* ]]
}

@test "Verified: n/a with recognised category is accepted" {
  export GIT_SHIM_LS_TREE_OUTPUT="spec/services/session_spec.rb"
  use_trailers "$(_trailers_with_verified "n/a (extract-only refactor, no behaviour change)")"

  local file
  file=$(write_fixture "verified-na-ok.txt" "$(_body_with_verified "n/a (extract-only refactor, no behaviour change)")")

  run invoke_validator "$file"
  [ "$status" -eq 0 ]
}

@test "Verified: n/a with vague rationale is rejected" {
  export GIT_SHIM_LS_TREE_OUTPUT="spec/services/session_spec.rb"
  use_trailers "$(_trailers_with_verified "n/a (just felt right)")"

  local file
  file=$(write_fixture "verified-na-vague.txt" "$(_body_with_verified "n/a (just felt right)")")

  run invoke_validator "$file"
  [ "$status" -eq 1 ]
  [[ "$output" == *"verified-rationale-vague"* ]]
}

@test "Verified: bare n/a without rationale is rejected" {
  export GIT_SHIM_LS_TREE_OUTPUT="spec/services/session_spec.rb"
  use_trailers "$(_trailers_with_verified "n/a")"

  local file
  file=$(write_fixture "verified-na-bare.txt" "$(_body_with_verified "n/a")")

  run invoke_validator "$file"
  [ "$status" -eq 1 ]
  [[ "$output" == *"missing-verified"* ]]
}

# ---------------------------------------------------------------------------
# Absence
# ---------------------------------------------------------------------------

@test "Missing Verified trailer fails missing-verified for free-text Slice" {
  export GIT_SHIM_LS_TREE_OUTPUT="spec/services/session_spec.rb"
  use_trailers "Tests: spec/services/session_spec.rb"$'\n'"Slice: handler + service + spec"$'\n'"Red-then-green: n/a (test fixture, no spec applies)"

  local body
  body="$(cat <<'MSG'
Expose session boundary on transaction events

When StartTransaction or StopTransaction messages arrive with a
meter reading that fails domain validation, we previously rejected
the entire event, which masked session starts and stops.

Tests: spec/services/session_spec.rb
Slice: handler + service + spec
Red-then-green: n/a (test fixture, no spec applies)
MSG
)"
  local file
  file=$(write_fixture "verified-absent.txt" "$body")

  run invoke_validator "$file"
  [ "$status" -eq 1 ]
  [[ "$output" == *"missing-verified"* ]]
}

@test "Missing Verified trailer is OK with Slice: docs-only" {
  use_trailers "Slice: docs-only"
  local body
  body="$(cat <<'MSG'
Update install instructions for Windows consumers

The symlink-free layout means Windows users need cp -f instead of
ln -s. The previous instructions silently created a text file.

Slice: docs-only
MSG
)"
  local file
  file=$(write_fixture "verified-docs-only.txt" "$body")

  run invoke_validator "$file"
  [ "$status" -eq 0 ]
}

@test "Missing Verified trailer is OK with Slice: spec-only" {
  use_trailers "Slice: spec-only"
  local body
  body="$(cat <<'MSG'
Add failing specs for enrollment race-condition handler

Tests written first; the handler implementation follows in the
next commit. These specs define the expected behaviour contract.

Slice: spec-only
MSG
)"
  local file
  file=$(write_fixture "verified-spec-only.txt" "$body")

  run invoke_validator "$file"
  [ "$status" -eq 0 ]
}

@test "Verified: garbage value (not a recognised form, not a path) is rejected" {
  export GIT_SHIM_LS_TREE_OUTPUT="spec/services/session_spec.rb"
  use_trailers "$(_trailers_with_verified "probably")"

  local file
  file=$(write_fixture "verified-garbage.txt" "$(_body_with_verified "probably")")

  run invoke_validator "$file"
  [ "$status" -eq 1 ]
  [[ "$output" == *"missing-verified"* ]]
}
