#!/usr/bin/env bats

load ../../packages/git-discipline/test/parallel-flow/helpers

teardown() {
  if [ -n "${TEST_HOLDER:-}" ]; then kill "$TEST_HOLDER" 2>/dev/null || true; wait "$TEST_HOLDER" 2>/dev/null || true; fi
}

setup_file() {
  export ENSEMBLE_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
}

@test "git-discipline resolves and guards authoring without calling coordination plugins" {
  local fakebin="$BATS_TEST_TMPDIR/absent-peers"
  mkdir -p "$fakebin"
  for peer in dibs bonsai; do
    printf '#!/bin/sh\necho unexpected-peer-call >&2\nexit 99\n' > "$fakebin/$peer"
    chmod +x "$fakebin/$peer"
  done
  git -C "$TEST_REPO" switch -q -c exercise-timing
  run env PATH="$fakebin:$PATH" bash -c "cd '$TEST_REPO' && '$GIT_DISCIPLINE' branch-policy && '$GIT_DISCIPLINE' guard-commit"
  [ "$status" -eq 0 ]
  [[ "$output" == *"policy=feature"* ]]
  [[ "$output" != *"unexpected-peer-call"* ]]
}

@test "occupied canonical checkout can use a Git worktree without Bonsai" {
  local dibs="$ENSEMBLE_ROOT/packages/dibs/bin/dibs"
  local hook="$ENSEMBLE_ROOT/packages/dibs/hooks/occupancy.sh"
  local linked="$BATS_TEST_TMPDIR/parallel-work"
  tail -f /dev/null >/dev/null 2>&1 & local holder=$!; TEST_HOLDER=$holder
  node "$dibs" claim "$TEST_REPO" --pid "$holder" --agent other --session other --description 'other feature' >/dev/null
  local payload=$(jq -nc --arg root "$TEST_REPO" '{hook_event_name:"PreToolUse",tool_name:"Write",session_id:"current",cwd:$root,tool_input:{file_path:($root+"/phrase.txt"),content:"x"}}')
  run env DIBS_BIN="$dibs" DIBS_HOLDER_PID=$$ DIBS_DESCRIPTION='parallel feature' bash "$hook" <<< "$payload"
  local refusal=$status
  local refusal_output="$output"
  git -C "$TEST_REPO" worktree add -q -b parallel-feature "$linked"
  run bash -c "cd '$linked' && '$GIT_DISCIPLINE' branch-policy && '$GIT_DISCIPLINE' guard-commit"
  local guard_status=$status
  local plan_output="$output"
  payload=$(jq -nc --arg root "$linked" '{hook_event_name:"PreToolUse",tool_name:"Write",session_id:"parallel",cwd:$root,tool_input:{file_path:($root+"/phrase.txt"),content:"x"}}')
  run env DIBS_BIN="$dibs" DIBS_HOLDER_PID=$$ DIBS_DESCRIPTION='parallel feature' bash "$hook" <<< "$payload"
  local linked_status=$status
  kill "$holder"
  [ "$refusal" -eq 2 ]
  [ "$guard_status" -eq 0 ]
  [ "$linked_status" -eq 0 ]
  [[ "$refusal_output" == *"occupies this directory"* ]]
  [[ "$plan_output" == *"authoring_branch=parallel-feature"* ]]
}

@test "Bonsai creates a feature worktree with no Dibs module" {
  run env DIBS_LIB=/nonexistent/dibs-lib.mjs node "$ENSEMBLE_ROOT/packages/bonsai/bin/bonsai" create independent-feature --repo "$TEST_REPO" --json
  [ "$status" -eq 0 ]
  [[ "$output" == *"unavailable"* ]]
  run bash -c "cd '$TEST_REPO/worktrees/independent-feature' && '$GIT_DISCIPLINE' guard-commit"
  [ "$status" -eq 0 ]
}

@test "worktree mode does not change the repository publication regime" {
  git -C "$TEST_REPO" config codingAgent.git.branchPolicy worktree
  run "$ENSEMBLE_ROOT/packages/git-discipline/skills/push-policy/git-repo-policy" "$TEST_REPO"
  [ "$status" -eq 0 ]
  [[ "$output" == *"mode=local-only"* ]]
}

