#!/usr/bin/env bats
# Red-then-green trailer: valid values, absent trailer, bare n/a without rationale.

load helpers

# ---------------------------------------------------------------------------
# Helper: body with a given RTG value
# ---------------------------------------------------------------------------

_body_with_rtg() {
  local rtg_value="$1"
  cat <<MSG
Expose session boundary on transaction events

When StartTransaction or StopTransaction messages arrive with a
meter reading that fails domain validation, we previously rejected
the entire event, which masked session starts and stops.

Tests: spec/services/session_spec.rb
Slice: handler + service + spec
Red-then-green: ${rtg_value}
Verified: operator-confirmed
MSG
}

# ---------------------------------------------------------------------------
# Red-then-green cases (3 cases)
# ---------------------------------------------------------------------------

@test "Red-then-green: bare yes is rejected with red-then-green-bare-yes" {
  export GIT_SHIM_LS_TREE_OUTPUT="spec/services/session_spec.rb"
  use_trailers "Tests: spec/services/session_spec.rb"$'\n'"Slice: handler + service + spec"$'\n'"Red-then-green: yes"$'\n'"Verified: operator-confirmed"

  local file
  file=$(write_fixture "rtg-yes.txt" "$(_body_with_rtg "yes")")

  run invoke_validator "$file"
  [ "$status" -eq 1 ]
  [[ "$output" == *"red-then-green-bare-yes"* ]]
}

@test "Red-then-green: n/a with long rationale is accepted" {
  export GIT_SHIM_LS_TREE_OUTPUT="spec/services/session_spec.rb"
  use_trailers "Tests: spec/services/session_spec.rb"$'\n'"Slice: handler + service + spec"$'\n'"Red-then-green: n/a (adding log line only, no logic change)"$'\n'"Verified: operator-confirmed"

  local file
  file=$(write_fixture "rtg-na-rationale.txt" "$(_body_with_rtg "n/a (adding log line only, no logic change)")")

  run invoke_validator "$file"
  [ "$status" -eq 0 ]
}

@test "Red-then-green: bare n/a without rationale fails" {
  export GIT_SHIM_LS_TREE_OUTPUT="spec/services/session_spec.rb"
  use_trailers "Tests: spec/services/session_spec.rb"$'\n'"Slice: handler + service + spec"$'\n'"Red-then-green: n/a"$'\n'"Verified: operator-confirmed"

  local file
  file=$(write_fixture "rtg-bare-na.txt" "$(_body_with_rtg "n/a")")

  run invoke_validator "$file"
  [ "$status" -eq 1 ]
  [[ "$output" == *"missing-red-then-green"* ]]
}

# ---------------------------------------------------------------------------
# Fix 2: migration-only and spec-only RTG exemption
# ---------------------------------------------------------------------------

@test "Slice: migration-only does not require Red-then-green (Fix 2)" {
  use_trailers "Slice: migration-only"
  local body
  body="$(cat <<'MSG'
Add NOT NULL constraint to sessions.user_id

The column lacked the constraint in the original migration.
Backfill confirmed no nulls exist in production before this runs.

Slice: migration-only
MSG
)"
  local file
  file=$(write_fixture "rtg-migration-only.txt" "$body")

  run invoke_validator "$file"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Spec-path form (insight 1): the trailer names the spec file that was seen
# red, and that path must be in the staged diff so the claim is anchored to
# the commit instead of pointing at any file in the repo.
# ---------------------------------------------------------------------------

@test "Red-then-green: spec-path present in staged diff is accepted" {
  export GIT_SHIM_LS_TREE_OUTPUT="spec/services/session_spec.rb"
  export GIT_SHIM_DIFF_CACHED_OUTPUT="spec/services/session_spec.rb"$'\n'"app/services/session.rb"
  use_trailers "Tests: spec/services/session_spec.rb"$'\n'"Slice: handler + service + spec"$'\n'"Red-then-green: spec/services/session_spec.rb"$'\n'"Verified: operator-confirmed"

  local file
  file=$(write_fixture "rtg-path-staged.txt" "$(_body_with_rtg "spec/services/session_spec.rb")")

  run invoke_validator "$file"
  [ "$status" -eq 0 ]
}

