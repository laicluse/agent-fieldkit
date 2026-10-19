#!/usr/bin/env bash
# Shared setup, teardown, and fixture helpers for the install-hooks BATS suite.
#
# Strategy: each test creates a real disposable git repo via mktemp and
# invokes packages/git-discipline/skills/install-hooks/lib/install.sh against it.
# No git-shim is needed; we want the real git to honour core.hooksPath,
# git worktree, etc.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
INSTALL_SH="$REPO_ROOT/packages/git-discipline/skills/install-hooks/lib/install.sh"
SOURCE_HOOKS_DIR="$REPO_ROOT/packages/git-discipline/skills/commit-discipline/git-hooks"
NODE_BIN="$(asdf which node 2>/dev/null || command -v node)"

setup() {
  TEST_REPO="$BATS_TEST_TMPDIR/repo"
  install -d "$TEST_REPO"

  pushd "$TEST_REPO" >/dev/null
  git init -q -b main
  git config user.email "test@example.com"
  git config user.name "Test"
  git config init.defaultBranch main
  git config codingAgent.git.branchPolicy trunk
  popd >/dev/null

  # Each test runs as a clean shell; export only what install.sh consults.
  export HOME="$BATS_TEST_TMPDIR/home"
  export PATH="$(dirname "$NODE_BIN"):$PATH"
  install -d "$HOME/.claude/plugins"
}

use_linked_feature_worktree() {
  local primary_repo="$TEST_REPO"
  local feature_worktree="$BATS_TEST_TMPDIR/feature-worktree"
  git -C "$primary_repo" commit -q --allow-empty --no-verify -m "Initial commit"
  git -C "$primary_repo" branch feature
  git -C "$primary_repo" worktree add -q "$feature_worktree" feature
  TEST_REPO="$feature_worktree"
}

teardown() {
  : # BATS_TEST_TMPDIR cleanup handled by bats-core.
}

# run_install <repo-dir> <args...>
# Invokes install.sh with $repo-dir as cwd.
run_install() {
  local repo="$1"
  shift
  run bash -c "cd '$repo' && bash '$INSTALL_SH' $*"
}

# hook_target_path <hook-name>
# Returns the expected absolute path to the installed hook in the test repo.
hook_target_path() {
  local hook="$1"
  printf '%s/.git/hooks/%s' "$TEST_REPO" "$hook"
}
