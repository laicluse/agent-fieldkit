# References

Sources for the rules in SKILL.md. Grounded in existing design literature and icon system documentation.

## CRAP (Contrast, Repetition, Alignment, Proximity)

Robin Williams, *The Non-Designer's Design Book* (1994, Peachpit Press). The four principles every beginning designer learns. Covered in the Foundation section.

## Gestalt

Max Wertheimer, Kurt Koffka (1920s). *Pragnanz* (simplicity), *Similarity* (equal elements group), *Proximity* (nearness implies relation), *Closure* (brain fills gaps), *Continuity* (eye follows flowing lines).

## Grid discipline

Josef Muller-Brockmann, *Grid Systems in Graphic Design* (1981). All spacing derived from a shared base.

## Data-ink ratio

Edward Tufte, *The Visual Display of Quantitative Information* (1983). Maximize the proportion of "ink" that directly represents data.

## Print margins (1:1:2:3)

Jan Tschichold, *The Form of the Book* (1991, Hartley & Marks). Margin ratios inner:top:outer:bottom = 1:1:2:3. The Van de Graaf canon from medieval manuscripts: 2:3:4:6.

## Visual balance and optical center

Rudolf Arnheim, *Art and Visual Perception: A Psychology of the Creative Eye* (1954, University of California Press). Visual center of gravity, optical center lies above geometric center, asymmetric balance via visual weighting.

## Icon grids

- **Apple Human Interface Guidelines, Icons**: https://developer.apple.com/design/human-interface-guidelines/icons. Inner icon-grid bounding box (primary content) and outer bounding box (secondary content). "If an icon's primary content extends beyond the icon grid bounding box, it tends to look out of place."
- **Material Design, Metrics & Keylines**: https://m1.material.io/style/icons.html. Canvas 24x24 dp, live area 20x20 dp, 4 dp padding all around. Dense variant: 20x20 canvas, 16x16 live area, 2 dp padding.
- **Lucide Icon Design Guide**: https://lucide.dev/contribute/icon-design-guide. 24x24 viewBox, minimum 1 px padding inside canvas, stroke-width 2 centered. Actual edge lies at `coordinate +- 1` due to the centered stroke.

## Optical corrections

- **Bjango, Formulas for optical adjustments**: https://bjango.com/articles/opticaladjustments/. "A square and a circle with matching width and height do not look like they are the same weight. The circle seems smaller." A circle must be ~112.84% of a square to weigh optically equal.
- **Erik Spiekermann, *Stop Stealing Sheep and Find Out How Type Works*** (1993). Overshoot in typography: round letterforms extend past baseline and x-height. Also: digits and letters must be aligned to cap-height center, not glyph bounding box, because of ascent/descent asymmetry in font metrics.
- **Braid Design, Capsize**: https://seek-oss.github.io/capsize/. Library and article about cap-height line-height. "Flex centering in CSS uses the line-box, not the cap-height, which means text appears visually offset from center in buttons and badges." Fix via calculated line-height or `text-box-trim: trim-both cap alphabetic`.
- **CSS WG, `text-box-trim`**: https://www.w3.org/TR/css-inline-3/#text-edges. New CSS property for line-box trimming to cap-height/baseline. Browser support 2024+.

## SVG overflow default

- **CSS-Tricks, 6 Common SVG Fails**: https://css-tricks.com/6-common-svg-fails-and-how-to-fix-them/. "By default, the CSS overflow value of svg elements is set to hidden, meaning anything outside of the viewBox gets clipped off." Fix via `overflow="visible"` is a workaround, not a solution.
- **SVG spec, viewBox**: https://www.w3.org/TR/SVG11/coords.html#ViewBoxAttribute.

## Pixel-perfect vector work

- **iconvectors.io, Pixel-Perfect SVG Setup**: https://iconvectors.io/tutorials/make-pixel-perfect-svg-icons.html. Even strokes (2, 4) on integer coordinates, odd strokes (1, 3) on `.5` offsets. Export to bitmap 1x/2x to inspect edges.

## Canon (general)

Massimo Vignelli, *The Vignelli Canon* (2010, Lars Muller). Freely available. Discipline over creativity, deliberate restriction of choices.
