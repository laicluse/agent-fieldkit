# Calibration pairs

Known human verdicts that a judge round must reproduce before its verdicts on new candidates are trusted. See [judging](../../skills/review/judging.md).

## Why this set exists

A judge round without an anchor measures nothing: it may be reporting position bias, a shared model default, or taste the operator does not hold. Running the judges on these pairs first, and reporting their agreement with the human verdicts, turns a round into evidence about one decision for these judges.

## What a pair is

One directory per pair, `NNN-<slug>/`, containing:

- `brief.md`: the task the surface serves, the constraints, the references the candidates were made against, and the decision the pair isolates.
- `a.png` and `b.png` (or `a.mp4` and `b.mp4` for motion pairs, judged on recordings, never on stills).
- `verdict.md`: the human verdict (`a`, `b` or `tie`), the visible difference it rests on, who judged and when, and the recorded disagreement when judges disagreed. A tie with a reason is a valid verdict.

Candidates must be the operator's own work or redistributable; nothing enters this set that cannot be published with the plugin.

## Composition

Keep the set small and deliberate, and label each pair by kind in `brief.md`: `kind: defect` when one candidate fails an observable requirement (tests whether a judge sees defects), or `kind: preference` when both pass the checks (tests whether preferences track the humans'). Report the two kinds separately; agreement on defect pairs proves nothing about preference. Among preference pairs include equally good different solutions (a named tie) and at least one motion pair. Avoid pairs that differ only in polish of the same idea; the set should also test whether a judge recognises two hypotheses.

## Using the set

Run every judge on every pair in both orders. Report, per judge: agreement with the human verdict, flips between orders, ties and abstentions. Decide exclusion rules on this set before judging new candidates. Calibration proves agreement with these people on these tasks; it does not prove taste.

The set ships empty. The first pairs come from the practice test in `../practice/`.
