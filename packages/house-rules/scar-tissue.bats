#!/usr/bin/env bats

setup() {
  SKILL="$BATS_TEST_DIRNAME/skills/scar-tissue/SKILL.md"
}

section() {
  local heading="$1"
  awk -v heading="$heading" '
    $0 == "## " heading { active = 1; next }
    active && /^## / { exit }
    active { print }
  ' "$SKILL"
}

@test "routing metadata names residue and handoff" {
  run ruby -ryaml -e '
    parts = File.read(ARGV.fetch(0)).split(/^---\s*$/)
    metadata = YAML.safe_load(parts.fetch(1))
    abort "wrong skill name" unless metadata.fetch("name") == "scar-tissue"
    description = metadata.fetch("description")
    abort "missing residue trigger" unless description.match?(/superseded residue/i)
    abort "missing diagnostic-test trigger" unless description.match?(/diagnostic test/i)
    abort "missing handoff trigger" unless description.match?(/before handoff/i)
  ' "$SKILL"
  [ "$status" -eq 0 ]
}

@test "cleanup preserves current responsibilities and readers" {
  run section "Catch it without creating ceremony"
  [ "$status" -eq 0 ]
  [[ "$output" =~ current[[:space:]]+failure[[:space:]]+mode ]] || return 1
  [[ "$output" =~ named[[:space:]]+current[[:space:]]+consumer ]] || return 1
  [[ "$output" =~ external[[:space:]]+reader ]] || return 1
}

@test "living docs describe current identity instead of lineage" {
  run section "Give living documents a present-tense identity"
  [ "$status" -eq 0 ]
  [[ "$output" =~ living[[:space:]]+README ]] || return 1
  [[ "$output" =~ Origin[[:space:]]+repositories ]] || return 1
  [[ "$output" =~ Git[[:space:]]+already[[:space:]]+owns[[:space:]]+lineage ]] || return 1
  [[ "$output" =~ explicit[[:space:]]+audit ]] || return 1
  [[ "$output" =~ named[[:space:]]+current[[:space:]]+reader ]] || return 1
}

@test "shared artifacts do not retain their editing worklog" {
  run section "Remove the worklog from the artifact"
  [ "$status" -eq 0 ]
  [[ "$output" =~ worklog ]] || return 1
  [[ "$output" =~ editing[[:space:]]+conversation ]] || return 1
  [[ "$output" =~ only[[:space:]]+current[[:space:]]+function ]] || return 1
  [[ "$output" =~ present-tense[[:space:]]+subject ]] || return 1
  [[ "$output" =~ audit ]] || return 1
}

@test "migration guidance leaves one canonical implementation" {
  run section "Migration without residue"
  [ "$status" -eq 0 ]
  [[ "$output" =~ canonical[[:space:]]+implementation ]] || return 1
  [[ "$output" =~ owning[[:space:]]+migration[[:space:]]+or[[:space:]]+deprecation[[:space:]]+protocol ]] || return 1
}
