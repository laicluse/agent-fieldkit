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

@test "a decision that belongs to someone else is not a gate" {
  stop_with "Bewust uitgesteld: de kleurkeuze. Dat besluit is van de productowner. 🏁"
  [[ "$output" == *"[dont-do-that/left-behind]"* ]]
  [[ "$output" == *"recommendation"* ]]
}

@test "a choice someone else has to make is not a gate" {
  stop_with "Bewust uitgesteld: de retentie van de auditregistratie, daarover moet de eigenaar nog beslissen. 🏁"
  [[ "$output" == *"[dont-do-that/left-behind]"* ]]
}

@test "a choice put to the operator passes" {
  stop_with "Bewust uitgesteld: de keuze is aan jou. Ik raad aan de kolom te laten staan, want verwijderen wint niets. 🏁"
  [ -z "$output" ]
}

@test "a decision named on the line after the deferral is not a gate either" {
  stop_with "$(printf 'Bewust uitgesteld: de kleurkeuze.\nDat besluit is van de productowner. 🏁')"
  [[ "$output" == *"[dont-do-that/left-behind]"* ]]
}

@test "a go the operator still has to give passes" {
  stop_with "Bewust uitgesteld: de hostwijziging wacht op expliciete toestemming; je moet nog beslissen of die nu mag. 🏁"
  [ -z "$output" ]
}

@test "a deferral in another paragraph does not excuse a third-party decision elsewhere" {
  stop_with "$(printf 'Bewust uitgesteld: de hostwijziging wacht op een go.\n\nDe indeling is klaar en de keuze is aan jou. 🏁')"
  [ -z "$output" ]
}

@test "a sentence to the operator does not excuse a third-party decision beside it" {
  stop_with "Bewust uitgesteld: de kleurkeuze. Dat besluit is van de productowner. Wil je dat ik het hem vraag? 🏁"
  [[ "$output" == *"[dont-do-that/left-behind]"* ]]
}

@test "a settled decision before the deferral does not count" {
  stop_with "De keuze is van de productowner en is al verwerkt. Bewust uitgesteld: de hostwijziging wacht op expliciete toestemming. 🏁"
  [ -z "$output" ]
}

@test "a form of address elsewhere in the sentence does not excuse a third-party decision" {
  stop_with "Bewust uitgesteld: de productowner moet nog beslissen over je voorstel. 🏁"
  [[ "$output" == *"[dont-do-that/left-behind]"* ]]
}

@test "a quoted escape token does not excuse a defect left behind" {
  stop_with "De hook kent de opening \`Bewust uitgesteld:\`. Het loggroeipanel heb ik laten liggen. 🏁"
  [[ "$output" == *"[dont-do-that/left-behind]"* ]]
}

@test "waiting for someone else's decision is not a gate" {
  stop_with "Bewust uitgesteld: ik wacht op het besluit van de productowner. 🏁"
  [[ "$output" == *"[dont-do-that/left-behind]"* ]]
}

@test "a choice laid before the operator by role passes" {
  stop_with "Bewust uitgesteld: de hostwijziging wacht op een go. De keuze is aan de operator; ik raad rollback aan. 🏁"
  [ -z "$output" ]
}

@test "a question about the agent's own next step passes" {
  stop_with "Bewust uitgesteld: de hostwijziging wacht op een go. Moet ik de huidige configuratie laten staan of voor rollback kiezen? 🏁"
  [ -z "$output" ]
}
