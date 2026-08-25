#!/usr/bin/env bats

DISPATCH="$BATS_TEST_DIRNAME/../hooks/dispatch.sh"

edit_payload() {
  jq -cn --arg path "$1" --arg old "$2" --arg new "$3" \
    '{hook_event_name:"PostToolUse", tool_name:"Edit", tool_input:{file_path:$path, old_string:$old, new_string:$new}}'
}

run_guard() {
  run bash -c 'printf "%s" "$1" | DD_AGENT=claude bash "$2"' _ "$1" "$DISPATCH"
}

@test "adding lines to a SKILL.md asks for a reread of the surrounding section" {
  run_guard "$(edit_payload /repo/skills/foo/SKILL.md "one" "one
two
three")"

  [[ "$output" == *"reread"* ]]
  [[ "$output" == *"contradict"* ]]
}

@test "the operator instruction sources count as instruction artefacts" {
  for path in /repo/CLAUDE.md /repo/AGENTS.md /home/me/.laicluse/circus/shared/20-gates.md; do
    run_guard "$(edit_payload "$path" "one" "one
two")"
    [[ "$output" == *"reread"* ]]
  done
}

@test "code files never trigger the reread nudge" {
  run_guard "$(edit_payload /repo/lib/cascade.mjs "one" "one
two
three")"

  [[ "$output" != *"reread"* ]]
}

@test "a removal is not an addition, so it stays silent" {
  run_guard "$(edit_payload /repo/skills/foo/SKILL.md "one
two
three" "one")"

  [[ "$output" != *"reread"* ]]
}

@test "a same-size rewording stays silent" {
  run_guard "$(edit_payload /repo/skills/foo/SKILL.md "one
two" "een
twee")"

  [[ "$output" != *"reread"* ]]
}
