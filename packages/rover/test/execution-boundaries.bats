#!/usr/bin/env bats

setup() {
  rover_root="$BATS_TEST_DIRNAME/.."
  main="$rover_root/skills/rover/SKILL.md"
  stop="$rover_root/skills/stop/SKILL.md"
}

@test "no skill overrides stops or makes research spending unlimited" {
  run grep -ERn 'halts as advisory|Intermediate halts are treated as advisory|No user-feedback during a rover action. Forbidden|cost of satisfying.*never priced|Tokens spent.*cheap|hard five-minute fuse' "$rover_root/skills"
  [ "$status" -eq 1 ]
}

@test "new loop instructions carry failure and budget boundaries" {
  run sed -n '/^## Instructions$/,/^### Phases$/p' "$main"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Explicit stops and budgets are binding"* ]]
  [[ "$output" == *"observed cause, relevant change and falsifiable prediction"* ]]
  [[ "$output" == *"does not authorize a new research sequence"* ]]
  [[ "$output" == *"never claim completion to end continuation"* ]]
}

@test "negative outcomes stop with unmet criteria without restarting reviews" {
  grep -Fq 'Unmet criteria remain unmet; they do not force a return to DRIVE after a stop.' "$stop"
  grep -Fq 'A stop report does not start a new review cycle.' "$stop"
  grep -Fq 'Never mark an unfinished goal complete to cancel continuation.' "$stop"
}

@test "documentation and renamed experiments cannot reset the budget" {
  grep -Fq 'Never reset the budget by renaming an experiment, restarting a session or changing a prompt.' "$main"
  grep -Fq 'an unchanged report, routine status update or summary of reviewed findings does not start another review' "$main"
}

@test "a status question cannot resume stopped research" {
  grep -Fq 'A status question, new evidence or stale wake-up does not resume stopped work.' "$main"
  ! grep -Fq 'On any interjection:' "$main"
  ! grep -Fq 'blanket approval for autonomous decisions' "$main"
}

@test "the loop template cannot demand pride before honoring a stop" {
  ! grep -Fq 'runs pride on it' "$main"
  grep -Fq 'No new review is required to honor a stop.' "$main"
}

@test "honest failure reporting cannot trigger automatic repair" {
  grep -Fq 'An honest negative or stopped outcome is not a forbidden success claim.' "$rover_root/skills/pride/SKILL.md"
  ! grep -Fq 'sends the rover back to DRIVE, no exceptions' "$rover_root/skills/pride/SKILL.md"
  ! grep -Fq 'stay in DRIVE until the matrix evidence exists' "$rover_root/skills/verify/SKILL.md"
}

@test "optional trim and reporting cannot become mandatory stop gates" {
  ! grep -Fq 'INSPECT cannot transition to STOW' "$rover_root/skills/trim/SKILL.md"
  ! grep -Fq 'without a pride log entry' "$main"
}

@test "loop persists cumulative limits without granting an unspecified budget" {
  grep -Fq 'budget_limit: not specified (no open-ended research authorized)' "$main"
  grep -Fq 'budget_used: record cumulative usage and accounting source' "$main"
  grep -Fq 'negative_stop_condition: specify before uncertain research' "$main"
  grep -Fq 'unmet criteria return to DRIVE for an authorized repair or verification route' "$main"
}
