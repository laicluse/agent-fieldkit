#!/usr/bin/env bats

setup() {
  DISPATCH="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../hooks" && pwd)/dispatch.sh"
  export LAICLUSE_HOME="$BATS_TEST_TMPDIR/state"
  export GIT_DISCIPLINE_SHADOW_LOG="$BATS_TEST_TMPDIR/shadow.log"
  export GIT_CONFIG_NOSYSTEM=1
  export GIT_CONFIG_GLOBAL=/dev/null
  PARENT="$BATS_TEST_TMPDIR/collection"
  TARGET="$PARENT/experiment"
  mkdir -p "$TARGET"
  git init -q -b main "$TARGET"
  TARGET="$(cd "$TARGET" && pwd -P)"
  cd "$TARGET"
  git config user.name "Example Author"
  git config user.email "author@example.test"
  git config core.hooksPath "$BATS_TEST_TMPDIR/empty-hooks"
  printf 'baseline\n' > note.md
  git add note.md
  git commit -q -m 'Record baseline'
  printf 'updated\n' > note.md
  git add note.md
  cd "$PARENT"
}

assert_rotation() {
  local input="$1" state_file
  run bash "$DISPATCH" <<< "$input"
  [ "$status" -eq 2 ]
  [[ "$output" == *"Rule 4/15"* ]]
  run bash "$DISPATCH" <<< "$input"
  [ "$status" -eq 0 ]
  state_file=$(
    cd "$TARGET"
    source "$(dirname "$DISPATCH")/lib/common.sh"
    source "$(dirname "$DISPATCH")/guards/commit-subject.sh"
    _dd_resolve_commit_subject_state_file "$input"
  )
  grep -q '^rp=0$' "$state_file"
  (cd "$TARGET" && git commit -q -m 'Compare values')
  run bash "$DISPATCH" <<< "$(jq '.hook_event_name="PostToolUse"' <<< "$input")"
  [ "$status" -eq 0 ]
  grep -q '^rp=1$' "$state_file"
}

@test "deny ack and post-tool advancement use the same child workdir" {
  local command='git commit -m "Compare values" # ack-rule4:essentie'
  assert_rotation "$(jq -cn --arg target "$TARGET" --arg command "$command" '{hook_event_name:"PreToolUse",tool_name:"Bash",session_id:"workdir-test",tool_input:{command:$command,workdir:$target}}')"
}

@test "Claude cwd-only payloads advance the child repository state" {
  local command='git commit -m "Compare values" # ack-rule4:essentie'
  assert_rotation "$(jq -cn --arg target "$TARGET" --arg command "$command" '{cwd:$target,hook_event_name:"PreToolUse",tool_name:"Bash",session_id:"cwd-test",tool_input:{command:$command}}')"
}
