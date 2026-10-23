# Space pitfalls

Read when scanning the space axis. Each entry: the visible symptom, the explanations that compete for it, the check that separates them, and the move that follows. These are observations from past reviews, not rules about how a product should be spaced.

| Symptom | Competing explanations | Distinguishing check | Move |
|---|---|---|---|
| Content presses an edge on one side only | A shorthand with a zero (`padding: 0.6rem 0`); an element placed outside the padded container | Read every value of the shorthand; check the element's parent | Give the element its own spacing or the missing side its value |
| Outer margins fine, inner blocks touch | Collapsed sibling gaps; first-child margin collapsing through parent padding | Walk each adjacent pair inside the container and name the gap; check for a border or padding between parent top and first child | Set the gaps; `display: flow-root` or an explicit border-top when margins collapse |
| It "fits" but looks wrong | Fit mistaken for quality | Ask what the spacing communicates, not whether it overflows | Judge relation and hierarchy, not containment |
| Icon or glyph feels cut off at one edge | Path outside the viewBox; centered stroke adding half its width; SVG's silent default clipping | Add half the stroke width to the path bounds and compare with the viewBox | Leave margin inside the viewBox or enlarge it; changing overflow may move the clip to the parent |
| A popover, toast, sheet or banner shows text that starts or ends mid-sentence | Intrinsic size smaller than the content because of modifier or layout order; a capped height; a guessed line clamp | Read every visible line against the source string; confirm the first and last word are present in the open state | Reorder the layout chain so content can grow; remove the cap or raise the clamp |
| Round shape feels smaller than its square neighbour | Missing optical overshoot | Compare by eye against the neighbour | Overshoot the round shape; size it by eye, not by a fixed percentage |
| Text in a pill or button sits high next to its icon | Font ascent larger than descent; alignment to the bounding box rather than cap height | Compare text and icon centres at the real scale | Align to cap-height centre: a micro-translate or cap-height line metrics |
| Centred content feels low | Geometric centre, not optical centre | Squint and compare the perceived centre of gravity | Raise slightly; judge the amount in context |
| Fonts shrunk to make content fit | Fitting treated as the goal | Check readability and the accepted type scale | Restructure the layout instead when that keeps the intended hierarchy |
| A fix was made and the review stopped | One edge corrected, the others not rescanned | Rescan all four edges after every change | Repeat the trace until nothing new appears |
