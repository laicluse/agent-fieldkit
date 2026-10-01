#!/usr/bin/env bats
# Visual trailer + UI-touch heuristic.
#
# The Visual: trailer mirrors Red-then-green: in format (path or
# "n/a (rationale)"). The trigger is different: Visual is required only when
# the staged diff touches UI files (.tsx, .jsx, .vue, .svelte, .html, .htm,
# .css, .scss, .sass, .less, .erb, .haml, .slim, .storyboard, .xib,
# .xcassets/, or .swift files containing SwiftUI / UIKit / AppKit symbols).
# Backend-only commits do not need the trailer.

load helpers

# ---------------------------------------------------------------------------
# Helpers: build a body with or without a Visual: trailer
# ---------------------------------------------------------------------------

_body_no_visual() {
  cat <<MSG
Render onboarding banner above tab strip

The banner replaces the static placeholder we shipped last week
and now hosts the IAP teaser for unconfigured users.

Tests: spec/views/onboarding_view_spec.rb
Slice: frontend layer
Red-then-green: n/a (test fixture, no spec applies)
Verified: operator-confirmed
MSG
}

_body_with_visual() {
  local visual_value="$1"
  cat <<MSG
Render onboarding banner above tab strip

The banner replaces the static placeholder we shipped last week
and now hosts the IAP teaser for unconfigured users.

Tests: spec/views/onboarding_view_spec.rb
Slice: frontend layer
Red-then-green: n/a (test fixture, no spec applies)
Verified: operator-confirmed
Visual: ${visual_value}
MSG
}

_body_no_visual_backend() {
  cat <<MSG
Treat credentials as orthogonal to purchase state

The computed appState used to short-circuit to .purchased the moment
the engine returned isConfigured. The new onboarding flow breaks that
assumption.

Tests: spec/services/app_state_spec.rb
Slice: backend layer
Red-then-green: n/a (test fixture, no spec applies)
Verified: operator-confirmed
MSG
}

# Standard trailers strings that the shim returns for each fixture variant.
_trailers_no_visual='Tests: spec/views/onboarding_view_spec.rb
Slice: frontend layer
Red-then-green: n/a (test fixture, no spec applies)
Verified: operator-confirmed'

_trailers_with_visual() {
  local visual_value="$1"
  printf '%s\nVisual: %s' "$_trailers_no_visual" "$visual_value"
}

_trailers_backend='Tests: spec/services/app_state_spec.rb
Slice: backend layer
Red-then-green: n/a (test fixture, no spec applies)
Verified: operator-confirmed'

# ---------------------------------------------------------------------------
# UI-touch heuristic returns 0 / 1 for representative file types
# ---------------------------------------------------------------------------

@test "_vb_is_ui_touch: .tsx file is UI-touched" {
  export GIT_SHIM_DIFF_CACHED_OUTPUT="src/App.tsx"
  run bash -c "source '$VALIDATOR'; _vb_is_ui_touch"
  [ "$status" -eq 0 ]
}

@test "_vb_is_ui_touch: .css file is UI-touched" {
  export GIT_SHIM_DIFF_CACHED_OUTPUT="styles/main.css"
  run bash -c "source '$VALIDATOR'; _vb_is_ui_touch"
  [ "$status" -eq 0 ]
}

@test "_vb_is_ui_touch: plain .html file is UI-touched" {
  export GIT_SHIM_DIFF_CACHED_OUTPUT="docs/page/index.html"
  run bash -c "source '$VALIDATOR'; _vb_is_ui_touch"
  [ "$status" -eq 0 ]
}

@test "_vb_is_ui_touch: generated .html (git-discipline-generated) is NOT UI-touched" {
  export GIT_SHIM_DIFF_CACHED_OUTPUT="docs/page/index.html"
  export GIT_SHIM_GENERATED_PATHS="docs/page/index.html"
  run bash -c "source '$VALIDATOR'; _vb_is_ui_touch"
  [ "$status" -eq 1 ]
}

@test "_vb_is_ui_touch: generated mark exempts only marked files; real UI still counts" {
  export GIT_SHIM_DIFF_CACHED_OUTPUT="docs/page/index.html"$'\n'"src/App.tsx"
  export GIT_SHIM_GENERATED_PATHS="docs/page/index.html"
  run bash -c "source '$VALIDATOR'; _vb_is_ui_touch"
  [ "$status" -eq 0 ]
}

@test "_vb_is_ui_touch: .erb file is UI-touched" {
  export GIT_SHIM_DIFF_CACHED_OUTPUT="app/views/layouts/application.html.erb"
  run bash -c "source '$VALIDATOR'; _vb_is_ui_touch"
  [ "$status" -eq 0 ]
}

