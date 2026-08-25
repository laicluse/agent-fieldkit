#!/usr/bin/env bats

load helpers

@test "verify records passing evidence and local merge creates a two-parent commit without checkout" {
  create_feature_commit
  local base candidate
  base=$(git -C "$TEST_REPO" rev-parse refs/heads/main)
  candidate=$(git -C "$TEST_REPO" rev-parse HEAD)

  run bash -c "cd '$TEST_REPO' && '$GIT_DISCIPLINE' verify --local -- true"
  [ "$status" -eq 0 ]

  run bash -c "cd '$TEST_REPO' && '$GIT_DISCIPLINE' merge --local"
  [ "$status" -eq 0 ]
  [ "$(git -C "$TEST_REPO" branch --show-current)" = "feature" ]

  local merged parents
  merged=$(git -C "$TEST_REPO" rev-parse refs/heads/main)
  parents=$(git -C "$TEST_REPO" show -s --format=%P "$merged")
  [ "$parents" = "$base $candidate" ]
  [ "$(git -C "$TEST_REPO" rev-parse "$merged^{tree}")" = "$(git -C "$TEST_REPO" rev-parse "$candidate^{tree}")" ]
}
# The merge is the only thing a candidate worktree exists for, so the report
# that lands the merge is also where the reader learns the worktree is spent.
# Leaving that to the skill alone lost it: the instruction is read before the
# merge and has to survive until after it.
@test "a merge from a linked worktree names it and the prune step" {
  create_feature_worktree_commit

  run bash -c "cd '$FEATURE_WORKTREE' && '$GIT_DISCIPLINE' verify --local -- true"
  [ "$status" -eq 0 ]

  run bash -c "cd '$FEATURE_WORKTREE' && '$GIT_DISCIPLINE' merge --local"
  [ "$status" -eq 0 ]
  [[ "$output" == *"$FEATURE_WORKTREE"* ]]
  [[ "$output" == *"bonsai:prune"* ]]
  [[ "$output" == *"feature"* ]]
}

@test "the prune pointer denies deployment as a reason to keep the worktree" {
  create_feature_worktree_commit

  run bash -c "cd '$FEATURE_WORKTREE' && '$GIT_DISCIPLINE' verify --local -- true"
  run bash -c "cd '$FEATURE_WORKTREE' && '$GIT_DISCIPLINE' merge --local"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Deployment is not a reason to keep it"* ]]
}

@test "a merge from the primary checkout points at no worktree to prune" {
  create_feature_commit

  run bash -c "cd '$TEST_REPO' && '$GIT_DISCIPLINE' verify --local -- true"
  [ "$status" -eq 0 ]

  run bash -c "cd '$TEST_REPO' && '$GIT_DISCIPLINE' merge --local"
  [ "$status" -eq 0 ]
  [[ "$output" != *"bonsai:prune"* ]]
}

@test "verify command failure creates no mergeable candidate" {
  create_feature_commit

  run bash -c "cd '$TEST_REPO' && '$GIT_DISCIPLINE' verify --local -- bash -c 'exit 23'"
  [ "$status" -eq 23 ]

  run bash -c "cd '$TEST_REPO' && '$GIT_DISCIPLINE' merge --local"
  [ "$status" -ne 0 ]
  [[ "$output" == *"has no passing verification"* ]]
}

@test "local target merges a repository with a remote without touching origin" {
  add_origin
  create_feature_commit
  local base candidate remote_before
  base=$(git -C "$TEST_REPO" rev-parse refs/heads/main)
  candidate=$(git -C "$TEST_REPO" rev-parse HEAD)
  remote_before=$(git -C "$REMOTE_REPO" rev-parse refs/heads/main)

  run bash -c "cd '$TEST_REPO' && '$GIT_DISCIPLINE' verify --local -- true"
  [ "$status" -eq 0 ]

  run bash -c "cd '$TEST_REPO' && '$GIT_DISCIPLINE' merge --local"
  [ "$status" -eq 0 ]

  local merged parents
  merged=$(git -C "$TEST_REPO" rev-parse refs/heads/main)
  parents=$(git -C "$TEST_REPO" show -s --format=%P "$merged")
  [ "$parents" = "$base $candidate" ]
  [ "$(git -C "$REMOTE_REPO" rev-parse refs/heads/main)" = "$remote_before" ]
}