@test "Red-then-green: spec-path NOT in staged diff fails with red-then-green-path-not-in-staged" {
  export GIT_SHIM_LS_TREE_OUTPUT="spec/services/session_spec.rb"
  export GIT_SHIM_DIFF_CACHED_OUTPUT="app/services/session.rb"
  use_trailers "Tests: spec/services/session_spec.rb"$'\n'"Slice: handler + service + spec"$'\n'"Red-then-green: spec/services/session_spec.rb"$'\n'"Verified: operator-confirmed"

  local file
  file=$(write_fixture "rtg-path-not-staged.txt" "$(_body_with_rtg "spec/services/session_spec.rb")")

  run invoke_validator "$file"
  [ "$status" -eq 1 ]
  [[ "$output" == *"red-then-green-path-not-in-staged"* ]]
}

# ---------------------------------------------------------------------------
# Test-name suffix (insight 2): the trailer names <path>:<test-name> and the
# validator checks that the test name actually exists in the staged blob.
# This is what the user is really after: the commit says WHICH test was seen
# red, so the claim cannot be hallucinated.
# ---------------------------------------------------------------------------

@test "Red-then-green: <path>:<line> # <test-name> combined form is accepted" {
  export GIT_SHIM_LS_TREE_OUTPUT="spec/services/session_spec.rb"
  export GIT_SHIM_DIFF_CACHED_OUTPUT="spec/services/session_spec.rb"
  set_staged_blob "spec/services/session_spec.rb" 'describe "session" do
  it "starts a session on StartTransaction" do
    expect(true).to eq(true)
  end
end'
  use_trailers "Tests: spec/services/session_spec.rb"$'\n'"Slice: handler + service + spec"$'\n'"Red-then-green: spec/services/session_spec.rb:2 # starts a session on StartTransaction"$'\n'"Verified: operator-confirmed"

  local file
  file=$(write_fixture "rtg-combined-ok.txt" "$(_body_with_rtg "spec/services/session_spec.rb:2 # starts a session on StartTransaction")")

  run invoke_validator "$file"
  [ "$status" -eq 0 ]
}

@test "Red-then-green: combined form rejects bare <path>:<line> (no test-name)" {
  export GIT_SHIM_LS_TREE_OUTPUT="spec/services/session_spec.rb"
  export GIT_SHIM_DIFF_CACHED_OUTPUT="spec/services/session_spec.rb"
  set_staged_blob "spec/services/session_spec.rb" 'line1
line2
line3'
  use_trailers "Tests: spec/services/session_spec.rb"$'\n'"Slice: handler + spec"$'\n'"Red-then-green: spec/services/session_spec.rb:3"$'\n'"Verified: operator-confirmed"

  local file
  file=$(write_fixture "rtg-bare-line.txt" "$(_body_with_rtg "spec/services/session_spec.rb:3")")

  run invoke_validator "$file"
  [ "$status" -eq 1 ]
  [[ "$output" == *"missing-red-then-green"* ]]
}

@test "Red-then-green: combined form rejects bare <path>:<test-name> (no line)" {
  export GIT_SHIM_LS_TREE_OUTPUT="spec/services/session_spec.rb"
  export GIT_SHIM_DIFF_CACHED_OUTPUT="spec/services/session_spec.rb"
  set_staged_blob "spec/services/session_spec.rb" 'describe "session" do
  it "starts a session on StartTransaction" do
    expect(true).to eq(true)
  end
end'
  use_trailers "Tests: spec/services/session_spec.rb"$'\n'"Slice: handler + service + spec"$'\n'"Red-then-green: spec/services/session_spec.rb:starts a session on StartTransaction"$'\n'"Verified: operator-confirmed"

  local file
  file=$(write_fixture "rtg-bare-name.txt" "$(_body_with_rtg "spec/services/session_spec.rb:starts a session on StartTransaction")")

  run invoke_validator "$file"
  [ "$status" -eq 1 ]
  [[ "$output" == *"missing-red-then-green"* ]]
}

@test "Red-then-green: combined form line out of range fires red-then-green-line-out-of-range" {
  export GIT_SHIM_LS_TREE_OUTPUT="spec/services/session_spec.rb"
  export GIT_SHIM_DIFF_CACHED_OUTPUT="spec/services/session_spec.rb"
  set_staged_blob "spec/services/session_spec.rb" 'describe "x" do
  it "name" do
  end
end'
  use_trailers "Tests: spec/services/session_spec.rb"$'\n'"Slice: handler + spec"$'\n'"Red-then-green: spec/services/session_spec.rb:99 # name"$'\n'"Verified: operator-confirmed"

  local file
  file=$(write_fixture "rtg-combined-line-oob.txt" "$(_body_with_rtg "spec/services/session_spec.rb:99 # name")")

  run invoke_validator "$file"
  [ "$status" -eq 1 ]
  [[ "$output" == *"red-then-green-line-out-of-range"* ]]
  # Range check gates the name check: when the line is out of range,
  # `red-then-green-test-not-found` must NOT also fire (even though "name"
  # is present in the blob via `it "name"`). Asserting the negative pins
  # the check ordering: a future reorder that runs name-check first would
  # surface both errors and break this assertion.
  [[ "$output" != *"red-then-green-test-not-found"* ]]
}

@test "Red-then-green: combined form rejects line zero (1-based numbering)" {
  export GIT_SHIM_LS_TREE_OUTPUT="spec/services/session_spec.rb"
  export GIT_SHIM_DIFF_CACHED_OUTPUT="spec/services/session_spec.rb"
  set_staged_blob "spec/services/session_spec.rb" 'describe "x" do
  it "name" do
  end
end'
  use_trailers "Tests: spec/services/session_spec.rb"$'\n'"Slice: handler + spec"$'\n'"Red-then-green: spec/services/session_spec.rb:0 # name"$'\n'"Verified: operator-confirmed"

  local file
  file=$(write_fixture "rtg-line-zero.txt" "$(_body_with_rtg "spec/services/session_spec.rb:0 # name")")

  run invoke_validator "$file"
  [ "$status" -eq 1 ]
  [[ "$output" == *"missing-red-then-green"* ]]
}

@test "Red-then-green: combined form accepts test name containing # (RSpec Class#method)" {
  export GIT_SHIM_LS_TREE_OUTPUT="spec/services/session_spec.rb"
  export GIT_SHIM_DIFF_CACHED_OUTPUT="spec/services/session_spec.rb"
  set_staged_blob "spec/services/session_spec.rb" 'describe "session" do
  it "Session#start_event with bad reading" do
    expect(true).to eq(true)
  end
end'
  use_trailers "Tests: spec/services/session_spec.rb"$'\n'"Slice: handler + service + spec"$'\n'"Red-then-green: spec/services/session_spec.rb:2 # Session#start_event with bad reading"$'\n'"Verified: operator-confirmed"

  local file
  file=$(write_fixture "rtg-name-with-hash.txt" "$(_body_with_rtg "spec/services/session_spec.rb:2 # Session#start_event with bad reading")")

  run invoke_validator "$file"
  [ "$status" -eq 0 ]
}

@test "Red-then-green: trailing whitespace on the value does not break path parsing" {
  export GIT_SHIM_LS_TREE_OUTPUT="spec/services/session_spec.rb"
  export GIT_SHIM_DIFF_CACHED_OUTPUT="spec/services/session_spec.rb"
  use_trailers "Tests: spec/services/session_spec.rb"$'\n'"Slice: handler + service + spec"$'\n'"Red-then-green: spec/services/session_spec.rb   "$'\n'"Verified: operator-confirmed"

  local file
  file=$(write_fixture "rtg-trailing-space.txt" "$(_body_with_rtg "spec/services/session_spec.rb   ")")

  run invoke_validator "$file"
  [ "$status" -eq 0 ]
}

@test "Red-then-green: combined form name not in blob fires red-then-green-test-not-found" {
  export GIT_SHIM_LS_TREE_OUTPUT="spec/services/session_spec.rb"
  export GIT_SHIM_DIFF_CACHED_OUTPUT="spec/services/session_spec.rb"
  set_staged_blob "spec/services/session_spec.rb" 'describe "session" do
  it "stops a session on StopTransaction" do
    expect(true).to eq(true)
  end
end'
  use_trailers "Tests: spec/services/session_spec.rb"$'\n'"Slice: handler + service + spec"$'\n'"Red-then-green: spec/services/session_spec.rb:2 # starts a session on StartTransaction"$'\n'"Verified: operator-confirmed"

  local file
  file=$(write_fixture "rtg-combined-name-missing.txt" "$(_body_with_rtg "spec/services/session_spec.rb:2 # starts a session on StartTransaction")")

  run invoke_validator "$file"
  [ "$status" -eq 1 ]
  [[ "$output" == *"red-then-green-test-not-found"* ]]
}

# ---------------------------------------------------------------------------
# Combined-form runner-pattern coverage: the test-name half of the suffix is
# matched against runner declarations in the staged blob. The xctest and bats
# variants exercise the func/@test patterns the rspec scenarios above do not
# cover.
# ---------------------------------------------------------------------------

@test "Red-then-green: combined form matches XCTest func declaration" {
  export GIT_SHIM_LS_TREE_OUTPUT="Tests/SessionTests.swift"
  export GIT_SHIM_DIFF_CACHED_OUTPUT="Tests/SessionTests.swift"
  set_staged_blob "Tests/SessionTests.swift" 'import XCTest
final class SessionTests: XCTestCase {
  func testStartSessionOnStartTransaction() {
    XCTAssertTrue(true)
  }
}'
  use_trailers "Tests: Tests/SessionTests.swift"$'\n'"Slice: handler + spec"$'\n'"Red-then-green: Tests/SessionTests.swift:3 # testStartSessionOnStartTransaction"$'\n'"Verified: operator-confirmed"

  local file
  file=$(write_fixture "rtg-xctest.txt" "$(_body_with_rtg "Tests/SessionTests.swift:3 # testStartSessionOnStartTransaction")")

  run invoke_validator "$file"
  [ "$status" -eq 0 ]
}

@test "Red-then-green: combined form matches BATS @test declaration" {
  export GIT_SHIM_LS_TREE_OUTPUT="test/foo.bats"
  export GIT_SHIM_DIFF_CACHED_OUTPUT="test/foo.bats"
  # Build content with printf so the literal "@test" never appears at the
  # start of a line in this .bats source file. The bats preprocessor would
  # otherwise rewrite the line into bats_test_function() syntax before the
  # test runs, and the validator would never see the @test marker we want
  # to match.
  local bats_content
  bats_content=$(printf '#!/usr/bin/env bats\n%s "starts cleanly with no args" {\n  run echo hi\n}\n' "@test")
  set_staged_blob "test/foo.bats" "$bats_content"
  use_trailers "Tests: test/foo.bats"$'\n'"Slice: validator + spec"$'\n'"Red-then-green: test/foo.bats:2 # starts cleanly with no args"$'\n'"Verified: operator-confirmed"

  local file
  file=$(write_fixture "rtg-bats.txt" "$(_body_with_rtg "test/foo.bats:2 # starts cleanly with no args")")

  run invoke_validator "$file"
  [ "$status" -eq 0 ]
}

@test "Red-then-green: combined form matches Playwright test declaration" {
  export GIT_SHIM_LS_TREE_OUTPUT="e2e/selection.spec.js"
  export GIT_SHIM_DIFF_CACHED_OUTPUT="e2e/selection.spec.js"
  set_staged_blob "e2e/selection.spec.js" 'test("selecting a marble adds an optical lens", async ({ page }) => {
  await page.goto("/fixture/");
});'
  use_trailers "Tests: e2e/selection.spec.js"$'\n'"Slice: validator + spec"$'\n'"Red-then-green: e2e/selection.spec.js:1 # selecting a marble adds an optical lens"$'\n'"Verified: operator-confirmed"

  local file
  file=$(write_fixture "rtg-playwright.txt" "$(_body_with_rtg "e2e/selection.spec.js:1 # selecting a marble adds an optical lens")")

  run invoke_validator "$file"
  [ "$status" -eq 0 ]
}

@test "Red-then-green: garbage value (no extension, not yes/n/a) is rejected" {
  export GIT_SHIM_LS_TREE_OUTPUT="spec/services/session_spec.rb"
  use_trailers "Tests: spec/services/session_spec.rb"$'\n'"Slice: handler + service + spec"$'\n'"Red-then-green: probably"$'\n'"Verified: operator-confirmed"

  local file
  file=$(write_fixture "rtg-garbage.txt" "$(_body_with_rtg "probably")")

  run invoke_validator "$file"
  [ "$status" -eq 1 ]
  [[ "$output" == *"missing-red-then-green"* ]]
}

@test "Slice: spec-only does not require Red-then-green (Fix 2)" {
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
  file=$(write_fixture "rtg-spec-only.txt" "$body")

  run invoke_validator "$file"
  [ "$status" -eq 0 ]
}
