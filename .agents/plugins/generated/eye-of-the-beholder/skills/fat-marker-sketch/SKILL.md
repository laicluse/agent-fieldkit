---
name: fat-marker-sketch
description: Classify an uploaded screenshot, annotated capture, sketch, mockup, or image before using it as design evidence; extract intent without copying annotation-tool styling.
---

# Screenshot, annotation, or fat-marker sketch

## The real problem

An uploaded image can contain several different things: product UI, a screenshot-tool annotation layer, a rough sketch, or a finished design reference. Calling all of them a *fat-marker sketch* obscures the useful distinction. It also encourages the opposite mistake this skill exists to prevent: copying a bright arrow, callout bubble, or rough box into the product as though those pixels were design decisions.

Classify the artifact first. Then decide which pixels are evidence and which are commentary. A fat-marker sketch is one possible class, not the default name for every uploaded image.

The term comes from Shape Up (Basecamp): a fat-marker sketch is drawn with a pen so thick that detail is deliberately impossible. That is a useful way to read an actual rough sketch. It is not an accurate label for a crisp product screenshot that happens to have annotations on top.

## Classify before interpreting

Use all available evidence in this order:

1. **Accompanying words.** Explicit statements about what the image is and what to do with it outrank every inference.
2. **Visible layers.** Distinguish captured product pixels from arrows, callouts, highlights, boxes, labels, and screenshot-tool chrome.
3. **Filename provenance.** When the host exposes the uploaded filename, inspect it before interpreting the image. Names containing capture conventions or tool names such as `CleanShot`, `Screenshot`, `Screen Shot`, `Schermafbeelding`, `Snip`, or `Screen Capture` are evidence that the file originated as a screenshot. Treat matching case-insensitively and expect other apps and locales. A filename is a provenance hint, never an intent verdict: it does not prove that annotations are present, that the underlying UI should or should not be matched, or that a renamed file is a design artifact.
4. **Image metadata.** Dimensions, alpha, or embedded metadata can support a classification when the host exposes them, but do not block on unavailable metadata.

Choose the narrowest fitting class:

| Class | What it looks like | How to use it |
|-------|--------------------|---------------|
| **Annotated screenshot** | Captured app, website, or OS pixels with arrows, callouts, highlights, boxes, or labels layered over them | Treat the underlying screenshot as product evidence and the marks as commentary. Extract their target and meaning; discard their visual styling. Do not rename the image a fat-marker sketch. |
| **Clean screenshot** | Captured UI without a visible annotation layer | Use it as evidence of current state or as a reference according to the user's words. A screenshot filename says where it came from, not whether it is feedback or a match target. |
| **Low-fidelity sketch** | A rough drawing, wireframe, or spatial proposal whose author intentionally omitted visual detail | Read it as a fat-marker sketch: preserve complaint, content, direction, and topology, but do not reproduce incidental pixels or measurements. |
| **Design artifact or reference** | A deliberate comp, Figma frame, brand asset, polished mockup, or named product element | Preserve the axes the user identifies. When they state match-intent, route to visual-inspection. |
| **Unknown image** | The available evidence does not distinguish the classes above | Use the accompanying request when it supplies intent. For a wordless, unannotated image, ask one short classification question before editing. |

Do not infer annotation presence from a screenshot filename alone. Confirm it visually. Conversely, a generic or renamed filename does not erase an annotation layer that is visible in the pixels.

## Match intent is separate from artifact type

Classification answers *what the file is*. Match intent answers *how the user wants it used*. Keep those questions separate.

Treat pixels as a literal visual reference only when the user states match intent:

- Match-intent words: "pixel-perfect", "match this exactly", "precies zo", "exact zo", "identiek", "1:1", "make it look like this".
- The user names a real product element, brand asset, or Figma frame as the thing to reproduce ("our actual dashboard", "the Figma hero frame", "the real app").
- The user says the annotation itself is the design ("use these exact colors", "this is the mockup, build it").

An annotated screenshot can contain literal reference pixels underneath commentary. For example, "make this button match the existing header" can use the captured header as a reference while the red arrow remains only a pointer. If match intent is present, hand the named reference axes to visual-inspection.

## What to extract, what to ignore

Annotated screenshots and low-fidelity sketches can carry five kinds of signal:

1. **Complaint.** What feels wrong right now? Name the pain without translating annotation styling into product styling.
2. **Target area.** Where is the user pointing? An arrow or box often says *where* even when it says nothing about *how*.
3. **Direction.** Which way should it move? Bigger, calmer, tighter, warmer, more prominent, gone. A direction is a vector, not a destination.
4. **Content.** Any real words, values, labels, or data that must survive into the result.
5. **Topology.** What goes near what, in what order, at what rough level of the hierarchy.

Discard the annotation tool's visual voice unless the user explicitly promotes it to design input:

