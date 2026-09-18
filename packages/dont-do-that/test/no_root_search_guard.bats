#!/usr/bin/env bats

DISPATCH="$BATS_TEST_DIRNAME/../hooks/dispatch.sh"

setup() {
  export HOME="$BATS_TEST_TMPDIR/Users/tester"
  export LAICLUSE_HOME="$BATS_TEST_TMPDIR/laicluse"
  export PROJECT="$HOME/github.com/acme/app"
  mkdir -p "$PROJECT" "$LAICLUSE_HOME"
}

bash_search() {
  local payload
  payload=$(jq -cn --arg cwd "$1" --arg cmd "$2" \
    '{hook_event_name:"PreToolUse", tool_name:"Bash", cwd:$cwd, tool_input:{command:$cmd}}')
  run bash -c 'printf "%s" "$1" | DD_AGENT="$3" DD_ONLY_PRETOOLUSE_GUARDS=no-root-search bash "$2"' _ "$payload" "$DISPATCH" "${3:-claude}"
}

tool_search() {
  local payload
  payload=$(jq -cn --arg tool "$1" --arg cwd "$2" --argjson input "$3" \
    '{hook_event_name:"PreToolUse", tool_name:$tool, cwd:$cwd, tool_input:$input}')
  run bash -c 'printf "%s" "$1" | DD_AGENT=claude DD_ONLY_PRETOOLUSE_GUARDS=no-root-search-tool bash "$2"' _ "$payload" "$DISPATCH"
}

denied() {
  [ "$status" -eq 2 ]
  [[ "$output" == *"[dont-do-that/no-root-search]"* ]]
}