@test "local merge keeps a checked-out default worktree coherent" {
  create_feature_worktree_commit
  local base candidate
  base=$(git -C "$TEST_REPO" rev-parse refs/heads/main)
  candidate=$(git -C "$FEATURE_WORKTREE" rev-parse HEAD)

  run bash -c "cd '$FEATURE_WORKTREE' && '$GIT_DISCIPLINE' verify --local -- true"
  [ "$status" -eq 0 ]

  run bash -c "cd '$FEATURE_WORKTREE' && '$GIT_DISCIPLINE' merge --local"
  [ "$status" -eq 0 ]

  local merged parents
  merged=$(git -C "$TEST_REPO" rev-parse HEAD)
  parents=$(git -C "$TEST_REPO" show -s --format=%P "$merged")
  [ "$parents" = "$base $candidate" ]
  [ "$(git -C "$TEST_REPO" status --porcelain)" = "" ]
  [ "$(git -C "$TEST_REPO" show HEAD:file.txt)" = "$(cat "$TEST_REPO/file.txt")" ]
}

@test "local merge leaves a dirty default worktree and its ref untouched" {
  create_feature_worktree_commit
  (cd "$FEATURE_WORKTREE" && "$GIT_DISCIPLINE" verify --local -- true)
  local base
  base=$(git -C "$TEST_REPO" rev-parse refs/heads/main)
  printf 'local work\n' >> "$TEST_REPO/file.txt"

  run bash -c "cd '$FEATURE_WORKTREE' && '$GIT_DISCIPLINE' merge --local"

  [ "$status" -ne 0 ]
  [[ "$output" == *"checked-out default worktree is not clean"* ]]
  [ "$(git -C "$TEST_REPO" rev-parse refs/heads/main)" = "$base" ]
  [ "$(tail -n 1 "$TEST_REPO/file.txt")" = "local work" ]
}

@test "local merge preserves untracked files in the default worktree" {
  create_feature_worktree_commit
  (cd "$FEATURE_WORKTREE" && "$GIT_DISCIPLINE" verify --local -- true)
  printf 'keep me\n' > "$TEST_REPO/untracked.txt"

  run bash -c "cd '$FEATURE_WORKTREE' && '$GIT_DISCIPLINE' merge --local"

  [ "$status" -eq 0 ]
  [ "$(cat "$TEST_REPO/untracked.txt")" = "keep me" ]
  [ "$(git -C "$TEST_REPO" status --porcelain --untracked-files=no)" = "" ]
}

@test "moving the candidate after verification requires verification again" {
  create_feature_commit
  (cd "$TEST_REPO" && "$GIT_DISCIPLINE" verify --local -- true)
  commit_on_current_branch "$TEST_REPO" "more feature" "Move candidate"

  run bash -c "cd '$TEST_REPO' && '$GIT_DISCIPLINE' merge --local"

  [ "$status" -ne 0 ]
  [[ "$output" == *"has no passing verification"* ]]
}

@test "advancing default after verification loses the merge race" {
  create_feature_commit
  (cd "$TEST_REPO" && "$GIT_DISCIPLINE" verify --local -- true)
  advance_local_default
  local current_default
  current_default=$(git -C "$TEST_REPO" rev-parse refs/heads/main)

  run bash -c "cd '$TEST_REPO' && '$GIT_DISCIPLINE' merge --local"

  [ "$status" -ne 0 ]
  [[ "$output" == *"default branch moved"* ]]
  [ "$(git -C "$TEST_REPO" rev-parse refs/heads/main)" = "$current_default" ]
}

@test "remote merge uses a non-force compare-and-swap push and leaves the feature checked out" {
  add_origin
  create_feature_commit
  local base candidate
  base=$(git -C "$TEST_REPO" rev-parse refs/remotes/origin/main)
  candidate=$(git -C "$TEST_REPO" rev-parse HEAD)

  run bash -c "cd '$TEST_REPO' && '$GIT_DISCIPLINE' verify --remote -- true"
  [ "$status" -eq 0 ]

  run bash -c "cd '$TEST_REPO' && '$GIT_DISCIPLINE' merge --remote"
  [ "$status" -eq 0 ]
  [ "$(git -C "$TEST_REPO" branch --show-current)" = "feature" ]

  local remote_tip parents
  remote_tip=$(git --git-dir="$REMOTE_REPO" rev-parse refs/heads/main)
  parents=$(git --git-dir="$REMOTE_REPO" show -s --format=%P "$remote_tip")
  [ "$parents" = "$base $candidate" ]
}

@test "remote merge distinguishes policy rejection from a lost race" {
  add_origin
  create_feature_commit
  (cd "$TEST_REPO" && "$GIT_DISCIPLINE" verify --remote -- true)
  printf '#!/bin/sh\nexit 1\n' >"$REMOTE_REPO/hooks/pre-receive"
  chmod +x "$REMOTE_REPO/hooks/pre-receive"

  run bash -c "cd '$TEST_REPO' && '$GIT_DISCIPLINE' merge --remote"

  [ "$status" -ne 0 ]
  [[ "$output" == *"Remote rejected the merge push"* ]]
  [[ "$output" != *"default branch moved"* ]]
}
