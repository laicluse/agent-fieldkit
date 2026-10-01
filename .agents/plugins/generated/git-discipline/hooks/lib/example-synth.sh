#!/bin/bash
# packages/git-discipline/hooks/lib/example-synth.sh
# Synthesizes a filled example commit body from the staged diff.
# Sourced by commit-body.sh (block-mode) to populate the deny error message.
#
# Public function:
#   git_discipline_synthesize_example
#     Reads staged diff (git diff --cached --name-only + --shortstat).
#     Classifies paths into layers, suggests Slice token and Tests trailer,
#     then prints a multi-line example body on stdout.
#     Never exits non-zero; falls back to a generic template on any error.
#
# Classification logic is delegated to layer-classify.sh (same directory).

# Source the shared classification library.
_ES_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
# shellcheck disable=SC1091
. "$_ES_LIB_DIR/layer-classify.sh"
# Source the small UI-touch helper so the synthesized example can decide
# whether to emit a Visual: line based on the same heuristic the validator
# applies. ui-touch.sh is a leaf lib so this does not pull in the validator.
# shellcheck disable=SC1091
. "$_ES_LIB_DIR/ui-touch.sh"

# git_discipline_synthesize_example
# Prints a multi-line example commit body on stdout.
git_discipline_synthesize_example() {
  # Collect staged paths.
  local staged_paths
  staged_paths=$(git diff --cached --name-only 2>/dev/null || true)

  # Classify using the shared library.
  local layer_summary
  layer_summary=$(printf '%s\n' "$staged_paths" | classify_diff)

  # Collect spec paths for the Tests trailer.
  local spec_paths
  spec_paths=$(printf '%s\n' "$staged_paths" | suggest_tests)

  # Build Slice token.
  # example-synth uses "handler" instead of "backend" for display purposes to
  # match the git-discipline schema vocabulary. Apply that rename here.
  local slice_token
  slice_token=$(suggest_slice "$layer_summary" | sed 's/\bbackend\b/handler/g')

  # Build Tests trailer value.
  local tests_value
  if [[ -n "$spec_paths" ]]; then
    tests_value="$spec_paths"
  elif [[ "$slice_token" = "docs-only" || "$slice_token" = "config-only" || \
          "$slice_token" = "migration-only" ]]; then
    tests_value="n/a (${slice_token})"
  else
    tests_value="<spec-path>"
  fi

  # Determine Red-then-green default.
  local rtg_value
  case "$slice_token" in
    docs-only|config-only)
      rtg_value="n/a (no executable behaviour changed)"
      ;;
    migration-only)
      rtg_value="n/a (schema change, no spec required)"
      ;;
    *)
      rtg_value='<spec-path> | <spec-path>:<line> # <test-name>'
      ;;
  esac

  # Decide whether to emit a Visual: line. The heuristic re-reads the staged
  # diff inside validate-body.sh; the cost is negligible and keeps the helper
  # contract self-contained.
  local visual_value=""
  if _vb_is_ui_touch; then
    visual_value='<what you expected to see, and saw> -> <capture path>'
  fi

  # Print the synthesized example.
  printf '<subject: one imperative sentence>\n'
  printf '\n'
  printf '<WHY paragraph: explain the reason for this change.\n'
  printf 'At least two sentences or 60+ chars ending with a period.>\n'
  printf '\n'
  printf 'Tests: %s\n' "$tests_value"
  printf 'Slice: %s\n' "$slice_token"
  printf 'Red-then-green: %s\n' "$rtg_value"
  if [[ -n "$visual_value" ]]; then
    printf 'Visual: %s\n' "$visual_value"
  fi
  # Verified line: drops on opt-out tokens, mirrors RTG for non-opt-outs.
  case "$slice_token" in
    docs-only|config-only|migration-only|spec-only|chore-deps|revert|merge|wip)
      ;;
    *)
      if [[ "$rtg_value" =~ ^n/a ]]; then
        printf 'Verified: <operator-confirmed | agent-confirmed | <path> | n/a (reason)>\n'
      else
        printf 'Verified: <operator-confirmed | agent-confirmed | <path> | red-then-green | n/a (reason)>\n'
      fi
      printf 'Verified-how: Due to <reason>, this was confirmed by <what you ran and saw>  (required only when Verified: agent-confirmed)\n'
      ;;
  esac
}
