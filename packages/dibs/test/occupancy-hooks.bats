#!/usr/bin/env bats

load helpers
# Contract tests for the dibs occupancy enforcement hook. End-to-end cases run
# the real hooks/occupancy.sh; unit cases source it (the main dispatch is
# guarded behind a sourced-vs-executed check). A temp LAICLUSE_HOME keeps the
# lock store hermetic and DIBS_HOLDER_PID pins the recorded holder pid.

setup() {
  dibs_clear_ambient_identity
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../../.." && pwd)"
  HOOK="$REPO_ROOT/packages/dibs/hooks/occupancy.sh"
  NODE_BIN="$(command -v node)"
  export DIBS_BIN="$REPO_ROOT/packages/dibs/bin/dibs"
  export CLAUDE_PLUGIN_ROOT="$REPO_ROOT/packages/dibs"
  export LAICLUSE_HOME="$BATS_TEST_TMPDIR/laicluse"
  # A claim needs a work description; the hook reads it from DIBS_DESCRIPTION.
  # Provide one by default so cases that exercise claim/refuse behaviour are not
  # every one of them blocked; cases that test the no-description block unset it.
  export DIBS_DESCRIPTION="occupancy hook test work"
  DIR="$BATS_TEST_TMPDIR/work"
  mkdir -p "$DIR"
}

dibs() { "$NODE_BIN" "$DIBS_BIN" "$@"; }

emit() {
  jq -nc --arg e "$1" --arg t "$2" --arg cwd "$DIR" \
    '{hook_event_name:$e, tool_name:$t, cwd:$cwd, session_id:"sess-1", tool_input:{file_path:($cwd+"/f.txt"), content:"x"}}'
}

run_hook() {
  emit "$1" "$2" > "$BATS_TEST_TMPDIR/in.json"
  run "$HOOK" < "$BATS_TEST_TMPDIR/in.json"
}

stop_emit() {
  jq -nc --arg cwd "$DIR" --arg message "$1" \
    '{hook_event_name:"Stop", cwd:$cwd, session_id:"sess-1", stop_hook_active:false, last_assistant_message:$message}'
}

run_stop_hook() {
  stop_emit "$1" > "$BATS_TEST_TMPDIR/in.json"
  run "$HOOK" < "$BATS_TEST_TMPDIR/in.json"
}

bash_emit() {
	jq -nc --arg cwd "$DIR" --arg cmd "$1" \
		'{hook_event_name:"PreToolUse", tool_name:"Bash", cwd:$cwd, session_id:"sess-1", tool_input:{command:$cmd}}'
}

run_bash_hook() {
	bash_emit "$1" > "$BATS_TEST_TMPDIR/in.json"
	run "$HOOK" < "$BATS_TEST_TMPDIR/in.json"
}

init_test_repo() {
	local repo="$1"
	local branch="${2:-}"
	mkdir -p "$repo"
	if [ -n "$branch" ]; then
		git -C "$repo" init -q -b "$branch"
	else
		git -C "$repo" init -q
	fi
	git -C "$repo" config core.hooksPath /dev/null
	git -C "$repo" config user.email test@example.invalid
	git -C "$repo" config user.name Test
	printf 'root\n' > "$repo/README.md"
	git -C "$repo" add README.md
	git -C "$repo" commit -qm init
}

init_bash_target_repo() {
	init_test_repo "$1"
}

@test "gate hard-denies a write when a live other-session agent holds the dir" {
  tail -f /dev/null >/dev/null 2>&1 & local other=$!
  dibs claim "$DIR" --pid "$other" --agent codex --session other-sess --description "stale dibs lock cleanup" >/dev/null
  export DIBS_HOLDER_PID=$$
  run_hook PreToolUse Write
  kill "$other" 2>/dev/null || true
  [ "$status" -eq 2 ]
  echo "$output" | grep -q '\[dibs/occupancy\]'
  echo "$output" | grep -qi "held by codex"
  echo "$output" | grep -qi "work: stale dibs lock cleanup"
  echo "$output" | grep -qi "since"
  echo "$output" | grep -qi "surface this to the operator"
  echo "$output" | grep -qi "git worktree"
  echo "$output" | grep -qi "new branch"
  echo "$output" | grep -qi "loose non-git copy"
  echo "$output" | grep -qi "not a deliverable working tree"
}

@test "gate allows a different live pid of the SAME session (no self-lockout)" {
  tail -f /dev/null >/dev/null 2>&1 & local other=$!
  dibs claim "$DIR" --pid "$other" --agent claude --session sess-1 >/dev/null
  export DIBS_HOLDER_PID=$$
  run_hook PreToolUse Write
  kill "$other" 2>/dev/null || true
  [ "$status" -eq 0 ]
  ! echo "$output" | grep -q '\[dibs/occupancy\]'
}

@test "gate allows a resumed codex owner even when the session id changed" {
  tail -f /dev/null >/dev/null 2>&1 & local other=$!
  dibs claim "$DIR" --pid "$other" --agent codex --session old-thread --owner cmux-tab-1 >/dev/null
  export DIBS_HOLDER_PID=$$ PLUGIN_ROOT="$REPO_ROOT/packages/dibs" CMUX_TAB_ID=cmux-tab-1
  jq -nc --arg cwd "$DIR" '{hook_event_name:"PreToolUse", tool_name:"Write", cwd:$cwd, session_id:"new-thread", tool_input:{file_path:($cwd+"/f.txt"), content:"x"}}' > "$BATS_TEST_TMPDIR/in.json"

  run "$HOOK" < "$BATS_TEST_TMPDIR/in.json"
  local rc=$status
  run dibs check "$DIR" --json
  kill "$other" 2>/dev/null || true

  [ "$rc" -eq 0 ]
  ! echo "$output" | grep -q '\[dibs/occupancy\]'
  echo "$output" | grep -q "\"pid\": $$"
}

