# eye-of-the-beholder

Visual layout review. Observation before explanation: screenshot first, describe what you see, then diagnose. Design-TDD for CSS.

Catches cramped text, missing margins, disproportionate spacing, broken WCAG contrast, ad-hoc token use, snapping transitions, out-of-sync animations, layout that jumps between states, and content that disappears before its container does. It also helps translate a user who has taste but no design vocabulary into a direction, and reads uploaded screenshots as feedback rather than as literal designs.

This plugin ships five sister skills:

- **`/eye-of-the-beholder`** (default): diagnostic, per-change visual review.
- **`/taste-test`**: direction elicitation for someone who has taste but cannot describe it. Shows divergent options and reads the reaction instead of asking for a spec, then records the result in a growing `visual-language.md`.
- **`/fat-marker-sketch`**: classifies an uploaded visual as an annotated screenshot, clean screenshot, actual low-fidelity sketch, or design reference before extracting intent. Annotation-tool styling stays out of the product.
- **`/art-director`**: upstream identity work. Captures brand, visual language, and design-system architecture BEFORE CSS exists. Not for small UI tweaks; for new products, brand refreshes, or first-time design-system foundation.
- **`/visual-inspection`**: reference matching. Forces a screenshot-plus-measurement loop when a new element must match an existing visual reference on named axes such as padding, radius, font, color, size, or alignment.

## Installation

```bash
claude plugins install eye-of-the-beholder@laicluse-agent-fieldkit
codex plugin add eye-of-the-beholder@laicluse-agent-fieldkit
```

## Skills

### `/eye-of-the-beholder`

Reviews the current visual state. Captures a screenshot, lists concrete observations, then maps each observation to a diagnosis: token, spacing scale, contrast ratio, animation timing, layout shift, or another visible cause. Includes a complaint-to-axis table that turns a gut-word ("too busy", "it jumps", "looks cheap") into the axis to scan, a layout-stability axis for unwanted motion between states, a one-meaning-per-channel rule for visual semantics, and a convergence guard that routes to `/taste-test` or a first-principles reset when the same complaint survives two rounds.

### `/taste-test`

Elicits a visual direction from a user who knows what they like when they see it but cannot describe it. Renders 3 to 5 genuinely divergent options side by side, offers reaction-card word-axes to point at instead of asking for a specification, harvests current genre exemplars for transferable moves (not copied pixels), and actively avoids the documented AI-slop tells. Records each decision in a growing `visual-language.md` so the direction is not re-litigated every session. Sits between `/art-director` (heavy, once) and `/eye-of-the-beholder` (diagnostic, per change).

### `/fat-marker-sketch`

Classifies an uploaded screenshot or image before using it as design evidence. It distinguishes annotated screenshots from actual low-fidelity sketches, separates captured product pixels from annotation-tool pixels, and uses exposed filenames such as `CleanShot` or `Screenshot` as provenance hints rather than verdicts. It then extracts the complaint, target, direction, content, and topology; ignores incidental annotation styling; and routes stated match intent to `/visual-inspection`.

### `/art-director`

Produces `brand.md` + `visual-language.md` + `design-system/` skeleton from stakeholder interviews, competitive scan, and brand strategy. Three modules: brand identity discovery, visual language translation across type / color / form / motion / photography, and design-system architecture with token layers and component taxonomy. Artefacts become the standard that the session's build-time discipline applies per feature and eye-of-the-beholder verifies per change.

### `/visual-inspection`

Compares a reference element and the result side by side. The user names the axis; the skill records the reference value, result value, match verdict, and screenshot evidence. It is stricter than an open visual review: every named axis stays open until it matches or the user accepts the deviation.

## Auto-trigger

`/eye-of-the-beholder` activates DURING and AFTER layout CSS, color token, contrast, layout-stability, or animation work, to scan the rendered result. Also activates when a gut-word complaint ("too busy", "it jumps", "looks cheap", "off") needs translating into an axis to scan.

`/fat-marker-sketch` is the classifier and reading discipline for any image shared as a design cue. Auto-selection is unreliable when a message contains only a dropped image because there may be no text for the description to match. Keep the discipline primed: inspect any exposed filename, then verify the visible layers instead of guessing from the name. `CleanShot`, `Screenshot`, and localized capture names indicate likely screenshot provenance; visible marks establish whether it is annotated. Once the resulting change is rendered, `/eye-of-the-beholder` scans the render.

`/taste-test` activates when the user reacts with a gut-word and no specification, when a new screen has no established direction and they cannot describe one, or when two rounds of pixel iteration have not converged. It is not for "make it match this reference" (that is visual-inspection) or full brand work (that is art-director).

`/art-director` activates only on explicit brand / art-direction / design-system-architecture requests, or at the start of a new product or brand refresh. Strict triage: it does NOT auto-fire on per-component or per-view design work.

`/visual-inspection` activates when a user points at a reference element and asks for the result to match it on one or more visual axes, with match-intent stated. It is not for general "make it better" review (that remains eye-of-the-beholder) or for reading an uploaded image as feedback (that is fat-marker-sketch).

## Why observation first

Skipping straight to diagnosis is how AI reviews end up validating their own assumptions. The eye-of-the-beholder skill insists on at least three concrete observations before any cause is named, so the diagnosis has to fit what is actually on screen.

The art-director skill works one level up: brand attributes and visual-language decisions captured upfront are the reference against which observations get their meaning. "Feels off" is unverifiable until there is a documented standard to feel off from. Taste-test is the lighter, per-direction way to produce that standard when the user cannot describe it: it shows options, reads the reaction, and records the result. Visual-inspection works one level tighter: a named reference turns the visual question into a measurement loop. Fat-marker-sketch guards the input side by distinguishing captured product evidence, annotation commentary, rough sketches, and deliberate references before any pixels are translated into UI.
