#!/usr/bin/env bats
# allow-comment: drives hooks/dispatch.sh against real repos whose origin/HEAD
# allow-comment: names main, asserting that merging the default branch into a
# allow-comment: feature branch is refused while other merges pass.

SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
DISPATCH="$(cd "$SCRIPT_DIR/../.." && pwd)/hooks/dispatch.sh"

setup() {
  export HOME="$BATS_TEST_TMPDIR/home"
  install -d "$HOME/.claude/plugins"
  export LAICLUSE_HOME="$BATS_TEST_TMPDIR/laicluse"
  install -d "$LAICLUSE_HOME/git-discipline"
  TEST_REPO="$BATS_TEST_TMPDIR/repo"
  git init -q -b main "$TEST_REPO"
  git -C "$TEST_REPO" config user.email test@example.com
  git -C "$TEST_REPO" config user.name Test
  git -C "$TEST_REPO" commit -q --allow-empty -m seed
  git -C "$TEST_REPO" update-ref refs/remotes/origin/main HEAD
  git -C "$TEST_REPO" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
  git -C "$TEST_REPO" checkout -q -b feature/check-in
}

dispatch() {
  jq -cn --arg c "$1" '{hook_event_name:"PreToolUse",tool_name:"Bash",session_id:"s",tool_input:{command:$c}}' > "$BATS_TEST_TMPDIR/payload.json"
  run bash -c "cd '$TEST_REPO' && bash '$DISPATCH' < '$BATS_TEST_TMPDIR/payload.json'"
}

@test "merging origin/main into a feature branch is refused with the rebase route" {
  dispatch 'git merge --no-ff --no-commit origin/main'
  [ "$status" -eq 2 ]
  [[ "$output" == *"[git-discipline/default-merge]"* ]]
  [[ "$output" == *"rebase-latest-default"* ]]
  [[ "$output" == *"--force-with-lease"* ]]
}

@test "merging local main into a feature branch is refused" {
  dispatch 'git merge main'
  [ "$status" -eq 2 ]
  [[ "$output" == *"[git-discipline/default-merge]"* ]]
}

@test "aborting or continuing a merge passes" {
  dispatch 'git merge --abort'
  [ "$status" -eq 0 ]
  dispatch 'git merge --continue'
  [[ "$output" != *"default-merge"* ]]
}

@test "merging a feature branch into the default branch passes" {
  git -C "$TEST_REPO" checkout -q main
  dispatch 'git merge --no-ff feature/check-in'
  [[ "$output" != *"default-merge"* ]]
}

@test "merging another branch into a feature branch passes" {
  dispatch 'git merge feature/other'
  [[ "$output" != *"default-merge"* ]]
}

@test "a deliberate merge commit passes with the escape comment" {
  dispatch 'git merge origin/main # allow-default-merge'
  [[ "$output" != *"default-merge"* ]]
}

@test "git merge-base and merge-tree are not merges" {
  dispatch 'git merge-base --is-ancestor origin/main HEAD'
  [[ "$output" != *"default-merge"* ]]
  dispatch 'git merge-tree --write-tree origin/main HEAD'
  [[ "$output" != *"default-merge"* ]]
}

@test "without origin/HEAD the local init.defaultBranch decides" {
  git -C "$TEST_REPO" symbolic-ref --delete refs/remotes/origin/HEAD
  git -C "$TEST_REPO" config --local init.defaultBranch main
  dispatch 'git merge main'
  [ "$status" -eq 2 ]
  [[ "$output" == *"[git-discipline/default-merge]"* ]]
}
