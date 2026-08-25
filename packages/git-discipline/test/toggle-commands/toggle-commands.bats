#!/usr/bin/env bats
# packages/git-discipline/test/toggle-commands/toggle-commands.bats
#
# The four sentinel toggle commands run as UserPromptExpansion hooks: the
# operator's own keystroke performs the mutation, the hook blocks the
# expansion, and the skill body never reaches the model. Exit 2 is the block
# signal for this event, so every handled command exits 2 and carries its
# mnemonic in the message.

load helpers

@test "disable-git writes the repo sentinel" {
  run_expansion "git-discipline:disable-git" "maintenance window"

  [ "$status" -eq 2 ]
  [[ "$output" == *"[git-discipline/disable-git]"* ]]
  [ -f "$(repo_sentinel)" ]
}

@test "disable-git records the reason argument" {
  run_expansion "git-discipline:disable-git" "recovery window"

  [ "$status" -eq 2 ]
  [[ "$output" == *"recovery window"* ]]
  grep -qx "reason: recovery window" "$(repo_sentinel)"
}

@test "disable-git stamps the date it locked" {
  run_expansion "git-discipline:disable-git" "recovery window"

  grep -qE "^locked-at: [0-9]{4}-[0-9]{2}-[0-9]{2}$" "$(repo_sentinel)"
}

@test "the sentinel explains itself to whoever opens it" {
  run_expansion "git-discipline:disable-git" "recovery window"

  # A reader who never saw a deny message must learn from the file alone what
  # set it, what it blocks, and whose call lifting it is.
  grep -q "git-discipline" "$(repo_sentinel)"
  grep -q "operator's call" "$(repo_sentinel)"
  grep -q "agent cannot remove it" "$(repo_sentinel)"
}

@test "a denied command tells the agent it cannot lift the lock itself" {
  run_expansion "git-discipline:disable-git" "recovery window"

  local json
  json=$(jq -cn '{hook_event_name:"PreToolUse",tool_name:"Bash",tool_input:{command:"git commit -m x"}}')
  run bash "$DISPATCH" <<< "$json"

  [ "$status" -eq 2 ]
  [[ "$output" == *"cannot lift this yourself"* ]]
  [[ "$output" == *"Ask the operator"* ]]
}

@test "the CLI deny names the plugin and both lift routes" {
  run_expansion "git-discipline:disable-git" "recovery window"

  run bash -c ". '$SCRIPT_DIR/../../hooks/lib/deny-check.sh'; deny_check commit"

  [ "$status" -eq 1 ]
  [[ "$output" == *"git-discipline plugin"* ]]
  [[ "$output" == *"delete"* ]]
}

@test "disable-git trims surrounding whitespace from the reason" {
  run_expansion "git-discipline:disable-git" "   padded reason   "

  [ "$status" -eq 2 ]
  grep -qx "reason: padded reason" "$(repo_sentinel)"
}

@test "disable-git without a reason is refused" {
  run_expansion "git-discipline:disable-git"

  [ "$status" -eq 2 ]
  [[ "$output" == *"reason is required"* ]]
}

@test "disable-git without a reason writes no sentinel" {
  run_expansion "git-discipline:disable-git"

  [ ! -f "$(repo_sentinel)" ]
}

@test "disable-git treats a whitespace-only reason as missing" {
  run_expansion "git-discipline:disable-git" "    "

  [ "$status" -eq 2 ]
  [[ "$output" == *"reason is required"* ]]
  [ ! -f "$(repo_sentinel)" ]
}

@test "a denied git command quotes the reason and the date" {
  run_expansion "git-discipline:disable-git" "recovery window"

  local json
  json=$(jq -cn '{hook_event_name:"PreToolUse",tool_name:"Bash",tool_input:{command:"git commit -m x"}}')
  run bash "$DISPATCH" <<< "$json"

  [ "$status" -eq 2 ]
  [[ "$output" == *"Reason: recovery window (locked "* ]]
}

@test "a legacy sentinel without a reason still denies" {
  : > "$(repo_sentinel)"

  local json
  json=$(jq -cn '{hook_event_name:"PreToolUse",tool_name:"Bash",tool_input:{command:"git commit -m x"}}')
  run bash "$DISPATCH" <<< "$json"

  [ "$status" -eq 2 ]
  [[ "$output" == *"[git-discipline/disable-git]"* ]]
  [[ "$output" != *"Reason:"* ]]
}