@test "first codex write reclaims an older ownerless foreign codex lock" {
  dibs claim "$DIR" --pid $$ --agent codex --session old-thread >/dev/null
  local lockpath
  lockpath="$(dibs check "$DIR" --json | jq -r '.path')"
  jq '.hostname="some-other-host" | del(.owner)' "$lockpath" > "$lockpath.tmp"
  mv "$lockpath.tmp" "$lockpath"
  export DIBS_HOLDER_PID=$$ PLUGIN_ROOT="$REPO_ROOT/packages/dibs" CMUX_TAB_ID=cmux-tab-1
  jq -nc --arg cwd "$DIR" '{hook_event_name:"PreToolUse", tool_name:"Write", cwd:$cwd, session_id:"new-thread", tool_input:{file_path:($cwd+"/f.txt"), content:"x"}}' > "$BATS_TEST_TMPDIR/in.json"

  run "$HOOK" < "$BATS_TEST_TMPDIR/in.json"
  local rc=$status
  run dibs check "$DIR" --json

  [ "$rc" -eq 0 ]
  echo "$output" | grep -q "\"pid\": $$"
  echo "$output" | grep -q '"owner": "cmux-tab-1"'
}

@test "gate allows a free dir and records occupancy" {
  export DIBS_HOLDER_PID=$$
  run_hook PreToolUse Write
  [ "$status" -eq 0 ]
  run dibs check "$DIR" --json
  echo "$output" | grep -q "\"pid\": $$"
}

@test "the missing-dibs denial hands back a claim bound to this session" {
  unset DIBS_DESCRIPTION
  payload="$(jq -cn --arg cwd "$DIR" '{hook_event_name:"PreToolUse", tool_name:"Write", cwd:$cwd, session_id:"sess-from-payload", tool_input:{file_path:($cwd+"/f.txt"), content:"x"}}')"

  run bash -c 'printf "%s" "$1" | bash "$2"' _ "$payload" "$HOOK"

  [ "$status" -eq 2 ]
  [[ "$output" == *"--session sess-from-payload"* ]]
}

@test "gate records DIBS_DESCRIPTION on hook claims" {
  export DIBS_HOLDER_PID=$$ DIBS_DESCRIPTION="Fix Dibs Lock Labels"
  run_hook PreToolUse Write
  [ "$status" -eq 0 ]
  run dibs check "$DIR" --json
  echo "$output" | grep -q '"description": "Fix Dibs Lock Labels"'
}

@test "gate blocks a write when no dibs and no description are administered" {
  unset DIBS_DESCRIPTION
  export DIBS_HOLDER_PID=$$
  run_hook PreToolUse Write
  [ "$status" -eq 2 ]
  echo "$output" | grep -qi 'no dibs registered for you'
  echo "$output" | grep -qi 'dibs claim'
  echo "$output" | grep -qi 'description'
  run dibs check "$DIR" --json
  echo "$output" | grep -q '"state": "free"'
}

# This refusal is where most agents compose a description, so it has to carry
# the bar and not only the syntax. Asking for the activity produced the same
# label in every directory, which is the failure this wording exists to avoid.
@test "the no-dibs refusal asks for the change and names the reader" {
  unset DIBS_DESCRIPTION
  export DIBS_HOLDER_PID=$$
  run_hook PreToolUse Write
  [ "$status" -eq 2 ]
  echo "$output" | grep -qi 'the change you are making'
  echo "$output" | grep -qi 'weeks from now'
}

@test "the no-dibs refusal shows a description that passes and one that fails" {
  unset DIBS_DESCRIPTION
  export DIBS_HOLDER_PID=$$
  run_hook PreToolUse Write
  [ "$status" -eq 2 ]
  echo "$output" | grep -qi 'finish the plugin install'
  echo "$output" | grep -qi 'session work'
}

@test "the CLI refusal carries the same bar as the hook refusal" {
  unset DIBS_DESCRIPTION
  run dibs claim "$DIR" --pid $$ --agent claude --session sess-1
  [ "$status" -ne 0 ]
  echo "$output" | grep -qi 'the change you are making'
  echo "$output" | grep -qi 'not the activity'
}

@test "gate does not record the actual default branch as work description" {
  local repo="$BATS_TEST_TMPDIR/default-branch-repo"
  init_test_repo "$repo" trunk
  git -C "$repo" remote add origin git@example.invalid:org/repo.git
  git -C "$repo" update-ref refs/remotes/origin/trunk HEAD
  git -C "$repo" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/trunk

  export DIBS_HOLDER_PID=$$
  DIR="$repo"
  run_bash_hook "touch default.txt"
  [ "$status" -eq 0 ]
  run dibs check "$repo" --json
  ! echo "$output" | grep -q '"description": "trunk"'
}

@test "gate treats current HEAD as default when origin HEAD is absent" {
  local repo="$BATS_TEST_TMPDIR/current-head-default-repo"
  init_test_repo "$repo" main
  git -C "$repo" checkout -b trunk >/dev/null
  git -C "$repo" commit --allow-empty -m "trunk default" >/dev/null

  export DIBS_HOLDER_PID=$$
  DIR="$repo"
  run_bash_hook "touch current-head.txt"
  [ "$status" -eq 0 ]
  run dibs check "$repo" --json
  ! echo "$output" | grep -q '"description": "trunk"'
}

