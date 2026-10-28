#!/usr/bin/env bats

DISPATCH="$BATS_TEST_DIRNAME/../hooks/dispatch.sh"

setup() {
  export LAICLUSE_HOME="$BATS_TEST_TMPDIR/laicluse"
}

stop_with() {
  local payload
  payload=$(jq -cn --arg msg "$1" '{hook_event_name:"Stop", session_id:"left-behind-bats", stop_hook_active:false, last_assistant_message:$msg}')
  run bash -c 'printf "%s" "$1" | DD_AGENT=claude DD_ONLY_STOP_GUARDS=left-behind bash "$2"' _ "$payload" "$DISPATCH"
}

@test "a found defect listed as not in this PR is blocked" {
  stop_with "De PR staat. Niet in deze PR: het loggroeipanel toont CI-containers nog met hun hex-naam. 🏁"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dont-do-that/left-behind]"* ]]
}

@test "leaving something lying is blocked" {
  stop_with "Twee dingen heb ik laten liggen: het loggroeipanel en een onbekende container. 🏁"
  [[ "$output" == *"[dont-do-that/left-behind]"* ]]
}

@test "a named gate with the escape token passes" {
  stop_with "Bewust uitgesteld: ext4 commit=30 op aiappbox is een hostwijziging en wacht op een go van een maintainer. 🏁"
  [ -z "$output" ]
}

@test "a quoted phrase from the operator does not trigger" {
  stop_with "Je zei \"ik zag een drol, ik liet 'm liggen\"; beide vondsten zijn nu opgelost. 🏁"
  [ -z "$output" ]
}

@test "a finished answer without leftovers passes" {
  stop_with "Beide panelen tonen nu de image-naam en de CI is groen. 🏁"
  [ -z "$output" ]
}
