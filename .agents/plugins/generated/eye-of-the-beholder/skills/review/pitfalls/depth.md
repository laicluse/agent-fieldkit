# Depth pitfalls

Read when a complaint uses depth words: "sits below", "hidden behind", "cut off", "partially missing", "should sit on top". The reflex is to change offset or padding; the evidence usually says occlusion or clipping.

## Language that means depth

| User says | Read as |
|---|---|
| "sits below, should sit on top", "leeft onderop" | Probably occluded; check before changing position |
| "hidden behind X", "wordt verstopt door X" | X renders above the receiver |
| "cut off", "partially missing" | Clipped by an ancestor or occluded by a sibling; distinguish first |

These are starting hypotheses. Switch to a positioning reading when the missing region matches the bounds of no sibling, material or ancestor frame.

## Symptoms

| Symptom | Competing explanations | Distinguishing check | Move |
|---|---|---|---|
| Part of an element is missing | Occluded by a sibling; clipped by an ancestor frame; positioned off | Trace the boundary of the gap: does it coincide with a sibling's edge, with the ancestor's bounds, or with neither? | Occlusion: reorder or isolate. Clipping: widen or release the ancestor. Position: only after both are ruled out |
| An overlay disappears under a material | A composited material (glass effect, `backdrop-filter`, canvas, WebGL, top-layer dialog) promotes its plane above overlays attached to the same view | Remove the material temporarily or inspect the compositing order | Extract the overlay to a sibling outside the material's scope, or add an isolation boundary |
| `z-index` had no effect | It only orders true stacking siblings; across overlay chains it does nothing | Confirm the two elements share a stacking context | Create the context first, or restructure the siblings |
| Offsets grew until the element stopped being obscured | A symptom bandage; the element was positioned correctly | Reset the offsets and check for occlusion | Fix depth, then restore the intended geometry |
| Custom layout children render in the wrong order | Depth follows the builder or draw order, not placement calls | Check the source order of children | Reorder the builder or draw calls |

Fix order: confirm the cause, find the smallest scope that escapes the occluder (reorder siblings, extract, isolate, move up the hierarchy), verify with a fresh capture, and only then adjust placement.