@test "_vb_is_ui_touch: .swift file with View conformance and brace on next line is UI-touched" {
  set_staged_blob "Sources/Screen.swift" "struct OnboardingView: View
{
  var body: some View { Text(\"hi\") }
}"
  export GIT_SHIM_DIFF_CACHED_OUTPUT="Sources/Screen.swift"
  run bash -c "source '$VALIDATOR'; _vb_is_ui_touch"
  [ "$status" -eq 0 ]
}

@test "_vb_is_ui_touch: .swift file referencing ViewModifier is not UI-touched (regex word-boundary)" {
  set_staged_blob "Sources/Mod.swift" "import Foundation
struct CustomMod: ViewModifier { func body(content: Content) -> some View { content } }"
  export GIT_SHIM_DIFF_CACHED_OUTPUT="Sources/Mod.swift"
  run bash -c "source '$VALIDATOR'; _vb_is_ui_touch"
  # ViewModifier is a SwiftUI type but the conformance does NOT match : View
  # because the boundary check requires a non-identifier char after View. The
  # `some View` reference also doesn't match the conformance pattern because
  # it has no preceding `:`. This is a deliberate trade-off: we catch
  # `import SwiftUI` cases on the same import line, and pure-Foundation
  # ViewModifier helpers are rare enough that the operator can opt-in via
  # Visual: n/a (rationale) when needed.
  [ "$status" -eq 1 ]
}

@test "_vb_is_ui_touch: .swift file with import SwiftUI is UI-touched" {
  set_staged_blob "Sources/Screen.swift" "import SwiftUI

struct OnboardingView: View {
  var body: some View { Text(\"hi\") }
}"
  export GIT_SHIM_DIFF_CACHED_OUTPUT="Sources/Screen.swift"
  run bash -c "source '$VALIDATOR'; _vb_is_ui_touch"
  [ "$status" -eq 0 ]
}

@test "_vb_is_ui_touch: .swift partial-stage that hides UI symbols falls back to working tree" {
  # Simulate `git add -p` of a non-UI hunk: staged blob has only the
  # Foundation portion, but the working-tree file still carries SwiftUI
  # symbols. The heuristic must catch this via the working-tree backstop.
  set_staged_blob "Sources/Mixed.swift" "import Foundation
struct Helper { var x: Int }"
  local wt_file="$TMPDIR_TEST/Sources/Mixed.swift"
  mkdir -p "$(dirname "$wt_file")"
  printf 'import SwiftUI\n\nstruct MixedView: View {\n  var body: some View { Text("hi") }\n}\n' > "$wt_file"

  # Run from $TMPDIR_TEST so the relative path "Sources/Mixed.swift" resolves
  # to the working-tree file we just wrote.
  export GIT_SHIM_DIFF_CACHED_OUTPUT="Sources/Mixed.swift"
  run bash -c "cd '$TMPDIR_TEST' && source '$VALIDATOR'; _vb_is_ui_touch"
  [ "$status" -eq 0 ]
}

@test "_vb_is_ui_touch: .swift file without UI symbols is not UI-touched" {
  set_staged_blob "Sources/Service.swift" "import Foundation

struct AppState {
  var configured: Bool
}"
  export GIT_SHIM_DIFF_CACHED_OUTPUT="Sources/Service.swift"
  run bash -c "source '$VALIDATOR'; _vb_is_ui_touch"
  [ "$status" -eq 1 ]
}

@test "_vb_is_ui_touch: only .rb files staged is not UI-touched" {
  export GIT_SHIM_DIFF_CACHED_OUTPUT="lib/util.rb
spec/util_spec.rb"
  run bash -c "source '$VALIDATOR'; _vb_is_ui_touch"
  [ "$status" -eq 1 ]
}

@test "_vb_is_ui_touch: empty staged diff is not UI-touched" {
  export GIT_SHIM_DIFF_CACHED_OUTPUT=""
  run bash -c "source '$VALIDATOR'; _vb_is_ui_touch"
  [ "$status" -eq 1 ]
}

@test "_vb_is_ui_touch: .xcassets path is UI-touched" {
  export GIT_SHIM_DIFF_CACHED_OUTPUT="App/Assets.xcassets/AppIcon.appiconset/Contents.json"
  run bash -c "source '$VALIDATOR'; _vb_is_ui_touch"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Validator: UI-touched commits require Visual trailer
# ---------------------------------------------------------------------------

@test "UI-touch + relative Visual path resolves against repo root, not \$PWD" {
  export GIT_SHIM_DIFF_CACHED_OUTPUT="src/App.tsx"
  export GIT_SHIM_LS_TREE_OUTPUT="spec/views/onboarding_view_spec.rb"

  # Create the screenshot at <repo-root>/docs/screenshots/foo.png where the
  # shim returns TMPDIR_TEST as repo root.
  mkdir -p "$TMPDIR_TEST/docs/screenshots"
  : > "$TMPDIR_TEST/docs/screenshots/foo.png"

  use_trailers "$(_trailers_with_visual "the banner sits above the tab strip -> docs/screenshots/foo.png")"
  local file
  file=$(write_fixture "vis-relpath.txt" "$(_body_with_visual "the banner sits above the tab strip -> docs/screenshots/foo.png")")

  # Run from a different directory (HOME) to prove the check resolves
  # against repo root, not $PWD.
  run bash -c "cd \"\$HOME\"; source '$VALIDATOR'; validate_body '$file' 2>&1"
  [ "$status" -eq 0 ]
}

@test "UI-touch + Visual: existing path passes" {
  export GIT_SHIM_DIFF_CACHED_OUTPUT="src/App.tsx"
  export GIT_SHIM_LS_TREE_OUTPUT="spec/views/onboarding_view_spec.rb"

  local screenshot
  screenshot=$(write_visual_path "screenshots/onboarding-banner.png")

  use_trailers "$(_trailers_with_visual "the banner sits above the tab strip -> $screenshot")"
  local file
  file=$(write_fixture "vis-path.txt" "$(_body_with_visual "the banner sits above the tab strip -> $screenshot")")

  run invoke_validator "$file"
  [ "$status" -eq 0 ]
}

@test "UI-touch + Visual path without a checked claim fails with visual-claim-missing" {
  export GIT_SHIM_DIFF_CACHED_OUTPUT="src/App.tsx"
  export GIT_SHIM_LS_TREE_OUTPUT="spec/views/onboarding_view_spec.rb"

  local screenshot
  screenshot=$(write_visual_path "screenshots/onboarding-banner.png")

  use_trailers "$(_trailers_with_visual "$screenshot")"
  local file
  file=$(write_fixture "vis-no-claim.txt" "$(_body_with_visual "$screenshot")")

  run invoke_validator "$file"
  [ "$status" -eq 1 ]
  [[ "$output" == *"visual-claim-missing"* ]]
}

@test "UI-touch + Visual claim too short to name an assumption fails" {
  export GIT_SHIM_DIFF_CACHED_OUTPUT="src/App.tsx"
  export GIT_SHIM_LS_TREE_OUTPUT="spec/views/onboarding_view_spec.rb"

  local screenshot
  screenshot=$(write_visual_path "screenshots/onboarding-banner.png")

  use_trailers "$(_trailers_with_visual "looks ok -> $screenshot")"
  local file
  file=$(write_fixture "vis-short-claim.txt" "$(_body_with_visual "looks ok -> $screenshot")")

  run invoke_validator "$file"
  [ "$status" -eq 1 ]
  [[ "$output" == *"visual-claim-missing"* ]]
}

@test "UI-touch + Visual capture under ~/ resolves against HOME" {
  export GIT_SHIM_DIFF_CACHED_OUTPUT="src/App.tsx"
  export GIT_SHIM_LS_TREE_OUTPUT="spec/views/onboarding_view_spec.rb"

  mkdir -p "$HOME/visual-checks"
  : > "$HOME/visual-checks/banner.png"

  use_trailers "$(_trailers_with_visual "the banner sits above the tab strip -> ~/visual-checks/banner.png")"
  local file
  file=$(write_fixture "vis-home.txt" "$(_body_with_visual "the banner sits above the tab strip -> ~/visual-checks/banner.png")")

  run invoke_validator "$file"
  [ "$status" -eq 0 ]
}

@test "UI-touch + capture older than the changed UI file fails with visual-stale" {
  export GIT_SHIM_DIFF_CACHED_OUTPUT="src/App.tsx"
  export GIT_SHIM_LS_TREE_OUTPUT="spec/views/onboarding_view_spec.rb"

  local screenshot
  screenshot=$(write_visual_path "screenshots/onboarding-banner.png")
  touch -t 202001010000 "$screenshot"
  mkdir -p "$TMPDIR_TEST/src"
  : > "$TMPDIR_TEST/src/App.tsx"

  use_trailers "$(_trailers_with_visual "the banner sits above the tab strip -> $screenshot")"
  local file
  file=$(write_fixture "vis-stale.txt" "$(_body_with_visual "the banner sits above the tab strip -> $screenshot")")

  run invoke_validator "$file"
  [ "$status" -eq 1 ]
  [[ "$output" == *"visual-stale"* ]]
}

@test "UI-touch + Visual: n/a fails with visual-na-on-ui-touch (no escape on UI commits)" {
  export GIT_SHIM_DIFF_CACHED_OUTPUT="src/App.tsx"
  export GIT_SHIM_LS_TREE_OUTPUT="spec/views/onboarding_view_spec.rb"

  use_trailers "$(_trailers_with_visual "n/a (logo refresh, no behaviour change)")"
  local file
  file=$(write_fixture "vis-na.txt" "$(_body_with_visual "n/a (logo refresh, no behaviour change)")")

  run invoke_validator "$file"
  [ "$status" -eq 1 ]
  [[ "$output" == *"visual-na-on-ui-touch"* ]]
}

@test "UI-touch + missing Visual fails with missing-visual and names the touched files" {
  export GIT_SHIM_DIFF_CACHED_OUTPUT="src/App.tsx"
  export GIT_SHIM_LS_TREE_OUTPUT="spec/views/onboarding_view_spec.rb"

  use_trailers "$_trailers_no_visual"
  local file
  file=$(write_fixture "vis-missing.txt" "$(_body_no_visual)")

  run invoke_validator "$file"
  [ "$status" -eq 1 ]
  [[ "$output" == *"missing-visual"* ]]
  [[ "$output" == *"src/App.tsx"* ]]
}

@test "UI-touch + bare n/a fails with missing-visual" {
  export GIT_SHIM_DIFF_CACHED_OUTPUT="src/App.tsx"
  export GIT_SHIM_LS_TREE_OUTPUT="spec/views/onboarding_view_spec.rb"

  use_trailers "$(_trailers_with_visual "n/a")"
  local file
  file=$(write_fixture "vis-bare-na.txt" "$(_body_with_visual "n/a")")

  run invoke_validator "$file"
  [ "$status" -eq 1 ]
  [[ "$output" == *"missing-visual"* ]]
}

@test "UI-touch + nonexistent path fails with visual-path-not-found" {
  export GIT_SHIM_DIFF_CACHED_OUTPUT="src/App.tsx"
  export GIT_SHIM_LS_TREE_OUTPUT="spec/views/onboarding_view_spec.rb"

  use_trailers "$(_trailers_with_visual "the banner sits above the tab strip -> /no/such/screenshot.png")"
  local file
  file=$(write_fixture "vis-bad-path.txt" "$(_body_with_visual "the banner sits above the tab strip -> /no/such/screenshot.png")")

  run invoke_validator "$file"
  [ "$status" -eq 1 ]
  [[ "$output" == *"visual-path-not-found"* ]]
}

@test "UI-touch + n/a with too-short rationale fails" {
  export GIT_SHIM_DIFF_CACHED_OUTPUT="src/App.tsx"
  export GIT_SHIM_LS_TREE_OUTPUT="spec/views/onboarding_view_spec.rb"

  use_trailers "$(_trailers_with_visual "n/a (short)")"
  local file
  file=$(write_fixture "vis-short-na.txt" "$(_body_with_visual "n/a (short)")")

  run invoke_validator "$file"
  [ "$status" -eq 1 ]
  [[ "$output" == *"missing-visual"* ]]
}

# ---------------------------------------------------------------------------
# Validator: non-UI commits do not require Visual trailer
# ---------------------------------------------------------------------------

@test "no UI-touch + missing Visual passes (silent on backend-only)" {
  export GIT_SHIM_DIFF_CACHED_OUTPUT="lib/app_state.rb"
  export GIT_SHIM_LS_TREE_OUTPUT="spec/services/app_state_spec.rb"

  use_trailers "$_trailers_backend"
  local file
  file=$(write_fixture "no-ui-no-vis.txt" "$(_body_no_visual_backend)")

  run invoke_validator "$file"
  [ "$status" -eq 0 ]
}

@test "no UI-touch + well-formed Visual: n/a (rationale) passes (format checked when present)" {
  export GIT_SHIM_DIFF_CACHED_OUTPUT="lib/app_state.rb"
  export GIT_SHIM_LS_TREE_OUTPUT="spec/services/app_state_spec.rb"

  local body
  body=$(printf '%s\nVisual: n/a (backend rewrite, no UI touched)' "$(_body_no_visual_backend)")

  use_trailers "$(printf '%s\nVisual: n/a (backend rewrite, no UI touched)' "$_trailers_backend")"
  local file
  file=$(write_fixture "no-ui-with-vis.txt" "$body")

  run invoke_validator "$file"
  [ "$status" -eq 0 ]
}

@test "UI-touch + Visual: n/a fails with visual-na-on-ui-touch" {
  export GIT_SHIM_DIFF_CACHED_OUTPUT="src/App.tsx"
  export GIT_SHIM_LS_TREE_OUTPUT="spec/views/onboarding_view_spec.rb"

  use_trailers "$(_trailers_with_visual "n/a (logo refresh, no behaviour change)")"
  local file
  file=$(write_fixture "vis-na-on-ui-touch.txt" "$(_body_with_visual "n/a (logo refresh, no behaviour change)")")

  run invoke_validator "$file"
  [ "$status" -eq 1 ]
  [[ "$output" == *"visual-na-on-ui-touch"* ]]
  [[ "$output" == *"src/App.tsx"* ]]
}

@test "no UI-touch + malformed bare n/a Visual fails (format checked when present)" {
  export GIT_SHIM_DIFF_CACHED_OUTPUT="lib/app_state.rb"
  export GIT_SHIM_LS_TREE_OUTPUT="spec/services/app_state_spec.rb"

  local body
  body=$(printf '%s\nVisual: n/a' "$(_body_no_visual_backend)")

  use_trailers "$(printf '%s\nVisual: n/a' "$_trailers_backend")"
  local file
  file=$(write_fixture "no-ui-bare-na.txt" "$body")

  run invoke_validator "$file"
  [ "$status" -eq 1 ]
  [[ "$output" == *"missing-visual"* ]]
}

# ---------------------------------------------------------------------------
# Validator: deferral language in Visual: n/a rationale
# ---------------------------------------------------------------------------

@test "UI-touch + Visual: n/a rationale that defers to a future event fails" {
  export GIT_SHIM_DIFF_CACHED_OUTPUT="app/components/widget.tsx"
  export GIT_SHIM_LS_TREE_OUTPUT="spec/views/onboarding_view_spec.rb"

  local rationale="visual diff captured on next iteration when needed"
  use_trailers "$(_trailers_with_visual "n/a ($rationale)")"
  local file
  file=$(write_fixture "vis-defer.txt" "$(_body_with_visual "n/a ($rationale)")")

  run invoke_validator "$file"
  [ "$status" -eq 1 ]
  [[ "$output" == *"visual-rationale-defers"* ]]
}

@test "UI-touch + Visual: n/a rationale promising a follow-up screenshot fails" {
  export GIT_SHIM_DIFF_CACHED_OUTPUT="app/components/widget.tsx"
  export GIT_SHIM_LS_TREE_OUTPUT="spec/views/onboarding_view_spec.rb"

  local rationale="screenshot to be captured later as follow-up"
  use_trailers "$(_trailers_with_visual "n/a ($rationale)")"
  local file
  file=$(write_fixture "vis-followup.txt" "$(_body_with_visual "n/a ($rationale)")")

  run invoke_validator "$file"
  [ "$status" -eq 1 ]
  [[ "$output" == *"visual-rationale-defers"* ]]
}

@test "UI-touch + Visual: n/a with recognized category still fails (UI commits cannot opt out)" {
  export GIT_SHIM_DIFF_CACHED_OUTPUT="app/components/widget.tsx"
  export GIT_SHIM_LS_TREE_OUTPUT="spec/views/onboarding_view_spec.rb"

  local rationale="extract-only refactor; render output byte-identical"
  use_trailers "$(_trailers_with_visual "n/a ($rationale)")"
  local file
  file=$(write_fixture "vis-extract.txt" "$(_body_with_visual "n/a ($rationale)")")

  run invoke_validator "$file"
  [ "$status" -eq 1 ]
  [[ "$output" == *"visual-na-on-ui-touch"* ]]
}

@test "UI-touch + Visual: n/a vague rationale without recognized category fails" {
  export GIT_SHIM_DIFF_CACHED_OUTPUT="app/components/widget.tsx"
  export GIT_SHIM_LS_TREE_OUTPUT="spec/views/onboarding_view_spec.rb"

  local rationale="some hand-wavy reason that does not classify"
  use_trailers "$(_trailers_with_visual "n/a ($rationale)")"
  local file
  file=$(write_fixture "vis-vague.txt" "$(_body_with_visual "n/a ($rationale)")")

  run invoke_validator "$file"
  [ "$status" -eq 1 ]
  [[ "$output" == *"visual-rationale-vague"* ]]
}