allowed() {
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "find from the filesystem root is denied with the package-manager route" {
  bash_search "$PROJECT" 'find / -path "*/actionpack-*/lib/action_dispatch/middleware/exception_wrapper.rb" -not -path "*/node_modules/*"'
  denied
  [[ "$output" == *"bundle show"* ]]
  [[ "$output" == *"mdfind -name"* ]]
}

@test "find from the root stays denied behind a prune, a redirect, a pipe" {
  bash_search "$PROJECT" 'find / -path /proc -prune -o -name log_subscriber.rb -path "*active_job*" -print 2>/dev/null | head'
  denied
}

@test "find from the root is denied for Codex too" {
  bash_search "$PROJECT" 'find / -type d -name "puma-*"' codex
  denied
}

@test "a root search inside a quoted command substitution is denied" {
  bash_search "$PROJECT" 'GEM_DIR="$(find / -type d -name "actioncable-*")"; echo "$GEM_DIR"'
  denied
}

@test "wrappers, shell -c strings, path-qualified tools are denied" {
  bash_search "$PROJECT" 'sudo find / -name x'
  denied
  bash_search "$PROJECT" 'bash -lc "find / -name x"'
  denied
  bash_search "$PROJECT" '/usr/bin/find / -name x'
  denied
}

@test "home directory spellings are denied" {
  for root in '~' '~/' '$HOME' '"$HOME"' '${HOME}/' "$HOME" "/System/Volumes/Data$HOME"; do
    bash_search "$PROJECT" "find $root -name Gemfile"
    denied
  done
}

@test "the home Library, the app-container directories are denied" {
  bash_search "$PROJECT" 'ls -laR ~/Library'
  denied
  bash_search "$PROJECT" 'find "$HOME/Library/Containers" -name "*.sqlite"'
  denied
  bash_search "$PROJECT" 'rg token "$HOME/Library/Group Containers"'
  denied
}

@test "every recursive search tool is covered" {
  bash_search "$PROJECT" 'rg exception_wrapper /'
  denied
  bash_search "$PROJECT" 'grep -rn puma ~/'
  denied
  bash_search "$PROJECT" 'fd -e rb . $HOME'
  denied
  bash_search "$PROJECT" 'fd Gemfile --search-path /'
  denied
  bash_search "$PROJECT" 'ag puma ~'
  denied
  bash_search "$PROJECT" 'tree /Users'
  denied
  bash_search "$PROJECT" 'du -sh ~/*'
  denied
}

@test "a relative search is judged against the directory it runs in" {
  bash_search "$HOME" 'find . -name "*.rb"'
  denied
  bash_search "$HOME" 'rg -l puma'
  denied
  bash_search "$PROJECT" 'cd ~ && rg puma'
  denied
  bash_search "$PROJECT" 'find ../../.. -name Gemfile'
  denied
}

@test "a deep maxdepth from a guarded root is denied" {
  bash_search "$PROJECT" 'find ~ -maxdepth 4 -name .zshrc'
  denied
}

@test "project, named-directory searches pass" {
  bash_search "$PROJECT" 'find . -name "*.rb"'
  allowed
  bash_search "$PROJECT" 'rg -l puma'
  allowed
  bash_search "$PROJECT" 'find ~/github.com -name Gemfile'
  allowed
  bash_search "$PROJECT" 'find ~/Library/LaunchAgents -name "*.plist"'
  allowed
  bash_search "$PROJECT" 'grep -rn puma /opt/homebrew/lib/ruby'
  allowed
}

@test "a shallow listing of a guarded root passes" {
  bash_search "$PROJECT" 'find / -maxdepth 2 -name Users'
  allowed
  bash_search "$PROJECT" 'find ~ -maxdepth 1 -name ".*rc"'
  allowed
  bash_search "$PROJECT" 'fd --max-depth=1 . ~'
  allowed
  bash_search "$HOME" 'ls -la'
  allowed
  bash_search "$PROJECT" 'ls ~/Library/Containers'
  allowed
}

@test "a pattern that is a slash, a non-recursive grep pass" {
  bash_search "$PROJECT" 'grep -r "/" src'
  allowed
  bash_search "$PROJECT" 'rg / src'
  allowed
  bash_search "$PROJECT" 'grep -n localhost /etc/hosts'
  allowed
}

@test "a pattern search fed by a pipe reads stdin, passes in the home directory" {
  bash_search "$HOME" 'ps aux | rg claude'
  allowed
}

@test "search text that is data, not a command, passes" {
  bash_search "$PROJECT" 'git commit -m "block find / searches"'
  allowed
  bash_search "$PROJECT" 'echo "find / -name x"'
  allowed
  bash_search "$PROJECT" 'ssh build-host "find / -name x"'
  allowed
  bash_search "$PROJECT" $'cat <<NOTE > notes.md\nfind / -name x\nNOTE'
  allowed
}

@test "an unresolvable root passes" {
  bash_search "$PROJECT" 'find "$GEM_ROOT" -name x'
  allowed
}

@test "index queries pass" {
  bash_search "$HOME" 'mdfind -name exception_wrapper.rb'
  allowed
}

@test "the allow token lets an operator-requested root search through" {
  bash_search "$PROJECT" 'find / -name x # allow-root-search'
  allowed
}

@test "Grep without a path in the home directory is denied" {
  tool_search Grep "$HOME" '{"pattern":"puma"}'
  denied
  [[ "$output" == *"Pass a 'path'"* ]]
  [[ "$output" == *"# allow-root-search"* ]]
}

@test "Grep with a root path is denied, with a project path passes" {
  tool_search Grep "$PROJECT" '{"pattern":"puma","path":"/"}'
  denied
  tool_search Grep "$PROJECT" '{"pattern":"puma"}'
  allowed
  tool_search Grep "$HOME" "{\"pattern\":\"puma\",\"path\":\"$PROJECT\"}"
  allowed
}

@test "Glob is judged by the literal prefix, the depth of its pattern" {
  tool_search Glob "$HOME" '{"pattern":"**/Gemfile"}'
  denied
  tool_search Glob "$PROJECT" '{"pattern":"/**/puma-*"}'
  denied
  tool_search Glob "$HOME" '{"pattern":"Library/Containers/**/*.sqlite"}'
  denied
  tool_search Glob "$HOME" '{"pattern":"*.md"}'
  allowed
  tool_search Glob "$HOME" '{"pattern":"github.com/acme/**/*.rb"}'
  allowed
  tool_search Glob "$PROJECT" '{"pattern":"**/*.rb"}'
  allowed
}

@test "the deny sends the agent to where the answer logically lives" {
  bash_search "$PROJECT" 'find / -name "puma-*"'
  denied
  [[ "$output" == *"never a place to start a search"* ]]
  [[ "$output" == *"Decide first where the answer logically lives"* ]]
  [[ "$output" == *"you are guessing"* ]]
  tool_search Grep "$HOME" '{"pattern":"puma"}'
  denied
  [[ "$output" == *"Decide first where the answer logically lives"* ]]
}
