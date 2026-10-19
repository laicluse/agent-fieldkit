#!/usr/bin/env bats

load helpers

@test "guard-commit allows primary-checkout authoring by default" {
  git -C "$TEST_REPO" switch -q -c feature

  run bash -c "cd '$TEST_REPO' && '$GIT_DISCIPLINE' guard-commit"

  [ "$status" -eq 0 ]
}

@test "guard-commit ignores a global worktree requirement" {
  git config --global laicluse.requireWorktree true
  git -C "$TEST_REPO" switch -q -c feature

  run bash -c "cd '$TEST_REPO' && '$GIT_DISCIPLINE' guard-commit"

  [ "$status" -eq 0 ]
}

@test "guard-commit blocks primary-checkout authoring when the repo requires a worktree" {
  git -C "$TEST_REPO" switch -q -c feature
  git -C "$TEST_REPO" config --local laicluse.requireWorktree true

  run bash -c "cd '$TEST_REPO' && '$GIT_DISCIPLINE' guard-commit"

  [ "$status" -ne 0 ]
  [[ "$output" == *"primary checkout"* ]]
}

@test "guard-commit allows a feature branch in a linked worktree" {
  git -C "$TEST_REPO" branch feature
  local linked="$BATS_TEST_TMPDIR/feature-worktree"
  git -C "$TEST_REPO" worktree add -q "$linked" feature

  run bash -c "cd '$linked' && '$GIT_DISCIPLINE' guard-commit"

  [ "$status" -eq 0 ]
}

@test "guard-commit blocks default-branch authoring in a linked worktree" {
  git -C "$TEST_REPO" switch -q -c parking
  git -C "$TEST_REPO" config --local laicluse.requireWorktree true
  local linked="$BATS_TEST_TMPDIR/default-worktree"
  git -C "$TEST_REPO" worktree add -q "$linked" main

  run bash -c "cd '$linked' && '$GIT_DISCIPLINE' guard-commit"

  [ "$status" -ne 0 ]
  [[ "$output" == *"default branch"* ]]
}

@test "installed pre-commit allows canonical feature authoring by default" {
  git -C "$TEST_REPO" switch -q -c feature
  run bash -c "cd '$TEST_REPO' && bash '$INSTALL_HOOKS'"
  [ "$status" -eq 0 ]
  [ -x "$TEST_REPO/.git/hooks/pre-commit" ]

  run bash -c "cd '$TEST_REPO' && .git/hooks/pre-commit"

  [ "$status" -eq 0 ]
}

@test "installed pre-commit enforces an explicit repository worktree requirement" {
  git -C "$TEST_REPO" config --local laicluse.requireWorktree true
  run bash -c "cd '$TEST_REPO' && bash '$INSTALL_HOOKS'"
  [ "$status" -eq 0 ]

  run bash -c "cd '$TEST_REPO' && .git/hooks/pre-commit"

  [ "$status" -ne 0 ]
  [[ "$output" == *"default branch"* ]] || [[ "$output" == *"primary checkout"* ]]
}

@test "installed pre-push allows a direct default update by default" {
  add_origin
  local base direct_commit
  base=$(git -C "$TEST_REPO" rev-parse HEAD)
  direct_commit=$(printf "Merge branch 'fake'\n" | git -C "$TEST_REPO" commit-tree "HEAD^{tree}" -p "$base")
  (cd "$TEST_REPO" && bash "$INSTALL_HOOKS")

  run bash -c "printf '%s %s %s %s\\n' refs/heads/main '$direct_commit' refs/heads/main '$base' | (cd '$TEST_REPO' && .git/hooks/pre-push origin '$REMOTE_REPO')"

  [ "$status" -eq 0 ]
}

