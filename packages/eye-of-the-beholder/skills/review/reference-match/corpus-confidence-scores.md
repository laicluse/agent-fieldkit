# Corpus confidence scores

Empirical calibration of `ink-assert --confidence` against the corpus. Run with `--max-diff 2` (the tool default) on every case, score recorded as the integer the tool printed.

| Case | Verdict | Confidence |
|------|---------|------------|
| identical-favicon-twin | match | 100 |
| identical-pill-twin | match | 100 |
| pill-radius-2.5-too-small | mismatch | 61 |
| pill-radius-2-too-tight | mismatch | 49 |
| pill-radius-3-borderline | borderline | 48 |
| pill-radius-4-borderline | borderline | 40 |
| tiny-pill-dimension-mismatch | mismatch | 27 |
| pill-radius-5-too-wide | mismatch | 22 |
| favicon-vs-half-size-clearly-different | mismatch | 0 |

## Reading the table

- **Match cases score 100.** No false negatives in the current corpus. The 95-threshold is reachable on bit-perfect matches.
- **Mismatch cases score 0..61.** All sit below 95. The radius-2.5 case at 61 is the closest a mismatch comes to the threshold; that case differs from the favicon mainly on the BG-vs-AA corner split, which carries lower per-axis weight than ink-w or padding. The tool still classifies it as FAIL on the binary verdict because `pad.left` and `bgExt`/`aaExt` axes fail.
- **Borderline cases score 40..48.** They sit between the high-mismatch and the perfect-match bands, which matches their verdict semantics: neither pass nor fail, indeterminate.

## When to update this table

Re-run after any of these changes and overwrite this file:

- New axis added to `ink-assert.mjs`
- Tolerance values changed (any `--*-px` default)
- New case added to `cases/`
- `confidenceScore` weight table changed

The procedure is the bash loop documented in the comment of this file's source commit; the `corpus-confidence-scores` artefact is empirical, not derived.

## What this document is, and is not

This is a descriptive snapshot of how the current weights score the current corpus. It is not a validation that the weights generalise. The weights were chosen by hand, then sanity-checked on the corpus that already existed. There is no held-out validation set; the corpus and the weights co-evolved.

That means: a future case the corpus does not yet cover (a different glyph, a different reference pipeline, a different display size) may score in a band that surprises the operator. The corpus is small. The numbers above describe today's behaviour on today's cases, no more.

The 95-threshold is a design intent: a candidate that scores 95+ should be interchangeable with the reference for the operator's eye. The current scores satisfy that intent on the current corpus. They were not derived to satisfy it; they were tuned until they did. The distinction matters for honest expectations.
