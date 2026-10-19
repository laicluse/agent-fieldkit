#!/usr/bin/env bats

load helpers

@test "branch-policy preserves current-branch authoring when the repo has no override" {
  git -C "$TEST_REPO" switch -q -c feature
  run bash -c "cd '$TEST_REPO' && '$GIT_DISCIPLINE' branch-policy"
  [ "$status" -eq 0 ]
  [[ "$output" == *"policy=current"* ]]
  [[ "$output" == *"authoring_branch=feature"* ]]
}

@test "the repository can select default-branch authoring in its primary checkout" {
  git -C "$TEST_REPO" config --local codingAgent.git.branchPolicy default
  run bash -c "cd '$TEST_REPO' && '$GIT_DISCIPLINE' branch-policy"
  [ "$status" -eq 0 ]
  [[ "$output" == *"policy=default"* ]]
  [[ "$output" == *"authoring_branch=main"* ]]
  run bash -c "cd '$TEST_REPO' && '$GIT_DISCIPLINE' guard-commit"
  [ "$status" -eq 0 ]
}

@test "default-branch policy rejects ordinary commits left on a primary feature branch" {
  git -C "$TEST_REPO" config --local codingAgent.git.branchPolicy default
  git -C "$TEST_REPO" switch -q -c forgotten-feature
  run bash -c "cd '$TEST_REPO' && '$GIT_DISCIPLINE' guard-commit"
  [ "$status" -ne 0 ]
  [[ "$output" == *"authoring on main"* ]]
}

@test "default-branch authoring is local to one repo and ignores a global preference" {
  git config --global codingAgent.git.branchPolicy default
  git -C "$TEST_REPO" switch -q -c feature
  run bash -c "cd '$TEST_REPO' && '$GIT_DISCIPLINE' branch-policy"
  [ "$status" -eq 0 ]
  [[ "$output" == *"policy=current"* ]]
  run bash -c "cd '$TEST_REPO' && '$GIT_DISCIPLINE' guard-commit"
  [ "$status" -eq 0 ]
}

@test "default-branch policy keeps isolated feature worktrees available" {
  git -C "$TEST_REPO" config --local codingAgent.git.branchPolicy default
  local linked="$BATS_TEST_TMPDIR/feature-worktree"
  git -C "$TEST_REPO" worktree add -q -b isolated-feature "$linked"
  run bash -c "cd '$linked' && '$GIT_DISCIPLINE' branch-policy"
  [ "$status" -eq 0 ]
  [[ "$output" == *"authoring_branch=isolated-feature"* ]]
  run bash -c "cd '$linked' && '$GIT_DISCIPLINE' guard-commit"
  [ "$status" -eq 0 ]
}

@test "default-branch policy permits completing an actual merge on a primary integration branch" {
  git -C "$TEST_REPO" switch -q -c candidate
  commit_on_current_branch "$TEST_REPO" "candidate" "Candidate change"
  git -C "$TEST_REPO" switch -q -c integration main
  git -C "$TEST_REPO" merge -q --no-commit --no-ff candidate
  git -C "$TEST_REPO" config --local codingAgent.git.branchPolicy default
  run bash -c "cd '$TEST_REPO' && '$GIT_DISCIPLINE' guard-commit"
  [ "$status" -eq 0 ]
}

@test "unknown branch policies fail before accepting a commit" {
  git -C "$TEST_REPO" config --local codingAgent.git.branchPolicy typo
  run bash -c "cd '$TEST_REPO' && '$GIT_DISCIPLINE' guard-commit"
  [ "$status" -ne 0 ]
  [[ "$output" == *"branchPolicy"* ]]
}

@test "the worktree requirement stays authoritative when default authoring is also configured" {
  git -C "$TEST_REPO" config --local codingAgent.git.branchPolicy default
  git -C "$TEST_REPO" config --local laicluse.requireWorktree true
  run bash -c "cd '$TEST_REPO' && '$GIT_DISCIPLINE' guard-commit"
  [ "$status" -ne 0 ]
  [[ "$output" == *"linked feature worktree"* ]]
}

@test "installed pre-commit enforces the repository branch policy" {
  git -C "$TEST_REPO" config --local codingAgent.git.branchPolicy default
  git -C "$TEST_REPO" switch -q -c feature
  run bash -c "cd '$TEST_REPO' && bash '$INSTALL_HOOKS'"
  [ "$status" -eq 0 ]
  run bash -c "cd '$TEST_REPO' && .git/hooks/pre-commit"
  [ "$status" -ne 0 ]
  [[ "$output" == *"authoring on main"* ]]
}