@test "Dibs permits merge completion but keeps primary edits and other owners blocked" {
  local hook="$ENSEMBLE_ROOT/packages/dibs/hooks/occupancy.sh"
  local dibs="$ENSEMBLE_ROOT/packages/dibs/bin/dibs"
  git -C "$TEST_REPO" switch -q -c candidate
  commit_on_current_branch "$TEST_REPO" candidate 'Candidate change'
  git -C "$TEST_REPO" switch -q main
  git -C "$TEST_REPO" merge -q --no-commit --no-ff candidate
  git -C "$TEST_REPO" config codingAgent.git.branchPolicy worktree
  local payload=$(jq -nc --arg root "$TEST_REPO" '{hook_event_name:"PreToolUse",tool_name:"Bash",session_id:"integration",cwd:$root,tool_input:{command:"git commit -m merge"}}')
  run env DIBS_BIN="$dibs" DIBS_HOLDER_PID=$$ DIBS_DESCRIPTION='complete integration' bash "$hook" <<< "$payload"
  [ "$status" -eq 0 ]
  payload=$(jq -nc --arg root "$TEST_REPO" '{hook_event_name:"PreToolUse",tool_name:"Bash",session_id:"integration",cwd:$root,tool_input:{command:"touch unauthorized.txt && git commit -m merge"}}')
  run env DIBS_BIN="$dibs" DIBS_HOLDER_PID=$$ DIBS_DESCRIPTION='complete integration' bash "$hook" <<< "$payload"
  [ "$status" -eq 2 ]
  [[ "$output" == *"worktree-required"* ]]
  node "$dibs" release "$TEST_REPO" --pid $$ >/dev/null
  tail -f /dev/null >/dev/null 2>&1 & local holder=$!; TEST_HOLDER=$holder
  node "$dibs" claim "$TEST_REPO" --pid "$holder" --agent other --session other --description 'other integration' >/dev/null
  payload=$(jq -nc --arg root "$TEST_REPO" '{hook_event_name:"PreToolUse",tool_name:"Bash",session_id:"integration",cwd:$root,tool_input:{command:"git commit -m merge"}}')
  run env DIBS_BIN="$dibs" DIBS_HOLDER_PID=$$ DIBS_DESCRIPTION='complete integration' bash "$hook" <<< "$payload"
  local refusal=$status
  kill "$holder"
  [ "$refusal" -eq 2 ]
  [[ "$output" == *"occupies this directory"* ]]
}

@test "a worktree-only repository can bootstrap its first commit with both guards" {
  local unborn="$BATS_TEST_TMPDIR/bootstrap"
  git init -q -b main "$unborn"
  git -C "$unborn" config codingAgent.git.branchPolicy worktree
  run bash -c "cd '$unborn' && '$GIT_DISCIPLINE' guard-commit"
  [ "$status" -eq 0 ]
  local payload=$(jq -nc --arg root "$unborn" '{hook_event_name:"PreToolUse",tool_name:"Bash",session_id:"bootstrap",cwd:$root,tool_input:{command:"git commit -m initial"}}')
  run env DIBS_BIN="$ENSEMBLE_ROOT/packages/dibs/bin/dibs" DIBS_HOLDER_PID=$$ DIBS_DESCRIPTION='initialize repository' bash "$ENSEMBLE_ROOT/packages/dibs/hooks/occupancy.sh" <<< "$payload"
  [ "$status" -eq 0 ]
  git -C "$unborn" config user.name Test
  git -C "$unborn" config user.email test@example.invalid
  git -C "$unborn" commit -q --allow-empty -m Initial
  git -C "$unborn" rev-parse --verify HEAD >/dev/null
  git -C "$unborn" config --local init.defaultBranch main
  local linked="$BATS_TEST_TMPDIR/bootstrap-feature"
  payload=$(jq -nc --arg root "$unborn" --arg target "$linked" '{hook_event_name:"PreToolUse",tool_name:"Bash",session_id:"bootstrap",cwd:$root,tool_input:{command:("git worktree add -b first-feature " + $target)}}')
  run env DIBS_BIN="$ENSEMBLE_ROOT/packages/dibs/bin/dibs" DIBS_HOLDER_PID=$$ DIBS_DESCRIPTION='create first feature' bash "$ENSEMBLE_ROOT/packages/dibs/hooks/occupancy.sh" <<< "$payload"
  [ "$status" -eq 0 ]
  git -C "$unborn" worktree add -q -b first-feature "$linked"
  mkdir -p "$unborn/.git/hooks"
  printf '#!/bin/sh\nexec "%s" guard-commit\n' "$GIT_DISCIPLINE" > "$unborn/.git/hooks/pre-commit"
  chmod +x "$unborn/.git/hooks/pre-commit"
  git -C "$linked" config core.hooksPath "$unborn/.git/hooks"
  git -C "$linked" commit -q --allow-empty -m 'First feature'
}

@test "a standalone Bonsai package creates a worktree without peer installations" {
  local isolated="$BATS_TEST_TMPDIR/bonsai-only"
  cp -R "$ENSEMBLE_ROOT/packages/bonsai" "$isolated"
  run env -u DIBS_LIB HOME="$BATS_TEST_TMPDIR/home" node "$isolated/bin/bonsai" create standalone-feature --repo "$TEST_REPO" --json
  [ "$status" -eq 0 ]
  [[ "$output" == *"unavailable"* ]]
  [ -d "$TEST_REPO/worktrees/standalone-feature" ]
}

