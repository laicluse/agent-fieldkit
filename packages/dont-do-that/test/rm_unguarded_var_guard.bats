#!/usr/bin/env bats

DISPATCH="$BATS_TEST_DIRNAME/../hooks/dispatch.sh"

run_guard() {
  local payload
  payload=$(jq -cn --arg cmd "$1" '{hook_event_name:"PreToolUse", tool_name:"Bash", cwd:"/tmp", tool_input:{command:$cmd}}')
  run bash -c 'printf "%s" "$1" | DD_AGENT="$3" DD_ONLY_PRETOOLUSE_GUARDS=rm-unguarded-var bash "$2"' _ "$payload" "$DISPATCH" "${2:-claude}"
}

@test "denies rm on a variable path without a guard" {
  run_guard 'D=/tmp/x/after; rm -f $D/*.png; ls $D'
  [ "$status" -eq 2 ]
  [[ "$output" == *"[dont-do-that/rm-unguarded-var]"* ]]
  [[ "$output" == *'${D:?}'* ]]
}

@test "denies rm on a braced variable without a guard" {
  run_guard 'rm -rf "${OUT}/trace"'
  [ "$status" -eq 2 ]
}

@test "denies rm after a logical operator" {
  run_guard 'cd /tmp && rm -r $DIR'
  [ "$status" -eq 2 ]
}

@test "passes rm on a guarded variable" {
  run_guard 'rm -rf "${D:?}"/trace "${D:?}"/before'
  [ "$status" -eq 0 ]
}

@test "passes rm on a literal path" {
  run_guard 'rm -f ./after/*.png test/frontend/zz-capture.spec.js'
  [ "$status" -eq 0 ]
}

@test "passes a variable outside the rm arguments" {
  run_guard 'rm -f ./a.png; ls $D'
  [ "$status" -eq 0 ]
}

@test "passes rm inside a quoted heredoc body" {
  run_guard "python3 - <<'PY'
import os
os.system('rm -f \$D/x')
PY"
  [ "$status" -eq 0 ]
}

@test "passes a word that only contains rm" {
  run_guard 'npm run format $FILE; git rm-cache $X'
  [ "$status" -eq 0 ]
}

@test "passes with the allow comment" {
  run_guard 'rm -f $D/x # allow-rm-var'
  [ "$status" -eq 0 ]
}

@test "stays silent for codex" {
  run_guard 'rm -f $D/x' codex
  [ "$status" -eq 0 ]
}

@test "denies rm after then or do" {
  run_guard 'if true; then rm "$D/x"; fi'
  [ "$status" -eq 2 ]
  run_guard 'for f in a; do rm "$D/$f"; done'
  [ "$status" -eq 2 ]
}

@test "denies rm behind xargs or find -exec" {
  run_guard 'ls | xargs rm "$D/x"'
  [ "$status" -eq 2 ]
  run_guard 'find . -name x -exec rm "$D/x" \;'
  [ "$status" -eq 2 ]
}

@test "denies rm whose variable follows a line continuation" {
  run_guard 'rm -f \
  $D/x'
  [ "$status" -eq 2 ]
}

@test "passes a variable that is single-quoted or escaped" {
  run_guard "rm '\$D/x'"
  [ "$status" -eq 0 ]
  run_guard 'rm \$D/x'
  [ "$status" -eq 0 ]
}

@test "passes rm inside a single-quoted string or a comment" {
  run_guard "printf '%s' 'tekst; rm \$D/x'"
  [ "$status" -eq 0 ]
  run_guard 'echo ok # comment; rm $D/x'
  [ "$status" -eq 0 ]
}

@test "denies rm behind xargs options that take an argument" {
  run_guard 'ls | xargs -I {} rm "$D/{}"'
  [ "$status" -eq 2 ]
  run_guard 'ls | xargs -n 1 rm "$D/x"'
  [ "$status" -eq 2 ]
}

@test "denies rm on a command substitution" {
  run_guard 'rm $(printf %s "$D")'
  [ "$status" -eq 2 ]
  run_guard 'rm "/tmp/$(date +%s).log"'
  [ "$status" -eq 2 ]
}

@test "passes a guarded rm whose redirection target is a variable" {
  run_guard 'rm -f "${D:?}/x" 2>"$LOG" >&2'
  [ "$status" -eq 0 ]
}

@test "denies a variable after arithmetic in rm arguments" {
  run_guard 'rm $((1))/$D'
  [ "$status" -eq 2 ]
}
