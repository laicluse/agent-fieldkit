---
name: review
description: >-
  Review actual visual output against its accepted references, meaning and behavior. Diagnose known defects, verify combinations and scales, and return unresolved aesthetics to exploration.
---

# Review

Inspect the actual render and accepted target before explaining code. Separate observations, hypotheses and measured facts. A passing test or correct semantic encoding does not prove aesthetic success.

Use [image-input](image-input/protocol.md) to classify captures and references, [reference-match](reference-match/protocol.md) when a distinct reference plus match intent or a named visual axis identifies what to reproduce, and [diagnostics](diagnostics.md) for complaint-to-axis and technical diagnosis. See [background references](references.md) when deeper diagnostic context is useful. These internal protocols are supporting references, not additional public commands. Scope their heuristics to the accepted visual language; do not impose unrelated aesthetic defaults.

If the actual render cannot be captured or inspected, disclose the specific limitation, continue useful diagnosis or capture setup, and do not report the result as visually verified.

Capture at presentation resolution with enough product context to understand the state and behavior. Compare equivalent scales and data. Do not enlarge a low-resolution crop and call it evidence. Show fresh evidence in the shared artifact, not just a temporary local file.

Assess separately:

- Meaning and behavior: each visual channel has a clear role; dependencies and combined states remain correct.
- Aesthetics: silhouette, materials, lighting, palette relationships, depth and composition belong to the accepted world.
- Fidelity: the implementation retains the accepted concept's defining qualities on the relevant axes.
- Interaction: density, zoom, selection combinations, transitions and motion remain legible and stable in the real runtime.

Success on one dimension cannot compensate for failure on another. Point to concrete regions and visible differences. Do not invent aesthetic scores or infer measured colors from visual guesses. Independent review can challenge a reading, but agreement among uncalibrated reviewers is not evidence of user acceptance.

For a known defect, fix the demonstrated cause, render again and compare with both the target and best prior version. For an unresolved or repeatedly rejected direction, return to [explore](../explore/SKILL.md). Do not continue adding decoration to avoid reconsidering the premise.

Report what was verified and what remains uncertain. Update the canonical visual-language record and image links with the current accepted rendering. Keep rejected treatments clearly scoped and excluded from future recommendations unless the user explicitly reopens them.
