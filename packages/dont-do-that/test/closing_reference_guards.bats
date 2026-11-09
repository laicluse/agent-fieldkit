#!/usr/bin/env bats

DISPATCH="$BATS_TEST_DIRNAME/../hooks/dispatch.sh"

setup() {
  export LAICLUSE_HOME="$BATS_TEST_TMPDIR/laicluse"
}

stop_as() {
  local agent="$1" guard="$2" message="$3" payload
  payload=$(jq -cn --arg msg "$message" '{hook_event_name:"Stop", session_id:"closing-bats", stop_hook_active:false, last_assistant_message:$msg}')
  run bash -c 'printf "%s" "$1" | DD_AGENT="$2" DD_ONLY_STOP_GUARDS="$3" bash "$4"' _ "$payload" "$agent" "$guard" "$DISPATCH"
}

@test "a reference to a point the message does not describe is blocked in Claude and Codex" {
  for agent in claude codex; do
    stop_as "$agent" dangling-reference "De meldingsfix staat klaar. Voor punt 4 uit mijn vorige antwoord wacht ik nog. 🏁 Klaar."
    [ "$status" -eq 0 ]
    [[ "$output" == *"[dont-do-that/dangling-reference]"* ]]
    [[ "$output" == *"punt 4"* ]]
  done
}

@test "a range and an enumeration of undescribed points are blocked" {
  stop_as claude dangling-reference "De punten 2 tot en met 4 staan nog open."
  [[ "$output" == *"punten 2 tot en met 4"* ]]
  stop_as claude dangling-reference "Zie punten 1, 2 en 4.
1. Alleen de eerste staat hier."
  [[ "$output" == *"punten 1, 2 en 4"* ]]
}

@test "points described in the same message pass, also when the list is far above" {
  local filler
  filler=$(printf 'Toelichting zonder verwijzingen. %.0s' $(seq 1 80))
  stop_as claude dangling-reference "Twee dingen staan open:
1. De kern ontbreekt bij een halve installatie.
3. De filterlijst kan uit de pas lopen met de kern.
$filler
Points 1 and 3 are fixed now. 🏁 Committed."
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "quoted text, inline code, versions and step explanations are not references" {
  stop_as claude dangling-reference "Het label \"point 2\" en \`items 7\` blijven staan, versie punt 2.4 ook. In stap 1 wordt de invoer gevalideerd."
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "a go request to repair something inside the assignment is blocked in Claude and Codex" {
  for agent in claude codex; do
    stop_as "$agent" repair-gate "De twee lekken zijn beschreven. 🚦 I need your go to repair the parser before the PR."
    [ "$status" -eq 0 ]
    [[ "$output" == *"[dont-do-that/repair-gate]"* ]]
  done
  stop_as claude repair-gate "Beschreven.
🚦
Ik heb je go nodig om de parser te herstellen."
  [[ "$output" == *"[dont-do-that/repair-gate]"* ]]
}

@test "gates for push, publishing, spending or an operator choice still pass" {
  stop_as claude repair-gate "Klaar. 🚦 Ik heb je go nodig om de fix naar de remote branch te pushen."
  [ -z "$output" ]
  stop_as claude repair-gate "Klaar. 🚦 Kies de correcte factuurdatum voordat ik deze boeking publiceer."
  [ -z "$output" ]
  stop_as claude repair-gate "Klaar. 🚦 Ik heb je toestemming voor modelgebruik nodig voor een peer review van de fix."
  [ -z "$output" ]
}

@test "a multi-digit version number is not read as a shorter point" {
  stop_as claude dangling-reference "De documentatie beschrijft punt 12.4."
  [ -z "$output" ]
}

@test "a numbered line inside a tilde fence does not count as a described point" {
  stop_as claude dangling-reference "Voorbeeld:
~~~text
4. example
~~~
Zie punt 4."
  [[ "$output" == *"[dont-do-that/dangling-reference]"* ]]
}

@test "a long range needs every point described, not only its ends" {
  stop_as claude dangling-reference "1. Eerste.
22. Laatste.
Zie punten 1-22."
  [[ "$output" == *"[dont-do-that/dangling-reference]"* ]]
}

@test "a product choice about a repair is not a go request" {
  stop_as claude repair-gate "Beschreven. 🚦 Voor deze repair moet je kiezen: factuurregels verwijderen of de geboekte bedragen behouden."
  [ -z "$output" ]
}
