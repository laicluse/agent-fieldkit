#!/usr/bin/env bats
# Contract tests for bin/dibs claim: exclusive occupancy, refuse-with-holder,
# idempotent re-claim, and stale takeover when the holder pid is dead.

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

dibs_raw() { "$NODE_BIN" "$DIBS" "$@"; }

# A work description is mandatory on claim; inject a default for the many tests
# that exercise claim/refuse/takeover logic rather than the description itself.
dibs() {
  if [ "${1:-}" = "claim" ]; then
    case " $* " in
      *" --description "*) : ;;
      *) set -- "$@" --description "test claim" ;;
    esac
  fi
  "$NODE_BIN" "$DIBS" "$@"
}

@test "claim without a work description is rejected" {
  run dibs_raw claim "$DIR" --pid $$ --agent claude --json
  [ "$status" -ne 0 ]
  echo "$output" | grep -q 'work description is required'
  [ ! -d "$LAICLUSE_HOME/locks" ] || [ "$(ls "$LAICLUSE_HOME/locks" 2>/dev/null | wc -l)" -eq 0 ]
}

@test "re-claiming a lock this process already holds needs no new description" {
  dibs claim "$DIR" --pid $$ --agent claude --description "first claim with a label" --json >/dev/null
  run dibs_raw claim "$DIR" --pid $$ --agent claude --json
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"state": "held-by-self"'
}

@test "claim inherits the session identity a coding agent exports" {
  run env CLAUDE_CODE_SESSION_ID=sess-xyz CLAUDECODE=1 \
    "$NODE_BIN" "$DIBS" claim "$DIR" --description "session bound claim" --json
  [ "$status" -eq 0 ]
  run dibs check "$DIR" --json
  echo "$output" | grep -q '"session": "sess-xyz"'
  echo "$output" | grep -q '"agent": "claude"'
}

@test "an exported agent pid does not become the holder, only DIBS_HOLDER_PID does" {
  run env CLAUDE_PID=1 DIBS_HOLDER_PID=$$ CLAUDE_CODE_SESSION_ID=sess-xyz \
    "$NODE_BIN" "$DIBS" claim "$DIR" --description "pid stays local" --json
  [ "$status" -eq 0 ]
  run dibs check "$DIR" --json
  [ "$(jq -r '.holder.pid' <<< "$output")" -eq $$ ]
}

@test "explicit claim flags win over the exported session" {
  run env CLAUDE_CODE_SESSION_ID=sess-xyz CLAUDE_PID=1 \
    "$NODE_BIN" "$DIBS" claim "$DIR" --pid $$ --agent codex --session sess-flag --description "flags win" --json
  [ "$status" -eq 0 ]
  run dibs check "$DIR" --json
  echo "$output" | grep -q '"session": "sess-flag"'
  echo "$output" | grep -q '"agent": "codex"'
}

@test "claim on a free dir succeeds and writes a lock file" {
  run dibs claim "$DIR" --pid $$ --agent claude --json
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"state": "claimed"'
  [ "$(ls "$LAICLUSE_HOME/locks" | wc -l)" -eq 1 ]
}

@test "claim records a normalized short work description" {
  run dibs claim "$DIR" --pid $$ --agent claude --description "Fix Dibs Lock Labels!" --json
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"description": "Fix Dibs Lock Labels!"'
}

@test "a second live claimer is refused and told who holds it and since when" {
  dibs claim "$DIR" --pid $$ --agent claude --description "stale dibs lock cleanup" --json
  tail -f /dev/null >/dev/null 2>&1 & local other=$!
  run dibs claim "$DIR" --pid "$other" --agent codex
  kill "$other" 2>/dev/null || true
  [ "$status" -ne 0 ]
  echo "$output" | grep -qi "refused"
  echo "$output" | grep -qi "held by claude"
  echo "$output" | grep -qi "work: stale dibs lock cleanup"
  echo "$output" | grep -qi "since"
  echo "$output" | grep -qi "git worktree"
  echo "$output" | grep -qi "new branch"
  echo "$output" | grep -qi "claim that worktree path"
  echo "$output" | grep -qi "loose non-git copy"
  echo "$output" | grep -qi "not a deliverable working tree"
}

