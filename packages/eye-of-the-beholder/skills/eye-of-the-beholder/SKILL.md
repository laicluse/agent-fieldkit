---
name: eye-of-the-beholder
user-invocable: true
description: Visual review for layouts, color systems, animation, responsive screens, and screenshots with spacing, contrast, token, or timing concerns.
---

<post-update-broadcast>
BEFORE doing the actual work below, run this one-time check only when
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

# Eye of the Beholder

## The real problem

Claude writes CSS and only looks at the result at the end. And when Claude looks, it looks confirmingly ("I wrote padding, so there is space") rather than observationally ("what do I see?"). A designer looks a hundred times during the process. Claude looks once.

The solution is not more rules. The solution is looking more often, and looking differently.

## Interpreting user-provided screenshots

Classify an uploaded image before deciding how to use it. A captured UI with arrows, callouts, or highlights is an **annotated screenshot**, not a fat-marker sketch: the underlying product pixels are evidence and the annotation layer is commentary. An actual rough drawing or wireframe may be a **low-fidelity sketch**. Never copy screenshot-tool styling into product UI.

The full classification and reading protocol lives in the sister skill **fat-marker-sketch**. It uses accompanying words, visible layers, and, when exposed, the filename as a provenance hint. A name such as `CleanShot` or `Screenshot` supports screenshot provenance but never establishes annotation presence or match intent. Route stated match intent against named product or reference pixels to **visual-inspection**.

## From complaint to axis

A user rarely reports a defect in the vocabulary of the fix. They report a feeling: "too busy", "it jumps", "looks cheap", "off", "cramped". That feeling is data, not noise. It names which axis to scan; it does not name the cause. Translate the complaint into an axis, run that axis's observation questions, and say which axis you are scanning so a wrong translation surfaces before you spend a round on it.

| Complaint (the feeling) | Axis to scan | What to look for |
|-------------------------|--------------|-----------------|
| "too busy", "cluttered", "heavy", "noisy" | density / hierarchy | many competing accents, no dominant element, missing whitespace, everything the same weight |
| "it jumps", "it shifts", "things move around" | layout stability | position change on a state change, reflow, hover jitter, a container that resizes to its content |
| "cramped", "tight", "squished" | space (x/y) | padding below the comfortable ratio, sibling gaps collapsed, text pressing an edge |
| "empty", "sparse", "lost" | space (x/y) | voids without purpose, weak grouping, no anchor for the eye |
| "cheap", "generic", "looks AI-made", "template" | credibility | the vibe-coded tells: gradients, bordered-card grids, status dots, one-font defaults, decorative glow |
| "off", "odd", "something's wrong" | odd-one-out | one element slightly different from its siblings: a stray radius, weight, color, or gap |
| "hard to read", "can't tell them apart" | color / contrast | luminance delta below threshold, secondary text failing AA, adjacent surfaces too close |
| "what do the colors mean?", "why is this one different?" | channel semantics | a visual channel carrying more than one meaning, or decoration masquerading as encoding |
| "the motion is weird", "it snaps" | time (animation) | out-of-sync elements, teleporting content, wrong speed for the distance |
| "doesn't fit us", "wrong feel" | direction | there is no documented standard to fit; this is a taste-test or art-director gap, not a single-view fix |

The translation is a hypothesis: state it ("you said it feels busy, so I am scanning density and hierarchy") so a wrong mapping gets corrected at the axis, not the pixels.

## The core: observation before explanation

**After every layout change: screenshot. Describe what you see BEFORE looking back at the CSS.**

**Creating an image file is not the screenshot checkpoint. Immediately open every PNG produced for visual work with the host's image viewer and surface that rendered image to the user in the same turn. A local path, attachment link, or note that the file exists does not count as showing it. Do not continue iterating or hand off the work until the newly generated PNG itself has been opened and inspected.**

Not: "the padding should be 0.6rem, I see space, correct."
Instead: "I see text pressing against the top edge." Only then: why? Which CSS causes this?

This is the difference between confirmatory looking and observational looking. A doctor first describes the symptom, then the diagnosis. A designer first sees the result, then the code.

## When

In visual work, this skill is not something you call at the end. It is a working method:

1. **Write a block of layout CSS or a transition** (a container, a section, a page structure, a state transition)
2. **Screenshot or recording** (take it yourself or receive it from the user). For transitions: a GIF/MP4 or a series of frames from a headless browser.
3. **Describe what you see** in the result, without looking at the CSS. Scan clockwise: top -> right -> bottom -> left. Name the nearest element at each edge. For animations: repeat the scan on the start, mid, and end frame.
4. **Compare observation with intention.** Does something press against an edge? Does something feel cramped? Is there a void? Does something snap while the rest animates?
5. **Fix and repeat** from step 2.

This is design-TDD: the rendered result is the test, the CSS is the implementation.

## How to look

When examining a screenshot (taken yourself or provided), ask these questions in this order:

**Feel first, then measure:**

1. **Squint your eyes.** What stands out? Where does it feel cramped? Where does it feel empty? Where does your eye stop? This is Gestalt in action: the brain perceives grouping, proximity, and tension faster than conscious thought.

2. **Trace the edges.** Top -> right -> bottom -> left. What is the nearest element to each edge? How much space is between them? Does anything touch the edge?

   **Trace is fractal.** Do this at every level where something has an edge:
   - Page vs. viewport
   - Container vs. parent padding
   - Component vs. its own border/padding
   - Glyph or icon vs. viewBox or bounding box
   - Path/stroke vs. pixel-grid

   The same rules work at every level. An icon clipped within its viewBox is the same problem as a title touching the page edge, just one zoom step deeper.

