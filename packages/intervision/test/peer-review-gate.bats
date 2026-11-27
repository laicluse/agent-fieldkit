#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../../.." && pwd)"
  GATE="$REPO_ROOT/packages/intervision/hooks/scripts/peer-review-gate.sh"
  WORK="$(mktemp -d)"
  cd "$WORK"
  export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
  git init -q -b main .
  mkdir -p .claude-plugin .agents/plugins packages/p/skills/s
  echo '{}' > .claude-plugin/marketplace.json
  echo '{}' > .agents/plugins/marketplace.json
  git add -f . && git -c core.hooksPath=/dev/null commit -q -m root
}

stage() {
  mkdir -p "$(dirname "$1")"
  echo change >> "$1"
  git add -f "$1"
}

run_gate() {
  run bash -c "jq -cn --arg c \"\$2\" --arg w \"\$3\" '{tool_name:\"Bash\",tool_input:({command:\$c} + (if \$w == \"\" then {} else {workdir:\$w} end))}' | bash '$GATE' \"\$1\"" _ "$1" "$2" "${3:-}"
}

@test "Claude committing Codex payload is sent to the Codex peer" {
  stage .agents/plugins/generated/p/skills/s/SKILL.md
  run_gate claude 'git commit -m "Add skill"'
  [ "$status" -eq 2 ]
  [[ "$output" == *"Codex peer"* ]]
  [[ "$output" == *".agents/plugins/generated/p/skills/s/SKILL.md"* ]]
}

@test "a Codex-only skill source counts as Codex payload" {
  stage packages/p/skills/s/SKILL.codex.md
  run_gate claude 'git commit -m "Tune skill"'
  [ "$status" -eq 2 ]
}

@test "a reviewed commit passes" {
  stage packages/p/hooks/hooks.codex.json
  run_gate claude 'git commit -m "Add hook" # peer-reviewed: gpt-6.1-sol'
  [ "$status" -eq 0 ]
}

@test "Claude-only payload from Claude passes" {
  stage packages/p/skills/s/SKILL.claude.md
  run_gate claude 'git commit -m "Tune skill"'
  [ "$status" -eq 0 ]
}

@test "Codex committing a shared skill is sent to the Claude peer" {
  stage packages/p/skills/s/SKILL.md
  run_gate codex 'git commit -m "Tune skill"'
  [ "$status" -eq 2 ]
  [[ "$output" == *"Claude peer"* ]]
}

@test "Codex committing Codex-only payload passes" {
  stage .agents/plugins/generated/p/skills/s/SKILL.md
  run_gate codex 'git commit -m "Regenerate adapter"'
  [ "$status" -eq 0 ]
}

@test "a repository without both marketplaces is left alone" {
  git rm -q .agents/plugins/marketplace.json
  stage packages/p/skills/s/SKILL.codex.md
  run_gate claude 'git commit -m "Tune skill"'
  [ "$status" -eq 0 ]
}

@test "commands other than a commit are left alone" {
  stage packages/p/skills/s/SKILL.codex.md
  run_gate claude 'git status'
  [ "$status" -eq 0 ]
}

@test "a marker naming the session's own lab does not count" {
  stage packages/p/hooks/hooks.codex.json
  run_gate claude 'git commit -m "Add hook" # peer-reviewed: claude-opus-5-5'
  [ "$status" -eq 2 ]
}

@test "a marker inside the message instead of a trailing comment does not count" {
  stage packages/p/hooks/hooks.codex.json
  run_gate claude 'git commit -m "Document # peer-reviewed: gpt-6.1-sol"'
  [ "$status" -eq 2 ]
}

@test "Codex accepts a Claude model as reviewer" {
  stage packages/p/skills/s/SKILL.md
  run_gate codex 'git commit -m "Tune skill" # peer-reviewed: claude-opus-5-5'
  [ "$status" -eq 0 ]
}

@test "Codex changing a shared hook script is sent to the Claude peer" {
  stage packages/p/hooks/scripts/guard.sh
  run_gate codex 'git commit -m "Tune guard"'
  [ "$status" -eq 2 ]
}

@test "files added in the same command count" {
  mkdir -p packages/p/skills/s && echo x > packages/p/skills/s/SKILL.codex.md
  run_gate claude 'git add packages/p/skills/s/SKILL.codex.md && git commit -m "Tune skill"'
  [ "$status" -eq 2 ]
}

@test "commit -a counts tracked changes that are not staged" {
  stage packages/p/skills/s/SKILL.codex.md
  git -c core.hooksPath=/dev/null commit -q -m tracked
  echo more >> packages/p/skills/s/SKILL.codex.md
  run_gate claude 'git commit -am "Tune skill"'
  [ "$status" -eq 2 ]
}

@test "the tool's workdir decides which repository is checked" {
  stage packages/p/skills/s/SKILL.codex.md
  cd /
  run_gate claude 'git commit -m "Tune skill"' "$WORK"
  [ "$status" -eq 2 ]
}

@test "tests and docs alone need no peer" {
  stage packages/p/test/x.bats
  stage packages/p/README.md
  run_gate codex 'git commit -m "Docs"'
  [ "$status" -eq 0 ]
}

