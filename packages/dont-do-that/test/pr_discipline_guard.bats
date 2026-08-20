#!/usr/bin/env bats

DISPATCH="$BATS_TEST_DIRNAME/../hooks/dispatch.sh"

pre_bash_payload() {
  jq -cn --arg cwd "$1" --arg cmd "$2" \
    '{hook_event_name:"PreToolUse", tool_name:"Bash", cwd:$cwd, tool_input:{command:$cmd}}'
}

run_guard() {
  payload="$(pre_bash_payload "$REPO" "$1")"
  run bash -c 'printf "%s" "$1" | DD_AGENT=claude DD_ONLY_PRETOOLUSE_GUARDS=pr-discipline bash "$2"' _ "$payload" "$DISPATCH"
}

setup() {
  export ORIGIN="$BATS_TEST_TMPDIR/origin.git"
  export REPO="$BATS_TEST_TMPDIR/repo"
  git init -q --bare "$ORIGIN"
  git init -q -b main "$REPO"
  git -C "$REPO" config user.email t@example.invalid
  git -C "$REPO" config user.name Test
  echo one > "$REPO/a.txt"
  git -C "$REPO" add a.txt
  git -C "$REPO" commit -qm "first"
  git -C "$REPO" remote add origin "$ORIGIN"
  git -C "$REPO" push -q origin main
  git -C "$REPO" checkout -q -b feature
  echo feature > "$REPO/b.txt"
  git -C "$REPO" add b.txt
  git -C "$REPO" commit -qm "feature work"
}

advance_base() {
  git -C "$REPO" checkout -q main
  echo two >> "$REPO/a.txt"
  git -C "$REPO" commit -qam "base moved"
  git -C "$REPO" push -q origin main
  git -C "$REPO" checkout -q feature
}

@test "pr-discipline blocks gh pr create when the branch is behind its base" {
  advance_base
  run_guard 'gh pr create --title "Patients keep their notes" --base main'

  [ "$status" -ne 0 ]
  [[ "$output" == *"behind main"* ]]
}

@test "pr-discipline stays silent when the branch is current with its base" {
  run_guard 'gh pr create --title "Patients keep their notes" --base main'

  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "pr-discipline exempts gh pr edit from the currency check" {
  advance_base
  run_guard 'gh pr edit 12 --body "nieuwe uitleg"'

  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "pr-discipline honours the allow-behind-default escape" {
  advance_base
  run_guard 'gh pr create --title "Patients keep their notes" --base main # allow-behind-default'

  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