@test "Bash read-only command does not claim or block" {
	tail -f /dev/null >/dev/null 2>&1 & local other=$!
	dibs claim "$DIR" --pid "$other" --agent codex --session other-sess >/dev/null
	export DIBS_HOLDER_PID=$$
	run_bash_hook "git status --short"
	local rc=$status out="$output"
	run dibs check "$DIR" --json
	kill "$other" 2>/dev/null || true
	[ "$rc" -eq 0 ]
	[ -z "$out" ]
	echo "$output" | grep -q '"agent": "codex"'
}

@test "Bash mutating command gates an absolute target git worktree" {
	local repo="$BATS_TEST_TMPDIR/repo"
	init_test_repo "$repo"

	tail -f /dev/null >/dev/null 2>&1 & local other=$!
	dibs claim "$repo" --pid "$other" --agent codex --session other-sess >/dev/null
	export DIBS_HOLDER_PID=$$
	DIR="$BATS_TEST_TMPDIR"
	run_bash_hook "touch $repo/new.txt"
	kill "$other" 2>/dev/null || true
	[ "$status" -eq 2 ]
	echo "$output" | grep -q '\[dibs/occupancy\]'
}

@test "Bash resolves relative write targets from the command workdir, not the conversation cwd" {
	local conversation_repo="$BATS_TEST_TMPDIR/conversation-repo"
	local command_repo="$BATS_TEST_TMPDIR/command-repo"
	init_bash_target_repo "$conversation_repo"
	init_bash_target_repo "$command_repo"

	tail -f /dev/null >/dev/null 2>&1 & local other=$!
	dibs claim "$conversation_repo" --pid "$other" --agent codex --session other-sess --description "other session work" >/dev/null
	export DIBS_HOLDER_PID=$$
	jq -nc --arg cwd "$conversation_repo" --arg workdir "$command_repo" \
		'{hook_event_name:"PreToolUse", tool_name:"Bash", cwd:$cwd, session_id:"sess-1", tool_input:{command:"touch changed.txt", workdir:$workdir}}' > "$BATS_TEST_TMPDIR/in.json"

	run "$HOOK" < "$BATS_TEST_TMPDIR/in.json"
	local rc=$status
	run dibs check "$command_repo" --json
	local command_lock="$output"
	run dibs check "$conversation_repo" --json
	local conversation_lock="$output"
	kill "$other" 2>/dev/null || true

	[ "$rc" -eq 0 ]
	echo "$command_lock" | grep -q '"pid": '$$
	echo "$conversation_lock" | grep -q '"agent": "codex"'
}

@test "Codex refuses an ambiguous Bash mutation when its hook payload omits workdir" {
	local conversation_repo="$BATS_TEST_TMPDIR/conversation-repo"
	init_bash_target_repo "$conversation_repo"

	unset DIBS_DESCRIPTION
	export DIBS_HOLDER_PID=$$ PLUGIN_ROOT="$REPO_ROOT/packages/dibs"
	jq -nc --arg cwd "$conversation_repo" \
		'{hook_event_name:"PreToolUse", tool_name:"Bash", cwd:$cwd, session_id:"sess-1", tool_input:{command:"git merge --no-ff feature"}}' > "$BATS_TEST_TMPDIR/in.json"

	run "$HOOK" < "$BATS_TEST_TMPDIR/in.json"
	local rc=$status message="$output"
	run dibs check "$conversation_repo" --json

	[ "$rc" -eq 0 ]
	echo "$message" | jq -e '.hookSpecificOutput == {
		hookEventName: "PreToolUse",
		permissionDecision: "deny",
		permissionDecisionReason: "Dibs lock required for changes."
	}' >/dev/null
	echo "$output" | grep -q '"state": "free"'
}

@test "Codex accepts an ambiguous Bash mutation after claiming the conversation repo" {
	local conversation_repo="$BATS_TEST_TMPDIR/conversation-repo"
	local command
	init_bash_target_repo "$conversation_repo"

	export DIBS_HOLDER_PID=$$ PLUGIN_ROOT="$REPO_ROOT/packages/dibs"
	dibs claim "$conversation_repo" --pid $$ --agent codex --session sess-1 \
		--owner sess-1 --description "commit the claimed repository" >/dev/null
	command="$(printf 'git commit -m \"$(cat <<'\''EOF'\''\nSubject\n\nBody.\n\nSlice: docs-only\nEOF\n)\"')"
	jq -nc --arg cwd "$conversation_repo" --arg command "$command" \
		'{hook_event_name:"PreToolUse", tool_name:"Bash", cwd:$cwd, session_id:"sess-1", tool_input:{command:$command}}' > "$BATS_TEST_TMPDIR/in.json"

	run "$HOOK" < "$BATS_TEST_TMPDIR/in.json"

	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

@test "Codex refuses an unresolved Bash target when its hook payload omits workdir" {
	local conversation_repo="$BATS_TEST_TMPDIR/conversation-repo"
	init_bash_target_repo "$conversation_repo"

	unset DIBS_DESCRIPTION DIBS_MISSING_TARGET
	export DIBS_HOLDER_PID=$$ PLUGIN_ROOT="$REPO_ROOT/packages/dibs"
	jq -nc --arg cwd "$conversation_repo" \
		'{hook_event_name:"PreToolUse", tool_name:"Bash", cwd:$cwd, session_id:"sess-1", tool_input:{command:"touch \"$DIBS_MISSING_TARGET/result\""}}' > "$BATS_TEST_TMPDIR/in.json"

	run "$HOOK" < "$BATS_TEST_TMPDIR/in.json"
	local rc=$status message="$output"
	run dibs check "$conversation_repo" --json

	[ "$rc" -eq 0 ]
	echo "$message" | jq -e '.hookSpecificOutput == {
		hookEventName: "PreToolUse",
		permissionDecision: "deny",
		permissionDecisionReason: "Dibs lock required for changes."
	}' >/dev/null
	echo "$output" | grep -q '"state": "free"'
}