@test "installed pre-push enforces candidate topology when the repo requires a worktree" {
  add_origin
  git -C "$TEST_REPO" config --local laicluse.requireWorktree true
  local base direct_commit
  base=$(git -C "$TEST_REPO" rev-parse HEAD)
  direct_commit=$(printf "Merge branch 'fake'\n" | git -C "$TEST_REPO" commit-tree "HEAD^{tree}" -p "$base")
  (cd "$TEST_REPO" && bash "$INSTALL_HOOKS")

  run bash -c "printf '%s %s %s %s\\n' refs/heads/main '$direct_commit' refs/heads/main '$base' | (cd '$TEST_REPO' && .git/hooks/pre-push origin '$REMOTE_REPO')"

  [ "$status" -ne 0 ]
  [[ "$output" == *"two-parent merge"* ]]
}

@test "guard-commit rejects duplicate Rails migration versions in the index" {
  git -C "$TEST_REPO" config codingAgent.git.branchPolicy trunk
  mkdir -p "$TEST_REPO/projects/office/db/migrate"
  touch "$TEST_REPO/projects/office/db/migrate/20261006140000_add_identity.rb"
  touch "$TEST_REPO/projects/office/db/migrate/20261006140000_add_technique.rb"
  git -C "$TEST_REPO" add .

  run bash -c "cd '$TEST_REPO' && '$GIT_DISCIPLINE' guard-commit"

  [ "$status" -ne 0 ]
  [[ "$output" == *"Duplicate Rails migration version"* ]]
  [[ "$output" == *"rails generate migration"* ]]
  [[ "$output" == *"deployed migration"* ]]
}

@test "guard-commit permits the same migration version in different applications" {
  git -C "$TEST_REPO" config codingAgent.git.branchPolicy trunk
  mkdir -p "$TEST_REPO/projects/office/db/migrate" "$TEST_REPO/projects/app/db/migrate"
  touch "$TEST_REPO/projects/office/db/migrate/20261006140000_add_identity.rb"
  touch "$TEST_REPO/projects/app/db/migrate/20261006140000_add_identity.rb"
  git -C "$TEST_REPO" add .

  run bash -c "cd '$TEST_REPO' && '$GIT_DISCIPLINE' guard-commit"

  [ "$status" -eq 0 ]
}

@test "guard-commit checks staged state rather than unstaged migration files" {
  git -C "$TEST_REPO" config codingAgent.git.branchPolicy trunk
  mkdir -p "$TEST_REPO/db/migrate"
  touch "$TEST_REPO/db/migrate/20261006140000_add_identity.rb"
  git -C "$TEST_REPO" add .
  touch "$TEST_REPO/db/migrate/20261006140000_unstaged.rb"

  run bash -c "cd '$TEST_REPO' && '$GIT_DISCIPLINE' guard-commit"

  [ "$status" -eq 0 ]
}

@test "rebase rejects a clean merge that creates duplicate migration versions" {
  mkdir -p "$TEST_REPO/db/migrate"
  touch "$TEST_REPO/db/migrate/20261006140000_add_technique.rb"
  git -C "$TEST_REPO" add .
  git -C "$TEST_REPO" commit -qm "Add technique migration"
  git -C "$TEST_REPO" switch -qc feature HEAD~1
  mkdir -p "$TEST_REPO/db/migrate"
  touch "$TEST_REPO/db/migrate/20261006140000_add_identity.rb"
  git -C "$TEST_REPO" add .
  git -C "$TEST_REPO" commit -qm "Add identity migration"

  run bash -c "cd '$TEST_REPO' && '$GIT_DISCIPLINE' rebase --local"

  [ "$status" -ne 0 ]
  [[ "$output" == *"Duplicate Rails migration version"* ]]
  [ "$(git -C "$TEST_REPO" branch --show-current)" = feature ]
}

@test "guard-commit compares Rails migration versions numerically" {
  mkdir -p "$TEST_REPO/db/migrate"
  touch "$TEST_REPO/db/migrate/001_add_identity.rb"
  touch "$TEST_REPO/db/migrate/1_add_technique.rb"
  git -C "$TEST_REPO" add .

  run bash -c "cd '$TEST_REPO' && '$GIT_DISCIPLINE' guard-commit"

  [ "$status" -ne 0 ]
  [[ "$output" == *"Duplicate Rails migration version"* ]]
}
