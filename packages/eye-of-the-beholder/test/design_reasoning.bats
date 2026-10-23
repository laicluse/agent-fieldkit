#!/usr/bin/env bats

SKILLS="$BATS_TEST_DIRNAME/../skills"

@test "every public skill applies the shared design reasoning" {
  for skill in eye-of-the-beholder explore review define obvious; do
    grep -q 'design-reasoning.md' "$SKILLS/$skill/SKILL.md" || return 1
  done
}

@test "design reasoning designs toward quality instead of defending against defects" {
  run node - "$SKILLS/eye-of-the-beholder/design-reasoning.md" <<'NODE'
const fs = require("fs");
const text = fs.readFileSync(process.argv[2], "utf8");
const required = [
  /hypothesis/i,
  /could only exist here/i,
  /one variable per round/i,
  /record its source and when you observed it/i,
  /keep every difference that actually causes the effect/i,
  /every variant of a changed shared primitive/i,
  /motion over its whole sequence/i,
  /swap presentation order[^.]*allow ties/i,
  /novel[^.]*appealing[^.]*fit/i,
];
for (const rule of required) {
  if (!rule.test(text)) throw new Error(`missing reasoning: ${rule}`);
}
if (/\b(Inter|Roboto|Helvetica|60-30-10|indigo)\b/.test(text)) {
  throw new Error("design reasoning names a concrete style default");
}
NODE
  [ "$status" -eq 0 ]
}

@test "the entry point triggers on requests to improve, not only on complaints" {
  run node - "$SKILLS/eye-of-the-beholder/SKILL.md" <<'NODE'
const fs = require("fs");
const text = fs.readFileSync(process.argv[2], "utf8");
const description = text.match(/^description: >-\n([\s\S]*?)\n---/m);
if (!description) throw new Error("description missing");
for (const word of ["better", "more beautiful", "improvement loops", "looks AI-made"]) {
  if (!description[1].includes(word)) throw new Error(`description does not trigger on: ${word}`);
}
if (!/hypothesis first, then a loop that refines it/.test(text)) throw new Error("design loops are not ordered behind a hypothesis");
NODE
  [ "$status" -eq 0 ]
}

@test "exploration chooses the medium from the open question" {
  run node - "$SKILLS/explore/SKILL.md" "$SKILLS/define/templates/visual-foundations.md" <<'NODE'
const fs = require("fs");
const explore = fs.readFileSync(process.argv[2], "utf8");
const template = fs.readFileSync(process.argv[3], "utf8");
if (/default required exploration step/.test(explore)) throw new Error("image generation is still mandatory for every new form");
if (!/Choose the medium from the uncertainty/.test(explore)) throw new Error("explore does not choose a medium");
if (/\bInter\b|60-30-10/.test(template)) throw new Error("the foundations template still steers toward a style default");
NODE
  [ "$status" -eq 0 ]
}