@test "Dibs permits creation of a new feature worktree from an occupied worktree-only primary" {
  local linked="$TEST_REPO/worktrees/parallel-feature"
  mkdir -p "$TEST_REPO/worktrees"
  printf "*\n" > "$TEST_REPO/worktrees/.gitignore"
  local dibs="$ENSEMBLE_ROOT/packages/dibs/bin/dibs"
  local hook="$ENSEMBLE_ROOT/packages/dibs/hooks/occupancy.sh"
  git -C "$TEST_REPO" config codingAgent.git.branchPolicy worktree
  tail -f /dev/null >/dev/null 2>&1 & local holder=$!; TEST_HOLDER=$holder
  node "$dibs" claim "$TEST_REPO" --pid "$holder" --agent other --session other --description 'other integration' >/dev/null
  local payload=$(jq -nc --arg root "$TEST_REPO" --arg target "$linked" '{hook_event_name:"PreToolUse",tool_name:"Bash",session_id:"parallel",cwd:$root,tool_input:{command:("git worktree add -b parallel-feature " + $target)}}')
  run env DIBS_BIN="$dibs" DIBS_HOLDER_PID=$$ DIBS_DESCRIPTION='create parallel feature' bash "$hook" <<< "$payload"
  local creation_status=$status
  kill "$holder"
  [ "$creation_status" -eq 0 ]
  git -C "$TEST_REPO" worktree add -q -b parallel-feature "$linked"
  run bash -c "cd '$linked' && '$GIT_DISCIPLINE' guard-commit"
  [ "$status" -eq 0 ]
}

@test "a conflicted canonical merge can abort without permitting ordinary authoring" {
  local dibs="$ENSEMBLE_ROOT/packages/dibs/bin/dibs"
  local hook="$ENSEMBLE_ROOT/packages/dibs/hooks/occupancy.sh"
  git -C "$TEST_REPO" switch -q -c conflicting-feature
  printf 'feature\n' > "$TEST_REPO/file.txt"
  git -C "$TEST_REPO" commit -qam 'Feature conflict'
  git -C "$TEST_REPO" switch -q main
  printf 'default\n' > "$TEST_REPO/file.txt"
  git -C "$TEST_REPO" commit -qam 'Default conflict'
  git -C "$TEST_REPO" merge --no-commit conflicting-feature >/dev/null 2>&1 || true
  git -C "$TEST_REPO" config codingAgent.git.branchPolicy worktree
  local payload=$(jq -nc --arg root "$TEST_REPO" '{hook_event_name:"PreToolUse",tool_name:"Bash",session_id:"abort",cwd:$root,tool_input:{command:"git merge --abort"}}')
  run env DIBS_BIN="$dibs" DIBS_HOLDER_PID=$$ DIBS_DESCRIPTION='abort conflicted integration' bash "$hook" <<< "$payload"
  [ "$status" -eq 0 ]
  payload=$(jq -nc --arg root "$TEST_REPO" '{hook_event_name:"PreToolUse",tool_name:"Bash",session_id:"abort",cwd:$root,tool_input:{command:"git add file.txt"}}')
  run env DIBS_BIN="$dibs" DIBS_HOLDER_PID=$$ DIBS_DESCRIPTION='ordinary authoring' bash "$hook" <<< "$payload"
  [ "$status" -eq 2 ]
  [[ "$output" == *"worktree-required"* ]]
  git -C "$TEST_REPO" merge --abort
  [ "$(cat "$TEST_REPO/file.txt")" = default ]
}

@test "worktree creation cannot bypass another checkout or forcibly reset an occupied branch" {
  local other="$BATS_TEST_TMPDIR/other-checkout"
  git init -q "$other"
  local dibs="$ENSEMBLE_ROOT/packages/dibs/bin/dibs"
  local hook="$ENSEMBLE_ROOT/packages/dibs/hooks/occupancy.sh"
  tail -f /dev/null >/dev/null 2>&1 & local holder=$!; TEST_HOLDER=$holder
  node "$dibs" claim "$other" --pid "$holder" --agent other --session other --description 'other authoring' >/dev/null
  local payload=$(jq -nc --arg root "$TEST_REPO" --arg target "$other/nested" '{hook_event_name:"PreToolUse",tool_name:"Bash",session_id:"create",cwd:$root,tool_input:{command:("git worktree add -b innocent " + $target)}}')
  run env DIBS_BIN="$dibs" DIBS_HOLDER_PID=$$ DIBS_DESCRIPTION='create feature' bash "$hook" <<< "$payload"
  [ "$status" -eq 2 ]
  [[ "$output" == *"occupies this directory"* ]]
  git -C "$TEST_REPO" config codingAgent.git.branchPolicy worktree
  mkdir -p "$TEST_REPO/worktrees"
  printf '*\n' > "$TEST_REPO/worktrees/.gitignore"
  payload=$(jq -nc --arg root "$TEST_REPO" '{hook_event_name:"PreToolUse",tool_name:"Bash",session_id:"create",cwd:$root,tool_input:{command:"git worktree add -f -B main worktrees/forced"}}')
  run env DIBS_BIN="$dibs" DIBS_HOLDER_PID=$$ DIBS_DESCRIPTION='forced feature' bash "$hook" <<< "$payload"
  [ "$status" -eq 2 ]
}

