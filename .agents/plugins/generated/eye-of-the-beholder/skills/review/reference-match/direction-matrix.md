# Direction matrix

How each tunable CSS knob on the candidate pill moves each axis in `ink-assert`.

Cell legend: `↑` = increasing the knob makes the candidate's measured value go up (relative to a fixed reference); `↓` = increasing the knob makes the value go down; `↕` = non-monotonic (the value can move either direction depending on the regime); `0` = no measurable effect at the resolutions this tool operates at; `?` = not yet measured.

Reference baseline for the matrix: a 32x32 device-pixel canvas-PNG favicon with a dark squircle and orange "31" digits. The candidate is a CSS pill rendered at 16 CSS pixels at DPR 2.

| Axis | border-radius | padding | font-size | font-weight | letter-spacing | filter:blur | box-shadow |
|------|---------------|---------|-----------|-------------|----------------|-------------|------------|
| frame.w | 0 | ↑ | 0 | 0 | 0 | 0 | ↑ |
| frame.h | 0 | ↑ | 0 | 0 | 0 | 0 | ↑ |
| ink.w | 0 | 0 | ↑ | ↑ | ↑ | 0 | 0 |
| ink.h | 0 | 0 | ↑ | ↑ | 0 | 0 | 0 |
| pad.top | 0 | ↑ | ↓ | 0 | 0 | 0 | ↑ |
| pad.right | 0 | ↑ | ↓ | ↓ | ↓ | 0 | ↑ |
| pad.bottom | 0 | ↑ | ↓ | 0 | 0 | 0 | ↑ |
| pad.left | 0 | ↑ | ↓ | ↓ | ↓ | 0 | ↑ |
| corner.TL/TR/BL/BR (diag) | ↑ | 0 | 0 | 0 | 0 | ↑ | 0 |
| bgDiag.* | ↑ | 0 | 0 | 0 | 0 | ↓ | 0 |
| aaDiag.* | 0 | 0 | 0 | 0 | 0 | ↑ | 0 |
| edgeExt.* (legacy combined) | ↑ | 0 | 0 | 0 | 0 | ↑ | 0 |
| bgExt.* | ↑ | 0 | 0 | 0 | 0 | ↓ | 0 |
| aaExt.* | 0 | 0 | 0 | 0 | 0 | ↑ | 0 |
| halo.* | 0 | 0 | 0 | 0 | 0 | ↑ | ↑ |
| hist.INK | 0 | 0 | ↑ | ↑ | ↑ | 0 | 0 |
| hist.FRAME | ↑ | ↑ | ↓ | ↓ | ↓ | ↓ | ↑ |
| hist.EDGE | ↑ | 0 | 0 | 0 | 0 | ↑ | ↑ |
| hist.BG | ↓ | ↓ | 0 | 0 | 0 | ↓ | ↓ |
| pixel diff | ↕ | ↕ | ↕ | ↕ | ↕ | ↓ (small) | ↕ |

The multi-scale meanRGB axes (`ms.32x32` through `ms.1x1`) are intentionally absent from this matrix. Their value at a given scale is an integral over the frame area, so the direction depends on which classes the integral happens to mix. A row marked `↕` everywhere is uninformative; the operator should read `ms.*` axes as final tightness checks rather than as iteration targets, and tune the structural axes above (frame, ink, padding, corners) to drive `ms.*` toward the reference indirectly.

## Notes

**border-radius vs corner axes.** Increasing border-radius moves the visible curve further into the corner, raising `corner.diag`, `bgDiag`, `bgExt`, and `edgeExt`. It does NOT raise `aaDiag`/`aaExt`/`halo` because CSS border-radius produces a sharp transition: more BG pixels in the corner, not more EDGE pixels. The aa-axes only respond to filters or shadows that introduce anti-aliased gradients.

**filter:blur is the soft-corner knob.** It increases all aa-* axes and `halo` while reducing `bgExt` and `bgDiag` (BG turns into EDGE under blur). It is the only CSS-only mechanism that produces canvas-PNG-style soft corners. Side effect: it blurs the glyph too, so use it sparingly.

**padding shifts geometry, not corner shape.** All four `pad.*` axes follow padding directly (their CSS namesakes); `frame.w/h` follows total padding addition. Corners and aa-axes do not respond to padding.

**font knobs change ink, not frame.** `font-size`, `font-weight`, and `letter-spacing` move `ink.*` and `hist.INK`/`hist.FRAME` (the digit fills less or more of the frame area). They do not affect the frame box geometry.

**Multi-scale meanRGB at 1x1 is an integral.** Changing border-radius, padding, font-size all shift the average color over the frame area, sometimes up, sometimes down depending on whether the change adds more INK (orange) or more BG (light gray). Direction is non-monotonic; rely on the surrounding axes to localize.

**Pixel diff is generally non-monotonic.** Increasing the candidate's match on one axis can lower or raise pixel diff depending on which other axes shift. Use the diff as a final tightness check, not as an iteration target.

## How to extend the matrix

When a new axis is added to ink-assert, run a knob sweep against a fixed reference and observe the direction. The recommended sweep:

1. Build a 32x32 favicon canvas as the reference.
2. Render a CSS pill at default settings, capture, run ink-assert.
3. Bump one knob (e.g. border-radius from 2 to 5 in 0.5 steps), capture each, run ink-assert.
4. For each axis, plot value vs knob. Monotonic increase = `↑`, monotonic decrease = `↓`, peak-and-fall or oscillation = `↕`, flat = `0`.
5. Add the row.

This file is reference, not a generated artefact. Update it when ink-assert changes, when corpus extension surfaces a new knob, or when an empirical sweep contradicts a cell.
