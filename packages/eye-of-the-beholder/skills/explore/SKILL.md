---
name: explore
user-invocable: true
description: >-
  Explore a new visual treatment with image generation and real references. Show concrete proposals, resolve one consequential design decision per round, and establish an accepted visual target before implementation.
---

# Explore

## Establish the brief

Start with the current product and accepted reference images, not adjectives alone. Identify purpose, encoded meanings, simultaneous states, relevant scales and qualities that must survive. Separate fixed functional requirements from unresolved appearance. Do not prescribe rings, badges, lighting tricks or another mechanism before exploring what belongs in this visual world.

Ask only what changes the next visual decision and cannot be learned from the artifacts or conversation. The user can react to images without naming a style.

## Generate visual proposals

Resolve the real backend using [image generation across hosts](generation.md) before promising a generation round.

For genuinely new visual treatments, image generation is the default required exploration step. Read the available image-generation tool or skill instructions and use actual accepted reference images as inputs, not only a prose description. Verify that the tool received the intended images. Follow the user's explicit tool preferences. If image generation is unavailable, disclose the limitation and agree a fallback; do not silently substitute coding-model CSS, SVG or text-only options. Exact corrections and reuse of accepted components may skip this step.

Give each reference a role: current product, material, lighting, composition, interaction, or exact matching on named axes. Classify image inputs using [the protocol](../review/image-input/protocol.md). Exclude annotation and video-player chrome from product interpretation. Preserve the existing world unless redesigning it is explicitly in scope.

Show proposals in sufficient product context and at comparable scale and density. Use a family sheet for related or combined states so the model develops a coherent system. Label generated images as concepts: they are not screenshots of a working implementation. Open each generated image with the host image viewer and show the image itself in the conversation or shared artifact; a filename or a claim that it was generated is not a visual proposal. Inspect each result before presenting it for drift, impossible geometry, lost semantics or mislabeled states. Retain the original baseline and best earlier candidate. Prefer editing an accepted image when refining one decision.

## One decision per round

This limit concerns design decisions. Resolve blocking input classification, backend or display questions first; they are prerequisites, not additional design rounds. Bundle closely related factual gaps where that reduces effort.

1. Name the uncertainty that matters next. Choose the number and kind of proposals needed to expose it; there is no mandatory three-option format.
2. Generate, inspect and show the proposals. Describe visible differences and state which direction you would back and why. Do not mistake your recommendation for user acceptance.
3. Ask one consequential question and wait before dependent generation or implementation. Combinations and “none of these” are valid answers. Do not require a forced winner or design vocabulary.
4. Translate the reaction into the next constraint. Confirm only genuine ambiguity; an explicit decision needs no second approval.
5. After a failed round, reconsider the assumption that produced it. After two nonconverging aesthetic corrections, revisit the brief or references before another cosmetic variation. Do not keep narrowing a rejected direction. If a reframed round still produces no acceptable direction, pause further generation and identify the missing reference or decision with the user; do not restart the same loop indefinitely.

Judge the entire material world: silhouette, palette relationships, light, depth, composition and motion. Gradients, glow, rounded forms and decorative detail are not inherently defects. A generic anti-slop checklist is not a substitute for this user's target, and code checks cannot prove beauty.

## Make the handoff concrete

Once the user accepts a visual direction and implementation is authorized, save the accepted image or durable artifact link, its reference roles, the generation prompt and model/settings only where actually known. Record rejected decisions with their scope and reason so they do not return as new suggestions. Separate accepted appearance from unresolved mechanism or behavior. Never claim that acceptance of one implies acceptance of the other.

For a new record, use [the visual-language template](../define/templates/visual-language.md). Extend the project's canonical visual-language document instead of replacing it with a generic template. Include image anchors and a compact decision record: decision, status, image, rationale, scope, remaining uncertainty. Concepts and verified implementation captures must be distinguishable.

Specify the states to implement and verify, including simultaneous highlights, overview/detail scales, dense data and transitions where relevant. A still image cannot establish interaction or motion quality: after concept acceptance, build a small interactive study when needed, then review the actual implementation with [review](../review/SKILL.md). If a technical constraint would materially change the accepted appearance, show the compromise before treating it as accepted. Do not silently replace the target with the easiest implementation.

See [method and evidence](references.md) for provenance and limits. This workflow uses complementary tools; it does not assert universal aesthetic superiority of image models.
