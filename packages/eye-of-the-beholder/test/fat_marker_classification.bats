#!/usr/bin/env bats

SKILL="$BATS_TEST_DIRNAME/../skills/fat-marker-sketch/SKILL.md"

@test "incoming images are classified before a workflow is selected" {
  run node - "$SKILL" <<'NODE'
const fs = require("fs");
const skill = fs.readFileSync(process.argv[2], "utf8");

const requiredDistinctions = [
  "Annotated screenshot",
  "Low-fidelity sketch",
  "Design artifact or reference",
  "provenance hint",
];

for (const distinction of requiredDistinctions) {
  if (!skill.includes(distinction)) {
    throw new Error(`missing image classification distinction: ${distinction}`);
  }
}

if (!/filename[^.]*never[^.]*verdict/i.test(skill)) {
  throw new Error("filename provenance is not bounded as a hint rather than a verdict");
}
NODE
  [ "$status" -eq 0 ]
}

@test "annotated screenshots are not renamed fat-marker sketches" {
  run node - "$SKILL" <<'NODE'
const fs = require("fs");
const skill = fs.readFileSync(process.argv[2], "utf8");

const obsoleteDefaults = [
  "Almost every image a non-designer uploads is a *fat marker sketch*",
  "An uploaded image is a fat-marker sketch unless the user earns the exception",
  "Reading this upload as a fat marker sketch (no match-intent stated)",
];

for (const obsoleteDefault of obsoleteDefaults) {
  if (skill.includes(obsoleteDefault)) {
    throw new Error(`obsolete universal sketch default remains: ${obsoleteDefault}`);
  }
}
NODE
  [ "$status" -eq 0 ]
}
