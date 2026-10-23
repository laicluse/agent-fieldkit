#!/usr/bin/env bats

SKILLS="$BATS_TEST_DIRNAME/../skills"

@test "every public skill applies the shared design reasoning" {
  for skill in eye-of-the-beholder explore review define obvious; do
    grep -q 'design-reasoning.md' "$SKILLS/$skill/SKILL.md" || return 1
  done
}

@test "the entry point carries the reasoning questions in its own body" {
  run node - "$SKILLS/eye-of-the-beholder/SKILL.md" <<'NODE'
const fs = require("fs");
const text = fs.readFileSync(process.argv[2], "utf8");
for (const rule of [/structure of attention/, /could only exist here/, /design hypothesis before polishing/, /agent decisions? with their reasoning/]) {
  if (!rule.test(text)) throw new Error(`router body lacks: ${rule}`);
}
NODE
  [ "$status" -eq 0 ]
}

@test "design reasoning designs toward quality instead of defending against defects" {
  run node - "$SKILLS/eye-of-the-beholder/design-reasoning.md" <<'NODE'
const fs = require("fs");
const text = fs.readFileSync(process.argv[2], "utf8");
const required = [
  /hypothesis/i,
  /could only exist here/i,
  /Conventional controls need not become unique/,
  /one variable per round/i,
  /record its source and when you observed it/i,
  /reference-library\.md/,
  /kept or rejected/,
  /keep every difference that actually causes the effect/i,
  /every variant of a changed shared primitive/i,
  /motion over its whole sequence/i,
  /judging\.md/,
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
if (!/hypothesis first[^.]*then a loop that refines it/.test(text)) throw new Error("design loops are not ordered behind a hypothesis");
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
if (/\bInter\b|60-30-10|8 px radius|280 ms/.test(template)) throw new Error("the foundations template still steers toward a style default");
NODE
  [ "$status" -eq 0 ]
}

@test "the reference library is a dated memory with outcomes, not a quota" {
  run node - "$SKILLS/explore/reference-library.md" "$SKILLS/explore/SKILL.md" <<'NODE'
const fs = require("fs");
const library = fs.readFileSync(process.argv[2], "utf8");
const explore = fs.readFileSync(process.argv[3], "utf8");
for (const rule of [/observed:/, /designed:/, /mechanism:/, /depends_on:/, /expected <…>; saw <…>; kept \| rejected/, /draws\.md/, /habit to examine, not a prohibition/, /not fresh design/, /Do not add to meet a quota/, /never enters the shared library/]) {
  if (!rule.test(library)) throw new Error(`library lacks: ${rule}`);
}
if (!/reference-library\.md/.test(explore)) throw new Error("explore does not consult the library");
if (!/draw log/.test(explore)) throw new Error("explore does not record draws");
NODE
  [ "$status" -eq 0 ]
}

@test "judging is calibrated and never a numeric diversity gate" {
  run node - "$SKILLS/review/judging.md" "$BATS_TEST_DIRNAME/calibration/README.md" <<'NODE'
const fs = require("fs");
const judging = fs.readFileSync(process.argv[2], "utf8");
const calibration = fs.readFileSync(process.argv[3], "utf8");
for (const rule of [/Abstract labels/, /Both orders/, /Ties allowed/, /different bias profiles/, /Decide exclusion rules on calibration pairs before the round/, /not as a numeric gate/, /checks run before the round, not preferences/, /test\/calibration/]) {
  if (!rule.test(judging)) throw new Error(`judging lacks: ${rule}`);
}
for (const rule of [/verdict\.md/, /tie/, /motion pair/, /both orders/]) {
  if (!rule.test(calibration)) throw new Error(`calibration README lacks: ${rule}`);
}
NODE
  [ "$status" -eq 0 ]
}

@test "diagnostics is an observation method with pitfalls loaded per axis" {
  run node - "$SKILLS/review/diagnostics.md" "$SKILLS/review/pitfalls" <<'NODE'
const fs = require("fs");
const path = require("path");
const text = fs.readFileSync(process.argv[2], "utf8");
const words = text.split(/\s+/).length;
if (words > 1800) throw new Error(`diagnostics is ${words} words; keep it an observation method`);
for (const axis of ["space", "depth", "color", "motion", "copy"]) {
  if (!text.includes(`pitfalls/${axis}.md`)) throw new Error(`diagnostics does not route to pitfalls/${axis}.md`);
  const file = fs.readFileSync(path.join(process.argv[3], `${axis}.md`), "utf8");
  if (!/Competing explanations/.test(file)) throw new Error(`${axis} pitfalls lack the symptom/explanations/check/move form`);
}
if (/113%|2-5% upward|every visual element must contribute/i.test(text)) throw new Error("diagnostics still carries a style rule as a diagnosis");
NODE
  [ "$status" -eq 0 ]
}

@test "delegated decisions carry through explore and the loop rule" {
  run node - "$SKILLS/explore/SKILL.md" "$SKILLS/eye-of-the-beholder/SKILL.md" <<'NODE'
const fs = require("fs");
const explore = fs.readFileSync(process.argv[2], "utf8");
const router = fs.readFileSync(process.argv[3], "utf8");
if (!/delegated the design decisions, decide, record the choice as an agent decision/.test(explore)) throw new Error("explore still waits for the user under delegation");
if (!/as a recorded agent decision under delegation/.test(explore)) throw new Error("explore's handoff requires user acceptance only");
if (!/agent decision under delegation/.test(router)) throw new Error("the loop rule requires user acceptance only");
NODE
  [ "$status" -eq 0 ]
}

@test "the library treats age as a signal and keeps project identity out" {
  run node - "$SKILLS/explore/reference-library.md" <<'NODE'
const fs = require("fs");
const text = fs.readFileSync(process.argv[2], "utf8");
if (!/Age is a signal, not a gate/.test(text)) throw new Error("library has a calendar gate");
if (/at least one observed in the last twelve months\?/.test(text)) throw new Error("coverage requires a recent observation");
if (!/anonymised/.test(text)) throw new Error("shared outcomes may carry project identity");
NODE
  [ "$status" -eq 0 ]
}

@test "calibration separates defect pairs from preference pairs and the practice test has its briefs" {
  run node - "$SKILLS/review/judging.md" "$BATS_TEST_DIRNAME/calibration/README.md" "$BATS_TEST_DIRNAME/practice" <<'NODE'
const fs = require("fs");
const path = require("path");
const judging = fs.readFileSync(process.argv[2], "utf8");
const calibration = fs.readFileSync(process.argv[3], "utf8");
if (!/defect pairs[\s\S]*preference pairs/.test(judging)) throw new Error("judging does not separate defect from preference calibration");
if (!/kind: defect/.test(calibration) || !/kind: preference/.test(calibration)) throw new Error("calibration README does not label pair kinds");
const readme = fs.readFileSync(path.join(process.argv[4], "README.md"), "utf8");
for (const brief of ["marketing", "dense-work-ui", "quiet-text", "motion"]) {
  const file = path.join(process.argv[4], "briefs", `${brief}.md`);
  if (!fs.existsSync(file)) throw new Error(`missing brief ${brief}`);
  const text = fs.readFileSync(file, "utf8");
  if (!/## Domains/.test(text) || !/## Acceptance criteria/.test(text)) throw new Error(`brief ${brief} lacks domains or acceptance criteria`);
}
if (!/restore it before every run/.test(readme)) throw new Error("practice runs do not start from the same library state");
NODE
  [ "$status" -eq 0 ]
}

@test "obvious decides an action's space from its task, not its markup" {
  run node - "$SKILLS/obvious/SKILL.md" <<'NODE'
const fs = require("fs");
const text = fs.readFileSync(process.argv[2], "utf8");
for (const rule of [
  /earns no dialog or page of its own/,
  /modal when blocking helps/,
  /own task space, a page or a cell/,
  /not from the HTML element, the number of fields/,
  /repeat often belongs on the main surface/,
  /confirmations, errors, feedback and focus return stay with the action/,
  /nngroup\.com\/articles\/modal-nonmodal-dialog/,
  /carbondesignsystem\.com\/building-blocks\/core\/components\/modal\/guidelines/,
  /design-system\.service\.gov\.uk\/components\/button/,
]) {
  if (!rule.test(text)) throw new Error(`obvious lacks: ${rule}`);
}
NODE
  [ "$status" -eq 0 ]
}
