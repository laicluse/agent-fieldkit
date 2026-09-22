#!/usr/bin/env bats
# Contract tests for bin/dibs check: free vs holder reporting, liveness.

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

@test "check reports a free dir as free" {
  run dibs check "$DIR" --json
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"state": "free"'
}

@test "check reports the holder, pid and acquired-at for a held dir" {
  dibs claim "$DIR" --pid $$ --agent claude --description "stale dibs lock cleanup" --json >/dev/null
  run dibs check "$DIR" --json
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"state": "held"'
  echo "$output" | grep -q '"agent": "claude"'
  echo "$output" | grep -q '"description": "stale dibs lock cleanup"'
  echo "$output" | grep -q '"acquiredAt"'
  echo "$output" | grep -q '"alive": true'
}

@test "check human output names the holder and since-when" {
  dibs claim "$DIR" --pid $$ --agent claude --description "stale dibs lock cleanup" --json >/dev/null
  run dibs check "$DIR"
  [ "$status" -eq 0 ]
  echo "$output" | grep -qi "held by claude"
  echo "$output" | grep -qi "work: stale dibs lock cleanup"
  echo "$output" | grep -qi "alive"
}

@test "check distinguishes lock age from recent dirty-file activity" {
  git -C "$DIR" init -q
  printf 'first\n' > "$DIR/note.md"
  git -C "$DIR" add note.md
  git -C "$DIR" -c user.name=Test -c user.email=test@example.invalid commit -qm initial
  printf 'second\n' >> "$DIR/note.md"
  "$NODE_BIN" -e 'require("node:fs").utimesSync(process.argv[1], new Date("2020-01-01T00:00:00.000Z"), new Date("2020-01-01T00:00:00.000Z"))' "$DIR/note.md"
  dibs claim "$DIR" --pid $$ --agent claude --description "inspect worktree activity" --json >/dev/null

  run dibs check "$DIR" --json
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"worktreeActivity"'
  echo "$output" | grep -q '"lastModifiedAt": "2020-01-01T00:00:00.000Z"'
  echo "$output" | grep -Eq '"relativeAge": "[0-9]+ days ago"'

  run dibs check "$DIR"
  [ "$status" -eq 0 ]
  echo "$output" | grep -qi 'latest dirty-file change'
  echo "$output" | grep -qi 'days ago'
}

@test "check on a non-existent directory errors clearly" {
  run dibs check "$BATS_TEST_TMPDIR/nope"
  [ "$status" -ne 0 ]
  echo "$output" | grep -qi "does not exist"
}

@test "the held report names the holder host for cross-host diagnosis" {
  dibs claim "$DIR" --pid $$ --agent claude --json >/dev/null
  run dibs check "$DIR"
  echo "$output" | grep -qiE "on [^ ]+ since"
}

@test "check reports a dead holder as not alive and stale" {
  tail -f /dev/null >/dev/null 2>&1 & local holder=$!
  dibs claim "$DIR" --pid "$holder" --agent claude --json >/dev/null
  kill "$holder"; wait "$holder" 2>/dev/null || true
  run dibs check "$DIR" --json
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"alive": false'
  echo "$output" | grep -q '"stale": true'
}
