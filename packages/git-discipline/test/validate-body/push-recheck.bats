#!/usr/bin/env bats
# Push/rebase re-validation must not re-run state-dependent path checks.
#
# The push-body-gate walks the push range and calls validate_body once per
# commit with GIT_DISCIPLINE_VALIDATE_CONTEXT=<sha>. At that point the path-existence
# checks (Tests path in tree/delta, Red-then-green path in delta, Visual path
# on disk, Verified path on disk) are anachronistic: a /tmp screenshot is long
# gone, a spec has moved, an already-merged commit's spec is in a different
# commit's delta. Those checks are only meaningful at commit time, where the
# context is "staged" (normal commit) or "HEAD" (amend).
#
# Each behaviour is asserted as a pair: the check fires at commit time and is
# skipped on push (sha) re-validation. A final test proves the structural
# safety-net (trailer presence) survives in every context, so a body shipped
# via --no-verify is still caught at push.

load helpers

# ---------------------------------------------------------------------------
# Body builders. Each carries a subject, a two-line WHY, and the four trailers;
# the caller varies the one trailer under test. Trailers are mirrored into
# use_trailers so the git interpret-trailers shim returns the matching block.
# ---------------------------------------------------------------------------

_why='The placeholder we shipped last week was a stub; this replaces
it with the reviewed string so analytics stop masking the state.'

_body() {
  # _body <trailer-block>
  printf 'Replace onboarding placeholder\n\n%s\n\n%s\n' "$_why" "$1"
}

# Run the validator under an explicit push-style sha context.
invoke_at_sha() {
  local file="$1"
  bash -c "export GIT_DISCIPLINE_VALIDATE_CONTEXT=deadbeef; source '$VALIDATOR'; validate_body '$file' 2>&1"
}

# ---------------------------------------------------------------------------
# Visual path
# ---------------------------------------------------------------------------

@test "visual-path-not-found fires at commit time (staged context)" {
  export GIT_SHIM_DIFF_CACHED_OUTPUT="lib/app_state.rb"
  export GIT_SHIM_LS_TREE_OUTPUT="spec/services/app_state_spec.rb"
  local trailers='Tests: spec/services/app_state_spec.rb
Slice: backend layer
Red-then-green: n/a (test fixture, no spec applies)
Verified: operator-confirmed
Visual: the banner sits above the tab strip -> /no/such/screenshot.png'
  use_trailers "$trailers"
  local file
  file=$(write_fixture "vis-staged.txt" "$(_body "$trailers")")

  run invoke_validator "$file"
  [ "$status" -eq 1 ]
  [[ "$output" == *"visual-path-not-found"* ]]
}

@test "visual-path-not-found is skipped on push re-validation (sha context)" {
  export GIT_SHIM_LS_TREE_OUTPUT="spec/services/app_state_spec.rb"
  local trailers='Tests: spec/services/app_state_spec.rb
Slice: backend layer
Red-then-green: n/a (test fixture, no spec applies)
Verified: operator-confirmed
Visual: the banner sits above the tab strip -> /no/such/screenshot.png'
  use_trailers "$trailers"
  local file
  file=$(write_fixture "vis-sha.txt" "$(_body "$trailers")")

  run invoke_at_sha "$file"
  [ "$status" -eq 0 ]
  [[ "$output" != *"visual-path-not-found"* ]]
}

# ---------------------------------------------------------------------------
# Verified path
# ---------------------------------------------------------------------------

@test "verified-path-not-found fires at commit time (staged context)" {
  export GIT_SHIM_DIFF_CACHED_OUTPUT="lib/app_state.rb"
  export GIT_SHIM_LS_TREE_OUTPUT="spec/services/app_state_spec.rb"
  local trailers='Tests: spec/services/app_state_spec.rb
Slice: backend layer
Red-then-green: n/a (test fixture, no spec applies)
Verified: /no/such/run.log'
  use_trailers "$trailers"
  local file
  file=$(write_fixture "ver-staged.txt" "$(_body "$trailers")")

  run invoke_validator "$file"
  [ "$status" -eq 1 ]
  [[ "$output" == *"verified-path-not-found"* ]]
}