- Arrow color, weight, and style. A red arrow does not mean "add red".
- Callout bubbles, speech balloons, numbered stickers, and their fills, borders, fonts, and shadows.
- Highlighter strokes and their color. A yellow highlight marks attention, not a yellow background.
- Hand-drawn boxes and their stroke. A box marks a region, not necessarily a bordered container.
- Screenshot-tool chrome: CleanShot toolbars, Preview markup styling, OS window frames, and tool-added shadows.
- Capture accidents: crop tightness, capture aspect ratio, and where the drag happened to stop.

One color exception matters. When two or more annotation colors consistently separate distinct groups, color may encode a relationship. Preserve the distinction, not the literal hues, unless the user explicitly names those hues as design.

For each mark ask: does this tell me what the user means, or what tool they drew with? Preserve the first and discard the second.

## Interpretation readback before the first edit

Use the actual classification name. Do not announce an annotated screenshot as a fat-marker sketch.

```
Reading this upload as: <annotated screenshot / clean screenshot / low-fidelity sketch / design reference>.
Evidence: <brief visible or filename provenance; omit when obvious>.

From it I read:
- Complaint: <what feels wrong>
- Target: <where the user is pointing>
- Direction: <which way to move it, or "open">
- Content to keep: <real words/values, or "none">

I am ignoring (annotation, not design):
- <e.g. the red arrow and its color>
- <e.g. the CleanShot callout bubble styling>

I am going to:
- <the change, in product terms, in the existing design language>
```

Then act. Do not wait for approval in an autonomous flow. The readback localizes a miss without forcing the user to translate visual feedback into a written specification.

Carry the classification and readback, not an unframed image, into any delegated step. If the implementation needs the underlying reference pixels, pass the image together with that framing; do not remove evidence that the implementer must inspect.

When the direction is open, do not invent one. If a gut-word maps to an eye-of-the-beholder complaint axis, scan that axis. If the direction is genuinely absent, use taste-test to show a small fan of directions.

## Reference-scope check

When the user asks to borrow one aspect from an existing design, pin the named axis before building: grid, color, type, spacing, radius, density, motion, or tone.

```
Borrowing from the reference: <the named axis>
Not borrowing: <the other visible axes>
```

Copying more than the named axis is scope creep. Copying everything except the named axis misses the request.

## Relationship to the other skills

- **eye-of-the-beholder** scans a rendered result. This skill classifies incoming visual evidence and extracts the user's signal first.
- **visual-inspection** handles stated match intent against named reference axes. An annotated screenshot may route there for its underlying product pixels while its annotation layer remains commentary.
- **taste-test** handles genuinely open direction by showing divergent options. A low-fidelity sketch or annotated screenshot can identify the target before taste-test explores alternatives.

## Common blind spots

| What the agent does | What goes wrong |
|---------------------|-----------------|
| Calls every uploaded image a fat-marker sketch | Artefact type and interpretation strategy are collapsed. Classify first. |
| Calls a CleanShot capture a sketch | The filename identifies likely screenshot provenance, not a rough drawing. |
| Assumes `CleanShot` means annotations are present | The file may be an untouched capture. Confirm the visible annotation layer. |
| Trusts a generic filename as proof that the image is not a screenshot | Uploads get renamed and stripped of metadata. Filename is supporting evidence only. |
| Treats the entire annotated screenshot as disposable feedback | Underlying product pixels may document current state or supply a literal named reference. Split the layers. |
| Copies annotation color or callout styling into UI | Those pixels usually belong to the annotation tool, not the product design. |
| Builds a scribbled box as a bordered container | A drawn box identifies a region; grouping may belong in whitespace or hierarchy. |
| Assumes crisp pixels mean "match exactly" | Capture fidelity does not establish match intent. Read the user's words. |
| Hands an unframed annotated screenshot to another implementer | The annotation layer can be mistaken for product styling. Pass classification and readback with the evidence. |
| Ignores annotation colors that separate groups | Preserve the encoded distinction while discarding incidental literal hues. |

## Output examples

Annotated screenshot:

```
Reading this upload as an annotated screenshot. The CleanShot filename supports screenshot provenance; the arrow and callout are a visible annotation layer.

From it I read:
- Complaint: the header feels cramped against the top edge
- Target: the title area indicated by the arrow
- Direction: more breathing room above it
- Content to keep: "Q3 Results"

I am ignoring (annotation, not design):
- the red arrow and its color
- the callout bubble's font, fill, and shadow

I am going to:
- add top spacing using the product's existing spacing scale, then render and scan it
```

Actual low-fidelity sketch:

```
Reading this upload as a low-fidelity sketch: it proposes rough structure rather than showing captured product UI.

From it I read:
- Target: the results page
- Direction: summary first, details second
- Content to keep: total, period, and comparison
- Topology: summary above the detail list

I am going to:
- preserve that hierarchy while designing the concrete layout in the product's visual language
```
