---
name: eye-of-the-beholder
user-invocable: true
description: >-
  The entry point for visual and interaction design: requests to make something better, nicer, more beautiful, more convincing or clearer, new treatments, redesigns, design improvement loops and evaluations, unclear controls, excessive explanation, or feedback such as ugly, feels off, generic, looks AI-made, lelijk, or past niet. Routes usability repair, visual exploration and rendering review.
---

# Eye of the Beholder

Own the path from a visual or interaction request to a convincing result. The user brings purpose and taste; you bring proposals, evidence and technical execution. They should not need to pick a subskill or supply design vocabulary. Correct implementation does not establish aesthetic quality.

## Reason before routing

Decide from what this surface must do, not from what such surfaces usually look like: what must the viewer understand or decide, and in what order; which structure of attention does the task need; what belongs together and what contrasts; what is specific to this product, its content and its users; what can this medium do that a static picture cannot. When appearance is open or the request is to make something better, form a visible design hypothesis before polishing, and ask of every candidate which visible choice could only exist here. [Design reasoning](design-reasoning.md) is the canonical text for these questions and for how proposals, references and judgements are handled; every route applies it.

If a retired invocation appears as text, explain the migration and route it: taste-test to explore, art-director to define, fat-marker-sketch to review/image-input, visual-inspection to review/reference-match. These are internal routes, not promises that the host still recognizes retired commands.

## Start from evidence

Read the project's visual-language document and inspect the actual current render, accepted reference images and prior decisions. Classify supplied images with [the image-input protocol](../review/image-input/protocol.md); a capture filename is never match intent. Inspect the implementation for questions the code can answer. State the observable outcome, qualities to preserve and most consequential unresolved decision. Do not reinterview decisions already established in the conversation.

## Choose the route

| Situation | Route |
| --- | --- |
| Confusing controls, over-explaining UI, cognitive load or a task that requires avoidable interpretation | [obvious](../obvious/SKILL.md) |
| New visual treatment, explicitly unresolved appearance, a request to make an existing surface better, nicer or more convincing without a named defect, or a direction that remains rejected after diagnosis | [explore](../explore/SKILL.md) |
| Explicit identity work or missing foundations necessary for the current product decision | [define](../define/SKILL.md), which uses explore as needed |
| A first complaint about an existing render, exact correction, component reuse, rendering defect, or target verification | [review](../review/SKILL.md) |

For a first complaint such as “cramped” or “off”, review the actual render and diagnose the relevant axis before deciding that a new visual treatment is needed. Do not interpret every gut-word as a redesign request. A greenfield screen does not automatically require brand work.

A visual-language document does not resolve every future appearance. An available semantic channel is not an aesthetic recommendation. Genuinely new visual form needs a visible proposal even when its function is fully specified; explore chooses the medium that exposes the open question. Exact corrections and reuse do not need a concept round.

An automated improvement loop, evaluation or hill-climb on appearance follows the same order: an accepted design hypothesis first (user-accepted, or an agent decision under delegation), then a loop that refines it. Derive its judging criteria from [design reasoning](design-reasoning.md) and the accepted hypothesis, not from a list of forbidden techniques.

Discussion about this workflow stays discussion: mentioning image generation is not an instruction to generate a product design.

## Decide what gates the work

For an unresolved visual or consequential interaction choice, resolve one decision per round: show the evidence, state a defensible recommendation and wait before dependent work. A decision can change many variables at once. A rejection of every candidate is evidence, not a mandate to choose the least bad one.

When the user has delegated the design decisions, take them, record them as agent decisions with their reasoning, and show the result; never report an agent decision as user acceptance. An understood, already-authorized correction through obvious or review needs no new concept round.

Concept, mechanism and implementation approval are distinct. A general implementation go does not accept an unseen concept; an accepted concept lets already-requested implementation continue. Track accepted, rejected, provisional and unresolved decisions with scoped image references, carry an accepted direction through to the real render and review it, and keep the canonical visual-language record current. An exploration-only request ends at the concept decision. Follow repository rules for commits and publication.

<post-update-broadcast>
BEFORE starting the visual work, run this one-time check only when
`CLAUDE_PLUGIN_ROOT` is set:

```bash
if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; then
  node "${CLAUDE_PLUGIN_ROOT}/bin/check-broadcast"
fi
```

If the command produces output, the eye-of-the-beholder plugin was updated since
the last time you saw the broadcast on this machine. Show the output
verbatim in a markdown block, prefixed with one short sentence
("eye-of-the-beholder was updated; here is what changed."). Then continue with
the rest of this skill.

If the command produces no output, say nothing about updates and proceed.

The helper writes the sentinel only when stdout was non-empty, so a silent
run does not mark the version as seen. In agents that do not set
`CLAUDE_PLUGIN_ROOT` the broadcast is intentionally skipped; that is the
guard's purpose, not an oversight.
</post-update-broadcast>