@test "Codex gates an explicit git target when its hook payload omits workdir" {
	local conversation_repo="$BATS_TEST_TMPDIR/conversation-repo"
	local command_repo="$BATS_TEST_TMPDIR/command-repo"
	init_bash_target_repo "$conversation_repo"
	init_bash_target_repo "$command_repo"

	tail -f /dev/null >/dev/null 2>&1 & local other=$!
	dibs claim "$conversation_repo" --pid "$other" --agent codex --session other-sess --description "other session work" >/dev/null
	export DIBS_HOLDER_PID=$$ PLUGIN_ROOT="$REPO_ROOT/packages/dibs"
	jq -nc --arg cwd "$conversation_repo" --arg repo "$command_repo" \
		'{hook_event_name:"PreToolUse", tool_name:"Bash", cwd:$cwd, session_id:"sess-1", tool_input:{command:("git -C " + $repo + " merge --no-ff feature")}}' > "$BATS_TEST_TMPDIR/in.json"

	run "$HOOK" < "$BATS_TEST_TMPDIR/in.json"
	local rc=$status
	run dibs check "$command_repo" --json
	local command_lock="$output"
	run dibs check "$conversation_repo" --json
	local conversation_lock="$output"
	kill "$other" 2>/dev/null || true

	[ "$rc" -eq 0 ]
	echo "$command_lock" | grep -q '"pid": '$$
	echo "$conversation_lock" | grep -q '"agent": "codex"'
}

@test "opt-in worktree requirement denies primary checkout mutation and allows linked worktree" {
	local primary="$BATS_TEST_TMPDIR/primary"
	local linked="$BATS_TEST_TMPDIR/linked"
	init_test_repo "$primary"
	git -C "$primary" config laicluse.requireWorktree true
	git -C "$primary" worktree add -b linked "$linked" >/dev/null

	export DIBS_HOLDER_PID=$$
	DIR="$primary"
	run_bash_hook "touch primary.txt"
	[ "$status" -eq 2 ]
	echo "$output" | grep -q '\[dibs/worktree-required\]'
	echo "$output" | grep -q 'operator explicitly asked you to work without a worktree'
	echo "$output" | grep -q 'git config laicluse.requireWorktree false'

	git -C "$primary" config laicluse.requireWorktree false
	run_bash_hook "touch primary.txt"
	[ "$status" -eq 0 ]

	DIR="$linked"
	run_bash_hook "touch linked.txt"
	[ "$status" -eq 0 ]
}

@test "gate self-heals a dead holder and allows the write" {
  tail -f /dev/null >/dev/null 2>&1 & local dead=$!
  dibs claim "$DIR" --pid "$dead" --agent claude >/dev/null
  kill "$dead"; wait "$dead" 2>/dev/null || true
  export DIBS_HOLDER_PID=$$
  run_hook PreToolUse Write
  [ "$status" -eq 0 ]
}

@test "gate fails open when the dir does not exist" {
  rmdir "$DIR"
  export DIBS_HOLDER_PID=$$
  run_hook PreToolUse Write
  [ "$status" -eq 0 ]
}

@test "gate fails open when the payload carries no cwd" {
  tail -f /dev/null >/dev/null 2>&1 & local other=$!
  dibs claim "$DIR" --pid "$other" --agent codex --session other-sess >/dev/null
  export DIBS_HOLDER_PID=$$
  jq -nc '{hook_event_name:"PreToolUse", tool_name:"Write", session_id:"sess-1", tool_input:{file_path:"/tmp/x.ts", content:"x"}}' > "$BATS_TEST_TMPDIR/in.json"
  run "$HOOK" < "$BATS_TEST_TMPDIR/in.json"
  kill "$other" 2>/dev/null || true
  [ "$status" -eq 0 ]
  ! echo "$output" | grep -q '\[dibs/occupancy\]'
}

@test "gate fails open when the payload carries no session id" {
  tail -f /dev/null >/dev/null 2>&1 & local other=$!
  dibs claim "$DIR" --pid "$other" --agent codex --session other-sess >/dev/null
  export DIBS_HOLDER_PID=$$
  jq -nc --arg cwd "$DIR" '{hook_event_name:"PreToolUse", tool_name:"Write", cwd:$cwd, tool_input:{file_path:($cwd+"/f.txt"), content:"x"}}' > "$BATS_TEST_TMPDIR/in.json"
  run "$HOOK" < "$BATS_TEST_TMPDIR/in.json"
  kill "$other" 2>/dev/null || true
  [ "$status" -eq 0 ]
}

@test "apply_patch gates the target git worktree instead of an occupied parent cwd" {
  local parent="$BATS_TEST_TMPDIR/repo"
  local child="$parent/worktrees/child"
  init_test_repo "$parent"
  git -C "$parent" worktree add -b child "$child" >/dev/null

  tail -f /dev/null >/dev/null 2>&1 & local other=$!
  dibs claim "$parent" --pid "$other" --agent claude --session other-sess >/dev/null
  export DIBS_HOLDER_PID=$$
  jq -nc --arg cwd "$parent" --arg target "$child/new.txt" '
    {
      hook_event_name:"PreToolUse",
      tool_name:"apply_patch",
      cwd:$cwd,
      session_id:"sess-1",
      tool_input:{patch:"*** Begin Patch\n*** Add File: \($target)\n+ok\n*** End Patch\n"}
    }' > "$BATS_TEST_TMPDIR/in.json"

  run "$HOOK" < "$BATS_TEST_TMPDIR/in.json"
  local rc=$status
  run dibs check "$child" --json
  kill "$other" 2>/dev/null || true
  [ "$rc" -eq 0 ]
  echo "$output" | grep -q "\"pid\": $$"
}

