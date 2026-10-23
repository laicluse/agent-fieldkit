---
name: review
description: >-
  Review actual visual output against its accepted references, meaning and behavior. Diagnose known defects, verify combinations and scales, and return unresolved aesthetics to exploration.
---

# Review

Inspect the actual render and accepted target before explaining code. Separate observations, hypotheses and measured facts. A passing test or correct semantic encoding does not prove aesthetic success. Judge with [design reasoning](../eye-of-the-beholder/design-reasoning.md); a review without an accepted target can find defects but cannot establish that a surface is convincing.

Before reviewing a change, inventory what it can reach: shared components and tokens, the surfaces that use them, states, breakpoints and transitions. A surface outside the sample you were optimizing for still has to be looked at when a shared primitive under it changed.

Use [image-input](image-input/protocol.md) to classify captures and references, [reference-match](reference-match/protocol.md) when a distinct reference plus match intent or a named visual axis identifies what to reproduce, and [diagnostics](diagnostics.md) for complaint-to-axis and technical diagnosis. See [background references](references.md) when deeper diagnostic context is useful. These internal protocols are supporting references, not additional public commands. Scope their heuristics to the accepted visual language; do not impose unrelated aesthetic defaults.

If the actual render cannot be captured or inspected, disclose the specific limitation, continue useful diagnosis or capture setup, and do not report the result as visually verified.

Capture at presentation resolution with enough product context to understand the state and behavior. Compare equivalent scales and data. Do not enlarge a low-resolution crop and call it evidence. Show fresh evidence in the shared artifact, not just a temporary local file.

Motion evidence must be playable by its recipient outside the capture browser (H.264 MP4, `yuv420p`, fast-start for ordinary desktop handoff; verify the delivered file) and must preserve the timing being judged: measure the displayed frame rate during the recorded interaction and report it. See [motion pitfalls](pitfalls/motion.md).

When explanations compensate for unclear controls, hidden state or avoidable choices, use [obvious](../obvious/SKILL.md) to reconsider the interaction before polishing its copy. Do not turn an exact visual correction into an unrelated usability redesign.

Assess separately:

- Meaning and behavior: each visual channel has a clear role; dependencies and combined states remain correct.
- Aesthetics: silhouette, materials, lighting, palette relationships, depth and composition belong to the accepted world.
- Fidelity: the implementation retains the accepted concept's defining qualities on the relevant axes.
- Interaction: density, zoom, selection combinations, transitions and motion remain legible and stable in the real runtime.

Success on one dimension cannot compensate for failure on another. Point to concrete regions and visible differences. Do not invent aesthetic scores or infer measured colors from visual guesses. Independent review can challenge a reading; when judges compare candidates, follow [judging](judging.md), and remember that agreement among uncalibrated reviewers is not evidence of user acceptance. When a reviewed mechanism came from the [reference library](../explore/reference-library.md), record the outcome on its entry.

For a known defect, fix the demonstrated cause, then review the whole visible surface in the fresh render, not only the changed or reported region. Exercise the states that can change the meaning of the touched surface; for repeated-object interfaces this includes populated, partial and empty content plus the transition to the next item. A control or affordance without content or a useful outcome is a defect, even when it was outside the original callout.

After two operator corrections on the same visual surface, stop point-fixing and reopen the premise before another implementation pass. Re-establish the user's task, the information that must survive repeated use, and the relevant state matrix; then review the full surface from that model. For an unresolved or repeatedly rejected direction, return to [explore](../explore/SKILL.md). Do not continue adding decoration to avoid reconsidering the premise.

Report what was verified and what remains uncertain. Update the canonical visual-language record and image links with the current accepted rendering. Keep rejected treatments clearly scoped and excluded from future recommendations unless the user explicitly reopens them.
