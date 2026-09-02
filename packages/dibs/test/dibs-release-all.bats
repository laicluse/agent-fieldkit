#!/usr/bin/env bats
# Contract tests for bin/dibs release-all: release every lock this session holds
# across all directories in one sweep, keyed by holder identity (pid/session/owner).

load helpers

setup() {
  dibs_clear_ambient_identity
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../../.." && pwd)"
  DIBS="$REPO_ROOT/packages/dibs/bin/dibs"
  NODE_BIN="$(command -v node)"
  export LAICLUSE_HOME="$BATS_TEST_TMPDIR/laicluse"
  A="$BATS_TEST_TMPDIR/a"
  B="$BATS_TEST_TMPDIR/b"
  C="$BATS_TEST_TMPDIR/c"
  mkdir -p "$A" "$B" "$C"
}

dibs() {
  if [ "${1:-}" = "claim" ]; then
    case " $* " in *" --description "*) : ;; *) set -- "$@" --description "test claim" ;; esac
  fi
  "$NODE_BIN" "$DIBS" "$@"
}
lockcount() { ls "$LAICLUSE_HOME/locks" 2>/dev/null | wc -l | tr -d ' '; }

@test "release-all by pid removes every lock that pid holds across directories" {
  dibs claim "$A" --pid $$ --agent claude --json >/dev/null
  dibs claim "$B" --pid $$ --agent claude --json >/dev/null
  [ "$(lockcount)" -eq 2 ]
  run dibs release-all --pid $$
  [ "$status" -eq 0 ]
  [ "$(lockcount)" -eq 0 ]
}

@test "release-all by pid leaves locks held by a different pid intact" {
  dibs claim "$A" --pid $$ --agent claude --json >/dev/null
  dibs claim "$C" --pid 999999 --agent codex --json >/dev/null
  run dibs release-all --pid $$
  [ "$status" -eq 0 ]
  [ "$(lockcount)" -eq 1 ]
}

@test "release-all with no selector is an error and removes nothing" {
  dibs claim "$A" --pid $$ --agent claude --json >/dev/null
  run dibs release-all
  [ "$status" -ne 0 ]
  [ "$(lockcount)" -eq 1 ]
}

@test "release-all matching nothing succeeds with a zero count" {
  run dibs release-all --pid $$ --json
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"count": 0'
}

@test "release-all --json reports the released count and paths" {
  dibs claim "$A" --pid $$ --agent claude --json >/dev/null
  dibs claim "$B" --pid $$ --agent claude --json >/dev/null
  run dibs release-all --pid $$ --json
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"state": "released-all"'
  echo "$output" | grep -q '"count": 2'
}

@test "release-all by owner and agent matches locks regardless of pid" {
  dibs claim "$A" --pid 111111 --agent codex --owner tab-7 --json >/dev/null
  dibs claim "$B" --pid 222222 --agent codex --owner tab-7 --json >/dev/null
  dibs claim "$C" --pid 333333 --agent codex --owner tab-9 --json >/dev/null
  run dibs release-all --owner tab-7 --agent codex
  [ "$status" -eq 0 ]
  [ "$(lockcount)" -eq 1 ]
}

@test "release-all requires every supplied selector to match the same holder" {
  dibs claim "$A" --pid 29066 --agent codex \
    --owner retained-shell-owner \
    --session retained-shell-thread --json >/dev/null
  dibs claim "$B" --pid 80049 --agent codex \
    --owner retained-shell-owner \
    --session earlier-shell-thread --json >/dev/null

  run dibs release-all --pid 29066 \
    --owner retained-shell-owner --agent codex --json

  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"count": 1'
  run dibs check "$A" --json
  echo "$output" | grep -q '"state": "free"'
  run dibs check "$B" --json
  echo "$output" | grep -q '"state": "held"'
  echo "$output" | grep -q '"pid": 80049'
}