@test "apply_patch gates a freeform raw patch string by its target git worktree" {
  local parent="$BATS_TEST_TMPDIR/repo"
  local child="$parent/worktrees/child"
  init_test_repo "$parent"
  git -C "$parent" worktree add -b child "$child" >/dev/null

  tail -f /dev/null >/dev/null 2>&1 & local other=$!
  dibs claim "$parent" --pid "$other" --agent claude --session other-sess >/dev/null
  export DIBS_HOLDER_PID=$$
  jq -nc --arg cwd "$parent" --arg target "$child/new.txt" '
    {
      hook_event_name:"PreToolUse",
      tool_name:"apply_patch",
      cwd:$cwd,
      session_id:"sess-1",
      tool_input:"*** Begin Patch\n*** Add File: \($target)\n+ok\n*** End Patch\n"
    }' > "$BATS_TEST_TMPDIR/in.json"

  run "$HOOK" < "$BATS_TEST_TMPDIR/in.json"
  local rc=$status
  run dibs check "$child" --json
  kill "$other" 2>/dev/null || true
  [ "$rc" -eq 0 ]
  echo "$output" | grep -q "\"pid\": $$"
}

@test "SessionStart does not steer aside when a live other-session agent holds the dir" {
  tail -f /dev/null >/dev/null 2>&1 & local other=$!
  dibs claim "$DIR" --pid "$other" --agent codex --session other-sess >/dev/null
  export DIBS_HOLDER_PID=$$
  run_hook SessionStart startup
  local rc=$status
  local session_output="$output"
  run dibs check "$DIR" --json
  kill "$other" 2>/dev/null || true
  [ "$rc" -eq 0 ]
  [ -z "$session_output" ]
  echo "$output" | grep -q '"agent": "codex"'
}

@test "SessionStart leaves a free dir unclaimed" {
  export DIBS_HOLDER_PID=$$
  run_hook SessionStart startup
  [ "$status" -eq 0 ]
  run dibs check "$DIR" --json
  echo "$output" | grep -q '"state": "free"'
}

@test "SessionStart ignores missing dibs because enforcement starts at write time" {
  export DIBS_BIN="$BATS_TEST_TMPDIR/nonexistent-dibs"
  export CLAUDE_PLUGIN_ROOT="$BATS_TEST_TMPDIR/nowhere"
  export DIBS_HOLDER_PID=$$
  run_hook SessionStart startup
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "SessionEnd releases the dir the holder held" {
  export DIBS_HOLDER_PID=$$
  dibs claim "$DIR" --pid $$ --agent claude >/dev/null
  run_hook SessionEnd ""
  [ "$status" -eq 0 ]
  run dibs check "$DIR" --json
  echo "$output" | grep -q '"state": "free"'
}

@test "SessionEnd sweeps every directory this session locked, not only cwd" {
  local dir2="$BATS_TEST_TMPDIR/work2"
  mkdir -p "$dir2"
  export DIBS_HOLDER_PID=$$
  dibs claim "$DIR" --pid $$ --agent claude --session sess-1 >/dev/null
  dibs claim "$dir2" --pid $$ --agent claude --session sess-1 >/dev/null
  run_hook SessionEnd ""
  [ "$status" -eq 0 ]
  run dibs check "$DIR" --json
  echo "$output" | grep -q '"state": "free"'
  run dibs check "$dir2" --json
  echo "$output" | grep -q '"state": "free"'
}

@test "SessionEnd does not disturb a dir held by another agent" {
  tail -f /dev/null >/dev/null 2>&1 & local other=$!
  dibs claim "$DIR" --pid "$other" --agent codex --session other-sess >/dev/null
  export DIBS_HOLDER_PID=$$
  run_hook SessionEnd ""
  local rc=$status
  run dibs check "$DIR" --json
  kill "$other" 2>/dev/null || true
  [ "$rc" -eq 0 ]
  echo "$output" | grep -q '"agent": "codex"'
}

# A lock lasts as long as the session. Ending a turn is not a release: the
# previous rule read the assistant's closing prose for a completion marker and
# swept every lock whenever it did not find one, which is every turn that opens
# its closing line with a marker instead of ending on one.

@test "a finished-sounding turn keeps every lock the session holds" {
  local dir2="$BATS_TEST_TMPDIR/work2"
  mkdir -p "$dir2"
  export DIBS_HOLDER_PID=$$
  dibs claim "$DIR" --pid $$ --agent claude --session sess-1 >/dev/null
  dibs claim "$dir2" --pid $$ --agent claude --session sess-1 >/dev/null

  run_stop_hook "Implemented, verified, and committed."
  [ "$status" -eq 0 ]
  run dibs check "$DIR" --json
  echo "$output" | grep -q '"pid": '$$
  run dibs check "$dir2" --json
  echo "$output" | grep -q '"pid": '$$
}

@test "a turn that pauses for the operator keeps its lock" {
  export DIBS_HOLDER_PID=$$
  dibs claim "$DIR" --pid $$ --agent claude --session sess-1 >/dev/null

  run_stop_hook "🚦 Waiting on your choice before I continue."
  [ "$status" -eq 0 ]
  run dibs check "$DIR" --json
  echo "$output" | grep -q '"pid": '$$
}

@test "a turn that reports completion keeps its lock" {
  export DIBS_HOLDER_PID=$$
  dibs claim "$DIR" --pid $$ --agent claude --session sess-1 >/dev/null

  run_stop_hook "🏁 Committed and the tree is clean."
  [ "$status" -eq 0 ]
  run dibs check "$DIR" --json
  echo "$output" | grep -q '"pid": '$$
}

@test "no wording at the end of a turn can release a lock" {
  export DIBS_HOLDER_PID=$$
  local phrasing
  for phrasing in "Done." "Which account should I use?" "Still going 🚧" "🚧 Still going." ""; do
    dibs claim "$DIR" --pid $$ --agent claude --session sess-1 >/dev/null
    run_stop_hook "$phrasing"
    [ "$status" -eq 0 ]
    run dibs check "$DIR" --json
    echo "$output" | grep -q '"pid": '$$ || {
      echo "released on phrasing: [$phrasing]" >&2
      return 1
    }
  done
}

@test "SessionEnd still sweeps every directory this session locked" {
  local dir2="$BATS_TEST_TMPDIR/work2"
  mkdir -p "$dir2"
  export DIBS_HOLDER_PID=$$
  dibs claim "$DIR" --pid $$ --agent claude --session sess-1 >/dev/null
  dibs claim "$dir2" --pid $$ --agent claude --session sess-1 >/dev/null

  run_hook SessionEnd ""
  [ "$status" -eq 0 ]
  run dibs check "$DIR" --json
  echo "$output" | grep -q '"state": "free"'
  run dibs check "$dir2" --json
  echo "$output" | grep -q '"state": "free"'
}

@test "neither hook manifest registers a Stop handler" {
  run jq -e '.hooks.Stop' "$REPO_ROOT/packages/dibs/hooks/hooks.json"
  [ "$status" -ne 0 ]
  run jq -e '.hooks.Stop' "$REPO_ROOT/packages/dibs/hooks/hooks.codex.json"
  [ "$status" -ne 0 ]
}

@test "the recorded holder pid equals DIBS_HOLDER_PID, not the hook shell" {
  export DIBS_HOLDER_PID=$$
  run_hook PreToolUse Write
  [ "$status" -eq 0 ]
  local lockpath
  lockpath="$(dibs check "$DIR" --json | jq -r '.path')"
  run jq -r '.pid' "$lockpath"
  [ "$output" = "$$" ]
}

@test "DIBS_OCCUPANCY=off disables enforcement entirely" {
  tail -f /dev/null >/dev/null 2>&1 & local other=$!
  dibs claim "$DIR" --pid "$other" --agent codex --session other-sess >/dev/null
  export DIBS_HOLDER_PID=$$ DIBS_OCCUPANCY=off
  run_hook PreToolUse Write
  kill "$other" 2>/dev/null || true
  [ "$status" -eq 0 ]
  ! echo "$output" | grep -q '\[dibs/occupancy\]'
}

@test "holder pid walk resolves the nearest claude/codex ancestor (hermetic fake ps)" {
  unset DIBS_HOLDER_PID
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  cat > "$BATS_TEST_TMPDIR/bin/ps" <<'PS'
#!/bin/bash
mode="$2"; pid="$4"
if [ "$mode" = "comm=" ]; then
  case "$pid" in
    100) echo "/usr/bin/foo" ;;
    200) echo "/usr/local/bin/node" ;;
    300) echo "/Users/x/.local/share/claude/versions/2.1.179" ;;
    400) echo "/bin/zsh" ;;
  esac
