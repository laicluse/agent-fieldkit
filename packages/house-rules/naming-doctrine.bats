#!/usr/bin/env bats

@test "backlog names lead with human outcomes instead of implementation details" {
  doctrine="$BATS_TEST_DIRNAME/skills/naming-is-hard/references/naming-doctrine.md"

  run grep -F 'For backlog ideas, refinements, variants, and proposed slices, write for the product owner who may have no implementation context.' "$doctrine"
  [ "$status" -eq 0 ]

  run grep -F 'Lead with the observable human problem or desired outcome; move component names, hooks, commands, and technical causes into the description or grounding.' "$doctrine"
  [ "$status" -eq 0 ]
}

@test "epic boundaries separate product outcomes instead of components" {
  doctrine="$BATS_TEST_DIRNAME/skills/naming-is-hard/references/naming-doctrine.md"

  run grep -F 'An epic boundary should separate outcomes a product owner can steer independently, not components, repositories, technical layers, or implementation teams.' "$doctrine"
  [ "$status" -eq 0 ]
}

@test "precise domain terms beat generic gate jargon" {
  doctrine="$BATS_TEST_DIRNAME/skills/naming-is-hard/references/naming-doctrine.md"

  run grep -F 'Treat `gate` as a naming smell' "$doctrine"
  [ "$status" -eq 0 ]

  run grep -F 'This is a prompt to choose precisely, not a banned-word rule.' "$doctrine"
  [ "$status" -eq 0 ]
}
