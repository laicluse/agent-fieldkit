# Rendering diagnostics

These checks locate defects; they do not define taste. The user's requirements and the accepted visual target govern. Any number below is a starting point for an observation, never a universal threshold. Read the pitfalls file for an axis only when you are scanning that axis: [space](pitfalls/space.md), [depth](pitfalls/depth.md), [color](pitfalls/color.md), [motion](pitfalls/motion.md), [copy](pitfalls/copy.md).

## From complaint to axis

A user rarely reports a defect in the vocabulary of the fix. They report a feeling: "too busy", "it jumps", "looks cheap", "off", "cramped". That feeling is data. It names which axis to scan, not the cause. Translate the complaint into an axis, run that axis's observation questions, and say which axis you are scanning so a wrong translation surfaces before you spend a round on it.

| Complaint | Axis | Observation |
|---|---|---|
| "too busy", "cluttered", "heavy" | density / hierarchy | competing accents, no dominant element, everything the same weight |
| "it jumps", "things move around" | layout stability | something moved on a state change that should have stayed put |
| "cramped", "tight", "squished" | space | padding below the comfortable relation, sibling gaps collapsed, text pressing an edge |
| "empty", "sparse", "lost" | space | voids without purpose, weak grouping, no anchor for the eye |
| "cheap", "generic", "looks AI-made" | credibility | incoherent material, lighting, hierarchy or composition against the accepted world, or choices that would fit any product; no technique is a defect by itself |
| "off", "something's wrong" | odd-one-out | one element slightly unlike its siblings: a stray radius, weight, color or gap |
| "hard to read", "can't tell them apart" | color / contrast | luminance delta too small, secondary text failing the applicable requirement, adjacent surfaces too close |
| "what do the colors mean?" | channel semantics | an information-carrying channel with more than one meaning, or variation that encodes nothing while looking like it does |
| "it sits below", "is hidden", "cut off" | depth | occlusion or clipping before position |
| "the motion is weird", "it snaps" | time | out-of-sync elements, teleporting content, wrong speed for the distance |
| "doesn't fit us", "wrong feel" | direction | the accepted references are missing, contradicted or insufficient; route unresolved appearance to explore |

## Observation before explanation

After every layout change: capture the render and describe what you see before looking at the code. "I see text pressing the top edge" first; only then "which rule causes it?" Code describes intent, the render is the result. Open and inspect every capture yourself before you continue; show captures to the user when you present a decision or a result, not for every diagnostic look.

A capture is evidence only at presentation resolution, with enough product context to understand the state, at the scale and data the user sees. Do not enlarge a low-resolution crop and call it evidence.

## How to look

Feel first, then measure:

1. **Squint.** What stands out, where does the eye stop, where does it feel cramped or empty? Grouping, proximity and tension register before conscious thought.
2. **Trace the edges**, top, right, bottom, left. Name the nearest element to each edge and the space to it. The trace is fractal: page against viewport, container against parent, component against its own padding, glyph against its box, stroke against the pixel grid.
3. **Read the rhythm.** Are the distances between repeating elements consistent? Perimeter padding and internal gaps are separate judgements: generous outer margins with collapsed internal blocks read as dumped text in a box.
4. **Find the odd one out.** An element almost like its siblings but not quite is usually a bug, not a variation.
5. **Name every touch.** What touches what, what touches an edge, what falls outside its container, and is each touch intentional?
6. **Check containment.** Does every icon, glyph and auto-sizing text container show all of its content? Clipping is silent; read every visible line against the source.
7. **Weigh optically.** Round and pointed shapes weigh less than squares of the same bounds; mathematically centered content can feel low. Judge corrections by eye in context, not by a fixed number.
8. **Weigh the composition.** Balanced, and intentionally so? Balance can be symmetric or asymmetric; neither is better by default.
9. **Account for the hand.** Fingers, bezels and frames cover edges; margins must leave what the user holds.

Only then measure. A measured value establishes a fact, not a defect: compare it with the user's request, the accepted reference, the product's tokens or the applicable accessibility requirement. Without a standard, describe the visible relationship and call your interpretation a hypothesis. Do not manufacture a threshold to turn it into a failure.

## The same discipline on every axis

Each axis repeats the method: observe, then look beneath the render for the mechanism, then fix in an order that corrects causes before symptoms.

- **Depth.** "Sits below", "hidden", "cut off" are depth words. Occlusion by a sibling or a material, clipping by an ancestor, and wrong position are competing hypotheses; the shape of the missing region tells them apart. Correct the cause before compensating with offsets.
- **Color.** Count the grays. Look for the distinction between adjacent surfaces instead of inferring it from class names. Read secondary text at the real scale. Then audit the token vocabulary and compute contrast where a requirement applies; light and dark are two designs sharing one set of roles.
- **Channel semantics.** For every channel that carries information (hue, pattern, stroke, position, size, shape), state the one thing it encodes and whether that mapping is written down. Decoration is not a defect; decoration that looks like information is.
- **Time.** The still becomes a series of frames. Do elements that belong together move at the same tempo? Does content disappear before its container has left? Is the speed right for the distance? Record and dissect; rest states prove nothing about the journey. When sub-5% movement is in question, read pixels: [pixel sampling](pixel-sampling.md).
- **Layout stability.** Across a state change, did anything move that was not acted on? Distinguish intended reflow (content that should grow) from unintended shift. For unintended shift, a layout that reserves no space for a state it will enter is the usual mechanism; reserving the space beats animating the jump.
- **Aesthetic coherence.** Compare the render with the accepted target as a connected whole: silhouette, material, light, palette relationships, depth, composition, motion. Name the regions where the candidate leaves the visual language. A passing geometry or semantics check does not establish aesthetic quality.

## Closing a review

A reported defect says where the review starts, not where it ends. Inspect the whole visible surface in the fresh render, and exercise the states that change the meaning of the touched surface: empty, partial and populated content and the transition to the next item. An affordance without content or outcome is a defect even when nobody reported it.

Judge interface copy at the frequency the user meets it: a sentence that helps once becomes noise on the hundredth repetition. Resolve ambiguity by topology, control wording and hierarchy before persistent explanatory copy; see [copy pitfalls](pitfalls/copy.md).

After two operator corrections on the same surface, stop point-fixing. Restate the user's task, the information that must survive repeated use and the relevant state matrix, then review the full surface from that model. When the direction itself is unresolved or the same aesthetic complaint survives two corrections, return to [explore](../explore/SKILL.md) and keep the best earlier version for comparison.

## Output

Report what you observed before what you diagnosed, then the cause and the fix, edge by edge for layouts and frame by frame for motion. Name the odd one out. Keep the report as short as the finding allows.