@test "refused claim under --json reports state refused and the holder" {
  dibs claim "$DIR" --pid $$ --agent claude --description "stale dibs lock cleanup" --json
  tail -f /dev/null >/dev/null 2>&1 & local other=$!
  run dibs claim "$DIR" --pid "$other" --agent codex --json
  kill "$other" 2>/dev/null || true
  [ "$status" -ne 0 ]
  echo "$output" | grep -q '"state": "refused"'
  echo "$output" | grep -q '"agent": "claude"'
  echo "$output" | grep -q '"description": "stale dibs lock cleanup"'
  echo "$output" | grep -q '"acquiredAt"'
  echo "$output" | grep -q '"suggestion"'
  echo "$output" | grep -qi "git worktree"
  echo "$output" | grep -qi "loose non-git copy"
}

@test "re-claim by the same pid is idempotent (held-by-self)" {
  dibs claim "$DIR" --pid $$ --agent claude --json
  run dibs claim "$DIR" --pid $$ --agent claude --json
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"state": "held-by-self"'
}

@test "a resumed owner can reclaim with a new pid" {
  tail -f /dev/null >/dev/null 2>&1 & local old=$!
  tail -f /dev/null >/dev/null 2>&1 & local new=$!
  dibs claim "$DIR" --pid "$old" --agent codex --owner cmux-tab-1 --json >/dev/null

  run dibs claim "$DIR" --pid "$new" --agent codex --owner cmux-tab-1 --json
  local rc=$status
  local out="$output"
  run dibs check "$DIR" --json
  kill "$old" "$new" 2>/dev/null || true

  [ "$rc" -eq 0 ]
  echo "$out" | grep -q '"state": "reclaimed-by-owner"'
  echo "$output" | grep -q "\"pid\": $new"
}

@test "a different owner is still refused" {
  tail -f /dev/null >/dev/null 2>&1 & local old=$!
  tail -f /dev/null >/dev/null 2>&1 & local new=$!
  dibs claim "$DIR" --pid "$old" --agent codex --owner cmux-tab-1 --json >/dev/null

  run dibs claim "$DIR" --pid "$new" --agent codex --owner cmux-tab-2 --json
  kill "$old" "$new" 2>/dev/null || true

  [ "$status" -ne 0 ]
  echo "$output" | grep -q '"state": "refused"'
}

@test "a codex resume can reclaim an older ownerless foreign codex lock" {
  dibs claim "$DIR" --pid $$ --agent codex --json >/dev/null
  local lockpath
  lockpath="$(dibs check "$DIR" --json | "$NODE_BIN" -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>console.log(JSON.parse(s).path))')"
  "$NODE_BIN" -e 'const fs=require("fs");const p=process.argv[1];const r=JSON.parse(fs.readFileSync(p,"utf8"));r.hostname="some-other-host";r.session="old-thread";delete r.owner;fs.writeFileSync(p,JSON.stringify(r))' "$lockpath"

  run dibs claim "$DIR" --pid $$ --agent codex --owner cmux-tab-1 --legacy-codex-resume --json

  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"state": "reclaimed-by-owner"'
  echo "$output" | grep -q '"reason": "legacy-codex-resume"'
}

@test "a dead holder's lock is taken over by the next claimer" {
  tail -f /dev/null >/dev/null 2>&1 & local holder=$!
  dibs claim "$DIR" --pid "$holder" --agent claude --json
  kill "$holder"; wait "$holder" 2>/dev/null || true
  run dibs claim "$DIR" --pid $$ --agent codex --json
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"state": "took-over-stale"'
  echo "$output" | grep -q '"reason": "holder-dead"'
}

