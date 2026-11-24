# Space, grouping and layout

Read this before deciding where things go, how far apart they sit, what is boxed and what leads. Space is the first tool of layout: it groups, separates and ranks before any line, fill or size does.

Every rule below is followed, or broken on purpose with the reason written in the project's record. A choice that is neither is an oversight. Evidence is marked: **measured** (research), **convention** (long practice, argued by the cited author), **opinion**.

## How people see a layout

- People see groups. Things close together are taken as one group; things that look alike are taken as the same kind; things inside one boundary are taken as belonging together; an incomplete shape is completed by the eye (**measured**: proximity, similarity and closure by the Gestalt psychologists from the 1920s, common region by Palmer in 1992; applied by Nielsen Norman).
- Proximity "can overpower competing visual cues such as similarity of color or shape" (Nielsen Norman). Distance alone can say what belongs together.
- A boundary is the most explicit signal and the most expensive. Borders and backgrounds "can result in busy, cluttered designs and in many situations it's enough to rely on proximity for grouping."
- People assume aligned items are related and read an indented item as subordinate to the one above it (Apple). Alignment is a statement, not tidiness.
- Reading order sets expectation: people start at the top and at the edge where reading begins, so what matters most goes there (Apple).
- Pointing takes longer the farther and the smaller the target (**measured**, Fitts 1954). It follows, as design practice, that controls used together sit together and that a frequent control is not a small one.

## Rules

| Rule | Reason | An oversight looks like |
| --- | --- | --- |
| Group with distance first. The space inside a group is clearly smaller than the space between groups. | Proximity groups without adding anything to look at; equal gaps say nothing. | A label as far from its own field as from the next one; a heading midway between two sections. |
| Add a line or a fill only where distance cannot do it: many dense groups, a region that scrolls or moves on its own, a target for dropping. | Every boundary is one more thing to process. | A box around each of several groups that were already separate; cards inside cards. |
| What is the same looks the same; what looks different is different. | Similarity is read as kinship, so an accidental difference reads as a meaning. | Two buttons of the same kind with different padding; one list row taller than its siblings. |
| Take every distance from one scale: a small unit and its multiples, with fine steps for the inside of components and coarse steps between regions. | A scale makes equal relations equal and keeps a rhythm; Carbon builds on 2, 4 and 8 with an 8 px unit, USWDS on multiples of 8. | Gaps of 10, 12, 13 and 15 on one screen. |
| Align to few edges. Each new element takes an edge that exists. | Aligned items are read as related and can be scanned in a line; "relate each new element to existing elements" (Butterick). | Five slightly different left edges; text in a box not aligned with text outside it. |
| A grid is a help, not a proof. Coarse beats fine; it may come out of the content. | "You can play a great game in the grid or a lousy game" (Crouwel, quoted by Butterick). A complicated grid "might as well be no grid at all." | Everything on a twelve-column grid and still no order. |
| The ranking is visible. Where a surface has one main purpose, one thing leads; where it compares, the things compared are equal and stand above the rest. Rank by contrast with the surroundings, by size, and by grouping, in about three levels. | "If everything is contrasted, then nothing stands out." | A screen where the squint test shows no order, or an order the content does not have. |
| Work outward from the content, not inward from the edges. Margins are set by line length and by what must be seen together. | "A lot of mediocre typography results from a perceived need to fill space." Empty space is not waste. | Text stretched to the window; elements enlarged to fill a region. |
| Density follows the task. A tool used all day shows more per screen and keeps positions stable; a page read once gives each thing room. | Cramming options into too small an area makes them harder to understand (Nielsen Norman); spreading a working surface out costs every later use. | A dashboard with landing-page spacing; a form squeezed into a corner of an empty window. |
| Nothing jumps unexpectedly. Reserve the room a foreseeable state will need, and prefer disabling a control to making it vanish where its absence would move its neighbours. Content that must grow (an error message, text the user enlarged, a narrower window) may reflow. | A layout that shifts without cause breaks the user's memory of where things are and makes them miss their target. | A row that grows when a status appears; a button that moves when a message loads. |
| Controls differ visibly from content. | People must find what they can act on without trying everything (Apple). | A link that looks like a label; a label that looks like a button. |

Required, not weighed: a pointer target is at least 24 by 24 CSS pixels, or, when smaller, a circle of 24 CSS pixels in diameter centred on it does not touch another target or such a circle of another small target (WCAG 2.2, 2.5.8, level AA, which also lists exceptions such as targets inside a sentence). Platform guidance asks for more on touch screens.

## Deciding for a surface

1. List what is on the surface and say what belongs with what. That list is the grouping; draw it with distance before anything else.
2. Rank it: what must be seen first, what second, what only when looked for.
3. Choose the unit and the scale of distances, and the few edges everything aligns to.
4. Place what ranks first where reading starts. Set margins from the content outward.
5. Add boundaries last, and only where step 1 failed with distance alone.
6. Squint at the render, or blur it: the groups and the leading element must still be visible. Then look for an accidental difference: a gap, an edge or a size that is almost but not quite like its siblings. Each is a defect until it has a reason.
7. Check the states: empty, full, longest content, narrowest width. Nothing may jump between them.

## Sources

Read for this file on 2026-11-24:

- Nielsen Norman Group: [proximity](https://www.nngroup.com/articles/gestalt-proximity/), [common region](https://www.nngroup.com/articles/common-region/), [similarity](https://www.nngroup.com/articles/gestalt-similarity/), [closure](https://www.nngroup.com/articles/principle-closure/), [visual hierarchy](https://www.nngroup.com/articles/visual-hierarchy-ux-definition/), [use of screen space](https://www.nngroup.com/articles/utilize-available-screen-space/).
- Apple, [Human Interface Guidelines: Layout](https://developer.apple.com/design/human-interface-guidelines/layout).
- IBM Carbon: [spacing](https://carbondesignsystem.com/elements/spacing/overview/), [2x grid](https://carbondesignsystem.com/elements/2x-grid/overview/). U.S. Web Design System, [spacing units](https://designsystem.digital.gov/design-tokens/spacing-units/).
- Matthew Butterick, *Practical Typography*: [grids](https://practicaltypography.com/grids.html), [page margins](https://practicaltypography.com/page-margins.html), [maxims of page layout](https://practicaltypography.com/maxims-of-page-layout.html).
- Wikipedia: [principles of grouping](https://en.wikipedia.org/wiki/Principles_of_grouping), [Fitts's law](https://en.wikipedia.org/wiki/Fitts%27s_law), [canons of page construction](https://en.wikipedia.org/wiki/Canons_of_page_construction).
- Target size: [WCAG 2.2, target size (minimum)](https://www.w3.org/TR/WCAG22/#target-size-minimum).

Not read, and worth reading before this file is extended: Josef Müller-Brockmann, *Grid Systems in Graphic Design*; Jan Tschichold, *The Form of the Book*; Edward Tufte, *The Visual Display of Quantitative Information*. The rule on layout stability rests on practice and on the reasoning given, not on a source read here.
