#!/usr/bin/env bats

DISPATCH="$BATS_TEST_DIRNAME/../hooks/dispatch.sh"

setup() {
  export LAICLUSE_HOME="$BATS_TEST_TMPDIR/laicluse"
}

stop_with() {
  local payload
  payload=$(jq -cn --arg msg "$1" '{hook_event_name:"Stop", session_id:"copyable-table-bats", stop_hook_active:false, last_assistant_message:$msg}')
  run bash -c 'printf "%s" "$1" | DD_AGENT=claude DD_ONLY_STOP_GUARDS=copyable-table bash "$2"' _ "$payload" "$DISPATCH"
}

@test "a subscription URL inside a table row blocks" {
  stop_with $'| Calendar | URL |\n|---|---|\n| Holidays | `webcal://calendar.example.com/feeds/team-holidays.ics` |\n\n🏁'
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dont-do-that/copyable-table]"* ]]
  [[ "$output" == *"own fenced code block"* ]]
}

@test "a long inline-code value inside a table row blocks" {
  stop_with $'| Item | Value |\n|---|---|\n| token | `0123456789abcdef0123456789abcdef01234567` |'
  [[ "$output" == *"[dont-do-that/copyable-table]"* ]]
}

@test "the same URL in its own code block passes" {
  stop_with $'Holidays:\n```\nwebcal://calendar.example.com/feeds/team-holidays.ics\n```\n\n🏁'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "a table of short identifiers passes" {
  stop_with $'| Sender | Count |\n|---|---|\n| `office@example.org` | 7 |\n| `owner/repo@1a2b3c4` | 1 |'
  [ -z "$output" ]
}

@test "a table inside a fenced block is example text and passes" {
  stop_with $'```\n| a | https://example.com/long/path |\n```'
  [ -z "$output" ]
}

@test "a table without outer pipes is still a table" {
  stop_with $'Calendar | URL\n--- | ---\nHolidays | https://calendar.example.com/feeds/team-holidays.ics'
  [[ "$output" == *"[dont-do-that/copyable-table]"* ]]
}

@test "a lone line starting with a pipe is not a table" {
  stop_with $'| see https://example.com/a/long/path for details'
  [ -z "$output" ]
}

@test "a table inside a tilde fence passes" {
  stop_with $'~~~\n| a | b |\n|---|---|\n| x | https://example.com/long/path |\n~~~'
  [ -z "$output" ]
}

@test "three backticks inside a four-backtick fence do not close it" {
  stop_with $'````\n```\n| a | b |\n|---|---|\n| x | https://example.com/long/path |\n````'
  [ -z "$output" ]
}

@test "a table row without a pipe still belongs to the table" {
  stop_with $'| URL |\n|---|\nhttps://example.com/calendar.ics'
  [[ "$output" == *"[dont-do-that/copyable-table]"* ]]
}

@test "an uppercase URL scheme is still a URL" {
  stop_with $'| a | b |\n|---|---|\n| x | HTTPS://EXAMPLE.COM/calendar.ics |'
  [[ "$output" == *"[dont-do-that/copyable-table]"* ]]
}

@test "an indented table example is a code block and passes" {
  stop_with $'    | a | b |\n    |---|---|\n    | x | https://example.com/long/path |'
  [ -z "$output" ]
}

@test "a heading after a table ends the table" {
  stop_with $'| a | b |\n|---|---|\n| x | y |\n# See | https://example.com/long/path'
  [ -z "$output" ]
}

@test "a horizontal rule after a table ends the table" {
  stop_with $'| a | b |\n|---|---|\n| x | y |\n---\nSee https://example.com/long/path'
  [ -z "$output" ]
}

@test "an issue number at the start of a row keeps the row in the table" {
  stop_with $'Issue | Link\n--- | ---\n#123 | https://example.com/issues/123'
  [[ "$output" == *"[dont-do-that/copyable-table]"* ]]
}