@test "an unlabelled reason parses alongside a labelled date" {
  printf 'a reason on the first line\nlocked-at: 2026-01-05\n' > "$(repo_sentinel)"

  local json
  json=$(jq -cn '{hook_event_name:"PreToolUse",tool_name:"Bash",tool_input:{command:"git commit -m x"}}')
  run bash "$DISPATCH" <<< "$json"

  [ "$status" -eq 2 ]
  [[ "$output" == *"Reason: a reason on the first line (locked 2026-01-05)."* ]]
}

@test "a legacy sentinel with only a reason line still quotes it" {
  printf 'old style reason\n' > "$(repo_sentinel)"

  local json
  json=$(jq -cn '{hook_event_name:"PreToolUse",tool_name:"Bash",tool_input:{command:"git commit -m x"}}')
  run bash "$DISPATCH" <<< "$json"

  [ "$status" -eq 2 ]
  [[ "$output" == *"Reason: old style reason."* ]]
}

@test "enable-git names the lock it lifted" {
  run_expansion "git-discipline:disable-git" "recovery window"

  run_expansion "git-discipline:enable-git"

  [ "$status" -eq 2 ]
  [[ "$output" == *"recovery window"* ]]
  [ ! -f "$(repo_sentinel)" ]
}

@test "enable-git removes the repo sentinel" {
  : > "$(repo_sentinel)"

  run_expansion "git-discipline:enable-git"

  [ "$status" -eq 2 ]
  [[ "$output" == *"[git-discipline/enable-git]"* ]]
  [ ! -f "$(repo_sentinel)" ]
}

@test "enable-git reports when no lock was active" {
  run_expansion "git-discipline:enable-git"

  [ "$status" -eq 2 ]
  [[ "$output" == *"No git lock was active"* ]]
}

@test "disable-discipline writes the session sentinel" {
  run_expansion "git-discipline:disable-discipline" "" "sess-a"

  [ "$status" -eq 2 ]
  [[ "$output" == *"[git-discipline/disable-discipline]"* ]]
  [ -f "$(session_sentinel sess-a)" ]
}

@test "enable-discipline removes the session sentinel" {
  mkdir -p "$(dirname "$(session_sentinel sess-b)")"
  : > "$(session_sentinel sess-b)"

  run_expansion "git-discipline:enable-discipline" "" "sess-b"

  [ "$status" -eq 2 ]
  [ ! -f "$(session_sentinel sess-b)" ]
}

@test "enable-discipline reports when the guards are already active" {
  run_expansion "git-discipline:enable-discipline" "" "sess-c"

  [ "$status" -eq 2 ]
  [[ "$output" == *"already active"* ]]
}

@test "enable-discipline flags a still-present global sentinel" {
  local dir="$BATS_TEST_TMPDIR/.laicluse/git-discipline"
  mkdir -p "$dir"
  : > "$dir/git-discipline-disabled-sess-d"
  : > "$dir/git-discipline-disabled-global"

  run_expansion "git-discipline:enable-discipline" "" "sess-d"

  [ "$status" -eq 2 ]
  [[ "$output" == *"GLOBAL"* ]]
}

@test "enable-discipline never removes the global sentinel" {
  local dir="$BATS_TEST_TMPDIR/.laicluse/git-discipline"
  mkdir -p "$dir"
  : > "$dir/git-discipline-disabled-sess-e"
  : > "$dir/git-discipline-disabled-global"

  run_expansion "git-discipline:enable-discipline" "" "sess-e"

  [ -f "$dir/git-discipline-disabled-global" ]
}

@test "a session toggle leaves the repo lock alone" {
  : > "$(repo_sentinel)"

  run_expansion "git-discipline:enable-discipline" "" "sess-f"

  [ -f "$(repo_sentinel)" ]
}

@test "an unrelated command passes through untouched" {
  run_expansion "some-other-plugin:some-skill"

  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "a payload without a command name passes through untouched" {
  local json
  json=$(jq -cn '{hook_event_name:"UserPromptExpansion",session_id:"sess-g"}')
  run bash "$DISPATCH" <<< "$json"

  [ "$status" -eq 0 ]
}

@test "disable-git outside a git repo changes nothing" {
  local outside
  outside=$(mktemp -d)
  cd "$outside"

  run_expansion "git-discipline:disable-git" "some reason"

  [ "$status" -eq 2 ]
  [[ "$output" == *"Not inside a git repository"* ]]
}

@test "a bare command name without the plugin prefix still resolves" {
  run_expansion "disable-git" "bare name"

  [ "$status" -eq 2 ]
  [ -f "$(repo_sentinel)" ]
}
