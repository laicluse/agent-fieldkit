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

stop_with_extra() {
  local payload
  payload=$(jq -cn --arg msg "$1" --argjson extra "$2" '{hook_event_name:"Stop", session_id:"premature-bats", stop_hook_active:false, last_assistant_message:$msg} + $extra')
  run bash -c 'printf "%s" "$1" | DD_AGENT=claude DD_ONLY_STOP_GUARDS=premature bash "$2"' _ "$payload" "$DISPATCH"
}

@test "a turn waiting on running background work is not a premature stop" {
  stop_with_extra "Vijf agents analyseren de projecten; daarna bundel ik de uitkomst." \
    '{"background_tasks":[{"id":"a1","type":"subagent","status":"running","description":"Analyze projects"}],"session_crons":[]}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "a turn waiting on a one-shot wake-up is not a premature stop" {
  stop_with_extra "Ronde 4 is gelogd; de volgende ronde start bij de geplande wake-up." \
    '{"background_tasks":[],"session_crons":[{"id":"c1","schedule":"5 14 4 10 *","recurring":false,"prompt":"resume run"}]}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "a recurring cron alone does not excuse an unmarked stop" {
  stop_with_extra "Ik heb de guard aangepast en de tests draaien groen." \
    '{"background_tasks":[],"session_crons":[{"id":"c2","schedule":"*/10 * * * *","recurring":true,"prompt":"poll"}]}'
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dont-do-that/premature]"* ]]
}

@test "a quoted question inside a finished turn is not a question to the operator" {
  stop_with "De controle die daarna gebouwd is (\"gebruikt de test echt het filter?\") is algemeen bruikbaar en staat nu in het protocol. 🏁 Drie regels zijn klaar."
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "a question mark in inline code or a URL is not a question" {
  stop_with "De route \`/search?q=stoel\` en https://example.com/a?b=1 zijn gecontroleerd en de suite is groen. 🏁 Klaar."
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "a real trailing question still contradicts the finish flag" {
  stop_with "De guard is aangepast en gecommit. 🏁 Zal ik hem ook pushen?"
  [ "$status" -eq 0 ]
  [[ "$output" == *"contradictory"* ]]
}