@test "verified-path-not-found is skipped on push re-validation (sha context)" {
  export GIT_SHIM_LS_TREE_OUTPUT="spec/services/app_state_spec.rb"
  local trailers='Tests: spec/services/app_state_spec.rb
Slice: backend layer
Red-then-green: n/a (test fixture, no spec applies)
Verified: /no/such/run.log'
  use_trailers "$trailers"
  local file
  file=$(write_fixture "ver-sha.txt" "$(_body "$trailers")")

  run invoke_at_sha "$file"
  [ "$status" -eq 0 ]
  [[ "$output" != *"verified-path-not-found"* ]]
}

# ---------------------------------------------------------------------------
# Tests path
# ---------------------------------------------------------------------------

@test "tests-path-not-found fires at commit time (staged context)" {
  export GIT_SHIM_DIFF_CACHED_OUTPUT="lib/app_state.rb"
  export GIT_SHIM_LS_TREE_OUTPUT="lib/app_state.rb"
  local trailers='Tests: spec/services/app_state_spec.rb
Slice: backend layer
Red-then-green: n/a (test fixture, no spec applies)
Verified: operator-confirmed'
  use_trailers "$trailers"
  local file
  file=$(write_fixture "tests-staged.txt" "$(_body "$trailers")")

  run invoke_validator "$file"
  [ "$status" -eq 1 ]
  [[ "$output" == *"tests-path-not-found"* ]]
}

@test "tests-path-not-found is skipped on push re-validation (sha context)" {
  export GIT_SHIM_LS_TREE_OUTPUT="lib/app_state.rb"
  local trailers='Tests: spec/services/app_state_spec.rb
Slice: backend layer
Red-then-green: n/a (test fixture, no spec applies)
Verified: operator-confirmed'
  use_trailers "$trailers"
  local file
  file=$(write_fixture "tests-sha.txt" "$(_body "$trailers")")

  run invoke_at_sha "$file"
  [ "$status" -eq 0 ]
  [[ "$output" != *"tests-path-not-found"* ]]
}

# ---------------------------------------------------------------------------
# Red-then-green path in delta
# ---------------------------------------------------------------------------

@test "red-then-green-path-not-in-staged fires at commit time (staged context)" {
  export GIT_SHIM_DIFF_CACHED_OUTPUT="lib/app_state.rb"
  export GIT_SHIM_LS_TREE_OUTPUT="spec/services/app_state_spec.rb"
  local trailers='Tests: spec/services/app_state_spec.rb
Slice: backend layer
Red-then-green: spec/services/app_state_spec.rb
Verified: operator-confirmed'
  use_trailers "$trailers"
  local file
  file=$(write_fixture "rtg-staged.txt" "$(_body "$trailers")")

  run invoke_validator "$file"
  [ "$status" -eq 1 ]
  [[ "$output" == *"red-then-green-path-not-in-staged"* ]]
}

@test "red-then-green-path-not-in-staged is skipped on push re-validation (sha context)" {
  export GIT_SHIM_LS_TREE_OUTPUT="spec/services/app_state_spec.rb"
  local trailers='Tests: spec/services/app_state_spec.rb
Slice: backend layer
Red-then-green: spec/services/app_state_spec.rb
Verified: operator-confirmed'
  use_trailers "$trailers"
  local file
  file=$(write_fixture "rtg-sha.txt" "$(_body "$trailers")")

  run invoke_at_sha "$file"
  [ "$status" -eq 0 ]
  [[ "$output" != *"red-then-green-path-not-in-staged"* ]]
}

# ---------------------------------------------------------------------------
# Structural safety-net survives at push: a body that omits a trailer is still
# caught under a sha context, so a --no-verify commit cannot slip past push.
# ---------------------------------------------------------------------------

@test "missing trailer is still caught on push re-validation (sha context)" {
  export GIT_SHIM_LS_TREE_OUTPUT="spec/services/app_state_spec.rb"
  use_trailers ""
  local file
  file=$(write_fixture "no-trailers-sha.txt" \
    "$(printf 'Replace onboarding placeholder\n\n%s\n' "$_why")")

  run invoke_at_sha "$file"
  [ "$status" -eq 1 ]
  [[ "$output" == *"missing-slice"* ]]
}
