# eye-of-the-beholder changelog

The post-update broadcast (see `bin/check-broadcast`) shows the topmost
section once per machine whenever the installed `version` in
`.claude-plugin/plugin.json` changes. Entry headers record the version at
which the entry was written; a pre-commit hook auto-bumps `plugin.json` on
every commit, so the header may lag the shipped version. Header numbers are
informational, the broadcast is positional. Use the `--force` flag on the
helper to re-read at any time.

Categories:

- **Breaking**: user must adapt
- **Added**: new commands, new optional behavior
- **Changed**: non-breaking adjustments worth knowing about
- **Fixed**: silent unless the bug was user-visible

Patch-level fixes that change nothing the user can observe are intentionally
omitted; the broadcast budget is for things the user benefits from knowing.
The helper writes the sentinel only when stdout is non-empty, so a CHANGELOG
without a `## [vX.Y.Z]` section stays silent on every update.

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