elif [ "$mode" = "ppid=" ]; then
  case "$pid" in
    100) echo 200 ;; 200) echo 300 ;; 300) echo 400 ;; 400) echo 1 ;;
  esac
fi
PS
  chmod +x "$BATS_TEST_TMPDIR/bin/ps"
  source "$HOOK"
  PATH="$BATS_TEST_TMPDIR/bin:$PATH" run occ_holder_pid 100
  [ "$status" -eq 0 ]
  [ "$output" = "300" ]
}

@test "holder pid walk picks the inner codex, not the outer claude it runs under (hermetic fake ps)" {
  unset DIBS_HOLDER_PID
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  cat > "$BATS_TEST_TMPDIR/bin/ps" <<'PS'
#!/bin/bash
mode="$2"; pid="$4"
if [ "$mode" = "comm=" ]; then
  case "$pid" in
    100) echo "/bin/bash" ;;
    250) echo "/Users/x/.codex/packages/standalone/releases/codex-path/codex" ;;
    350) echo "/usr/local/bin/node" ;;
    450) echo "/Users/x/.local/bin/claude" ;;
  esac
elif [ "$mode" = "ppid=" ]; then
  case "$pid" in
    100) echo 250 ;; 250) echo 350 ;; 350) echo 450 ;; 450) echo 1 ;;
  esac
fi
PS
  chmod +x "$BATS_TEST_TMPDIR/bin/ps"
  source "$HOOK"
  PATH="$BATS_TEST_TMPDIR/bin:$PATH" run occ_holder_pid 100
  [ "$status" -eq 0 ]
  [ "$output" = "250" ]
}

@test "a codex launched under a claude session still labels itself codex" {
  source "$HOOK"
  PLUGIN_ROOT="/some/codex/cache" CLAUDE_PLUGIN_ROOT="/some/codex/cache" run occ_agent_label
  [ "$status" -eq 0 ]
  [ "$output" = "codex" ]
}

@test "a 2>/dev/null stderr redirect does not mark a read-only command as mutating" {
  source "$HOOK"
  run occ_bash_mutates "grep -r needle app 2>/dev/null"
  [ "$status" -eq 1 ]
  run occ_bash_mutates "find . -name '*.rb' 2>/dev/null"
  [ "$status" -eq 1 ]
  run occ_bash_mutates "echo written > out.txt"
  [ "$status" -eq 0 ]
}

@test "dibs never locks the /dev device tree" {
  run dibs claim /dev --pid $$ --agent claude --json
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"state": "excluded"'
}