3. **Look for the rhythm.** Are the distances between repeating elements (sections, cards, rows) consistent? Is the rhythm broken anywhere?

   **Internal rhythm is a separate judgment.** Measuring perimeter padding ("content is 32px from the edge") is not the same as measuring sibling gaps. Walk through each visual block within the container (title, paragraph, table, list, quote, signature, footer) and name the vertical space between each adjacent pair. Do two blocks touch each other? Is the gap smaller than the line-height of the body font? Are the gaps mutually consistent? A card with generous outer margins but collapsed internal blocks does not read as a document; it reads as dumped text in a box. This is "collapsed padding": the outer edge is fine, the inner housekeeping is not. Margin-collapse through the container padding is a known mechanism (first child margin-top collapses through parent padding-top if the parent has no border/padding/inline-content above the child); if you suspect this, check with DevTools or fix with `display: flow-root` / an explicit border-top.

4. **Look for the odd one out.** Is there an element that is just slightly different from the rest? Something that is almost the same but not quite? That is probably a bug, not a variation.

5. **Name every touch.** Which elements touch each other? Which elements touch an edge? Which elements fall outside their container? List them. For each: is this intentional? A border touching its container is usually deliberate. Text touching the page edge almost never is. Intentional touches are explicit (e.g. a `bleed` class), unintentional ones are bugs.

6. **Glyph and icon check.** For each vector icon or glyph in the screenshot: does the content fit within its own container? An icon that feels "cut off" at one edge is almost always a path running outside its viewBox. SVG has default `overflow: hidden`, so the clip is silent. For stroke-based icons: add half the stroke-width to the path bounds (with `stroke-width="1.5"` the actual edge lies at `coordinate ± 0.75`). Always fix by making the viewBox larger or the path smaller, never with `overflow="visible"` (that moves the problem to the parent).

   **The same trap applies one zoom step up: auto-sizing containers with text content.** Popovers, tooltips, sheets, banners, toasts, drawers, alert bodies, snackbars: each sizes itself to its content's intrinsic size. If the modifier or layout-prop order makes the intrinsic size smaller than the actual text needs (e.g. SwiftUI `.fixedSize().padding().frame(maxWidth:)` chained in the wrong order, CSS `max-height` capping a long string, `line-clamp` set to a guess number), the body is clipped silently from top, bottom, start, or end. The container looks correct in shape; the user reads a mid-string fragment that may even parse as a sentence on its own. When reviewing an open-state screenshot of any auto-sizing text container: **read every visible line of the popover/sheet/banner content against the source string. Count lines, compare wrapping. Confirm the first word and the last word are present.** A closed-state screenshot is not a substitute; the bug only exists when the container is open. If the visible text starts mid-sentence or ends mid-word, the container's intrinsic size is wrong, not the text. Fix by reordering the layout chain so the content can grow to its natural height (in SwiftUI: `.frame(width:alignment:).padding().fixedSize(horizontal: false, vertical: true)` typically works; in CSS: remove `max-height`, raise `line-clamp`, or audit `overflow: hidden` on the bubble).

7. **Optical vs. mathematical bounds.** Circles, triangles, and round glyphs weigh optically less than squares with the same mathematical bounds. Designers compensate with *overshoot*: an "O" is fractionally larger than an "H", a circle must be ~113% of a square to read as equally large, a triangle must have its sharp point extend past the baseline. Does a round shape feel "smaller" than a square neighbor of the same pixel size? That is not an illusion, it is a missing overshoot.

8. **Optical center sits higher than geometric center (Arnheim).** Mathematically centered content feels top-heavy. Push the visual center of gravity 2-5% upward. This is why `align-items: center` in CSS often feels "just too low": it is mathematically correct, not optically correct.

   **Exception for typography in icon containers** (buttons, pills, badges): here the rule works *in reverse*. A digit or letter naturally sits high within its line-box because font ascent is greater than font descent (typically 80/20). Cap-height center sits ~5% above em-box center. In a pill with an SVG icon that IS symmetrical, text feels "too high" (more whitespace below than above). Spiekermann's rule: *align to cap-height center, not to glyph bounding box*. Fix via micro-translate (~0.5-1px) or via `text-box-trim` / cap-height line-height libraries (Braid's capsize). In a review: do you see text and icon that do not feel equally centered in their container, with text higher than icon? That is font metric asymmetry, not your brain.

9. **Compare left with right, top with bottom.** Is the composition balanced? Not necessarily symmetrical, but intentional? Symmetrical composition often feels dull; asymmetric balance via visual weighting (color, contrast, mass) is livelier (Arnheim).

10. **How is this held?** The design borders on the physical world. Paper is held with fingers that cover the edges. A phone screen has bezels (or no longer does). A laptop has a frame. The design's margins must account for what the user physically covers.

**Tschichold's margin ratios for printed work: 1:1:2:3** (inner:top:outer:bottom). The bottom margin is largest because hands hold the paper there. The Van de Graaf canon from medieval manuscripts: 2:3:4:6. The same logic, even more dramatic.

**The medium mutates.** Smartphone bezels used to be thick, now nearly invisible. When bezels were thick, UI margins did not need to be large (fingers touched plastic, not pixels). Now bezels are gone, fingers cover the interface, so UI margins must grow. Apple's safe area insets grew along with shrinking bezels. For print the opposite is true: paper has no bezel, only paper. The "bezel" is zero, so the margin must compensate for everything.

**Practically:** for a loose A4 sheet held in hands, the outer and bottom margins matter most. A recipe on the counter is held at the top or side. The margins must be large enough that fingers do not cover text.

**Only then measure and fix:**

**Measuring and judging is one action, not two.** Writing down a pixel value is not a completed observation; only when that value has been tested against a standard or ratio is the finding complete. "There is 20px padding" is half a sentence. "20px padding on 14px body-font = 1.4x, below the 2.5x threshold for comfortable document reading" is a finding. The scan only ends when every measured value has an explicit verdict: good, cramped, generous, fails.

**Default ratios to test against:**
- Padding/gutter around body text: minimum 2.5x body-font size. Below that threshold it feels cramped, even if nothing is touching.
- Document-metaphor canvases (email-body, card-as-paper, editor-surface): Tschichold 1:1:2:3 (inner:top:outer:bottom) as starting point. Web-style 16-24px all around does not qualify; a document wants 2-3rem+ space around the text.
- Section gap vs. internal gap: minimum 2x difference to convey hierarchy. "14px vs 5px = 2.8:1" works; "14px vs 10px = 1.4:1" is ambiguous.
- Adjacent surface levels: minimum 1.07x luminance ratio (see color section).