@test "a live holder on this host is respected (not broken)" {
  tail -f /dev/null >/dev/null 2>&1 & local holder=$!
  dibs claim "$DIR" --pid "$holder" --agent claude --json
  run dibs claim "$DIR" --pid $$ --agent codex --json
  kill "$holder" 2>/dev/null || true
  [ "$status" -ne 0 ]
  echo "$output" | grep -q '"state": "refused"'
  echo "$output" | grep -q '"reason": "holder-alive"'
}

@test "a foreign-host lock is respected even when its pid is locally alive" {
  run dibs check "$DIR" --json
  local lockpath
  dibs claim "$DIR" --pid $$ --agent claude --json >/dev/null
  lockpath="$(dibs check "$DIR" --json | "$NODE_BIN" -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>console.log(JSON.parse(s).path))')"
  "$NODE_BIN" -e 'const fs=require("fs");const p=process.argv[1];const r=JSON.parse(fs.readFileSync(p,"utf8"));r.hostname="some-other-host";r.pid='"$$"';fs.writeFileSync(p,JSON.stringify(r))' "$lockpath"
  run dibs claim "$DIR" --pid $$ --agent codex --json
  [ "$status" -ne 0 ]
  echo "$output" | grep -q '"reason": "foreign-host"'
}

@test "claim refuses a directory that does not exist" {
  run dibs claim "$BATS_TEST_TMPDIR/nope" --pid $$ --json
  [ "$status" -ne 0 ]
  echo "$output" | grep -qi "does not exist"
}

@test "an unknown option gives a clear error, not parser advice" {
  run dibs claim "$DIR" --bogus --pid $$
  [ "$status" -ne 0 ]
  echo "$output" | grep -qi "unknown option"
}

@test "concurrent claimers on a free dir yield exactly one holder" {
  local n=20
  declare -a holders=()
  for i in $(seq 1 $n); do
    tail -f /dev/null >/dev/null 2>&1 & holders+=($!)
  done
  local outdir="$BATS_TEST_TMPDIR/out"
  mkdir -p "$outdir"
  declare -a claimers=()
  for i in $(seq 1 $n); do
	(
	  if dibs claim "$DIR" --pid "${holders[$((i - 1))]}" --agent "a$i" --json >/dev/null 2>&1; then
		echo 0 >"$outdir/$i.rc"
	  else
		echo $? >"$outdir/$i.rc"
	  fi
	) &
    claimers+=($!)
  done
  for claimer in "${claimers[@]}"; do wait "$claimer"; done
  for holder in "${holders[@]}"; do kill "$holder" 2>/dev/null || true; done
  local ok=0
  for i in $(seq 1 $n); do
    [ "$(cat "$outdir/$i.rc")" -eq 0 ] && ok=$((ok + 1))
  done
  [ "$ok" -eq 1 ]
  [ "$(ls "$LAICLUSE_HOME/locks" | wc -l)" -eq 1 ]
}

@test "a corrupt lock file is reported and taken over by the next claimer" {
  dibs claim "$DIR" --pid $$ --agent claude --json >/dev/null
  printf 'not json{' > "$LAICLUSE_HOME"/locks/*.lock
  run dibs check "$DIR" --json
  echo "$output" | grep -q '"state": "corrupt"'
  run dibs claim "$DIR" --pid $$ --agent codex --json
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"state": "took-over-stale"'
  echo "$output" | grep -q '"reason": "corrupt"'
}

@test "an age-capped stale foreign lock can be taken over" {
  dibs claim "$DIR" --pid $$ --agent claude --json >/dev/null
  local lockpath
  lockpath="$(dibs check "$DIR" --json | "$NODE_BIN" -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>console.log(JSON.parse(s).path))')"
  "$NODE_BIN" -e 'const fs=require("fs");const p=process.argv[1];const r=JSON.parse(fs.readFileSync(p,"utf8"));r.hostname="some-other-host";r.acquiredAt="2000-01-01T00:00:00.000Z";fs.writeFileSync(p,JSON.stringify(r))' "$lockpath"
  run dibs claim "$DIR" --pid $$ --agent codex --max-age-hours 1 --json
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"state": "took-over-stale"'
}
