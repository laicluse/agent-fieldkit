#!/usr/bin/env bats
# synth-example.bats
# Verifies that git_discipline_synthesize_example produces the correct Slice token
# and Tests trailer based on staged diff path classification.

load helpers

# ---------------------------------------------------------------------------
# Source example-synth.sh directly so we can call the function in isolation.
# ---------------------------------------------------------------------------

# DISPATCH is defined in helpers.bash as an absolute path; derive the lib
# path from it so the path survives BATS symlink resolution.
_SYNTH_HOOKS_DIR="$(dirname "$DISPATCH")"
SYNTH_LIB="${_SYNTH_HOOKS_DIR}/lib/example-synth.sh"

# run_synth
# Calls git_discipline_synthesize_example after sourcing the library in a subshell
# so the git shim is active and GIT_SHIM_DIFF_NAMES drives output.
run_synth() {
  # The function calls "git diff --cached --name-only" which goes through
  # the shim installed in setup().
  bash -c "source '$SYNTH_LIB'; git_discipline_synthesize_example"
}

# ---------------------------------------------------------------------------
# Backend + spec paths
# ---------------------------------------------------------------------------

@test "backend + spec staged paths produce Slice token with handler and spec" {
  export GIT_SHIM_DIFF_NAMES="$(printf 'app/services/session_service.rb\nspec/services/session_service_spec.rb')"

  result=$(run_synth)

  # Must contain "handler" (backend) and "spec" in the Slice line.
  slice_line=$(printf '%s' "$result" | grep '^Slice:')
  [[ "$slice_line" == *"handler"* ]]
  [[ "$slice_line" == *"spec"* ]]
}

@test "backend + spec staged paths: Tests trailer lists the detected spec path" {
  export GIT_SHIM_DIFF_NAMES="$(printf 'app/services/session_service.rb\nspec/services/session_service_spec.rb')"

  result=$(run_synth)

  tests_line=$(printf '%s' "$result" | grep '^Tests:')
  [[ "$tests_line" == *"session_service_spec.rb"* ]]
}

# ---------------------------------------------------------------------------
# Docs-only paths
# ---------------------------------------------------------------------------

@test "only .md files staged produce Slice: docs-only" {
  export GIT_SHIM_DIFF_NAMES="$(printf 'README.md\ndocs/guide.md\nCHANGELOG.md')"

  result=$(run_synth)

  slice_line=$(printf '%s' "$result" | grep '^Slice:')
  [[ "$slice_line" == *"docs-only"* ]]
}

@test "docs-only: Red-then-green is n/a" {
  export GIT_SHIM_DIFF_NAMES="$(printf 'README.md\ndocs/guide.md')"

  result=$(run_synth)

  rtg_line=$(printf '%s' "$result" | grep '^Red-then-green:')
  [[ "$rtg_line" == *"n/a"* ]]
}

# ---------------------------------------------------------------------------
# Migration-only paths
# ---------------------------------------------------------------------------

@test "db/migrate/ files staged produce Slice: migration-only" {
  export GIT_SHIM_DIFF_NAMES="$(printf 'db/migrate/20260430_add_session_id.rb')"

  result=$(run_synth)

  slice_line=$(printf '%s' "$result" | grep '^Slice:')
  [[ "$slice_line" == *"migration-only"* ]]
}

@test "migration-only: Red-then-green is n/a" {
  export GIT_SHIM_DIFF_NAMES="$(printf 'db/migrate/20260430_add_session_id.rb')"

  result=$(run_synth)

  rtg_line=$(printf '%s' "$result" | grep '^Red-then-green:')
  [[ "$rtg_line" == *"n/a"* ]]
}

# ---------------------------------------------------------------------------
# Mixed layers
# ---------------------------------------------------------------------------

@test "frontend + backend + spec staged paths include all layers in Slice token" {
  export GIT_SHIM_DIFF_NAMES="$(printf 'app/javascript/session.js\napp/controllers/session_controller.rb\nspec/controllers/session_controller_spec.rb')"

  result=$(run_synth)

  slice_line=$(printf '%s' "$result" | grep '^Slice:')
  [[ "$slice_line" == *"frontend"* ]]
  [[ "$slice_line" == *"handler"* ]]
  [[ "$slice_line" == *"spec"* ]]
}

# ---------------------------------------------------------------------------
# Visual: trailer synthesis (driven by UI-touch heuristic in validate-body.sh)
# ---------------------------------------------------------------------------

@test "UI-touched staged paths produce a Visual: line in the example" {
  export GIT_SHIM_DIFF_NAMES="$(printf 'src/components/Banner.tsx\nspec/banner_spec.rb')"

  result=$(run_synth)

  visual_line=$(printf '%s' "$result" | grep '^Visual:' || true)
  [[ -n "$visual_line" ]]
  [[ "$visual_line" == *'-> <capture path>'* ]]
}

@test "non-UI staged paths produce no Visual: line in the example" {
  export GIT_SHIM_DIFF_NAMES="$(printf 'app/services/billing.rb\nspec/services/billing_spec.rb')"

  result=$(run_synth)

  visual_line=$(printf '%s' "$result" | grep '^Visual:' || true)
  [[ -z "$visual_line" ]]
}
