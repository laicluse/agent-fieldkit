#!/usr/bin/env bats
# Contract tests for bonsai consuming the dibs lock when it hands out a worktree.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../../.." && pwd)"
  BONSAI="$REPO_ROOT/packages/bonsai/bin/bonsai"
  DIBS="$REPO_ROOT/packages/dibs/bin/dibs"
  NODE_BIN="$(command -v node)"
  export LAICLUSE_HOME="$BATS_TEST_TMPDIR/laicluse"
  FIX="$BATS_TEST_TMPDIR/proj"
  mkdir -p "$FIX"
  git -C "$FIX" init -q -b main
  git -C "$FIX" config init.defaultBranch main
  git -C "$FIX" config user.email t@t.t
  git -C "$FIX" config user.name t
  git -C "$FIX" commit -q --allow-empty -m init
}

run_bonsai() { "$NODE_BIN" "$BONSAI" "$@"; }

@test "create claims a dibs lock for the worktree it hands out" {
  DIBS_HOLDER_PID=$$ run run_bonsai create my-feature --repo "$FIX" --json
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"state": "claimed"'
  [ "$(ls "$LAICLUSE_HOME/locks" | wc -l)" -eq 1 ]
  "$NODE_BIN" "$DIBS" check "$FIX/worktrees/my-feature" --json | grep -q '"state": "held"'
  "$NODE_BIN" "$DIBS" check "$FIX/worktrees/my-feature" --json | grep -q '"description": "my feature"'
}

# The branch names the change this worktree exists for, so it has to win over
# DIBS_DESCRIPTION. A caller that pins that variable session-wide would
# otherwise label every worktree it ever hands out with the same phrase.
@test "the branch name beats a session-wide DIBS_DESCRIPTION" {
  DIBS_HOLDER_PID=$$ DIBS_DESCRIPTION="Claude Code session work" \
    run run_bonsai create labelled-feature --repo "$FIX" --json
  [ "$status" -eq 0 ]
  "$NODE_BIN" "$DIBS" check "$FIX/worktrees/labelled-feature" --json \
    | grep -q '"description": "labelled feature"'
}

@test "DIBS_DESCRIPTION still fills in when the caller names no description" {
  local dir="$BATS_TEST_TMPDIR/unnamed"
  mkdir -p "$dir"
  LIB="$REPO_ROOT/packages/bonsai/bin/bonsai-lib.mjs" TARGET="$dir" \
  DIBS_HOLDER_PID=$$ DIBS_DESCRIPTION="scheduled vault sweep" \
    "$NODE_BIN" --input-type=module -e '
      const { claimWorktreeLock } = await import(process.env.LIB);
      const result = await claimWorktreeLock(process.env.TARGET, undefined);
      if (!result.ok) { console.error(JSON.stringify(result)); process.exit(1); }
    ' >/dev/null
  "$NODE_BIN" "$DIBS" check "$dir" --json \
    | grep -q '"description": "scheduled vault sweep"'
}

@test "the claimed lock records the caller pid, not the short-lived bonsai pid" {
  DIBS_HOLDER_PID=$$ run run_bonsai create pid-feature --repo "$FIX" --json
  [ "$status" -eq 0 ]
  "$NODE_BIN" "$DIBS" check "$FIX/worktrees/pid-feature" --json | grep -q "\"pid\": $$"
}

@test "create still succeeds when dibs is unavailable (graceful degradation)" {
  DIBS_LIB=/nonexistent/dibs-lib.mjs run run_bonsai create no-dibs --repo "$FIX" --json
  [ "$status" -eq 0 ]
  [ -d "$FIX/worktrees/no-dibs" ]
  git -C "$FIX" show-ref --verify --quiet refs/heads/no-dibs
  echo "$output" | grep -q '"state": "unavailable"'
}

@test "claimWorktreeLock surfaces a warning when the dir is already held" {
  local dir="$BATS_TEST_TMPDIR/held"
  mkdir -p "$dir"
  sleep 60 & local holder=$!
  "$NODE_BIN" "$DIBS" claim "$dir" --pid "$holder" --agent other --description "held by test" --json >/dev/null
  run "$NODE_BIN" -e 'import(process.argv[1]).then(m=>m.claimWorktreeLock(process.argv[2], "conflicting test work")).then(r=>console.log(JSON.stringify(r,null,2)))' "$REPO_ROOT/packages/bonsai/bin/bonsai-lib.mjs" "$dir"
  kill "$holder" 2>/dev/null || true
  echo "$output" | grep -q '"state": "refused"'
  echo "$output" | grep -qi "already held by other"
}

@test "claimWorktreeLock discovers dibs from an installed peer plugin cache" {
  local cache="$BATS_TEST_TMPDIR/cache/laicluse-agent-fieldkit"
  mkdir -p "$cache/bonsai/2.0.29/.codex-plugin" "$cache/bonsai/2.0.29/bin" "$cache/dibs/2.0.31/bin"
  cp "$REPO_ROOT/.agents/plugins/generated/bonsai/.codex-plugin/plugin.json" "$cache/bonsai/2.0.29/.codex-plugin/plugin.json"
  cp "$REPO_ROOT/packages/bonsai/bin/bonsai-lib.mjs" "$cache/bonsai/2.0.29/bin/bonsai-lib.mjs"
  cp "$REPO_ROOT/packages/dibs/bin/dibs-lib.mjs" "$cache/dibs/2.0.31/bin/dibs-lib.mjs"
  local dir="$BATS_TEST_TMPDIR/cache-lock"
  mkdir -p "$dir"

  run "$NODE_BIN" -e 'import(process.argv[1]).then(m=>m.claimWorktreeLock(process.argv[2], "cache sibling lock")).then(r=>console.log(JSON.stringify(r,null,2)))' "$cache/bonsai/2.0.29/bin/bonsai-lib.mjs" "$dir"

  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"state": "claimed"'
  "$NODE_BIN" "$DIBS" check "$dir" --json | grep -q '"description": "cache sibling lock"'
}

@test "create surfaces a load error when dibs is present but broken" {
  local broken="$BATS_TEST_TMPDIR/broken-dibs.mjs"
  printf 'export function claim( {{{ broken\n' > "$broken"
  DIBS_LIB="$broken" run run_bonsai create broken-dibs --repo "$FIX" --json
  [ "$status" -eq 0 ]
  [ -d "$FIX/worktrees/broken-dibs" ]
  echo "$output" | grep -q '"state": "error"'
}

@test "bonsai reimplements no lock primitive of its own" {
  run grep -rEi "'wx'|O_EXCL|O_EXLOCK|flock" "$REPO_ROOT/packages/bonsai/bin"
  [ "$status" -ne 0 ]
}

@test "the claimed lock records DIBS_OWNER so another process can recognise it as its own" {
  DIBS_HOLDER_PID=$$ DIBS_OWNER=conveyor:some-run run run_bonsai create owner-feature --repo "$FIX" --json
  [ "$status" -eq 0 ]
  "$NODE_BIN" "$DIBS" check "$FIX/worktrees/owner-feature" --json | grep -q '"owner": "conveyor:some-run"'
}
