#!/usr/bin/env bats

load helpers

policy() { run bash -c "cd '$TEST_REPO' && '$GIT_DISCIPLINE' branch-policy"; }
guard() { run bash -c "cd '$TEST_REPO' && '$GIT_DISCIPLINE' guard-commit"; }

@test "unset policy requires a feature branch without switching or writing" {
  local before=$(git -C "$TEST_REPO" rev-parse HEAD)
  policy
  [ "$status" -eq 0 ]
  [[ "$output" == *"policy=feature"* ]]
  [[ "$output" == *"action=create-feature-branch"* ]]
  [[ "$output" == *$'authoring_branch=\n'* ]]
  [ "$(git -C "$TEST_REPO" branch --show-current)" = main ]
  [ "$(git -C "$TEST_REPO" rev-parse HEAD)" = "$before" ]
  guard
  [ "$status" -ne 0 ]
  [[ "$output" == *"feature branch"* ]]
}

@test "feature policy keeps a primary feature branch" {
  git -C "$TEST_REPO" switch -q -c phrase-boundaries
  policy
  [[ "$output" == *"authoring_branch=phrase-boundaries"* ]]
  [[ "$output" == *"action=author"* ]]
  guard
  [ "$status" -eq 0 ]
}

@test "trunk policy authors directly on the resolved default" {
  git -C "$TEST_REPO" branch -m main trunk-line
  git -C "$TEST_REPO" config init.defaultBranch trunk-line
  git -C "$TEST_REPO" config --local codingAgent.git.branchPolicy trunk
  policy
  [[ "$output" == *"policy=trunk"* ]]
  [[ "$output" == *"authoring_branch=trunk-line"* ]]
  guard
  [ "$status" -eq 0 ]
  git -C "$TEST_REPO" switch -q -c forgotten-feature
  policy
  [[ "$output" == *"action=return-to-default"* ]]
  guard
  [ "$status" -ne 0 ]
}

@test "global branch and worktree preferences do not configure a repository" {
  git config --global codingAgent.git.branchPolicy trunk
  git config --global laicluse.requireWorktree true
  policy
  [[ "$output" == *"policy=feature"* ]]
  [[ "$output" == *"worktree_required=false"* ]]
}

@test "all policies allow isolated feature worktrees" {
  local linked="$BATS_TEST_TMPDIR/feature-worktree"
  git -C "$TEST_REPO" worktree add -q -b isolated-feature "$linked"
  for mode in feature trunk worktree; do
    git -C "$TEST_REPO" config --local codingAgent.git.branchPolicy "$mode"
    run bash -c "cd '$linked' && '$GIT_DISCIPLINE' branch-policy && '$GIT_DISCIPLINE' guard-commit"
    [ "$status" -eq 0 ]
    [[ "$output" == *"authoring_branch=isolated-feature"* ]]
  done
}

@test "worktree mode reserves the primary checkout for integration" {
  git -C "$TEST_REPO" config --local codingAgent.git.branchPolicy worktree
  git -C "$TEST_REPO" switch -q -c feature
  policy
  [[ "$output" == *"worktree_required=true"* ]]
  [[ "$output" == *"action=create-worktree"* ]]
  guard
  [ "$status" -ne 0 ]
  [[ "$output" == *"primary checkout"* ]]
}

@test "an actual merge can complete on the default or an integration branch" {
  git -C "$TEST_REPO" switch -q -c candidate
  commit_on_current_branch "$TEST_REPO" candidate "Candidate change"
  git -C "$TEST_REPO" switch -q main
  git -C "$TEST_REPO" merge -q --no-commit --no-ff candidate
  for mode in feature trunk worktree; do
    git -C "$TEST_REPO" config --local codingAgent.git.branchPolicy "$mode"
    policy
    [[ "$output" == *"action=complete-merge"* ]]
    guard
    [ "$status" -eq 0 ]
  done
}

@test "linked default branches reject ordinary commits in every policy" {
  git -C "$TEST_REPO" switch -q -c parking
  local linked="$BATS_TEST_TMPDIR/default-worktree"
  git -C "$TEST_REPO" worktree add -q "$linked" main
  for mode in feature trunk worktree; do
    git -C "$TEST_REPO" config --local codingAgent.git.branchPolicy "$mode"
    run bash -c "cd '$linked' && '$GIT_DISCIPLINE' guard-commit"
    [ "$status" -ne 0 ]
    [[ "$output" == *"default branch"* ]]
  done
}

@test "legacy values normalize to the documented modes" {
  git -C "$TEST_REPO" config codingAgent.git.branchPolicy default
  policy
  [[ "$output" == *"policy=trunk"* ]]
  git -C "$TEST_REPO" config codingAgent.git.branchPolicy current
  policy
  [[ "$output" == *"policy=feature"* ]]
  git -C "$TEST_REPO" config codingAgent.git.branchPolicy trunk
  git -C "$TEST_REPO" config --local laicluse.requireWorktree true
  policy
  [[ "$output" == *"policy=worktree"* ]]
}

@test "unknown branch policies fail before accepting a commit" {
  git -C "$TEST_REPO" config codingAgent.git.branchPolicy typo
  guard
  [ "$status" -ne 0 ]
  [[ "$output" == *"branchPolicy"* ]]
}

