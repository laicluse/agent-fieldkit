# Motion and stability pitfalls

Read when scanning time (intended motion) or layout stability (unintended motion). The still becomes a series of frames; the edge trace runs on each key frame; the rhythm is the timing curve; the odd one out is the element that falls out of sync.

## Observing motion

Apply the scan to start, quarter, half, three-quarter and end frames. Do elements that belong together move at one tempo? Does content disappear before its container has left, or appear after it arrived? Does everything start and end together, and is a difference intentional stagger or a forgotten rule? Is a hidden cell parked (slides as a unit) or collapsed (snaps away)? Is the speed right for the distance, not merely the duration?

Record and dissect: capture the interaction, extract frames at a rate that gives several frames per transition, read them in order and compare each frame with the next. For mid-animation values, slow the animation down through its duration variable and sample computed styles at several points. A test that checks only rest states cannot fail on the bugs users experience halfway through. When the movement is below what an image view can show, read pixels: [pixel sampling](../pixel-sampling.md).

Motion evidence must stay representative: measure the displayed frame rate during the recorded interaction and report it; a recorder that materially lowers it invalidates the evidence even when the file is encoded at a higher rate.

## Symptoms

| Symptom | Competing explanations | Distinguishing check | Move |
|---|---|---|---|
| One element snaps while others animate | A transition rule missing on that element; an inline style driving a property with no transition | Read computed transition properties for every moving element | Give it the shared duration and easing |
| Content vanishes before its container finishes moving | Visibility flips at the start of the hidden state | Watch the mid frames | Delay the visibility flip until the movement ends (`transition: visibility 0s linear var(--duration)`); mirror for entry |
| Elements drift apart after a refactor | Durations and easings hard-coded in several places | Search for literal ms and curves | One vocabulary of duration and easing custom properties |
| Unrelated properties animate | `transition: all` | Read the transition list | Name the properties |
| Jank on rows of many animating items | Layout properties animating per frame | Profile or count reflows | Isolate with `contain: layout`; promote with `will-change: transform` (never a layout property) |
| A hidden cell jumps from nothing to something | Collapsed to zero instead of parked | Compare the hidden state's box | Park with retained size and hidden visibility |
| A 5% change is invisible in frames | Below image-view resolution | Sample pixels per frame | Measure, then judge |

## Stability

Across a state change (hover, focus, load, expand, validation), did anything move that was not acted on? A container that resizes to its content, a control that appears instead of enabling, values that arrive in stages, equivalent siblings with content-dependent heights: each shifts what follows. Reserve the space the state will need. Animating an unwanted jump produces a smooth unwanted jump.