@test "a 2>/dev/null redirect never contends the global /dev lock" {
  tail -f /dev/null >/dev/null 2>&1 & local other=$!
  dibs claim /dev --pid "$other" --agent codex --session other-sess >/dev/null 2>&1 || true
  export DIBS_HOLDER_PID=$$
  run_bash_hook "grep -r needle . 2>/dev/null"
  kill "$other" 2>/dev/null || true
  [ "$status" -eq 0 ]
  ! echo "$output" | grep -q '\[dibs/occupancy\]'
}

@test "a read-only command that references another repo path does not claim it" {
  local other_repo="$BATS_TEST_TMPDIR/other"
  init_test_repo "$other_repo"

  export DIBS_HOLDER_PID=$$
  run_bash_hook "grep -r needle $other_repo 2>/dev/null"
  [ "$status" -eq 0 ]
  run dibs check "$other_repo" --json
  echo "$output" | grep -q '"state": "free"'
}

@test "bogus path tokens from heredoc content do not claim the filesystem root" {
  # A mutating bash command whose embedded heredoc holds XML like </w:p> yields a
  # bogus "/w:p" candidate that walks up to "/". Before the guard this claimed the
  # filesystem root and collided with any session holding "/". The gate must stay at
  # real directory level and fall back to cwd instead.
  tail -f /dev/null >/dev/null 2>&1 & local other=$!
  dibs claim / --pid "$other" --agent codex --session other-sess >/dev/null
  export DIBS_HOLDER_PID=$$
  run_bash_hook 'python3 - <<PY
re.compile(r"</w:p>")
PY
cp a.docx b.docx'
  kill "$other" 2>/dev/null || true
  [ "$status" -eq 0 ]
  ! echo "$output" | grep -q '\[dibs/occupancy\]'
}

@test "Bash rm expands a tilde target without gating an occupied cwd" {
	local cwd_repo="$BATS_TEST_TMPDIR/cwd"
	export HOME="$BATS_TEST_TMPDIR/home"
	local target_repo="$HOME/other"
	init_bash_target_repo "$cwd_repo"
	init_bash_target_repo "$target_repo"

	tail -f /dev/null >/dev/null 2>&1 & local other_pid=$!
	dibs claim "$cwd_repo" --pid "$other_pid" --agent codex --session other-sess >/dev/null
	export DIBS_HOLDER_PID=$$
	DIR="$cwd_repo"
	run_bash_hook 'rm ~/other/f'
	local hook_status=$status hook_output="$output"
	run dibs check "$target_repo" --json
	local target_lock="$output"
	run dibs check "$cwd_repo" --json
	local cwd_lock="$output"
	kill "$other_pid" 2>/dev/null || true

	[ "$hook_status" -eq 0 ]
	[ -z "$hook_output" ]
	echo "$target_lock" | grep -q "\"pid\": $$"
	echo "$cwd_lock" | grep -q '"agent": "codex"'
}

@test "Bash git -C expands a tilde repo without gating an occupied cwd" {
	local cwd_repo="$BATS_TEST_TMPDIR/cwd"
	export HOME="$BATS_TEST_TMPDIR/home"
	local target_repo="$HOME/other"
	init_bash_target_repo "$cwd_repo"
	init_bash_target_repo "$target_repo"

	tail -f /dev/null >/dev/null 2>&1 & local other_pid=$!
	dibs claim "$cwd_repo" --pid "$other_pid" --agent codex --session other-sess >/dev/null
	export DIBS_HOLDER_PID=$$
	DIR="$cwd_repo"
	run_bash_hook 'git -C ~/other commit'
	local hook_status=$status hook_output="$output"
	run dibs check "$target_repo" --json
	local target_lock="$output"
	kill "$other_pid" 2>/dev/null || true

	[ "$hook_status" -eq 0 ]
	[ -z "$hook_output" ]
	echo "$target_lock" | grep -q "\"pid\": $$"
}

@test "Bash git commit ignores message-file and heredoc path text" {
	local cwd_repo="$BATS_TEST_TMPDIR/cwd"
	local decoy_repo="$BATS_TEST_TMPDIR/decoy"
	init_bash_target_repo "$cwd_repo"
	init_bash_target_repo "$decoy_repo"

	tail -f /dev/null >/dev/null 2>&1 & local other_pid=$!
	dibs claim "$decoy_repo" --pid "$other_pid" --agent codex --session other-sess >/dev/null
	export DIBS_HOLDER_PID=$$
	DIR="$cwd_repo"
	local command="git commit -F - <<'MSG'
Paths are text here: $decoy_repo/file and \$HOME/other/file.
MSG"
	run_bash_hook "$command"
	local hook_status=$status hook_output="$output"
	run dibs check "$cwd_repo" --json
	local cwd_lock="$output"
	run dibs check "$decoy_repo" --json
	local decoy_lock="$output"
	kill "$other_pid" 2>/dev/null || true

	[ "$hook_status" -eq 0 ]
	[ -z "$hook_output" ]
	echo "$cwd_lock" | grep -q "\"pid\": $$"
	echo "$decoy_lock" | grep -q '"agent": "codex"'
}

@test "Bash git ignores a message-file path outside its write target" {
	local target_repo="$BATS_TEST_TMPDIR/target"
	local message_repo="$BATS_TEST_TMPDIR/messages"
	init_bash_target_repo "$target_repo"
	init_bash_target_repo "$message_repo"

	tail -f /dev/null >/dev/null 2>&1 & local other_pid=$!
	dibs claim "$message_repo" --pid "$other_pid" --agent codex --session other-sess >/dev/null
	export DIBS_HOLDER_PID=$$
	DIR="$BATS_TEST_TMPDIR"
	run_bash_hook "git -C $target_repo commit -F $message_repo/message.txt"
	local hook_status=$status hook_output="$output"
	run dibs check "$target_repo" --json
	local target_lock="$output"
	kill "$other_pid" 2>/dev/null || true

	[ "$hook_status" -eq 0 ]
	[ -z "$hook_output" ]
	echo "$target_lock" | grep -q "\"pid\": $$"
}