Express problems as ratios, not pixels:
- "The title is at 0px from the top, but the body font is 12px. There should be at least 2.5x font size (~30px) there."
- "The section gap is 14px but the internal gap is 5px. That is a 2.8:1 ratio, clear enough."
- "This is a printed A4 sheet. Tschichold's ratio 1:1:2:3 at a 1.5cm base gives: top 1.5cm, inner 1.5cm, outer 3cm, bottom 4.5cm."
- "Email-body card has 20/24px padding on 14px body-font = 1.4x/1.7x. Below the 2.5x threshold, and far below Tschichold for document canvas. Cramped."

## Z-stacking: the same discipline, depth as the axis

Space (x/y) is one axis. Color is another. Depth (z) is a third. Before color and time, Z is the most commonly mis-diagnosed axis: when the user reports that an element "sits below" / "is partially missing" / "leeft onderop", the reflex is to bump offset or padding. That is the wrong diagnosis 90% of the time. The element is in the right position; it is being **occluded** by a sibling or a parent material that renders above it in the rendering tree.

### Language signals to read as Z, not x/y

Treat these as Z-axis terms by default, not screen-position terms:

| User says | Means |
|-----------|-------|
| "leeft onderop, moet bovenop" / "sits below, should sit on top" | Occluded; bring forward in Z. |
| "wordt verstopt door X" / "is hidden behind X" | X has a higher Z than the receiver. |
| "wordt afgesneden" / "is cut off" / "partially missing" | Either clipped by an ancestor frame OR occluded by a sibling. Distinguish before fixing. |
| "het hoort over de pill heen" / "should sit on top of the pill" | The element must render in a Z-layer above the receiver. |

Only switch to a positioning interpretation when the visual evidence rules out occlusion (the obscured region does NOT match the bounds of any rendered material/sibling above).

### Visual Z observation

20. **Is anything partially clipped or missing?** A badge whose lower half is gone is usually not positioned wrong; it is drawn behind a sibling or a material that happens to render on top. The MISSING region matches the bounds of the occluder almost perfectly. Trace the boundary of the gap; if it coincides with a sibling's edge, that sibling is the culprit.

21. **Is the receiver wrapped in a material that re-orders Z?** Apple's Liquid Glass (`glassEffect`, `GlassEffectContainer`), CSS `backdrop-filter`, custom `CALayer` materials, and similar composited surfaces can render the material plane ON TOP of overlays attached to the same view. The same is true for canvas elements, WebGL surfaces, and `<dialog>` top-layer in HTML. Materials promote themselves; siblings get demoted.

22. **Did you move it instead of un-occluding it?** If your first fix to an "onderop" report was to bump x/y or padding, you misdiagnosed. Revert the offset; find the Z-cause first; then re-apply offset only if needed.

### Looking beneath the screenshot: the rendering tree

Code-level audits when occlusion is suspected:

- **Source order in a stack container** (SwiftUI `ZStack`, custom `Layout`, HTML positioned siblings, CSS `z-index` stacking context): later siblings render on top.
- **Modifier chain order** (SwiftUI `.overlay()` / `.background()` chained off a view): the overlay closest to the bottom of the chain is on top, except when a material modifier in between promotes its plane.
- **Compositing escape hatches:** SwiftUI `.compositingGroup()` / `.drawingGroup()` on the occluded view promote it to its own layer that survives parent material flattening. CSS `isolation: isolate` / `transform: translateZ(0)` does the analogous thing for stacking-context boundaries.
- **`zIndex` works only between true stack siblings**, not across overlay/material chains. Reach for it only after you have a ZStack/positioned context to apply it in.
- **Custom layouts and renderers:** subview Z-order follows the @ViewBuilder return order in SwiftUI Layout (not `.place(...)` call order). In Canvas/WebGL the draw order is the call order. In CSS, document order plus stacking context (positioned + z-index, opacity < 1, transform, filter, isolation).

### Fix order

1. **Confirm the cause is occlusion, not position.** Visual check: does the missing region match the bounds of a material/sibling above? If yes → Z. If no → consider clipping by ancestor frame (CSS `overflow: hidden`, SwiftUI `.clipped()`, SVG `viewBox`). Only after both are ruled out, consider positioning.
2. **Find the smallest scope that escapes the occluder.** Order of escalation: (a) reorder siblings in the existing stack; (b) extract the obscured element into a sibling outside the material's compositing scope; (c) add a compositing-group / isolation boundary; (d) move it higher in the hierarchy.
3. **Verify with a screenshot before declaring victory.** If the gap shape persists, you have not addressed the actual occluder.
4. **Only adjust offset/padding AFTER occlusion is fixed.** The aesthetic placement question is downstream of the Z-correctness question.

### Common Z-axis blind spots

| What goes wrong | Reality |
|-----------------|---------|
| User says "onderop / under / hidden", first fix is offset/padding | Wrong diagnosis. The visual evidence is occlusion, not mis-position. Revert and look at Z. |
| Adding `.zIndex(N)` to an overlay chain | `zIndex` only works between siblings in a ZStack/stacking-context. Across overlay chains it does nothing. |
| Increasing offset to "push the badge fully outside" until it stops being obscured | Symptom-bandage. The element was always positioned correctly; the Z-fix preserves the design, the offset hack distorts it. |
| Trusting that "overlay is always on top of receiver" | Holds in plain SwiftUI, breaks when a material modifier (glassEffect, backdrop-filter) sits in the chain between them. |
| Custom Layout subviews appear in wrong Z | Z follows @ViewBuilder return order, not `.place(...)` call order. Re-order the builder, not the placement calls. |

## Color: the same discipline, a different axis

Space is one axis on which you look observationally. Color is a second. The same attitude works: not "these two cells both have a border so they are separated" but "do I see the difference?" Not "it says `text-muted` so the text is readable" but "can I comfortably read this without squinting?"

