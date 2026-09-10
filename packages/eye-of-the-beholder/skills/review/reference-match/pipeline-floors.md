# Pipeline floors

Per-axis irreducible floor when comparing a CSS-rendered candidate against a canvas-PNG reference at the same display size. The floor is the smallest delta the gate can hit no matter how the candidate's CSS is tuned, because the rendering pipelines differ at the rasterization level.

A floor is "irreducible" when no CSS knob can move the axis any closer to the reference without breaking another axis. A floor is "reducible-with-effect" when a side-effect knob (typically `filter:blur` or a stacked `box-shadow`) can reduce the floor at the cost of fidelity on a different axis.

Reference baseline: 32x32 device-pixel canvas-PNG favicon, dark squircle plus orange "31" digits, drawn via a `renderFaviconBadge` function. Candidate baseline: a CSS pill rendered at 16 CSS pixels at DPR 2 with `width:16px`, `height:16px`, `display:inline-flex`, `font-family:ui-sans-serif`.

## Floors

| Axis | Floor (delta) | Type | Citation case | Notes |
|------|---------------|------|---------------|-------|
| frame.w | 0 | reachable | identical-favicon-twin: 0 | `width:16px` plus `flex-shrink:0` locks bbox. Parent flex without shrink-lock squeezes the pill. |
| frame.h | 0 | reachable | identical-favicon-twin: 0 | Same with `height:16px`. |
| ink.w | 5 px observed (typical 1-3) | irreducible | pill-radius-3-borderline: -5 | CSS-text and canvas-text differ on glyph advance for "31" at DPR 2. The 5-pixel delta is for the radius-3 borderline case where `font-size:9` did not match the favicon's `font-size:38` (downscaled). Even at matched sizes, expect a 1 px residual. |
| ink.h | 1 px | reachable | pill-radius-3-borderline: 0 | Matched at default settings. |
| pad.top/bottom | 1 device px | reachable | pill-radius-3-borderline: pad.top -1, pad.bottom +1 | 0.25 CSS-pixel asymmetry from font ascent vs descent rasterizes to 1 device px at DPR 2. |
| pad.left/right | 2-3 device px | reachable | pill-radius-3-borderline: pad.right +3, pad.left +2 | Glyph metrics asymmetry. Closes with letter-spacing tuning. |
| corner.TL/TR/BL/BR (diag) | 0 | reachable | pill-radius-3-borderline: corner.* all 0 | Border-radius matches the canvas's nearest-curve-point. |
| bgDiag.* | 1-2 device px | irreducible | pill-radius-3-borderline: bgDiag.TL +2 | CSS border-radius leaves the (0,0) corner pixel pure BG; canvas-PNG paints it with AA. |
| aaDiag.* | 1-2 device px | irreducible | pill-radius-3-borderline: aaDiag.TL -2 | Mirror of bgDiag: CSS produces 0 EDGE in the corner; canvas produces 2-4. `filter:blur(0.3px)` reduces at glyph-blur cost. |
| edgeExt.* (legacy) | 1-2 px | reachable | pill-radius-3-borderline: edgeExt.TR +2 | Sum of bgExt and aaExt. The sum matches while the split exposes the cross-pipeline mismatch. |
| bgExt.* | 1-3 device px | irreducible without filter | pill-radius-3-borderline: bgExt.TL +3 | Same source as bgDiag: CSS hard cutoff vs canvas soft fade. |
| aaExt.* | 1-2 device px | irreducible without filter | pill-radius-3-borderline: aaExt.TL -2 | Same source as aaDiag. |
| halo.* | 2-3 EDGE pixels | irreducible | pill-radius-3-borderline: halo.TR +3 | Canvas produces 5-7 EDGE pixels in the 5x5 corner block; CSS produces 0-3. `filter:blur(0.3-0.5px)` raises CSS halo. |
| hist.INK | 2-3% | reachable | pill-radius-3-borderline: hist.INK -2.05 | Tune font-size and font-weight. |
| hist.FRAME | 1-2% | reachable | pill-radius-3-borderline: hist.FRAME +0.20 | Follows hist.INK plus border-radius. |
| hist.EDGE | 1-3% delta | irreducible | pill-radius-3-borderline: hist.EDGE -0.49 | Often passes; raises only when AA halos diverge sharply. |
| hist.BG | 1-2% delta | reachable | pill-radius-3-borderline: hist.BG +0.69 | Inverse of hist.EDGE. |
| ms.32x32.meanRGB | <5 RGB units | reachable | pill-radius-3-borderline: (-1.5, 2.5, 5.6) | Coarse-scale color balance matches. |
| ms.1x1.meanRGB | <8 RGB units typical, up to 15 | irreducible-when-corner-AA-differs | pill-radius-2-too-tight: 1x1 delta (5,4,5) | Cited from a different case (radius-2 instead of radius-3) because radius-3 happens to balance corner misclassification across the integral; radius-2 reveals the floor more cleanly. |
| pixel diff | 22-37% | irreducible | pill-radius-3-borderline: 30.37%, pill-radius-2: 30.08%, pill-radius-5: 37.60% | Cross-pipeline AA on glyph and corner pixels at threshold 24/255. |

## Implications for confidence

The `--confidence` scoring penalises every failed axis without distinguishing reachable from irreducible failures. A confidence below 95 is a "we are not at the twin-grade match" signal, not a "the gate broke" signal. When the failures are all on the irreducible-floor axes, read the score as "the cross-pipeline floor was reached, anything closer requires changing the rendering pipeline of one side".

The score-to-floor relationship is empirical: the corpus-measured calibration in `corpus-confidence-scores.md` shows what each case scores under the current weights, so the operator can compare a candidate's score against where the corpus's match, mismatch, and borderline cases land.

## Evidence

The values above were measured against the corpus on 2026-05-03 with `ink-assert.mjs` at the version of this commit. The reproduction recipe:

```bash
node packages/eye-of-the-beholder/skills/review/reference-match/scripts/ink-assert.mjs \
  --reference packages/eye-of-the-beholder/skills/review/reference-match/scripts/cases/identical-favicon-twin/reference.png \
  --candidate packages/eye-of-the-beholder/skills/review/reference-match/scripts/cases/pill-radius-3-borderline/candidate.png \
  --max-diff 2
```

Re-run on every borderline and mismatch case in `cases/`; the per-axis delta column is the floor evidence for that axis. The numbers in the table above are the consistent observed deltas across the borderline-and-mismatch subset, not theoretical limits. When the corpus changes (new case, new axis), re-run and update the table; the catalogue is empirical, not derived.

## How to extend this catalogue

When a new axis is added to `ink-assert`:

1. Run the corpus and observe how the new axis behaves on the borderline cases (radius 3 and 4 favicon-vs-pill).
2. Try every CSS knob in `direction-matrix.md` against the reference and see if any combination closes the new axis's gap.
3. If yes: floor is "reachable" or "reducible-with-effect", document the specific CSS variant.
4. If no: floor is "irreducible", document the cause (which pipeline produces the diverging pixels, and why).

The catalogue is empirical, not derived. Add measurements, do not infer values from theory.
