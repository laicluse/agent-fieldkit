#!/usr/bin/env bats

DISPATCH="$BATS_TEST_DIRNAME/../hooks/dispatch.sh"

run_guard() {
  local payload
  payload="$(jq -cn --arg cmd "$1" '{hook_event_name:"PreToolUse", tool_name:"Bash", cwd:"/tmp", tool_input:{command:$cmd}}')"
  run bash -c 'printf "%s" "$1" | DD_AGENT=codex DD_ONLY_PRETOOLUSE_GUARDS=no-shared-dependency-link bash "$2"' _ "$payload" "$DISPATCH"
}

@test "symlinking another checkout's dependency directory is denied" {
  for command in \
    "ln -s ~/code/app/node_modules worktrees/feature/node_modules" \
    "cd worktrees/feature && ln -sf ../../node_modules node_modules" \
    "ln -s /repo/.venv .venv" \
    "ln -s /repo/vendor/bundle vendor/bundle" \
    "/bin/ln -s /repo/node_modules node_modules" \
    "ln --symbolic /repo/node_modules node_modules" \
    "ln -s \"/my repo/node_modules\" node_modules" \
    "echo \\\"; ln -s /repo/node_modules node_modules" \
    "ln \\
-s /repo/node_modules node_modules"; do
    run_guard "$command"

    [ "$status" -eq 2 ]
    [[ "$output" == *"[dont-do-that/no-shared-dependency-link]"* ]]
  done
}

@test "other symlinks, text mentions and dependency installs pass" {
  for command in \
    "ln -s ~/code/app/config/master.key config/master.key" \
    "npm install" \
    "ls -la node_modules" \
    "ln node_modules/a b" \
    "echo ln -s /repo/node_modules node_modules" \
    "ln -s /repo/mynode_modules ./assets" \
    "ln -s /repo/node_modules/.bin/tool bin/tool" \
    "echo \"example; ln -s /repo/node_modules node_modules\"" \
    "echo 'example && ln -s /repo/node_modules node_modules'" \
    "printf '%s\n' \"first line
ln -s /repo/node_modules node_modules
\"" \
    "cat > notes.txt <<'EOF'
\"ln -s /repo/node_modules node_modules\" stays text
EOF"; do
    run_guard "$command"

    [ "$status" -eq 0 ]
  done
}
