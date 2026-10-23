# Color pitfalls

Read when scanning color, contrast or channel semantics. Look at the render first: count the grays, look for the distinction between adjacent surfaces, read secondary text at the real scale. Then look beneath it.

## Beneath the render

- **Token vocabulary.** Opacity modifiers on color utilities, palette colors in app code, hard-coded values in style blocks, and tokens that are used but not defined all signal a vocabulary with a missing role. The fix is rarely one more token; it is a vocabulary in which every role on screen has a name.
- **Contrast math.** Where an accessibility requirement applies, compute it instead of squinting. WCAG 2.1 relative luminance: per channel `c/255`, linearised as `c ≤ 0.03928 ? c/12.92 : ((c+0.055)/1.055)^2.4`; `L = 0.2126 R + 0.7152 G + 0.0722 B`; ratio `(L_lighter + 0.05) / (L_darker + 0.05)`. AA: 4.5:1 for body text, 3:1 for large text and control boundaries; AAA: 7:1 and 4.5:1. Run it for the combinations the product actually uses.
- **Surface hierarchy.** Adjacent surfaces must communicate their intended relation at the real viewing scale. In dark themes absolute luminance values are tiny, so judge ratios, not differences. No universal ratio establishes aesthetic success; compare with the accepted palette.
- **Two designs, one set of roles.** Light and dark are separate designs that must share role meanings: if a role is the most prominent reading surface in light, it is that in dark too. Keeping both values in one rule (for example `light-dark()`) is one way to stop them drifting; a token pair per mode is another. The check is that every role means the same thing in both modes.

## Symptoms

| Symptom | Competing explanations | Distinguishing check | Move |
|---|---|---|---|
| Two surfaces that should differ look the same | Delta too small for the scale; no distinction intended | Decide whether a distinction is needed and which channel should carry it | Raise the delta or carry the distinction another way; do not impose a generic threshold |
| Secondary text is tiring to read | Fails the applicable contrast requirement; size too small for its role | Compute the ratio and check the size | Meet the requirement; do not solve it by shrinking |
| A third text color appears as an opacity modifier | A missing tertiary role; a deliberate translucent treatment over varied backgrounds | Check whether the value is reused as a text level or applied once over a changing surface | Define the role when it is a level; keep the modifier when translucency is the point |
| Status colors feel weak | Light hues that fail contrast on light backgrounds | Compute the ratio for the status text on its background | Use the darker step that passes |
| "Dark mode looks fine" | Judged without measurement | Measure text and control contrast, then inspect surface hierarchy against the accepted target | Fix what the numbers and the target show |
| The viewer asks what a color means | A channel carrying two meanings; variation that encodes nothing while looking like data | For every information-carrying channel, state the one thing it encodes and whether it is written down | Give the second dimension its own channel; remove encoding-shaped variation that encodes nothing. Decoration that reads as decoration is allowed |
