#!/usr/bin/env bats

setup() {
  export LAICLUSE_HOME="$BATS_TEST_TMPDIR/home"
  TASTE="$BATS_TEST_DIRNAME/../bin/taste"
}

@test "a verdict is recorded once, with the user's words unchanged" {
  run node "$TASTE" record --aspect colour --choice no --words "altijd beige" --surface "planning board" --scope everywhere --host claude --at 2026-11-24
  [ "$status" -eq 0 ]
  run node "$TASTE" record --aspect colour --choice no --words "altijd beige" --surface "planning board" --scope everywhere --host codex --at 2026-11-24
  [[ "$output" == "already on record" ]]
  [ "$(wc -l < "$LAICLUSE_HOME/slow-taste/evidence/eye-of-the-beholder.jsonl")" -eq 1 ]
  grep -q '"note":"altijd beige"' "$LAICLUSE_HOME/slow-taste/evidence/eye-of-the-beholder.jsonl"
}

@test "the same words about another part or product are a separate verdict" {
  node "$TASTE" record --aspect type --choice yes --words "ja" --subject "the heading" --project gifts --at 2026-11-24
  node "$TASTE" record --aspect type --choice yes --words "ja" --subject "the table" --project gifts --at 2026-11-24
  node "$TASTE" record --aspect colour --choice yes --words "ja" --subject "the heading" --project gifts --at 2026-11-24
  node "$TASTE" record --aspect type --choice yes --words "ja" --subject "the heading" --project ledger --at 2026-11-24
  [ "$(wc -l < "$LAICLUSE_HOME/slow-taste/evidence/eye-of-the-beholder.jsonl")" -eq 4 ]
}

@test "a damaged line does not stop recording or recall" {
  mkdir -p "$LAICLUSE_HOME/slow-taste/evidence"
  printf '{"id":"broken' > "$LAICLUSE_HOME/slow-taste/evidence/eye-of-the-beholder.jsonl"
  run node "$TASTE" record --aspect colour --choice no --words "altijd beige" --scope everywhere
  [ "$status" -eq 0 ]
  run node "$TASTE" recall
  [ "$status" -eq 0 ]
  [[ "$output" == *"altijd beige"* && "$output" == *"skipped 1 unreadable"* ]]
}

@test "the copy Codex receives runs on its own" {
  repo="$(cd "$BATS_TEST_DIRNAME/../.." && cd .. && pwd)"
  generated="$repo/.agents/plugins/generated/eye-of-the-beholder/bin/taste"
  [ -x "$generated" ]
  run "$generated" recall
  [ "$status" -eq 0 ]
}

@test "a verdict about one product needs that product's name" {
  run node "$TASTE" record --aspect space --choice steer --words "hier 12 px"
  [ "$status" -eq 1 ]
  [[ "$output" == *"--scope project needs --project"* ]]
}

@test "recall separates what holds here from what was said about another surface" {
  node "$TASTE" record --aspect colour --choice no --words "altijd beige" --scope everywhere --at 2026-11-24
  node "$TASTE" record --aspect space --choice steer --words "hier 12 px" --project ledger --reading "tight padding" --at 2026-11-04
  node "$TASTE" record --aspect type --choice no --words "rare fontjes" --project gifts --at 2026-11-24
  run node "$TASTE" recall --project gifts
  [ "$status" -eq 0 ]
  holds="${output%%## Said about one other surface*}"
  hints="${output#*## Said about one other surface}"
  [[ "$holds" == *"altijd beige"* && "$holds" == *"rare fontjes"* && "$holds" != *"hier 12 px"* ]]
  [[ "$hints" == *"hier 12 px"* && "$hints" == *"reading: tight padding"* ]]
  [[ "$output" != *"ledger"* ]]
}

@test "recall can be narrowed to aspects and says so when nothing is on record" {
  run node "$TASTE" recall
  [[ "$output" == *"No design verdicts"* ]]
  node "$TASTE" record --aspect colour --choice no --words "altijd beige" --scope everywhere
  node "$TASTE" record --aspect type --choice no --words "rare fontjes" --scope everywhere
  run node "$TASTE" recall --aspect type
  [[ "$output" == *"rare fontjes"* && "$output" != *"altijd beige"* ]]
}

@test "an imported file can be imported again without duplicates" {
  printf '[{"aspect":"colour","choice":"no","words":"altijd beige","scope":"everywhere","at":"2026-11-24"}]' > "$BATS_TEST_TMPDIR/seed.json"
  run node "$TASTE" import "$BATS_TEST_TMPDIR/seed.json" --host claude
  [[ "$output" == "1 recorded, 0 already on record" ]]
  run node "$TASTE" import "$BATS_TEST_TMPDIR/seed.json" --host claude
  [[ "$output" == "0 recorded, 1 already on record" ]]
}

@test "every design route recalls the user's taste and a judge sees a new look first" {
  skills="$BATS_TEST_DIRNAME/../skills"
  for skill in eye-of-the-beholder explore review unslop define obvious; do
    grep -q "taste.md" "$skills/$skill/SKILL.md"
  done
  grep -q "judge.md" "$skills/review/SKILL.md"
  grep -q "judge.md" "$skills/unslop/SKILL.md"
  grep -q "Their words go in unchanged" "$skills/eye-of-the-beholder/taste.md"
  grep -q "Never write the user's words" "$skills/eye-of-the-beholder/taste.md"
  grep -q "without your reasoning" "$skills/review/judge.md"
  grep -q "Insufficient evidence" "$skills/review/judge.md"
}

@test "a design decision follows the rules of its plane or breaks them on purpose" {
  skills="$BATS_TEST_DIRNAME/../skills"
  grep -q "break them on purpose" "$skills/eye-of-the-beholder/design-reasoning.md"
  grep -q "Anything that looks unintended is a defect" "$skills/eye-of-the-beholder/design-reasoning.md"
  for plane in typography colour space motion icons wording; do
    grep -q "foundations/$plane.md" "$skills/eye-of-the-beholder/design-reasoning.md"
    grep -q "An oversight looks like" "$skills/eye-of-the-beholder/foundations/$plane.md"
    grep -q "^## Sources" "$skills/eye-of-the-beholder/foundations/$plane.md"
  done
  grep -q "foundations/typography.md" "$skills/unslop/SKILL.md"
  grep -q "foundations/colour.md" "$skills/unslop/SKILL.md"
  grep -q "they are met, not weighed" "$skills/eye-of-the-beholder/design-reasoning.md"
}
