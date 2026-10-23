---
name: explore
description: >-
  Explore a new visual treatment or a better version of an existing surface. Form distinct design hypotheses from the product and real references, make them visible in the medium that exposes the open question, resolve one consequential decision per round, and establish an accepted target before implementation or polishing.
---

# Explore

Apply [design reasoning](../eye-of-the-beholder/design-reasoning.md) throughout.

## Establish the brief

Start with the current product and accepted reference images, not adjectives alone. Identify purpose, encoded meanings, simultaneous states, relevant scales and qualities that must survive. Separate fixed functional requirements from unresolved appearance. Do not prescribe rings, badges, lighting tricks or another mechanism before exploring what belongs in this visual world.

Ask only what changes the next visual decision and cannot be learned from the artifacts or conversation. The user can react to images without naming a style.

When no accepted direction exists, or the request is to make a surface better without a named defect, start with a design hypothesis rather than incremental fixes. Consult the [reference library](reference-library.md) and its recent draws first; when its coverage of this task is thin, or proposals keep resembling each other or the model's defaults, research references as design reasoning describes before the next round, and add what you learn.

## Make proposals visible

Choose the medium from the uncertainty. Image generation suits atmosphere, material, lighting and imagery. Real typography and layout studies in the target medium suit text-driven and layout-driven surfaces. Small interactive studies suit behavior, transitions and time. An image model has defaults of its own; a generated bitmap is not automatically a better proposal than a built one.

When using image generation, resolve the real backend using [image generation across hosts](generation.md) before promising a generation round. Read the tool or skill instructions and use actual accepted reference images as inputs, not only a prose description. Verify that the tool received the intended images. Follow the user's explicit tool preferences. If the medium you need is unavailable, disclose the limitation and agree a fallback. Exact corrections and reuse of accepted components may skip proposals entirely.

When the direction is open, the proposals must differ in idea, composition, typography, imagery or tempo; variations of one layout do not expose a direction. Before showing them, compare the candidates on information order, composition, typography, imagery and tempo and name the differences; near-identical geometry is a prompt to check whether two proposals are one hypothesis, not a numeric gate ([judging](../review/judging.md)).

Give each reference a role: current product, material, lighting, composition, interaction, or exact matching on named axes. Classify image inputs using [the protocol](../review/image-input/protocol.md). Exclude annotation and video-player chrome from product interpretation. Preserve the existing world unless redesigning it is explicitly in scope.

Show proposals in sufficient product context and at comparable scale and density. Use a family sheet for related or combined states so the model develops a coherent system. Label generated images as concepts: they are not screenshots of a working implementation. Open each generated image with the host image viewer and show the image itself in the conversation or shared artifact; a filename or a claim that it was generated is not a visual proposal. Inspect each result before presenting it for drift, impossible geometry, lost semantics or mislabeled states. Retain the original baseline and best earlier candidate. Prefer editing an accepted image when refining one decision.

## One decision per round

This limit concerns design decisions. Resolve blocking input classification, backend or display questions first; they are prerequisites, not additional design rounds. Bundle closely related factual gaps where that reduces effort.

1. Name the uncertainty that matters next. Choose the number and kind of proposals needed to expose it; there is no mandatory three-option format. One decision can change many variables at once: which direction deserves development is a single decision.
2. Make, inspect and show the proposals. Describe visible differences and state which direction you would back and why. Do not mistake your recommendation for user acceptance.
3. Ask one consequential question and wait before dependent proposals or implementation. Combinations and “none of these” are valid answers. Do not require a forced winner or design vocabulary. When the user has delegated the design decisions, decide, record the choice as an agent decision with its reasoning, and continue; show the result rather than asking.
4. Translate the reaction into the next constraint. Confirm only genuine ambiguity; an explicit decision needs no second approval.
5. After a failed round, reconsider the assumption that produced it. After two nonconverging aesthetic corrections, revisit the brief or references before another cosmetic variation. Do not keep narrowing a rejected direction. If a reframed round still produces no acceptable direction, pause further proposals and identify the missing reference or decision with the user; do not restart the same loop indefinitely.

Judge the entire material world: silhouette, palette relationships, light, depth, composition and motion. Gradients, glow, rounded forms and decorative detail are not inherently defects. A generic anti-slop checklist is not a substitute for this user's target, and code checks cannot prove beauty.

## Make the handoff concrete

Once a visual direction is accepted (by the user, or as a recorded agent decision under delegation) and implementation is authorized, save the accepted image or durable artifact link, its reference roles, the generation prompt and model/settings only where actually known. Record rejected decisions with their scope and reason so they do not return as new suggestions. Record the mechanisms drawn in the library's draw log, and the outcome on the entries that were applied. Separate accepted appearance from unresolved mechanism or behavior. Never claim that acceptance of one implies acceptance of the other.

For a new record, use [the visual-language template](../define/templates/visual-language.md). Extend the project's canonical visual-language document instead of replacing it with a generic template. Include image anchors and a compact decision record: decision, status, image, rationale, scope, remaining uncertainty. Concepts and verified implementation captures must be distinguishable.

Specify the states to implement and verify, including simultaneous highlights, overview/detail scales, dense data and transitions where relevant. A still image cannot establish interaction or motion quality: after concept acceptance, build a small interactive study when needed, then review the actual implementation with [review](../review/SKILL.md). If a technical constraint would materially change the accepted appearance, show the compromise before treating it as accepted. Do not silently replace the target with the easiest implementation.

See [method and evidence](references.md) for provenance and limits. This workflow uses complementary tools; it does not assert universal aesthetic superiority of image models.
