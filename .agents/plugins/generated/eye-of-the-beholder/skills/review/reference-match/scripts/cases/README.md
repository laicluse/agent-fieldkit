# Validation corpus for ink-assert

Each subdirectory is one test case. Layout:

```
cases/<case-name>/
  reference.png    The "ground truth" image
  candidate.png    The candidate to compare against the reference
  verdict.txt      One of: match, mismatch, borderline
  notes.md         Optional human note explaining the verdict
```

## Verdict semantics

- **match**: the two images are visually equivalent at the resolution the operator viewed them. The corpus runner expects the tool to classify this case as PASS at default tolerances.
- **mismatch**: the two images are visually distinguishable. The corpus runner expects the tool to classify this case as FAIL at default tolerances.
- **borderline**: the case sits near a cross-pipeline floor or a tolerance boundary. Either binary classification is acceptable; the value of these cases is the confidence score they produce, which should land in a middle band. They are diagnostic aids, not pass/fail anchors.

## When the corpus runner reports a misclassification

A `match` case classified as FAIL means a tolerance is too strict for the visual reality, or an axis points in the wrong direction. A `mismatch` case classified as PASS means the axis-set is missing the dimension that distinguishes the two images. Either is a real change to the tool, not a tolerance shuffle.

## Corpus scope

This corpus is small (single-digit case count) and focuses on one comparison: CSS pill against a canvas-PNG favicon at 16 CSS pixels. It is enough to catch axis-collapse regressions on this exact scenario and to validate that the tool's verdict aligns with operator-visible ground truth on the parent-session screenshots. It is not a generalised visual-equivalence test suite; expanding the corpus to other element types (icons, text labels, SVG vs canvas, dark mode) is how the tool's confidence on those scenarios grows. Adding a case is the documented procedure under "Adding a new case" below.

## Adding a new case

1. Pick a name that describes the visual relationship in the directory name itself: `pill-radius-2-too-tight`, `tiny-pill-dimension-mismatch`. The name is the human-readable verdict cue.
2. Place `reference.png` and `candidate.png` cropped tightly around the elements (no extra context).
3. Write `verdict.txt` (one word, no extra whitespace handling required).
4. Optional: `notes.md` with operator ground truth, the original screenshot context, and the visual reason for the verdict.
5. Run `scripts/run-corpus.mjs` and confirm the new case classifies correctly.