### Visual color observation

Add these questions to the scan in "How to look":

11. **How many shades of gray do you see?** Count them in the screenshot. A disciplined system has few and uses them consistently. Ten subtle variants is not subtlety; it is ten separate choices that happen to live in the same repo.

12. **Adjacent surfaces.** Are two "different" surfaces next to each other (canvas vs. list pane, list vs. detail)? Do you see the distinction immediately, or do you have to search? If you have to search, the luminance delta is too small. This is especially a trap in dark mode.

13. **Can you read secondary text without squinting?** Metadata, timestamps, captions. If you instinctively enlarge it or lean closer, it fails WCAG AA. That is not a matter of taste but a structural error.

14. **Warning and status colors.** Are "red for error" and "green for ok" clear enough? Failure text on a white background must pass AA, just like body text. Tailwind's `red-500` sits just under AA on white (about 3.8:1) and `green-500` fails badly (about 2.3:1). Darker (`red-700`, `green-700`) passes.

### Looking beneath the screenshot: the token system

A screenshot can look fine while the system underneath is messy. Three audits done at code level, not on the image:

**1. Token vocabulary scan.** Grep in the component layer for the bypass patterns:

- Opacity modifiers on color utilities (Tailwind `text-foo/50`, `bg-foo/20`): usually a sign of a missing tint, not a deliberate opacity. The developer needed a third text level and only two existed.
- Palette colors in app code (`text-red-500`, `bg-blue-200`): bypasses the semantic system. Every use is a question "why wouldn't `text-danger` have worked here?"
- Hardcoded hex/rgb/oklch in style blocks (`color: #94a3b8`): a framework-free escape. Usually because the token system had no suitable word.
- Undefined tokens that are used anyway (`bg-surface-muted` when that token does not exist): Tailwind v4 generates no class and silently falls back to nothing. If you see an empty background where you expect color, check the theme definition.

Each of these patterns signals an incomplete token system. The fix is rarely "add a token" (reactive, repeats the problem). The fix is "revise the vocabulary until every role that appears in the UI has its own name."

**2. WCAG contrast math.** For each text color used on each background used, calculate the ratio. You do not need to squint; the math gives the definitive answer.

The WCAG 2.1 thresholds are 4.5:1 for normal text against background, 3:1 for large text (18pt or 14pt bold) and for UI components. AAA tightens to 7:1 and 4.5:1 respectively. The formula below lets observational work calculate a ratio on the spot without switching tools.

WCAG 2.1 SC 1.4.3 formula:

```
Per channel c (R, G, B):
  c_norm = c / 255
  c_lin  = c_norm ≤ 0.03928 ? c_norm / 12.92 : ((c_norm + 0.055) / 1.055)^2.4

Luminance:
  L = 0.2126 * R_lin + 0.7152 * G_lin + 0.0722 * B_lin

Ratio of two colors:
  ratio = (L_lighter + 0.05) / (L_darker + 0.05)
```

Thresholds:

| Use                                             | AA     | AAA  |
| ----------------------------------------------- | ------ | ---- |
| Body text (< 18pt regular, < 14pt bold)         | 4.5:1  | 7:1  |
| Large text (≥ 18pt, or ≥ 14pt bold)             | 3:1    | 4.5:1 |
| UI component boundary (button, input, control)  | 3:1    | -    |
| Decorative dividers / non-functional borders    | exempt | -    |

A small script in Ruby, Python, or JavaScript saves hours of visual doubt. Run it for every fg/bg combination the app actually uses, not for all theoretical combinations.

**3. Perceptual surface delta.** Adjacent surface levels (canvas, list pane, detail pane, hover, active) must be visually distinguishable. Minimum: **1.07x luminance ratio** between adjacent levels. Below that threshold the system claims hierarchy that does not exist optically.

This is especially a trap in dark mode. Absolute luminance values are small there (typically 0.003 - 0.02), so an absolute delta of 0.004 looks substantial in a spreadsheet but is perceptually zero. Always check the ratio, not the difference.

**Light and dark are two designs, not one.** If you fill a role (`surface-1`) correctly in light and then make dark mode "somewhere dark", you have two different semantic systems that happen to share a name. Every role must carry the same meaning in both modes: if `surface-1` is the most prominent reading surface in light, it must be that in dark too. Use `light-dark(light, dark)` in CSS custom properties so both values live side by side in the same rule and do not drift apart.

### One meaning per channel

Color is the most abused encoding channel, but the rule is general: each visual channel (hue, fill pattern or hatching, stroke, opacity, position, size, shape) should carry exactly one meaning, and that meaning should be written down. Two failures recur, and both read as "I don't understand what I'm looking at":

- **A channel carrying two meanings.** If hue already means "which campaign", it cannot also mean "which status". The viewer cannot tell which reading applies to a given mark, so the encoding collapses; the result is both ugly and unreadable. When a second dimension needs encoding, reach for a second channel, not a second meaning on the first.
- **A channel carrying no meaning.** A color, a dot, a ribbon, or a hatching that varies without encoding anything is decoration pretending to be information. If removing it loses nothing, it was noise.

The observation questions: how many distinct meanings does each channel carry here? For every color, pattern, and stroke on screen, can you state the one thing it encodes? Is there a written channel-to-meaning map? When the project has a `visual-language.md`, that map lives there (taste-test and art-director both record it); when it does not, the absence is itself a finding, because an unwritten mapping drifts every session.

## Credibility: the vibe-coded fingerprint

Space, color, and time are three axes. There is a fourth that is not about any single property but about the design's *idiom*: does the whole read as a considered product, or as generic template / AI-generated output? The reflex is confirmatory ("it has an accent color and rounded corners, so it looks modern"); the observation is "would a designer with a point of view have made these exact moves, or are these the defaults a model reaches for?" The tells below are recognizable on sight. Treat them as defects, not taste: they are the marks of an interface that was generated rather than designed.

