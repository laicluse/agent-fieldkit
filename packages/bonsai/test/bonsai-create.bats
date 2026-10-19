#!/usr/bin/env bats
# Contract tests for bin/bonsai create: worktree + branch + gitignore + json facts.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../../.." && pwd)"
  BONSAI="$REPO_ROOT/packages/bonsai/bin/bonsai"
  NODE_BIN="$(command -v node)"
  FIX="$BATS_TEST_TMPDIR/proj"
  mkdir -p "$FIX"
  git -C "$FIX" init -q -b main
  git -C "$FIX" config init.defaultBranch main
  git -C "$FIX" config user.email t@t.t
  git -C "$FIX" config user.name t
  git -C "$FIX" commit -q --allow-empty -m init
}

run_bonsai() { "$NODE_BIN" "$BONSAI" "$@"; }

@test "create makes a worktree, branch, gitignore and prints json facts" {
  run run_bonsai create my-feature --repo "$FIX" --json
  [ "$status" -eq 0 ]
  [ -d "$FIX/worktrees/my-feature" ]
  [ -f "$FIX/worktrees/.gitignore" ]
  echo "$output" | grep -q '"branch": "my-feature"'
  echo "$output" | grep -q '"worktree"'
  echo "$output" | grep -q '"port"'
  git -C "$FIX" show-ref --verify --quiet refs/heads/my-feature
}

@test "create sanitizes a slash branch into a dashed dir and returns both" {
  run run_bonsai create feature/foo --repo "$FIX" --json
  [ "$status" -eq 0 ]
  [ -d "$FIX/worktrees/feature-foo" ]
  echo "$output" | grep -q '"branch": "feature/foo"'
  echo "$output" | grep -q 'feature-foo'
}

@test "create refuses an existing branch with a clear message" {
  run_bonsai create dup --repo "$FIX" --json
  run run_bonsai create dup --repo "$FIX" --json
  [ "$status" -ne 0 ]
  echo "$output" | grep -qi "already exists"
}

@test "create is deterministic about the port for a given dir name" {
  run run_bonsai create stable --repo "$FIX" --json
  port_a="$(echo "$output" | grep '"port"' | grep -oE '[0-9]+')"
  [ "$port_a" -ge 3100 ]
  [ "$port_a" -le 3999 ]
}

@test "create --dir decouples the worktree dir from the branch name" {
  run run_bonsai create my-handle --dir my-handle-r2 --repo "$FIX" --json
  [ "$status" -eq 0 ]
  [ -d "$FIX/worktrees/my-handle-r2" ]
  [ ! -d "$FIX/worktrees/my-handle" ]
  echo "$output" | grep -q '"branch": "my-handle"'
  echo "$output" | grep -q 'my-handle-r2'
  git -C "$FIX" show-ref --verify --quiet refs/heads/my-handle
}

@test "create from inside a linked worktree anchors at the main worktree root, not nested" {
  run run_bonsai create first --repo "$FIX" --json
  [ "$status" -eq 0 ]
  run run_bonsai create second --repo "$FIX/worktrees/first" --json
  [ "$status" -eq 0 ]
  [ -d "$FIX/worktrees/second" ]
  [ ! -d "$FIX/worktrees/first/worktrees/second" ]
  echo "$output" | grep -q "$FIX/worktrees/second"
}

@test "create uses origin HEAD as the default branch before local main" {
  ORIGIN="$BATS_TEST_TMPDIR/origin.git"
  git init -q --bare -b trunk "$ORIGIN"
  main_sha="$(git -C "$FIX" rev-parse main)"
  git -C "$FIX" checkout -q -b trunk
  git -C "$FIX" commit -q --allow-empty -m "trunk base"
  trunk_sha="$(git -C "$FIX" rev-parse trunk)"
  git -C "$FIX" checkout -q main
  git -C "$FIX" remote add origin "$ORIGIN"
  git -C "$FIX" push -q origin trunk
  git -C "$FIX" fetch -q origin
  git -C "$FIX" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/trunk

  run run_bonsai create from-origin-head --repo "$FIX" --json
  [ "$status" -eq 0 ]
  echo "$output" | grep -q 'trunk'
  [ "$(git -C "$FIX" rev-parse from-origin-head)" = "$trunk_sha" ]
  [ "$(git -C "$FIX" rev-parse from-origin-head)" != "$main_sha" ]
}

