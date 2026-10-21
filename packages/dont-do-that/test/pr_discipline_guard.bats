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

@test "pr-discipline blocks a markdown link to an image in the PR body" {
  run_guard 'gh pr edit 12 --body "Capture: [monitor.png](https://github.com/o/r/blob/feature/doc/monitor.png)"'

  [ "$status" -ne 0 ]
  [[ "$output" == *"links to an image instead of showing it"* ]]
}

@test "pr-discipline blocks a blob image URL without raw=true" {
  run_guard 'gh pr edit 12 --body "![monitor](https://github.com/o/r/blob/feature/doc/monitor.png)"'

  [ "$status" -ne 0 ]
  [[ "$output" == *"?raw=true"* ]]
}

@test "pr-discipline blocks a bare image URL in the PR body" {
  run_guard 'gh pr edit 12 --body "Zie https://github.com/o/r/releases/download/pr-12-assets/after.png voor het resultaat"'

  [ "$status" -ne 0 ]
  [[ "$output" == *"bare image URL"* ]]
}

@test "pr-discipline accepts inline images with raw=true and release assets" {
  run_guard 'gh pr edit 12 --body "![a](https://github.com/o/r/blob/feature/doc/a.gif?raw=true) <img src=\"https://github.com/o/r/releases/download/pr-12-assets/b.png\" width=\"400\">"'

  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "pr-discipline reads the body from --body-file" {
  printf '%s\n' 'Beeld:' '' '![monitor](https://github.com/o/r/blob/feature/doc/monitor.png)' > "$REPO/body.md"
  run_guard "gh pr edit 12 --body-file $REPO/body.md"

  [ "$status" -ne 0 ]
  [[ "$output" == *"?raw=true"* ]]
}

@test "pr-discipline reads a relative --body-file from the working directory" {
  printf '%s\n' '## Summary' 'Iets.' > "$REPO/body.md"
  run_guard "gh pr create --title 'Patients keep their notes' --base main --body-file body.md"

  [ "$status" -ne 0 ]
  [[ "$output" == *"## Summary"* ]]
}

@test "pr-discipline accepts a clean --body-file" {
  printf '%s\n' '![a](https://github.com/o/r/raw/main/doc/a.png)' > "$REPO/body.md"
  run_guard "gh pr edit 12 --body-file $REPO/body.md"

  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "pr-discipline lets a deliberate image link through with the escape" {
  run_guard 'gh pr edit 12 --body "[monitor.png](https://github.com/o/r/blob/feature/doc/monitor.png)" # allow-image-link'

  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "pr-discipline blocks a task-list checkbox in an inline body" {
  run_guard $'gh pr edit 12 --body "Uitleg.\n\n- [ ] Een read-only query op productie telt de rijen\n- [x] Specs dekken de drie gevallen"'

  [ "$status" -eq 2 ]
  [[ "$output" == *"unchecked task-list box"* ]]
  [[ "$output" == *"Een read-only query"* ]]
}

@test "pr-discipline blocks an unchecked box from --body-file" {
  printf '%s\n' 'Uitleg.' '' '* [ ] Productietelling na de merge' > "$REPO/body.md"
  run_guard "gh pr edit 12 --body-file $REPO/body.md"

  [ "$status" -eq 2 ]
  [[ "$output" == *"unchecked task-list box"* ]]
}

@test "pr-discipline accepts ticked boxes as evidence" {
  run_guard $'gh pr edit 12 --body "- [x] Specs dekken de drie gevallen\n- [x] Migratie herstelde 0 rijen"'

  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "pr-discipline accepts a plain list and bracketed prose" {
  run_guard 'gh pr edit 12 --body "- Specs dekken vijf, zeven en twaalf maanden. Zie [x] in de tabel en array[ ] in Ruby."'

  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
