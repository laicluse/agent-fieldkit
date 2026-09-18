#!/usr/bin/env bats

DISPATCH="$BATS_TEST_DIRNAME/../hooks/dispatch.sh"

setup() {
  export LAICLUSE_HOME="$BATS_TEST_TMPDIR/laicluse"
}

stop_with() {
  local payload
  payload=$(jq -cn --arg msg "$1" '{hook_event_name:"Stop", session_id:"premature-bats", stop_hook_active:false, last_assistant_message:$msg}')
  run bash -c 'printf "%s" "$1" | DD_AGENT=claude DD_ONLY_STOP_GUARDS=premature bash "$2"' _ "$payload" "$DISPATCH"
}

@test "the closing nudge treats committed work as done, pushed or not" {
  stop_with "Ik heb de guard aangepast en de tests draaien groen."
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dont-do-that/premature]"* ]]
  [[ "$output" == *"committed work is done, pushed or not"* ]]
  [[ "$output" == *"A push or merge nobody ordered is not a 🚦"* ]]
  [[ "$output" != *"including unpushed commits"* ]]
}

@test "a finished turn with unpushed commits closes with the finish flag" {
  stop_with "De guard staat gecommit op de lokale default branch en de suite is groen. 🏁"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