@test "Bash git --git-dir expands HOME and gates that repository" {
	local cwd_repo="$BATS_TEST_TMPDIR/cwd"
	export HOME="$BATS_TEST_TMPDIR/home"
	local target_repo="$HOME/other"
	init_bash_target_repo "$cwd_repo"
	init_bash_target_repo "$target_repo"

	tail -f /dev/null >/dev/null 2>&1 & local other_pid=$!
	dibs claim "$cwd_repo" --pid "$other_pid" --agent codex --session other-sess >/dev/null
	export DIBS_HOLDER_PID=$$
	DIR="$cwd_repo"
	run_bash_hook 'git --git-dir="$HOME/other/.git" commit'
	local hook_status=$status hook_output="$output"
	run dibs check "$target_repo" --json
	local target_lock="$output"
	kill "$other_pid" 2>/dev/null || true

	[ "$hook_status" -eq 0 ]
	[ -z "$hook_output" ]
	echo "$target_lock" | grep -q "\"pid\": $$"
}

@test "Bash rm expands an exported variable target without gating cwd" {
	local cwd_repo="$BATS_TEST_TMPDIR/cwd"
	local target_repo="$BATS_TEST_TMPDIR/target"
	init_bash_target_repo "$cwd_repo"
	init_bash_target_repo "$target_repo"
	export TARGET_REPO="$target_repo"

	tail -f /dev/null >/dev/null 2>&1 & local other_pid=$!
	dibs claim "$cwd_repo" --pid "$other_pid" --agent codex --session other-sess >/dev/null
	export DIBS_HOLDER_PID=$$
	DIR="$cwd_repo"
	run_bash_hook 'rm "$TARGET_REPO/file"'
	local hook_status=$status hook_output="$output"
	run dibs check "$target_repo" --json
	local target_lock="$output"
	kill "$other_pid" 2>/dev/null || true

	[ "$hook_status" -eq 0 ]
	[ -z "$hook_output" ]
	echo "$target_lock" | grep -q "\"pid\": $$"
}

@test "Bash redirect expands HOME and gates only its output target" {
	local cwd_repo="$BATS_TEST_TMPDIR/cwd"
	export HOME="$BATS_TEST_TMPDIR/home"
	local target_repo="$HOME/other"
	init_bash_target_repo "$cwd_repo"
	init_bash_target_repo "$target_repo"

	tail -f /dev/null >/dev/null 2>&1 & local other_pid=$!
	dibs claim "$cwd_repo" --pid "$other_pid" --agent codex --session other-sess >/dev/null
	export DIBS_HOLDER_PID=$$
	DIR="$cwd_repo"
	run_bash_hook 'printf done > "$HOME/other/output.txt"'
	local hook_status=$status hook_output="$output"
	run dibs check "$target_repo" --json
	local target_lock="$output"
	kill "$other_pid" 2>/dev/null || true

	[ "$hook_status" -eq 0 ]
	[ -z "$hook_output" ]
	echo "$target_lock" | grep -q "\"pid\": $$"
}

@test "Bash copy gates a relative destination in cwd instead of its source" {
	local cwd_repo="$BATS_TEST_TMPDIR/cwd"
	local source_repo="$BATS_TEST_TMPDIR/source"
	init_bash_target_repo "$cwd_repo"
	init_bash_target_repo "$source_repo"

	tail -f /dev/null >/dev/null 2>&1 & local other_pid=$!
	dibs claim "$cwd_repo" --pid "$other_pid" --agent codex --session other-sess >/dev/null
	export DIBS_HOLDER_PID=$$
	DIR="$cwd_repo"
	run_bash_hook "cp $source_repo/README.md local-copy"
	local hook_status=$status hook_output="$output"
	kill "$other_pid" 2>/dev/null || true

	[ "$hook_status" -eq 2 ]
	echo "$hook_output" | grep -q '\[dibs/occupancy\]'
}

@test "Bash copy does not gate its occupied read-only source" {
	local source_repo="$BATS_TEST_TMPDIR/source"
	local target_repo="$BATS_TEST_TMPDIR/target"
	init_bash_target_repo "$source_repo"
	init_bash_target_repo "$target_repo"

	tail -f /dev/null >/dev/null 2>&1 & local other_pid=$!
	dibs claim "$source_repo" --pid "$other_pid" --agent codex --session other-sess >/dev/null
	export DIBS_HOLDER_PID=$$
	DIR="$BATS_TEST_TMPDIR"
	run_bash_hook "cp $source_repo/README.md $target_repo/copied.md"
	local hook_status=$status hook_output="$output"
	run dibs check "$target_repo" --json
	local target_lock="$output"
	kill "$other_pid" 2>/dev/null || true

	[ "$hook_status" -eq 0 ]
	[ -z "$hook_output" ]
	echo "$target_lock" | grep -q "\"pid\": $$"
}

@test "Bash read-only git with a path never claims or blocks that repository" {
	local target_repo="$BATS_TEST_TMPDIR/target"
	init_bash_target_repo "$target_repo"

	tail -f /dev/null >/dev/null 2>&1 & local other_pid=$!
	dibs claim "$target_repo" --pid "$other_pid" --agent codex --session other-sess >/dev/null
	export DIBS_HOLDER_PID=$$
	DIR="$BATS_TEST_TMPDIR"
	run_bash_hook "git -C $target_repo status --short"
	local hook_status=$status hook_output="$output"
	kill "$other_pid" 2>/dev/null || true

	[ "$hook_status" -eq 0 ]
	[ -z "$hook_output" ]
}