23. **Scan for the seven vibe-coded tells.** On any screenshot, actively look for: (1) neon / high-saturation palettes with no hierarchy; (2) dark mode with decorative glow / aurora / radial bloom that serves no function; (3) emoji used as UI elements (nav, icons, bullets); (4) purple gradients applied broadly; (5) everything wrapped in bordered containers, cards nested inside cards; (6) multicolored side-tabs, thin colored vertical accent-borders ("leading ribbons") on content blocks; (7) meaningless status dots, colored circles that appear without corresponding state. Add an eighth seen everywhere: the outline pill-badge with a leading dot used as a status chip. Each is a genre marker, not a design choice. Source: The Fountain Institute, "7 signs a UI has been vibe coded" (https://www.thefountaininstitute.com/blog/signs-vibe-coded-ui).

24. **The dot and the ribbon: does it encode anything?** The two most common dashboard tells are the colored status dot and the colored left accent-border. For each, ask the only question that matters: does this mark carry information that an adjacent label does not already carry? A green dot next to "connected" is redundant; the word already says it. A colored ribbon on a card that has no sibling card in another color is decoration pretending to be a category. If the mark is removed and nothing is lost, it was schmuck. Cut it.

25. **The callout reflex.** Important or success content gets wrapped in a tinted rounded box with a colored border (the alert / callout). Ask whether the box is doing work that a heading, a hairline, and a single accent-colored word could not. Grouping is the job of whitespace and a 1px rule, not of a filled tint. A green success box and a red error box are the same reflex; the meaning belongs on the text, not in a container.

### What credible products do instead

The restraint idiom shared by Stripe, Linear, and Vercel, stated as moves you can apply:

- **Group with typography and whitespace, not boxes.** A heading plus spacing reads as a section; a hairline (1px, low alpha) separates where a divider is genuinely needed. Reserve filled containers for functional surfaces (a scroll region, an input), never for emphasis.
- **Color is an accent on text and numbers, and only for meaning.** Green means success, red means danger, the brand color means the primary action. Apply it to a word or a value, never as a filled container or a decorative dot. One dominant color, one accent, one neutral.
- **Values get monospace / tabular figures.** A measured number ("5520 W"), an ID, or a timestamp reads as data when it is set in mono and aligns; it reads as decoration when it is bolded in the body face.
- **"Verified / done / live" is a status word or a ✓ glyph in the accent color, set on the text**, not a green alert box. The proof is the word and the value carried by weight; the container adds nothing.

When a redesign removes a box, a ribbon, a dot, or a pill and the meaning survives in the typography, the interface just moved from generated toward designed. That is the win condition for this axis.

## Animation: the same discipline, time as the axis

Space and color are two axes. Time is a third. The same attitude works: not "I wrote `transition: transform 200ms`, so it animates smoothly" but "what do I see between frame 0 and frame 12?" The screenshot becomes a *series* of screenshots. The edge trace happens on each key frame. The rhythm is the timing curve. The "odd one out" is the one element that falls out of sync.

A static end state that looks correct says nothing about the journey to get there. A UI that is neatly laid out before and after animating can collapse badly in between.

### Visual animation observation

Add these questions to the scan in "How to look". They are applied to a *series* of frames (start, quarter, half, three-quarter, end) rather than a single screenshot:

15. **Do all elements that belong together move as one?** When a header and its content both end at new positions, they must have the same *tempo* during the transition. Does the header snap while the content animates, or does one stop at 80% while the other is at 60%? This is rhythm on the time axis. A component that falls out of sync is the "odd one out" of animation.

16. **What happens to disappearing content?** Does an element collapse instantly while its container is still moving? That is a "teleporting element": it departs before its vehicle has left. You expect content to travel along until the journey ends. Fix pattern: `transition: visibility 0s linear var(--duration)` on the hidden state so the visibility flip only happens AFTER the movement finishes. Mirror image: does content only appear after its container has already moved? Then the entry is broken; visibility must flip instantly instead.

17. **Does everything start and end at the same moment?** Check the transition delay, duration, and easing of each animating element via `getComputedStyle`. Different durations are sometimes intentional (stagger) but more often a bug. "Nav snaps, content animates 200ms" is rarely expressive, usually a forgotten `transition` rule on the nav.

18. **Is a cell that is "hidden" truly gone or just invisible?** Parking off-screen (visibility hidden with full renderWidth) and collapsing to 0 (width 0, display none) look the same in a static screenshot. Under movement they do not: a parked cell can slide as one unit with the rest, a collapsed cell snaps away. For slide-style transitions: park, do not collapse.

19. **Timing versus distance.** A 200ms transition feels fast for a 50px shift and slow for an 800px shift. When multiple transitions run simultaneously with different distances, this becomes visible. The question is not "is the duration right?" but "is the SPEED (px/ms) correct for what I am communicating?" In large column shifts a shorter duration is sometimes more expressive than the same 200ms you use everywhere.

### Looking beneath the screenshot: timing and sync

A transition can look correct on a single frame but be out of sync under the hood. Code-level audits, just like the token vocabulary scan:

**1. Timing source scan.** Grep for hardcoded durations and easings in component code:

- Numeric ms/s values in CSS (`200ms`, `0.3s`): usually a missing custom property. If two elements in the same flow both hardcode `200ms` separately, they will drift apart at the first refactor.
- Hardcoded cubic-bezier or named ease (`ease`, `ease-out`, `cubic-bezier(...)`): same problem. Define a `--duration-*` and `--ease-*` vocabulary and use it everywhere.
- `transition: all`: almost always wrong. "All" includes properties you did not mean to animate (color, border) and properties that trigger layout (width, padding). Be explicit: `transition: transform var(--duration) var(--ease), opacity ...`.
- Svelte/React animation libs in places where CSS transitions would suffice: extra bundle, extra concept, usually not needed for state-to-state transitions.

**2. Sync audit.** For a flow where multiple elements must move together: explicitly list what does and what does not transition. An element receiving an inline `style:width` without a `transition` rule on it is a snapping element. That is the one quick check pattern you can run yourself via `grep -n "style:" --include="*.svelte"`.

**3. Compositor-only properties.** Transform and opacity are animated by the compositor without layout. Width, top, left, padding, margin are layout properties and trigger reflow per frame. For small elements that is fine. For rows of 5+ items or with parallel transitions it can jank. `contain: layout` on animating children isolates the reflow to their own box. `will-change: transform` (not `will-change: width`, which is an anti-pattern per MDN) promotes the element to its own layer.

The normative rule "transform and opacity only" for animations is the build-time standard that the project's design discipline should carry; what stays here is the observational diagnosis (reflow check on rows, `contain: layout` as a tactical fix, `will-change: width` as a specific anti-pattern) because those are about recognizing an existing problem, not about which rule to follow while building.

### Recording and dissecting yourself

Verifying an animation without recording it is the same as verifying a layout without a screenshot. Workflow:

**1. Reproduce.** User provides a GIF or MP4, OR you record it yourself. Self-recording can come from many routes: a headless browser test driver that saves screenshots in a loop, a manual screen-recording app, a structured user-flow recorder, a browser MCP with capture, or whichever capture tool already lives in the session's environment. Save the recording to a scratch directory that is gitignored.

**2. Dissect.** Extract frames at a useful rate (around 15 fps is enough for 200-400ms transitions, giving 3-6 frames over the animation; 30 fps for longer or subtler animations, at the cost of file size). Whatever extractor the session has works (a frame-grabber CLI, a Playwright video reader, a ffmpeg invocation, a screen-recording app's export); the outcome is decoded frames the Read tool can open. One concrete ffmpeg recipe:

```bash
ffmpeg -i capture.mp4 -vf "fps=15,scale=900:-1" /tmp/frame_%03d.png
```

`scale=900:-1` keeps file sizes small so the Read tool can view the frames.

Read the frames via the Read tool. Per frame: apply the scan questions from "How to look" (edges, rhythm, odd one out). Compare frame N with frame N+1: what changed, what should not have changed, what SHOULD have changed?

**3. Self-capture verification.** After a fix: record a new capture yourself to prove the problem is gone. Same workflow.

**4. Mid-animation inspection.** Rest-state screenshots only prove the end positions, not the journey. For intermediate inspection:

- **Slow-mo trick**: override the duration custom property via JS in a test: `document.querySelector('.root').style.setProperty('--duration', '1s')`. Trigger the transition, sleep 100-500ms, sample `getComputedStyle(element).transform` or `.visibility`. The 5x or 10x slowdown gives a wide window to read mid-animation values.
- **Multiple samples**: at t=50, 100, 150, 200ms take a snapshot, verify that the values interpolate monotonically and that related elements are in sync at each sample point.

**5. Rest-vs-mid testing.** An animation test that only checks rest state is broken by definition: it cannot fail on the halfway-through-the-animation bugs the user actually experiences. Write an explicit mid-animation assertion when it is critical that elements run in sync. The slow-mo trick makes this writable in any browser-driving test framework without race conditions.

### Pixel-level animation sampling

When you look at frames visually and the movements seem "roughly right", or you cannot tell whether a progress bar is retreating from 10% to 5%, that is the image-viewer limit: a 4px-wide bar over a 60px-tall row renders a 5% difference as 3 pixels. You cannot see that in a scaled-compressed image view. You need to read the pixel data directly from the frames.

**Technique** (four steps, language-agnostic): extract a 1-pixel-wide vertical slice at the bar position per frame, decode the raw RGB bytes, classify each pixel by RGB threshold into a small set of categories (selected colour, unread colour, background), count per category per frame to get an exact percentage. Reference implementation in Node + ffmpeg (sessions can wire the same four steps in any language and any frame extractor):

```javascript
const { execSync } = require('child_process')
const fs = require('fs')

const X = 29  // bar x-position in the GIF (measure beforehand via a single slice)
const gif = '/tmp/capture.gif'

function classify(r, g, b) {
  if (b > 150 && r < 180) return 'P'                    // purple/violet
  if (r > 200 && g > 140 && g < 190 && b < 120) return 'A'  // amber
  if (r > 200 && g > 200 && b > 200) return '.'         // background
  return '?'                                             // transition state
}

for (let n = 0; n < 50; n++) {
  execSync(`ffmpeg -y -v error -i ${gif} -vf "select=eq(n\\,${n}),crop=1:206:${X}:0" -vframes 1 /tmp/slice-${n}.ppm`)
  const buf = fs.readFileSync(`/tmp/slice-${n}.ppm`)
  // PPM: P6\n<w> <h>\n<max>\n<binary>
  const headerEnd = buf.indexOf(0x0a, buf.indexOf(0x0a, buf.indexOf(0x0a) + 1) + 1) + 1
  const pixels = buf.slice(headerEnd)
  const cells = []
  for (let i = 0; i < pixels.length; i += 3) cells.push(classify(pixels[i], pixels[i + 1], pixels[i + 2]))
  const p = cells.filter((c) => c === 'P').length
  const a = cells.filter((c) => c === 'A').length
  const pct = p + a > 0 ? Math.round(p * 100 / (p + a)) : 0
  console.log(`f${n}: ${cells.join('')}  purple=${pct}%`)
}
```

**The output gives the true picture that image view cannot deliver.** You do not just see that the bar goes from amber to purple; you see exactly that on frame 13 there is a jump to 28%, on frame 14 a peak to 33%, on frame 27 a low of 12%, etc. Only with this data can you work backwards to determine which CSS transition, $effect race, or JS reset is the cause.

**When to use**:
- A user reports a bug in an animation that you cannot see visually.
- You are unsure whether a progress bar fills linearly or has overshoot.
- You see a peak/dip/oscillation and want to know how large it is.
- Two elements animate simultaneously and you want to know whether they run in sync.

**When not needed**:
- Gross movement (entire element repositions, opacity 0 to 1).
- A difference of 20%+ that you can see with the naked eye.

**Rule of thumb**: if the user says "there is still a flicker/retreat/jitter" twice and you cannot see it, move from visual inspection to pixel sampling. Image view simply does not have the resolution for sub-5% movements.

## Layout stability: the axis of unwanted motion

Animation is intended motion. Layout stability is the absence of *unintended* motion, and it is a distinct axis with its own observation discipline. "It jumps", "it shifts", "things move around" is one of the most common defect reports, and it almost never means the animation is wrong; it means something moved that should have stayed put.

The reflex is to treat a jump as a one-off positioning bug. It is usually structural: a layout that reserves no space for a state it will later enter. Scan for it deliberately.

### Visual layout-stability observation

Apply these across a state change (hover, focus, load, expand, content update, validation), not to a single resting screenshot:

- **Does anything move that is not the thing being acted on?** Hovering a button should not shift its neighbors. A sibling that reflows on an unrelated interaction is the defect.
- **Does a container resize to its content instead of reserving space?** A field that grows when an error appears, a card that changes height when a badge loads, a row that widens with longer text: each pushes everything after it. Reserve the space up front.
- **On load, does content arrive in stages that reflow?** Text, then image, then the real values, each shoving the layout as it arrives. The final state can look perfect while the sequence to reach it jumps repeatedly.
- **Does a control appear and disappear rather than enable and disable?** A button that is absent until valid, then present, changes the layout at the worst moment. Keep it present and toggle its enabled state so the geometry holds.
- **Do equivalent siblings hold the same dimensions?** Nav bars, cells, headers that must read as one set: if their heights vary with content, they stop reading as a set and the row jitters.

### Looking beneath: what reserves space and what does not

- Elements that occupy space only when present (`display: none` toggled to block, conditionally rendered nodes) shift everything after them. Prefer reserving the space: `visibility: hidden` with the box retained, a `min-height`, a fixed-size slot, or a skeleton placeholder.
- Intrinsic-size containers (width or height auto to content) move their neighbors whenever the content changes. When the neighbor relationship matters, give the container a stable size.
- The load-time form has a name, cumulative layout shift, and its own specifics: reserve space for async content with explicit image dimensions, font fallback metrics, and placeholders for late values.
- The fix is almost always "reserve the space the state will need", not "animate the jump". Animating an unwanted jump only produces a smooth unwanted jump.

## Foundation

**Robin Williams (CRAP):** Contrast (make differences unmistakable or make them equal), Repetition (repeat visual choices for coherence), Alignment (everything must be visually connected to something else), Proximity (nearness implies relation).

**Gestalt (Wertheimer, Koffka):** The brain seeks the simplest interpretation (Pragnanz). Equal elements are perceived as a group (Similarity). This is why a 12-year-old "sees" spacing problems and Claude does not: the brain does it automatically, Claude must do it deliberately.

**Muller-Brockmann (Grid Systems):** Derive all spacing values from a shared base. The grid is a discipline that prevents arbitrariness.

**Tufte:** Maximize the data-ink ratio. Every visual element must contribute to understanding. **Tschichold:** White space is an active design element, not what remains.

**Arnheim (Art and Visual Perception):** Visual center of gravity matters more than pixel center. Optical center lies above geometric center. Asymmetric balance via visual weighting (mass, contrast, color) is livelier than strict symmetry.

**Apple HIG / Material Design / Lucide (icon grids):** Every icon has two bounding boxes. An outer canvas and an inner "live area". Primary content stays within the live area, secondary content may extend to the outer, never beyond. Material: 24x24 canvas, 20x20 live area, 2 dp padding all around. Lucide: 24x24 canvas, 22x22 live area, stroke-width 2 centered (which pushes the actual edge a further half-stroke outward). Apple SF Symbols: inner icon-grid box plus outer bounding box. An icon that touches the outer edge feels out of place.

**Bjango / Spiekermann (optical adjustments):** Mathematically identical shapes are optically unequal. Circles must overshoot the baseline and x-height. Sharp points of triangles must extend outside the bounding box. Vertical lines must appear thicker than horizontal ones to weigh equally. It is not an illusion to be fixed, it is how eyes work.

## Division of labor across the three moments

Eye-of-the-beholder is diagnostic. It looks at what IS there and compares it to intent. The other two moments in the chain are upstream (defining the standard) and build-time (applying it).

**art-director** (same plugin, sister skill) works upstream. Before CSS exists: define brand (who are we), visual language (how do we speak visually), and design-system architecture (how does this scale). Delivers `brand.md`, `visual-language.md`, and a `design-system/` skeleton. When eye-of-the-beholder observes that a hue does not fit or a spacing does not rhythm, the underlying standard should live in art-director's artifacts, not in every reviewer's head.

**Build-time design discipline** (whichever skill in the session governs this) uses the standard while building. Per feature. The normative rules (transform/opacity-only for animations, WCAG contrast ratios, spacing scale) come from there or from canonical sources (WCAG, OKLCH, framework docs). Eye-of-the-beholder refers to those rules; the build-time discipline refers to art-director's artifacts for the concrete brand choices within those rules.

The chain over time: art-director once (for a new product, brand refresh, first DS foundation), the build-time discipline per feature while building, eye-of-the-beholder per change afterward to verify visually. When eye-of-the-beholder signals a problem that does not sit in a single view but occurs system-wide (e.g. an uncoordinated spacing scale), that is a signal that art-director work is incomplete or missing.

## When iteration does not converge

Observation, fix, rescan is the right loop for a located defect. It is the wrong loop when the direction itself is wrong. When the same complaint survives two rounds of fixes ("still too busy", "still feels off", "nog steeds niet"), that is the signal that the problem is not a pixel value but the direction itself, and more pixel-pushing will not find it.

Stop the loop. Do not start a third round of the same adjustment. Two routes out:

- **If there is no agreed direction to verify against**, the gap is upstream: switch to **taste-test**, which elicits a direction by showing divergent options and reading the reaction, instead of guessing at the one the user is holding but cannot describe. eye-of-the-beholder verifies against a standard; if the standard does not exist, the standard has to be produced first.
- **If the current attempt has accumulated too many patches to reason about**, reset from first principles: set the current version aside and rebuild the one screen from the direction, rather than adjusting a version whose problems compound. This is usually cheaper than the third, fourth, and fifth round it replaces.

The tell: you are making the same *kind* of change again ("a bit more spacing", "a little calmer") and the reaction is not improving. Change the level, not the pixels.

## Common blind spots

| What Claude does | What goes wrong |
|-----------------|----------------|
| Writing `padding: 0.6rem 0` | The 0 is zero space left/right. Read every value. |
| Treating CleanShot or marker annotations as product design | The marks are feedback scaffolding. Extract the intent and ignore the screenshot-tool visual style unless exact-match intent is explicit. |
| Placing an element outside the main container | That element inherits no padding. It needs its own spacing. |
| Looking at the center, not the edges | The center always looks fine. The errors live at the edges. |
| Measuring only perimeter padding, not sibling gaps | Container has 32px all around, but a paragraph touches the table below. Collapsed padding. Walk explicitly through each sibling pair inside the container. |
| `:host` / container padding passed through by margin-collapse | First child margin-top collapses through parent padding-top if the parent has no border/padding between. Fix with `display: flow-root` or an explicit border-top. |
| "Does it fit?" as an evaluation criterion | Fit is not quality. Something can fit and still look bad. |
| Making a fix and stopping | Every fix triggers a rescan of all four edges. |
| Reading CSS as evidence | CSS describes intent, not result. The screenshot is the truth. |
| Shrinking font sizes to make things fit | Shrinking is always wrong. Restructure the layout. |
| SVG path filling the viewBox to the edge | Default `overflow: hidden` clips silently. Leave 1-2 units of margin, or enlarge the viewBox. |
| Declaring an auto-sizing text container done after seeing it "render" | A popover, sheet, banner, toast, or drawer auto-sizes to its intrinsic content. Wrong modifier order silently clips top/bottom or start/end of the body. Always read every visible line against the source string; check the first and last word are present. |
| Forgetting stroke-width in a bounds check | Centered stroke adds `width/2` to all sides. A path to y=16 with stroke=2 effectively ends at y=17. |
| Mathematically centering a glyph | Optical center is higher. Push 2-5% upward. |
| Making a round shape equal to a square one | Circles must be ~113% to weigh optically equal. |
| Only tracing the page edges | Trace is fractal. Every container with edges deserves an edge trace: component, glyph, path, pixel. |
| Symmetrically centering text and icon in a pill | Font ascent > descent makes digits appear optically high. Align to cap-height center, not bounding box. Micro-translate of 0.5-1px or cap-height line-height. |
| Opacity modifier as a third text color (`text-foo/50`) | You have a missing tertiary level, not half-text. Define an explicit token. |
| Palette color in app code (`text-red-500`) | Semantic bypass. Replace with `text-danger` or equivalent. |
| Hardcoded hex in a component style block | Missing token. Define a new role, or use an existing token that fits. |
| "Dark mode looks fine" without math | Check the ratios. Surface delta below 1.07x is invisible, text contrast below 4.5 fails AA. |
| Two adjacent surfaces where you see no difference | The difference IS not there. Increase the luminance delta to at least 1.07x. |
| Color values for light without a counterpart for dark | Both modes are separate designs. Use `light-dark(L, D)` so they live side by side. |
| Only rest-state screenshots for animation | The journey is the bug. Take frames or use the slow-mo trick to inspect mid-animation. |
| Judging progress animations on regular screenshots | 5% differences in bar-fill are invisible on normal image view. Sample pixels directly from frames. See "Pixel-level animation sampling" section. |
| Content disappearing before its container | Teleporting element. Delay `visibility: hidden` with `transition: visibility 0s linear var(--duration)` on the hidden state. |
| Hardcoded ms/ease scattered across components | Define `--duration-*` and `--ease-*` custom properties, use everywhere. Otherwise elements drift apart at the first refactor. |
| `transition: all` | Animates color, border, layout props too. Explicit: `transform var(--dur), opacity var(--dur)`. |
| `will-change: width` | Anti-pattern per MDN. Width is a layout property and gets no GPU compositing. Only use `will-change: transform` / `opacity`. |
| Inline `style:width` without a `transition` rule | Snaps instantly. Grep for `style:` in components to find snapping elements. |
| Cells collapsing to 0 instead of parking off-screen | Collapse forces "from nothing to something" jumps. Park via visibility-hidden with retained renderWidth. |

## Output

After viewing a screenshot:

```
Observation (before I look at the CSS):
- Top: the title touches the top of the page
- Right: sufficient space
- Bottom: ~25% white at the bottom, feels empty
- Left: the title starts further left than the step-content
- Rhythm: steps are evenly distributed
- Odd one out: step 3 has less content, feels narrower

Diagnosis (after CSS check):
- .print-header has padding: 0.6rem 0 (zero left/right)
- .print-header has no margin-top (presses against content-area top)

Fix:
- padding: 0.6rem 0.9rem (0.9rem = 3x base unit, equal to .main padding-x)
```

After viewing a series of frames (animation):

```
Observation per frame (before I look at the CSS):
- Frame 0 (start): nav shows 3 titles, content shows 3 cells, everything neatly in rhythm.
- Frame 3 (mid): nav is already at the new layout with 2 titles, content is halfway.
  The nav titles have snapped, the cells are still animating.
- Frame 6 (end): nav and content both in final position.
- Odd one out: the nav is not in rhythm with the content. They end together but
  do not start together.
- Disappearing content: in frame 3 the content of the sliding-away cell is already
  hidden while its container is still moving. Teleporting element.

Diagnosis (after CSS check):
- .nav-title has inline style:width but no `transition` rule in the CSS.
- .cell-collapsed sets visibility: hidden instantly without a delay.

Fix:
- .nav-title gets transition: width var(--duration) var(--ease).
- .cell-collapsed gets transition: visibility 0s linear var(--duration), so
  the visibility only flips after the movement is complete.
```