@test "installed pre-commit enforces feature as the default" {
  run bash -c "cd '$TEST_REPO' && bash '$INSTALL_HOOKS'"
  [ "$status" -eq 0 ]
  run bash -c "cd '$TEST_REPO' && .git/hooks/pre-commit"
  [ "$status" -ne 0 ]
  git -C "$TEST_REPO" switch -q -c phrase-boundaries
  run bash -c "cd '$TEST_REPO' && .git/hooks/pre-commit"
  [ "$status" -eq 0 ]
}

@test "the first repository commit can establish the initial branch" {
  local unborn="$BATS_TEST_TMPDIR/unborn"
  git init -q -b main "$unborn"
  git -C "$unborn" config init.defaultBranch main
  run bash -c "cd '$unborn' && '$GIT_DISCIPLINE' branch-policy && '$GIT_DISCIPLINE' guard-commit"
  [ "$status" -eq 0 ]
  [[ "$output" == *"action=initialize-repository"* ]]
}

@test "a paused rebase can commit on detached HEAD but ordinary detached authoring is rejected" {
  git -C "$TEST_REPO" checkout -q --detach
  guard
  [ "$status" -ne 0 ]
  [[ "$output" == *"Attach"* ]]
  git -C "$TEST_REPO" switch -q -c exercise-timing
  commit_on_current_branch "$TEST_REPO" first 'First change'
  commit_on_current_branch "$TEST_REPO" second 'Second change'
  local editor="$BATS_TEST_TMPDIR/edit-first"
  printf '#!/bin/sh\nsed "1s/^pick /edit /" "$1" > "$1.next"\nmv "$1.next" "$1"\n' > "$editor"
  chmod +x "$editor"
  GIT_SEQUENCE_EDITOR="$editor" git -C "$TEST_REPO" rebase -i HEAD~2
  policy
  [[ "$output" == *"action=complete-rebase"* ]]
  guard
  [ "$status" -eq 0 ]
}

@test "missing default metadata fails with a repair instruction without guessing" {
  git -C "$TEST_REPO" config init.defaultBranch absent
  guard
  [ "$status" -ne 0 ]
  [[ "$output" == *"git remote set-head origin -a"* ]]
}

@test "authoring modes and even invalid authoring configuration do not change push guards" {
  local base=$(git -C "$TEST_REPO" rev-parse HEAD)
  for mode in feature trunk worktree typo; do
    git -C "$TEST_REPO" config codingAgent.git.branchPolicy "$mode"
    run bash -c "printf '%s %s %s %s\n' refs/heads/main '$base' refs/heads/main '$base' | (cd '$TEST_REPO' && '$GIT_DISCIPLINE' guard-push)"
    [ "$status" -eq 0 ]
  done
}

@test "orphan branches in existing repositories are not repository initialization" {
  git -C "$TEST_REPO" config codingAgent.git.branchPolicy trunk
  git -C "$TEST_REPO" switch -q --orphan orphan-line
  policy
  [[ "$output" == *"action=return-to-default"* ]]
  guard
  [ "$status" -ne 0 ]
}

@test "installed hooks enforce explicit trunk and worktree policies" {
  git -C "$TEST_REPO" config codingAgent.git.branchPolicy trunk
  run bash -c "cd '$TEST_REPO' && bash '$INSTALL_HOOKS' && .git/hooks/pre-commit"
  [ "$status" -eq 0 ]
  git -C "$TEST_REPO" switch -q -c exercise-timing
  run bash -c "cd '$TEST_REPO' && .git/hooks/pre-commit"
  [ "$status" -ne 0 ]
  git -C "$TEST_REPO" config codingAgent.git.branchPolicy worktree
  run bash -c "cd '$TEST_REPO' && .git/hooks/pre-commit"
  [ "$status" -ne 0 ]
  local linked="$BATS_TEST_TMPDIR/linked"
  git -C "$TEST_REPO" worktree add -q -b isolated-feature "$linked"
  run bash -c "cd '$linked' && '$TEST_REPO/.git/hooks/pre-commit'"
  [ "$status" -eq 0 ]
}

@test "a rebase of the default branch does not permit feature-policy commits" {
  commit_on_current_branch "$TEST_REPO" first 'First change'
  commit_on_current_branch "$TEST_REPO" second 'Second change'
  local editor="$BATS_TEST_TMPDIR/edit-first"
  printf '#!/bin/sh\nsed "1s/^pick /edit /" "$1" > "$1.next"\nmv "$1.next" "$1"\n' > "$editor"
  chmod +x "$editor"
  GIT_SEQUENCE_EDITOR="$editor" git -C "$TEST_REPO" rebase -i HEAD~2
  guard
  [ "$status" -ne 0 ]
  git -C "$TEST_REPO" config codingAgent.git.branchPolicy trunk
  guard
  [ "$status" -eq 0 ]
}

@test "a global initial branch does not stand in for repository default metadata" {
  git config --global init.defaultBranch main
  git -C "$TEST_REPO" config --local --unset init.defaultBranch
  policy
  [ "$status" -ne 0 ]
  [[ "$output" == *"git remote set-head origin -a"* ]]
}