@test "create leaves the new branch untracked instead of tracking the default branch" {
  ORIGIN="$BATS_TEST_TMPDIR/origin.git"
  git init -q --bare -b main "$ORIGIN"
  git -C "$FIX" remote add origin "$ORIGIN"
  git -C "$FIX" push -q origin main
  git -C "$FIX" fetch -q origin
  git -C "$FIX" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
  git -C "$FIX" config branch.autoSetupMerge always

  run run_bonsai create untracked-start --repo "$FIX" --json
  [ "$status" -eq 0 ]
  run git -C "$FIX" rev-parse --abbrev-ref untracked-start@{upstream}
  [ "$status" -ne 0 ]
  [ -z "$(git -C "$FIX" config --get branch.untracked-start.merge)" ]
}

@test "create uses configured local default when origin HEAD is absent" {
  main_sha="$(git -C "$FIX" rev-parse main)"
  git -C "$FIX" checkout -q -b trunk
  git -C "$FIX" commit -q --allow-empty -m "trunk base without remote head"
  trunk_sha="$(git -C "$FIX" rev-parse trunk)"
  git -C "$FIX" config init.defaultBranch main

  run run_bonsai create from-configured-default --repo "$FIX" --json
  [ "$status" -eq 0 ]
  echo "$output" | grep -q 'main'
  [ "$(git -C "$FIX" rev-parse from-configured-default)" = "$main_sha" ]
  [ "$(git -C "$FIX" rev-parse from-configured-default)" != "$trunk_sha" ]
}

@test "create refuses a vaultsync managed checkout through the vaultsync CLI" {
  fake_vaultsync="$BATS_TEST_TMPDIR/vaultsync"
  cat > "$fake_vaultsync" <<'SH'
#!/bin/sh
if [ "$1" = "managed" ]; then
  printf '{"managed":true,"root":"%s"}\n' "$2"
  exit 0
fi
exit 2
SH
  chmod +x "$fake_vaultsync"

  VAULTSYNC_BIN="$fake_vaultsync" run run_bonsai create should-block --repo "$FIX" --json
  [ "$status" -ne 0 ]
  echo "$output" | grep -qi 'vaultsync'
  [ ! -d "$FIX/worktrees/should-block" ]
  ! git -C "$FIX" show-ref --verify --quiet refs/heads/should-block
}

@test "bonsai has no vaultsync storage-path knowledge" {
  run rg -n 'vaultsync.*registrations|registrations.*vaultsync|LAICLUSE_HOME|createHash|repoKey|sha256' "$REPO_ROOT/packages/bonsai/bin"
  [ "$status" -ne 0 ]
}

@test "create rejects a .. branch name as invalid" {
  run run_bonsai create .. --repo "$FIX" --json
  [ "$status" -ne 0 ]
  echo "$output" | grep -qi 'invalid branch'
}

@test "create rejects a branch name with whitespace" {
  run run_bonsai create "my feature" --repo "$FIX" --json
  [ "$status" -ne 0 ]
  echo "$output" | grep -qi 'invalid branch'
}

@test "create emits a JSON error object under --json on failure" {
  run_bonsai create dup2 --repo "$FIX" --json
  run run_bonsai create dup2 --repo "$FIX" --json
  [ "$status" -ne 0 ]
  echo "$output" | grep -q '"error"'
}

@test "create requires repository-local default metadata instead of a global preference" {
  git -C "$FIX" config --local --unset init.defaultBranch
  git config --file "$BATS_TEST_TMPDIR/global-policy" init.defaultBranch main
  GIT_CONFIG_GLOBAL="$BATS_TEST_TMPDIR/global-policy" run run_bonsai create uncertain-base --repo "$FIX" --json
  [ "$status" -ne 0 ]
  [ ! -d "$FIX/worktrees/uncertain-base" ]
}
