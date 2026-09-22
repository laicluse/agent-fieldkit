#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../../../.." && pwd)"
  SKILL="$REPO_ROOT/packages/git-discipline/skills/merge-to-default/SKILL.md"
}

@test "merge-to-default delegates verification and merge topology to the shared command" {
  grep -q 'bin/git-discipline" verify' "$SKILL"
  grep -q 'bin/git-discipline" merge' "$SKILL"
  grep -q -- '--local' "$SKILL"
  grep -q -- '--remote' "$SKILL"
  ! grep -q 'git checkout' "$SKILL"
  ! grep -q 'git merge' "$SKILL"
  ! grep -q 'git commit-tree' "$SKILL"
}

@test "merge and rebase use the same executable default-branch resolver" {
  local rebase_skill="$REPO_ROOT/packages/git-discipline/skills/rebase-latest-default/SKILL.md"

  for skill in "$SKILL" "$rebase_skill"; do
    grep -q 'bin/git-discipline" default' "$skill"
    ! grep -q 'git config --get init.defaultBranch' "$skill"
  done
}

@test "merge-to-default maps repository policy before choosing a local or remote CAS" {
  grep -q 'git-repo-policy' "$SKILL"
  grep -q 'local-only' "$SKILL"
  grep -q 'auto-trunk' "$SKILL"
  grep -q 'gated-trunk' "$SKILL"
  grep -q 'pr-flow' "$SKILL"
  grep -q 'external' "$SKILL"
}

@test "a merge order is not by itself a publication order" {
  grep -q 'gated-trunk) TARGET=--local' "$SKILL"
  ! grep -q 'auto-trunk|gated-trunk) TARGET=--remote' "$SKILL"
  grep -q 'Invoking this skill orders the merge, not the publication' "$SKILL"
  grep -q "operator's order names publishing this default" "$SKILL"
}

@test "a refused step ends the operation instead of being hand-finished" {
  grep -q 'The candidate cannot be the default branch' "$SKILL"
  grep -q 'Never finish a refused step by hand with direct Git commands' "$SKILL"
  grep -q 'never substitute an adjacent action' "$SKILL"
}

@test "deployment waits for an occupied or divergent canonical checkout" {
  grep -q 'held by another session' "$SKILL"
  grep -q 'committed-but-unintegrated work' "$SKILL"
  grep -q 'stop deployment and wait' "$SKILL"
  grep -q 'Do not detach' "$SKILL"
}

@test "canonical deployment checkout stays attached to its default branch" {
  grep -q 'must remain attached to its named default branch' "$SKILL"
  grep -q 'Never check out a raw commit SHA there' "$SKILL"
  grep -q 'the default branch ref itself must point at that SHA' "$SKILL"
}

@test "review skills use the same configured local default contract" {
  local intervision_codex="$REPO_ROOT/packages/intervision/skills/second-opinion/SKILL.codex.md"
  local intervision_claude="$REPO_ROOT/packages/intervision/skills/second-opinion/SKILL.claude.md"
  local rover_pride="$REPO_ROOT/packages/rover/skills/pride/SKILL.md"

  for skill in "$intervision_codex" "$intervision_claude" "$rover_pride"; do
    grep -q 'git config --get init.defaultBranch' "$skill"
    grep -q 'git rev-parse --verify "refs/heads/\$CONFIGURED_DEFAULT"' "$skill"
  done
  grep -q 'DEFAULT_REF=\$CONFIGURED_DEFAULT' "$rover_pride"
  grep -q 'RANGE="${DEFAULT_REF}..HEAD"' "$rover_pride"
}