@test "a heredoc commit with a trailing marker passes" {
  stage packages/p/skills/s/SKILL.codex.md
  run_gate claude "$(printf '%s\n' 'git commit -m "$(cat <<'"'"'EOF'"'"'' "The tool's skill" '' 'Slice: x' 'EOF' ')" # peer-reviewed: gpt-6.1-sol')"
  [ "$status" -eq 0 ]
}

@test "a marker on an earlier line does not count" {
  stage packages/p/skills/s/SKILL.codex.md
  run_gate claude "$(printf '%s\n' 'true # peer-reviewed: gpt-6.1-sol' 'git commit -m "Tune skill"')"
  [ "$status" -eq 2 ]
}

@test "a reviewer that is no model of the other lab does not count" {
  stage packages/p/skills/s/SKILL.codex.md
  run_gate claude 'git commit -m "Tune skill" # peer-reviewed: banana'
  [ "$status" -eq 2 ]
}

@test "a quoted cd path with spaces is followed" {
  SPACED="$(mktemp -d)/spaced repo" && mkdir -p "$SPACED"
  cp -R "$WORK/." "$SPACED/"
  cd "$SPACED" && stage packages/p/skills/s/SKILL.codex.md
  cd /
  run_gate claude "cd \"$SPACED\" && git commit -m \"Tune skill\""
  [ "$status" -eq 2 ]
}

@test "an unresolvable cd target is denied rather than trusted" {
  run_gate claude 'cd "/nowhere at all" && git commit -m "Tune skill"'
  [ "$status" -eq 2 ]
  [[ "$output" == *"Could not resolve the repository"* ]]
}

@test "an apostrophe inside a double-quoted message keeps the marker valid" {
  stage packages/p/skills/s/SKILL.codex.md
  run_gate claude "git commit -m \"Fix the tool's skill\" # peer-reviewed: gpt-6.1-sol"
  [ "$status" -eq 0 ]
}

@test "a quoted git -C path with spaces is followed" {
  SPACED="$(mktemp -d)/spaced repo" && mkdir -p "$SPACED"
  cp -R "$WORK/." "$SPACED/"
  cd "$SPACED" && stage packages/p/skills/s/SKILL.codex.md
  cd /
  run_gate claude "git -C '$SPACED' commit -m change"
  [ "$status" -eq 2 ]
}

@test "the marker may share the trailing comment with another acknowledgement" {
  stage packages/p/skills/s/SKILL.codex.md
  run_gate claude 'git commit -m "Tune skill" # ack-rule9:word # peer-reviewed: gpt-6.1-sol'
  [ "$status" -eq 0 ]
}

@test "the marker on the commit line counts when other commands follow" {
  stage packages/p/skills/s/SKILL.md
  run_gate claude "$(printf '%s\n' 'git commit -m "Tune skill" # peer-reviewed: gpt-6.1-sol' 'git log --oneline -1')"
  [ "$status" -eq 0 ]
}

@test "a heredoc commit keeps its marker when commands follow the body" {
  stage packages/p/skills/s/SKILL.md
  run_gate claude "$(printf '%s\n' "git commit -q -F - <<'EOF' # peer-reviewed: gpt-6.1-sol" 'Tune skill' '' "The tool's body" 'EOF' 'git status --short')"
  [ "$status" -eq 0 ]
}

@test "an apostrophe in a backslash-quoted heredoc body keeps the marker valid" {
  stage packages/p/skills/s/SKILL.md
  run_gate claude "$(printf '%s\n' 'git commit -F - <<\EOF # peer-reviewed: gpt-6.1-sol' "The tool's body" 'EOF')"
  [ "$status" -eq 0 ]
}

@test "a marker inside a heredoc body does not count" {
  stage packages/p/skills/s/SKILL.md
  run_gate claude "$(printf '%s\n' "git commit -F - <<'EOF'" 'Tune skill' '# peer-reviewed: gpt-6.1-sol' 'EOF')"
  [ "$status" -eq 2 ]
}

@test "a marker on a command after the commit does not count" {
  stage packages/p/skills/s/SKILL.md
  run_gate claude "$(printf '%s\n' 'git commit -m "Tune skill"' 'git log --oneline -1 # peer-reviewed: gpt-6.1-sol')"
  [ "$status" -eq 2 ]
}

@test "adding named paths counts only those paths, not other pending changes" {
  mkdir -p packages/q/skills/t
  echo pending > packages/q/skills/t/SKILL.md
  echo note > notes.txt
  run_gate claude 'git add notes.txt && git commit -m "Add notes"'
  [ "$status" -eq 0 ]
}

@test "adding everything still counts every pending change" {
  mkdir -p packages/q/skills/t
  echo pending > packages/q/skills/t/SKILL.md
  run_gate claude 'git add -A && git commit -m "Regenerate"'
  [ "$status" -eq 2 ]
}

@test "a marker after a later command on the same line does not count" {
  stage packages/p/skills/s/SKILL.md
  run_gate claude 'git commit -m "Tune skill" && git log -1 # peer-reviewed: gpt-6.1-sol'
  [ "$status" -eq 2 ]
}

@test "every commit in one command needs its own marker" {
  stage packages/p/skills/s/SKILL.md
  run_gate claude "$(printf '%s\n' 'git commit -m "One"' 'git commit -m "Two" # peer-reviewed: gpt-6.1-sol')"
  [ "$status" -eq 2 ]
}

@test "a stderr redirect does not split the commit from its marker" {
  stage packages/p/skills/s/SKILL.md
  run_gate claude 'git commit -m "Tune skill" 2>&1 # peer-reviewed: gpt-6.1-sol'
  [ "$status" -eq 0 ]
}

@test "a tab-indented heredoc terminator ends the body" {
  stage packages/p/skills/s/SKILL.md
  run_gate claude "$(printf 'git commit -F - <<-EOF # peer-reviewed: gpt-6.1-sol\n\tTune skill\n\tEOF\ngit status\n')"
  [ "$status" -eq 0 ]
}

@test "an added path with shell expansion counts every pending change" {
  mkdir -p packages/q/skills/t
  echo pending > packages/q/skills/t/SKILL.md
  echo note > notes.txt
  run_gate claude 'git add "$PWD/notes.txt" && git commit -m "Add notes"'
  [ "$status" -eq 2 ]
}

@test "an earlier commit with an invalid reviewer fails even when the last one is valid" {
  stage packages/p/skills/s/SKILL.md
  run_gate claude "$(printf '%s\n' 'git commit -m "One" # peer-reviewed: banana' 'git commit -m "Two" # peer-reviewed: gpt-6.1-sol')"
  [ "$status" -eq 2 ]
}

@test "a trailing backslash inside the marker comment still closes the commit" {
  stage packages/p/skills/s/SKILL.md
  run_gate claude 'git commit -m "Tune skill" # peer-reviewed: gpt-6.1-sol \'
  [ "$status" -eq 0 ]
}

@test "an added path with backslash escapes counts every pending change" {
  mkdir -p packages/q/skills/t
  echo pending > packages/q/skills/t/SKILL.md
  echo note > "my notes.txt"
  run_gate claude 'git add my\ notes.txt && git commit -m "Add notes"'
  [ "$status" -eq 2 ]
}

@test "heredoc syntax inside a quoted message does not hide a later commit" {
  stage packages/p/skills/s/SKILL.md
  run_gate claude "$(printf '%s\n' 'git commit -m "Explain <<EOF" # peer-reviewed: gpt-6.1-sol' 'git commit -m "Two"' 'EOF')"
  [ "$status" -eq 2 ]
}

@test "a here-string does not hide a later commit" {
  stage packages/p/skills/s/SKILL.md
  run_gate claude "$(printf '%s\n' 'git commit -m "One" # peer-reviewed: gpt-6.1-sol' 'cat <<<EOF' 'git commit -m "Two"' 'EOF')"
  [ "$status" -eq 2 ]
}

@test "an added path with a hash counts every pending change" {
  mkdir -p packages/q/skills/t
  echo pending > "packages/q/skills/t/SKILL#1.md"
  echo note > notes.txt
  run_gate claude 'git add notes.txt "packages/q/skills/t/SKILL#1.md" && git commit -m "Add notes"'
  [ "$status" -eq 2 ]
}

@test "combined add flags that stage everything count every pending change" {
  mkdir -p packages/q/skills/t
  echo pending > packages/q/skills/t/SKILL.md
  echo note > notes.txt
  run_gate claude 'git add -Av notes.txt && git commit -m "Update"'
  [ "$status" -eq 2 ]
}

@test "an earlier add of everything still counts when a later add names a path" {
  mkdir -p packages/q/skills/t
  echo pending > packages/q/skills/t/SKILL.md
  echo note > notes.txt
  run_gate claude 'git add -A && git add notes.txt && git commit -m "Update"'
  [ "$status" -eq 2 ]
}

@test "a path named add does not hide an earlier stage-all flag" {
  mkdir -p packages/q/skills/t
  echo pending > packages/q/skills/t/SKILL.md
  echo note > notes.txt
  run_gate claude 'git add -A add notes.txt && git commit -m "Update"'
  [ "$status" -eq 2 ]
}

@test "a directory change before a named add counts every pending change" {
  mkdir -p packages/q/skills/t sub
  echo pending > packages/q/skills/t/SKILL.md
  echo note > sub/notes.txt
  run_gate claude 'true && cd sub && git add notes.txt && git commit -m "Update"'
  [ "$status" -eq 2 ]
}

@test "a git option before add counts every pending change" {
  mkdir -p packages/q/skills/t
  echo pending > packages/q/skills/t/SKILL.md
  echo note > notes.txt
  run_gate claude 'git -c core.quotepath=off add notes.txt && git commit -m "Update"'
  [ "$status" -eq 2 ]
}

@test "a leading cd before a named add still narrows to that path" {
  mkdir -p packages/q/skills/t
  echo pending > packages/q/skills/t/SKILL.md
  echo note > notes.txt
  run_gate claude "cd $WORK && git add notes.txt && git commit -m \"Add notes\""
  [ "$status" -eq 0 ]
}
