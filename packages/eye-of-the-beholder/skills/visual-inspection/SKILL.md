---
name: visual-inspection
user-invocable: true
description: Match a new element to a named visual reference on padding, size, radius, font, color, alignment, or other explicit axes.
---

# Visual inspection

## The real problem

The user points to an existing UI element ("ik wil dezelfde pillen als de favicon, qua corner radius, padding en font") and Claude writes CSS that comes close, reads back its own CSS, sees "padding is there", and declares done. The result does not look like it. No screenshot of the reference taken, no screenshot of the result taken, no comparison done on the axes the user explicitly named.

This is a variant of the problem eye-of-the-beholder solves (confirmatory looking instead of observational looking), but more specific. The user has already named the axes. The work is not "check if it looks nice", the work is "place reference and result side by side and prove every named axis is equal".

## When

This skill activates when two things come together:

1. **A reference**. The user explicitly points to an existing element or another existing UI ("zoals de favicon", "zoals de header", "zoals deze button", a screenshot, a Figma frame).
2. **A match intent or a visual axis**. "Exact hetzelfde", "match", "zelfde uiterlijk", "precies zo", "identiek aan", "dezelfde look als", OR a specific visual property as criterion: padding, margin, space, ruimte, gap, align, alignment, grootte, size, pixels, corner radius, border radius, font, color, kleur.

"A screenshot" means captured product pixels, not screenshot-tool markup. An annotated screenshot may supply reference pixels underneath arrows, labels, numbered circles, highlighter strokes, or CleanShot callouts. Use the marks to locate the target and axes, but do not treat their colors, typography, bubbles, arrows, shadows, or layout as reference style unless the user explicitly says the annotation itself is the design.

The sister skill **fat-marker-sketch** owns incoming-image classification and the extraction protocol. Despite its historical name, it distinguishes annotated screenshots, clean screenshots, actual low-fidelity sketches, and design references. Visual-inspection engages once the user states match intent or names a visual axis to copy; it proves the result equals the reference on those axes.

"In lijn met" alone is not a trigger. That phrase in Dutch is usually non-visual ("in lijn met de sprint planning", "in lijn met de API response"). Only when the object is demonstrably a UI element ("in lijn met de header-button") does it count as match intent.

When both are present: this skill leads the work, not eye-of-the-beholder's open scan. The axes are given; the question is "klopt het met de referentie", not "what do I see".

## The core: two screenshots, one table

**Before you write a line of CSS:** screenshot of the reference. Not "I remember what the favicon looks like". Not "the CSS of the favicon says 8px padding". A PNG of the rendered element on screen.

**After every change:** screenshot of the result. Next to the reference. Per named axis: equal, or not equal. No "looks like it", no "looks good". The axes the user named are the tests; all other axes are noise until the user names them.

```
Axis          | Reference        | Result           | Match
--------------|------------------|------------------|------
Corner radius | 6px (measured)   | 4px (measured)   | no
Padding x     | 12px             | 8px              | no
Padding y     | 4px              | 4px              | yes
Font          | system-ui 13px   | -apple-system 12 | no
```

A row that says `no` is an open todo. Done means: all rows say `yes`, with screenshots as evidence.

**Tolerance for `yes`.** Unless the user names a different threshold: rendered pixel values must agree within 1px for distances, padding, margin, gap, and radii. Font-family and font-weight must match exactly; font-size within 0.5pt. Color: same token or within 1 step on a delta-E ladder. "Looks close" is `no`. The user decides when a deviation is acceptable; you do not.

## Steps

