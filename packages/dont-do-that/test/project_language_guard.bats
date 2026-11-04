#!/usr/bin/env bats

DISPATCH="$BATS_TEST_DIRNAME/../hooks/dispatch.sh"

run_guard() {
  local cwd="$1" cmd="$2" payload
  payload="$(jq -cn --arg cwd "$cwd" --arg cmd "$cmd" \
    '{hook_event_name:"PreToolUse", tool_name:"Bash", cwd:$cwd, tool_input:{command:$cmd}}')"
  run bash -c 'cd "$3" && printf "%s" "$1" | DD_AGENT=claude DD_ONLY_PRETOOLUSE_GUARDS=project-language bash "$2"' _ "$payload" "$DISPATCH" "$cwd"
}

setup() {
  export GO_REPO="$BATS_TEST_TMPDIR/go-repo"
  export PY_REPO="$BATS_TEST_TMPDIR/py-repo"
  export JS_REPO="$BATS_TEST_TMPDIR/js-repo"
  export PLAIN="$BATS_TEST_TMPDIR/plain"
  mkdir -p "$GO_REPO/internal/cli" "$PY_REPO" "$JS_REPO" "$PLAIN"
  git -C "$GO_REPO" init -q && touch "$GO_REPO/go.mod"
  git -C "$PY_REPO" init -q && touch "$PY_REPO/pyproject.toml"
  git -C "$JS_REPO" init -q && echo '{}' > "$JS_REPO/package.json"
}

@test "denies a python heredoc in a Go project and names Go" {
  run_guard "$GO_REPO" "python3 - <<'EOF'
print(1)
EOF"
  [ "$status" -eq 2 ]
  [[ "$output" == *"[dont-do-that/project-language]"* ]]
  [[ "$output" == *"Go"* ]]
}

@test "denies python -c from a subdirectory of a Go project" {
  run_guard "$GO_REPO/internal/cli" 'gh pr list --json number | python3 -I -c "import json,sys; print(json.load(sys.stdin))"'
  [ "$status" -eq 2 ]
}

@test "denies inline python behind env assignments and nice" {
  run_guard "$GO_REPO" 'FONT=x nice python3 -c "print(1)"'
  [ "$status" -eq 2 ]
}

@test "denies inline python after an option that takes a value" {
  run_guard "$GO_REPO" 'python3 -W ignore -c "print(1)"'
  [ "$status" -eq 2 ]
}

@test "denies node -e in a Go project" {
  run_guard "$GO_REPO" 'node -e "console.log(1)"'
  [ "$status" -eq 2 ]
}

@test "allows inline python in a Python project" {
  run_guard "$PY_REPO" 'python3 -c "print(1)"'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "allows node -e in a JavaScript project" {
  run_guard "$JS_REPO" 'node -e "console.log(1)"'
  [ "$status" -eq 0 ]
}

@test "allows inline python in a Go project that also declares Python" {
  touch "$GO_REPO/requirements.txt"
  run_guard "$GO_REPO" 'python3 -c "print(1)"'
  [ "$status" -eq 0 ]
}

@test "follows a leading cd into a Python project" {
  run_guard "$GO_REPO" "cd \"$PY_REPO\" && python3 -c 'print(1)'"
  [ "$status" -eq 0 ]
}

@test "allows running an existing script, which is a tool and not authoring" {
  run_guard "$GO_REPO" 'python3 scripts/build-font.py --check'
  [ "$status" -eq 0 ]
}

@test "allows running a quoted script path" {
  run_guard "$GO_REPO" 'python3 "scripts/build font.py"'
  [ "$status" -eq 0 ]
}

@test "allows a heredoc that feeds data to an existing script" {
  run_guard "$GO_REPO" "python3 scripts/build.py <<EOF
data
EOF"
  [ "$status" -eq 0 ]
}

@test "denies a heredoc fed to a bare interpreter" {
  run_guard "$GO_REPO" "python3 <<EOF
print(1)
EOF"
  [ "$status" -eq 2 ]
}

@test "resolves a relative cd against the hook cwd without hanging" {
  run timeout 5 bash -c 'printf "%s" "$1" | DD_AGENT=claude DD_ONLY_PRETOOLUSE_GUARDS=project-language bash "$2"' _ \
    "$(jq -cn --arg cwd "$GO_REPO" '{hook_event_name:"PreToolUse", tool_name:"Bash", cwd:$cwd, tool_input:{command:"cd internal && python3 -c \"print(1)\""}}')" "$DISPATCH"
  [ "$status" -eq 2 ]
}

@test "allows a quoted mention of inline python" {
  run_guard "$GO_REPO" 'echo "python3 -c print"'
  [ "$status" -eq 0 ]
}

@test "allows a directory without any project manifest" {
  run_guard "$PLAIN" 'python3 -c "print(1)"'
  [ "$status" -eq 0 ]
}

@test "allows an explicit other-language reason" {
  run_guard "$GO_REPO" 'python3 -c "from fontTools.ttLib import TTFont" # other-language: fontTools has no Go port'
  [ "$status" -eq 0 ]
}
