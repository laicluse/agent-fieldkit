#!/usr/bin/env bats

SKILL="$BATS_TEST_DIRNAME/../skills/review/SKILL.md"
DIAGNOSTICS="$BATS_TEST_DIRNAME/../skills/review/diagnostics.md"

@test "review closes over the whole visible surface rather than the edited region" {
  run node - "$SKILL" "$DIAGNOSTICS" <<'NODE'
const fs = require('node:fs');
const skill = fs.readFileSync(process.argv[2], 'utf8');
const diagnostics = fs.readFileSync(process.argv[3], 'utf8');
const contract = `${skill}\n${diagnostics}`;

const required = [
  /whole (visible )?(surface|viewport)/i,
  /not (only|just) the (changed|edited|reported)/i,
  /empty[^.]*partial[^.]*populated/i,
  /transition[^.]*next (item|object|candidate)/i,
  /affordance[^.]*content/i,
  /two[^.]*correction[^.]*premise/i,
];

for (const rule of required) {
  if (!rule.test(contract)) throw new Error(`missing review closure rule: ${rule}`);
}
NODE
  [ "$status" -eq 0 ]
}
