---
name: eye-of-the-beholder
description: >-
  The entry point for visual design: new visual elements, redesigns, or feedback such as ugly, unpleasing, feels off, lelijk, or past niet. Leads image-based exploration and one-decision-at-a-time collaboration, then verifies the real implementation.
---

# Eye of the Beholder

Own the path from a visual request to a convincing result. The user brings purpose and taste; you bring proposals, evidence and technical execution. They should not need to pick a subskill or supply design vocabulary. Correct implementation does not establish aesthetic quality.

If a retired invocation appears as text, explain the migration and route it: taste-test to explore, art-director to define, fat-marker-sketch to review/image-input, visual-inspection to review/reference-match. These are internal routes, not promises that the host still recognizes retired commands.

## Start from evidence

Read the project's visual-language document and inspect the actual current render, accepted reference images and prior decisions. Classify supplied images with [the image-input protocol](../review/image-input/protocol.md); a capture filename is never match intent. Inspect the implementation for questions the code can answer. State the observable outcome, qualities to preserve and most consequential unresolved decision. Do not reinterview decisions already established in the conversation.

## Choose the route

| Situation | Route |
| --- | --- |
| New visual treatment, explicitly unresolved appearance, or a direction that remains rejected after diagnosis | [explore](../explore/SKILL.md) |
| Explicit identity work or missing foundations necessary for the current product decision | [define](../define/SKILL.md), which uses explore as needed |
| A first complaint about an existing render, exact correction, component reuse, rendering defect, or target verification | [review](../review/SKILL.md) |

For a first complaint such as “cramped” or “off”, review the actual render and diagnose the relevant axis before deciding that a new visual treatment is needed. Do not interpret every gut-word as a redesign request. A greenfield screen does not automatically require brand work.

A visual-language document does not resolve every future appearance. An available semantic channel is not an aesthetic recommendation. Use image generation for genuinely new visual form even when its function is fully specified. Exact corrections and reuse do not need a concept round.

Discussion about this workflow stays discussion: mentioning image generation is not an instruction to generate a product design.

## Keep the collaboration continuous

Resolve one consequential design decision per round. Show the relevant visual evidence, state a defensible recommendation and wait for the user's response before dependent work. Adapt the next round to that response. A rejection of every candidate is useful evidence, not a mandate to choose the least bad one.

Track accepted, rejected, provisional and unresolved decisions with scoped image references. Distinguish concept approval, mechanism approval and implementation approval. Your own recommendation is not the user's acceptance. A general implementation go does not make an unseen concept accepted. Conversely, when implementation was already requested, accepting the relevant concept lets that authorized implementation continue without asking for another go. Ask only about an unresolved decision or changed scope.

When implementation is authorized and the visual direction is accepted, carry the chosen target through to the actual render and review it. Keep the canonical visual-language record and visible evidence current. An exploration-only request ends with the concept decision; it does not authorize implementation. Follow repository rules for commits and publication.

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
