---
name: taste-test
user-invocable: true
description: Elicit a visual direction from someone who has taste but cannot describe it, by showing divergent options and reading their gut reaction instead of asking them to specify. Use when the user says something looks off but cannot say why, asks to make something "nicer" or "more modern" without specifics, or a new screen has no established direction yet.
---

# Taste test

## The real problem

The user knows what they like when they see it and cannot draw it or name it. Asking them to describe the direction ("what feel are you going for? what colors? what typography?") pushes the burden onto the exact skill they lack, and the answer comes back in gut-words: "cleaner", "not so busy", "more 2026", "less cheap". Those words are real signal, but they are a reaction, not a spec, and building straight off them produces the generic default the model reaches for when under-directed. That default is AI slop, and it is precisely what the user will bounce.

The standard design move here is to show, not ask. Several established methods work this way: a timed gut test (show samples, score on instinct, and the time pressure surfaces the honest reaction), style tiles (Samantha Warren's deliverable for when a moodboard is too vague and a mockup too literal), and desirability reaction cards (offer a controlled vocabulary and have the person point instead of producing words themselves). All invert the language direction: the person selects, they do not compose. This skill brings that inversion to the agent. You show; the user points; the direction falls out of what they point at.

## When

**Activate:**

- The user reacts to something with a gut-word and no specification: "I don't like it", "it looks off", "too busy", "make it nicer", "more modern", "feels cheap".
- A new screen, page, or feature has no established visual direction yet and the user cannot describe one.
- The same complaint has survived a second unimproved round of pixel-level iteration and the work needs a direction reset (eye-of-the-beholder's convergence guard routes here).

**Do not activate:**

- The user named a concrete axis to match against a reference ("same radius as the favicon"). That is visual-inspection.
- The user uploaded an image as a cue. Classify and read it with fat-marker-sketch first; an annotated screenshot and an actual low-fidelity sketch carry different evidence. That skill may then route here when the direction remains open.
- This is a whole new product or brand with no identity at all, and the ask is brand-level. That is art-director, which works one level up and once.
- The change is a single measurable tweak on an existing, agreed direction ("this gap is too tight"). That is eye-of-the-beholder plus the build-time discipline.
- The complaint is "cheap", "generic", or "looks AI-made" about an existing rendered result. Run eye-of-the-beholder's credibility scan first: removing the vibe-coded tells (gradients, bordered-card grids, status dots, one-font defaults) is cheap and often enough. Escalate to a variant fan only when that scan does not converge, or when there is no rendered starting point yet to scan. A full fan is the expensive move; do not reach for it before the cheap one when a render already exists.

## The core: show, do not ask

The move is always the same. Instead of asking the user to specify a direction, you produce divergent candidates and let them react. Their reaction is the specification. Three tools, used in order or in combination.

### 1. The variant fan

Render 3 to 5 genuinely divergent directions of the same thing, side by side, and let the user pick and react. The discipline that makes this work:

- **Divergent, not tints of one.** Five shades of the same layout is not a fan; it is one direction with noise. Each variant must commit to a different *stance*: a different type personality, a different density, a different structural metaphor, a different amount of color. If a stranger could not tell them apart in a sentence each, they are too close.
- **Each variant is a position, not a compromise.** Do not hedge. One variant leans editorial and quiet, one leans dense and technical, one leans warm and soft. The point is to span the space so the user's pick is informative. A safe middle option in every slot wastes the fan.
- **Label each with its stance in a few words**, so the reaction attaches to a nameable thing: "A: quiet editorial", "B: dense technical", "C: warm consumer". When the user says "B, but calmer", you have learned two coordinates at once.
- **Render, do not describe.** A fan the user cannot see is not a fan. Produce the actual rendered options (real components, real type, real color) and show them. If you cannot render, that is the same blocker as any other unrendered visual work: arrange a way to render before continuing.
- **Budget the operator's attention, not only your compute.** Rendering is cheap for you; forming and voicing a judgment is the operator's scarce resource, and that scarcity was the whole premise. When the direction is only slightly uncertain, show one best-guess render plus a light reaction prompt instead of a full fan. Reserve the 3-to-5 fan for when the direction is genuinely absent. And if a fan round does not produce a confident pick, do not spin another fan: that is the signal to stop and ask one direct question, not to keep generating.

The user's pick, plus their one-line reaction to it, is worth more direction than a paragraph of interview answers.

### 2. Reaction-card axes

When the user struggles even to react, hand them the words. Offer a small set of word-axes and have them point at where on each axis the thing should sit. This is the reaction-card inversion: they select from an offered vocabulary instead of producing one.

Offer axes like:

- calm <-> energetic
- quiet <-> bold
- warm <-> clinical
- playful <-> serious
- soft <-> sharp
- dense <-> airy
- retro <-> current
- premium <-> utilitarian

The user marks a point on each axis that matters. "Calm, warm, current, airy" is a direction you can build against; it took them ten seconds and no design vocabulary. Do not offer all axes at once; pick the four or five that the decision actually turns on. The axes double as the seed for the variant fan: the poles tell you which stances to span.

### 3. The contemporary harvest

To make something read as current without it reading as generic, gather how real, credible products in the same genre solve this *right now*, and extract the *moves*, not the pixels. This is the difference between informed-by and copied-from.

- **Gather exemplars.** Look at how respected products in the adjacent category handle the same problem today. The session's research tools (web search, fetching real product pages) surface current work; the model's memory does not, because "current" changes and memory lags.
- **Extract moves, not pixels.** A move is a transferable decision: "they group with whitespace and a hairline instead of boxed cards", "values are set in tabular mono", "one accent color, used only on the primary action". Name the move. Do not copy the exemplar's exact hue, type, or layout; that is plagiarism and it will not fit.
- **Name the slop tells to avoid explicitly.** Current, credible restraint is defined as much by what it refuses as what it does. The generated-interface fingerprint is recognizable on sight and must be actively avoided (see the guardrails below).

The harvest is what lets you answer "make it more modern" with a direction that is genuinely of-the-moment and specific, rather than the timeless-looking default that reads as generated.

## Anti-slop guardrails

"Current" done by reflex produces the exact sameness the user is bouncing. The generated-interface tells to avoid (gradients, bordered-card grids, decorative glow, emoji-as-UI, meaningless status dots, vague hero copy, stock imagery) and the restraint idiom to reach for instead (group with type and whitespace, color only as a meaning-carrying accent, one dominant plus one accent plus one neutral) are catalogued with their source in eye-of-the-beholder's credibility axis; scan against that list rather than restating it here. The one point worth adding for direction-setting: typography is the fastest way out of slop, so pick type as a deliberate stance rather than defaulting to a system sans.

## The output: a growing visual-language.md

A direction that lives only in a chat transcript evaporates by the next session. Every taste-test lands its result in a `visual-language.md` at the project root (or the project's design-doc location), and grows the file per decision instead of rewriting it. The template in `templates/visual-language.md` is the starting shape.

This is deliberately lighter than art-director's full brand artifact set. Art-director runs once and produces brand, visual language, and design-system architecture from stakeholder research. Taste-test produces one section at a time, from a gut reaction, as decisions get made. The two can meet: a project that accumulates enough taste-test decisions has effectively grown a visual-language.md that a later art-director pass can formalize. Until then, the growing file is the standard that eye-of-the-beholder verifies against and the build-time discipline builds from, so the same direction does not get re-litigated every session.

Record each decision as: what was decided, the reaction that drove it (the user's own gut-words, kept verbatim, because they are the calibration for next time), the move chosen, and the slop tell it avoids.

Two guards on the write. First, if the file already exists, read its current shape before writing and extend it; do not overwrite a different structure (art-director may have produced a fuller version of the same file). Second, the reaction you are recording is your decode of a non-verbal signal (a pointed finger, a gut-word), so confirm it in one line before it becomes a recorded decision ("recording: you picked B for its calm density, dropping the boxed-card grid, yes?"). A wrong decode carries the false authority of a written decision and is harder to overturn later than a fresh guess would have been. When a new decision contradicts an earlier entry, supersede the old one rather than appending a silent conflict.

## Positioning

Four skills, four moments:

- **art-director**: define the whole identity, once, upstream, from research. Heavy.
- **taste-test**: find a direction for a screen or feature by showing options and reading reactions, when the user cannot describe it. Light, repeatable.
- **eye-of-the-beholder**: verify a rendered result against the direction, per change. Diagnostic.
- **visual-inspection**: prove a result matches a named reference on named axes. Directed.

## Common blind spots

| What the agent does | What goes wrong |
|--------------------|-----------------|
| Asks the user to describe the direction | They cannot; that is why they are stuck. Show options, read the reaction. |
| Renders five tints of one layout as "variants" | Not a fan. Each variant must commit to a different stance so the pick is informative. |
| Describes the options in prose instead of rendering them | A fan the user cannot see teaches nothing. Render real options. |
| Answers "more modern" from memory | Memory lags; "current" changes. Harvest real current exemplars, extract moves. |
| Copies an exemplar's colors and type | That is plagiarism and it will not fit. Extract the transferable move, not the pixels. |
| Reaches for the timeless-safe default | That default is the slop the user is bouncing. Take a position; avoid the named tells. |
| Lets the decision live only in chat | It evaporates next session. Record it in visual-language.md, grown per decision. |
| Keeps pixel-iterating past the second unimproved round | Non-convergence is the signal to reset direction with a fan, not to push more pixels. |
| Renders a full fan when the direction is only slightly uncertain | The operator's judgment is the scarce resource. One best-guess render plus a light reaction fits a small uncertainty; reserve the fan for an absent direction. |

## Output

```
You reacted with "too busy, feels cheap" and could not say more, so here is a
fan instead of a spec. Three divergent directions for the dashboard, same data:

- A: quiet editorial. One serif display face, generous whitespace, hairlines
     instead of cards, a single ink accent. Move borrowed: group by whitespace,
     not boxes (seen in current editorial-analytics products).
- B: dense technical. Tabular mono values, tight grid, monochrome plus one
     signal color used only for out-of-range values. Move: color carries
     meaning, never decoration.
- C: warm consumer. Rounded humanist sans, soft neutral surfaces, one warm
     accent on the primary action only. Move: warmth from type and surface, not
     from illustration.

None uses a gradient, a bordered-card grid, or a status dot (the slop tells you
were bouncing). Point at one, or mark these axes: calm<->energetic,
warm<->clinical, dense<->airy. Whatever you pick, I will record the direction in
visual-language.md so we build from it instead of re-deciding next time.
```
