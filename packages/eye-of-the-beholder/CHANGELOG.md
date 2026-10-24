# eye-of-the-beholder changelog

## [v2.0.22]

### Changed

- Design reasoning no longer counts a restyle of the same structure, section order and copy as a new direction. When the words, the page order or missing real material make a surface generic, a new hypothesis changes those first, with real material and the owner's own voice.

## [v2.0.20]

### Added

- `obvious` decides where an action belongs from the task's length, frequency, stakes and need for context: inline from its control, a modal only when blocking helps (information the process cannot continue without, a deliberate confirmation), and its own page or cell for substantial, multi-step or comparative work. The entry point routes that question to `obvious`. The rule links its sources (NN/g, Carbon, GOV.UK).

## [v2.0.15]

### Added

- `obvious` diagnoses confusing controls, over-explaining UI and avoidable cognitive load from the current task, then improves the interaction while preserving necessary guidance and accessibility. The main entry point and rendering review route relevant usability problems to it.

## [v2.0.10]

### Breaking

- Use `eye-of-the-beholder` as the entry point. The public stages are now `explore`, `define` and `review`; `taste-test`, `art-director`, `fat-marker-sketch` and `visual-inspection` are retired. Update saved invocations of those names.

### Changed

- New visual treatments start with reference-guided image generation and one consequential decision per round. Rejection of all candidates is valid. Concept, mechanism and implementation approval are tracked separately, and accepted images accompany the visual-language record.
- Review evaluates the real implementation's aesthetics, meaning, fidelity and interaction separately. Image classification and reference comparison tools remain available internally.
- Motion evidence defaults to broadly playable H.264 MP4 and is verified as a delivered file before it is linked for review. WebM remains available only when the recipient or target surface is known to support it.
- Motion review now rejects captures whose recorder materially depresses the product frame rate, and requires the observed runtime frame-rate range to accompany timing judgments.

## [v2.1.1]

### Fixed

- **`/fat-marker-sketch` now distinguishes annotated screenshots from actual sketches.** The skill classifies incoming images before interpreting them, separates captured product pixels from annotation-tool pixels, and uses exposed filenames such as `CleanShot` or `Screenshot` as provenance hints rather than proof of annotations or match intent. Its readback now names the actual artifact instead of calling every upload a fat-marker sketch.

## [v2.1.0]

### Added

- **`/taste-test`: elicit a visual direction without having to describe it.** For when you know what you like when you see it but cannot put it into words. It shows 3 to 5 genuinely divergent options side by side and reads which one you point at, offers reaction-card word-axes (calm vs energetic, warm vs clinical) to select from instead of composing your own, harvests current genre exemplars for transferable moves rather than copied pixels, and actively avoids the documented AI-slop tells. Each decision is recorded in a growing `visual-language.md` so the direction survives between sessions. It sits between `/art-director` (heavy, once) and `/eye-of-the-beholder` (diagnostic, per change).
- **`/fat-marker-sketch`: read an uploaded screenshot as feedback, not as a literal design.** An uploaded image is treated as a low-fidelity sketch by default. It extracts the complaint, target, direction, content, and topology, and ignores the annotation layer (arrow colors, callout bubbles, CleanShot or Preview chrome, hand-drawn boxes). It writes an interpretation readback before the first edit and pins the single axis when a reference is being borrowed. Literal reproduction is the earned exception, reserved for stated match-intent, which routes to `/visual-inspection`.

### Changed

- **`/eye-of-the-beholder` gained a complaint-to-axis table, a layout-stability axis, a one-meaning-per-channel rule, and a convergence guard.** Gut-word complaints ("too busy", "it jumps", "looks cheap") now map to the axis to scan. Layout shift between states ("it jumps") is a first-class axis. Every visual channel (color, hatching, stroke, opacity) is expected to carry one documented meaning. When the same complaint survives two rounds, the skill routes to `/taste-test` or a first-principles reset instead of pushing more pixels. The screenshot-interpretation section now defers to `/fat-marker-sketch` as the single source for that protocol.

## [v2.0.1]

### Breaking

- **eye-of-the-beholder now ships from the public laicluse-agent-fieldkit marketplace.** Install the Fieldkit copy for `eye-of-the-beholder`, `art-director`, and `visual-inspection`, then uninstall the old `eye-of-the-beholder@leclause` package. The skill names and trigger phrases are unchanged; only the marketplace identity changed.

### Changed

- **Codex receives generated adapter metadata for all three visual skills.** The skill sources remain shared, while Codex gets strict manifest and frontmatter views through the Fieldkit adapter build.

## [v1.0.35]

### Changed

- **External `impeccable` plugin no longer referenced.** Visual skills and `art-director` templates swap `impeccable` cross-references for canonical specs (WCAG 2.1, OKLCH) or "the build-time discipline in your session".
