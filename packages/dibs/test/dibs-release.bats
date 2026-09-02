#!/usr/bin/env bats
# Contract tests for bin/dibs release: only the holder may release.

load helpers

setup() {
  dibs_clear_ambient_identity
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../../.." && pwd)"
  DIBS="$REPO_ROOT/packages/dibs/bin/dibs"
  NODE_BIN="$(command -v node)"
  export LAICLUSE_HOME="$BATS_TEST_TMPDIR/laicluse"
  DIR="$BATS_TEST_TMPDIR/work"
  mkdir -p "$DIR"
}

dibs() {
  if [ "${1:-}" = "claim" ]; then
    case " $* " in *" --description "*) : ;; *) set -- "$@" --description "test claim" ;; esac
  fi
  "$NODE_BIN" "$DIBS" "$@"
}

@test "the holder can release and the lock file is removed" {
  dibs claim "$DIR" --pid $$ --agent claude --json >/dev/null
  run dibs release "$DIR" --pid $$
  [ "$status" -eq 0 ]
  echo "$output" | grep -qi "released"
  [ "$(ls "$LAICLUSE_HOME/locks" 2>/dev/null | wc -l)" -eq 0 ]
}

@test "release on an unheld dir is a no-op with success" {
  run dibs release "$DIR" --pid $$
  [ "$status" -eq 0 ]
  echo "$output" | grep -qi "not held"
}

@test "release by a non-holder is refused and leaves the lock in place" {
  dibs claim "$DIR" --pid $$ --agent claude --json >/dev/null
  tail -f /dev/null >/dev/null 2>&1 & local other=$!
  run dibs release "$DIR" --pid "$other"
  kill "$other" 2>/dev/null || true
  [ "$status" -ne 0 ]
  echo "$output" | grep -qi "held by claude"
  [ "$(ls "$LAICLUSE_HOME/locks" | wc -l)" -eq 1 ]
}

@test "release with a matching nonce succeeds" {
  dibs claim "$DIR" --pid $$ --agent claude --json >/dev/null
  local nonce
  nonce="$(cat "$LAICLUSE_HOME"/locks/*.lock | "$NODE_BIN" -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>console.log(JSON.parse(s).nonce))')"
  run dibs release "$DIR" --pid $$ --nonce "$nonce"
  [ "$status" -eq 0 ]
  echo "$output" | grep -qi released
}

@test "release with a wrong nonce is refused and leaves the lock" {
  dibs claim "$DIR" --pid $$ --agent claude --json >/dev/null
  run dibs release "$DIR" --pid $$ --nonce deadbeefdeadbeef
  [ "$status" -ne 0 ]
  echo "$output" | grep -qi "held by"
  [ "$(ls "$LAICLUSE_HOME/locks" | wc -l)" -eq 1 ]
}

@test "release by non-holder under --json reports held-by-other" {
  dibs claim "$DIR" --pid $$ --agent claude --json >/dev/null
  tail -f /dev/null >/dev/null 2>&1 & local other=$!
  run dibs release "$DIR" --pid "$other" --json
  kill "$other" 2>/dev/null || true
  [ "$status" -ne 0 ]
  echo "$output" | grep -q '"state": "held-by-other"'
}

@test "a retained codex shell can release its owner and thread lock after pid drift" {
  dibs claim "$DIR" --pid 29066 --agent codex \
    --owner retained-shell-owner \
    --session retained-shell-thread --json >/dev/null

  run env DIBS_OWNER=retained-shell-owner \
    CODEX_THREAD_ID=retained-shell-thread \
    "$NODE_BIN" "$DIBS" release "$DIR" --json

  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"state": "released"'
  [ "$(ls "$LAICLUSE_HOME/locks" 2>/dev/null | wc -l)" -eq 0 ]
}