1. **Identify the reference.** Which element does the user point to? Record a locator (CSS selector, aria-label, or bounding box on the page).
2. **Identify the axes.** Read back the user's sentence. Which properties did they name? Write them out as columns in the table. Do not guess extra axes; do not add axes the user did not name.
3. **Screenshot the reference.** A tightly-cropped PNG at the zoom factor the user is viewing. Any capture route that delivers that (headless browser, devtools screenshot, user-provided image, browser MCP, OS screen-capture utility) is fine.
4. **Measure the reference per axis.** Whichever measurement route reads the property (devtools computed styles for runtime values, pixel measurement on the screenshot for properties that cannot be read from a one-liner like effective corner radius with nested borders). Put the values in the table.
5. **Implement.** Write the CSS / SwiftUI / whatever.
6. **Screenshot the result.** Same crop strategy. Same zoom.
7. **Measure the result per axis.** Fill in the table.
8. **Compare.** For each axis: equal or not. If not equal: back to step 5 with that specific axis as focus. Loop until all axes say `yes`.
9. **Side-by-side evidence in the same response as the match claim.** The reference screenshot AND the result screenshot must be in the same response in which you claim "match". A screenshot from an earlier turn does not count; "I took it earlier" is not evidence. Take fresh, include both, then claim. Reading CSS is not evidence.

## When screenshots are not possible

If you cannot take a screenshot of BOTH the reference and the result, the work is blocked. Not "then I do it by feel".

- **Neither screenshottable** (no browser tooling, no running server, no user screenshot): ask the user to provide both screenshots.
- **Only the result screenshottable, reference not** (e.g. "match the favicon" without being able to render the favicon pill): ask the user for the reference screenshot. Building forward with only the result is the same as not screenshotting; the match claim has no counterpart.
- **Only the reference screenshottable, result not**: do not build further until you can render the result too. A match that cannot be proven visually is not a match.

Do not build forward without visual input from both sides when the user explicitly asked for a visual match; that is exactly the pattern this skill prevents.

For terminal and CLI output this does not apply; there "match" is a text comparison, not a visual one.

## Relation to eye-of-the-beholder

Eye-of-the-beholder is open diagnosis: look at what is there and name what is wrong. Visual-inspection is directed: the user has already named the axes; the work is proving every axis is equal to a reference. When all axes match and you still feel uncertainty about the broader visual result, layer eye-of-the-beholder on top for the open scan.

## Common blind spots

| What Claude does | What goes wrong |
|-----------------|----------------|
| Reading the reference CSS and assuming "padding 8px" | The rendered padding can be affected by box-sizing, line-height, or a nested element. Measure the rendered result. |
| Treating annotated screenshot markup as the reference | The operator's arrows and callouts are fat-marker feedback, not UI direction (see fat-marker-sketch). Match product pixels and named axes, not CleanShot's visual language. |
| Taking one screenshot after all changes | Without before/after you cannot see which change moved which axis. A fresh screenshot per iteration. |
| Including extra axes the user did not name | Scope creep dressed as thoroughness. The user named three axes; work on those three. |
| "Looks the same" without a table | No table = no evidence. A person can find two elements "the same" that measure 2px apart. |
| Different zoom level for reference and result | One element at 100%, another at 125% makes every pixel measurement worthless. |
| Cropping with a lot of neighboring UI | The eye adapts elements to their context. Crop tightly to compare only the two elements. |
| Stopping at "looks like it" | "Looks like it" is not `yes` in the table. Looks-like-it is an open todo. |
| Labeling a visual estimate as "measured" | Estimating a number from a screenshot without devtools is an assumption, not a measurement. Label it `estimated (~6px)` and note the measurement method. An estimated value may not lead to `yes` in the Match column; only devtools-computed-style or pixel-sample from a raw PNG counts as measured. |
| Referring to a screenshot from an earlier turn | The evidence must be in the same response as the match claim. "I took it earlier above" is not evidence for the current claim; take fresh. |

## Toolchain

The skill ships three executable files under `scripts/` and two reference documents alongside this SKILL.md:

