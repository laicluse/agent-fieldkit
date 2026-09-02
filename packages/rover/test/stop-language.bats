#!/usr/bin/env bats

setup() {
  repo_root="$(cd "$BATS_TEST_DIRNAME/../../.." && pwd)"
  stop_skill="$repo_root/packages/rover/skills/stop/SKILL.md"
}

@test "stop keeps active conversation language over generated Dispatch" {
  grep -Fq "The communiqué follows the operator's active conversation language at stop" "$stop_skill"
  grep -Fq "An internally generated, normalized, or translated Dispatch is workflow scaffolding, not evidence that the operator changed language" "$stop_skill"
  grep -Fq "when the operator is speaking Dutch and the rover stores an English Dispatch, the communiqué remains Dutch" "$stop_skill"
}