@test "atomic local merge respects a live Dibs holder of the clean default checkout" {
  create_feature_worktree_commit
  local dibs="$ENSEMBLE_ROOT/packages/dibs/bin/dibs"
  local base=$(git -C "$TEST_REPO" rev-parse main)
  run bash -c "cd '$FEATURE_WORKTREE' && '$GIT_DISCIPLINE' verify --local -- true"
  [ "$status" -eq 0 ]
  tail -f /dev/null >/dev/null 2>&1 & local holder=$!; TEST_HOLDER=$holder
  node "$dibs" claim "$TEST_REPO" --pid "$holder" --agent other --session other --description 'other default checkout work' >/dev/null
  run env DIBS_BIN="$dibs" DIBS_HOLDER_PID=$$ DIBS_SESSION=merger bash -c "cd '$FEATURE_WORKTREE' && '$GIT_DISCIPLINE' merge --local"
  local merge_status=$status merge_output="$output"
  kill "$holder"
  [ "$merge_status" -ne 0 ]
  [[ "$merge_output" == *"occupied"* ]]
  [ "$(git -C "$TEST_REPO" rev-parse main)" = "$base" ]
  [ "$(git -C "$TEST_REPO" status --porcelain)" = '' ]
  run env DIBS_BIN="$dibs" DIBS_HOLDER_PID=$$ DIBS_SESSION=merger bash -c "cd '$FEATURE_WORKTREE' && '$GIT_DISCIPLINE' merge --local"
  [ "$status" -eq 0 ]
}

@test "forced worktree creation checks the occupied checkout of its branch" {
  local dibs="$ENSEMBLE_ROOT/packages/dibs/bin/dibs"
  local hook="$ENSEMBLE_ROOT/packages/dibs/hooks/occupancy.sh"
  local linked="$BATS_TEST_TMPDIR/occupied-feature"
  git -C "$TEST_REPO" worktree add -q -b occupied-feature "$linked"
  tail -f /dev/null >/dev/null 2>&1 & local holder=$!; TEST_HOLDER=$holder
  node "$dibs" claim "$linked" --pid "$holder" --agent other --session other --description 'active feature' >/dev/null
  for command in 'git worktree add -f worktrees/duplicate occupied-feature' 'git worktree add -f -B occupied-feature worktrees/reset'; do
    local payload=$(jq -nc --arg root "$TEST_REPO" --arg command "$command" '{hook_event_name:"PreToolUse",tool_name:"Bash",session_id:"create",cwd:$root,tool_input:{command:$command}}')
    run env DIBS_BIN="$dibs" DIBS_HOLDER_PID=$$ DIBS_DESCRIPTION='forced feature' bash "$hook" <<< "$payload"
    [ "$status" -eq 2 ]
    [[ "$output" == *"occupies this directory"* ]]
  done
}

@test "atomic merge reuses the merging session's existing default checkout claim" {
  create_feature_worktree_commit
  local dibs="$ENSEMBLE_ROOT/packages/dibs/bin/dibs"
  run bash -c "cd '$FEATURE_WORKTREE' && '$GIT_DISCIPLINE' verify --local -- true"
  [ "$status" -eq 0 ]
  tail -f /dev/null >/dev/null 2>&1 & local holder=$!; TEST_HOLDER=$holder
  node "$dibs" claim "$TEST_REPO" --pid "$holder" --agent codex --session merger --owner merger --description 'current integration' >/dev/null
  run node "$dibs" check "$TEST_REPO" --json
  [ "$status" -eq 0 ]
  [[ "$output" == *'"held"'* ]]
  [[ "$output" == *'"alive": true'* ]]
  local base=$(git -C "$TEST_REPO" rev-parse main)
  run env DIBS_BIN="$dibs" DIBS_SESSION=merger DIBS_AGENT=codex DIBS_OWNER=merger bash -c "cd '$FEATURE_WORKTREE' && '$GIT_DISCIPLINE' merge --local"
  [ "$status" -eq 0 ]
  [ "$(git -C "$TEST_REPO" rev-parse main)" != "$base" ]
}