- `scripts/ink-assert.mjs`: gating tool. Runs structural axes (frame, ink, padding, corner, bgDiag, aaDiag, edgeExt, bgExt, aaExt, halo, hist) plus multi-scale meanRGB and pixel-diff. Modes: default (per-axis report), `--json` (machine-readable), `--confidence` (score 0..100, exit 0 only at >=95).
- `scripts/cases/`: validation corpus. Each subdirectory holds `reference.png`, `candidate.png`, and `verdict.txt` (one of `match`, `mismatch`, `borderline`).
- `scripts/run-corpus.mjs`: self-test runner. Iterates `cases/`, runs ink-assert per case, prints a confusion matrix (truePass, trueFail, falsePass, falseFail, borderline), exits 0 only when falsePass=0 AND falseFail=0.
- `direction-matrix.md`: per-axis direction effect of every tunable CSS knob (border-radius, padding, font-size, font-weight, letter-spacing, filter:blur, box-shadow). Tells you which knob to move when an axis fails in which direction.
- `pipeline-floors.md`: per-axis irreducible delta when comparing CSS-pill against canvas-PNG-favicon. Tells you when a residual delta is the cross-pipeline rasterization floor versus a fixable axis.
- `corpus-confidence-scores.md`: empirical calibration of the `--confidence` score against the validation corpus. Match cases score 100, mismatch cases score 0..61, borderline cases score 40..48 at the time of writing.

### Axis glossary

The tool emits axes whose short names are not self-evident on first contact. Reference list:

- `frame.w` / `frame.h`: bounding box of the visible element (FRAME pixels plus INK plus EDGE).
- `ink.w` / `ink.h`: bounding box of INK-classified pixels alone (typically the glyphs or icon).
- `pad.{top,right,bottom,left}`: distance in device pixels from the frame bbox to the ink bbox.
- `corner.{TL,TR,BL,BR}`: diagonal inset from the bbox corner to the first FRAME/INK pixel; the nearest-curve-point of the corner.
- `bgDiag.{TL,TR,BL,BR}`: along the same diagonal walk, count of pixels classified BG before the first FRAME/INK. Sharp-cutoff width.
- `aaDiag.{TL,TR,BL,BR}`: along the same diagonal walk, count of pixels classified EDGE (anti-aliased blend) before the first FRAME/INK. Soft-fade width.
- `edgeExt.{TL,TR,BL,BR}`: along the corner row (horizontal walk along the bbox top/bottom), total non-FRAME/INK pixel count. Equal to bgExt + aaExt; kept for backward visibility.
- `bgExt.{TL,TR,BL,BR}`: same row walk, BG-only count. Sharp-cutoff width along the edge.
- `aaExt.{TL,TR,BL,BR}`: same row walk, EDGE-only count. Soft-fade width along the edge.
- `halo.{TL,TR,BL,BR}`: count of EDGE-class pixels in the 5x5 corner block.
- `hist.{INK,FRAME,EDGE,BG}`: percentage of frame area classified as that class.
- `ms.WxH.meanRGB`: mean RGB color at progressively halved resolutions down to 1x1. The 1x1 meanRGB is a strict overall-color check; the larger ones are coarse-balance checks.
- `pixel diff`: percentage of pixels where the per-channel max delta exceeds the threshold (default 24/255).

The "diag" walk samples from the corner toward the center; the "ext" (extension) walk samples along the edge from the corner toward the opposite corner. Both expose the corner-curve geometry but from different angles.

### Common runtime warnings

- `autoBg corner spread is N RGB units (>30)`: the tool tried to detect the background color from the four corners of the input image and they disagreed. Pass `--bg R,G,B` explicitly. Sample the bg colour from a known-empty pixel of your reference (an image viewer's eyedropper tool works; ImageMagick's `magick file.png -resize 1x1 txt:` prints a single-pixel average).

When `--confidence` reports below 95, consult `direction-matrix.md` for the knob to move and `pipeline-floors.md` for the floor on that axis. When all failing axes are at their floor, the gate has reached the irreducible cross-pipeline limit and a higher score requires changing the rendering pipeline (e.g., replacing the CSS pill with an inline SVG mirror of the canvas).

The corpus is the regression suite. Every change to ink-assert or a new axis must be validated by running `run-corpus.mjs` and confirming `CORPUS CLEAN ✓`.
