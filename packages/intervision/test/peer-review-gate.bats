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
