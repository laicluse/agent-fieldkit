# Motion and response

Read this before adding, changing or removing anything that moves, fades, or answers an action. Motion explains a change; a movement that explains nothing is noise that the user pays for every time.

Every rule below is followed, or broken on purpose with the reason written in the project's record. A choice that is neither is an oversight. Evidence is marked: **measured**, **convention**, **opinion**.

## What time does to a user

- Three approximate limits have held for decades (**measured**, Miller 1968, Card 1991, reported by Nielsen): within about 0.1 s a response feels instant and needs no feedback but the result; up to about 1 s the flow of thought holds, though the delay is noticed; around 10 s people turn to something else, and need to know when the work will be done.
- An animation is time the user spends watching. In a tool, the frequent interactions are the ones that must not cost it: "generally avoid adding motion to UI interactions that occur frequently" (Apple).
- Motion has four honest jobs: feedback that an action registered, showing a change of state, showing where something came from or went, and pointing at what can be acted on (Nielsen Norman). Filling a wait with decoration is not one of them; such animations are what frustrate people in testing.
- Some people get dizzy or nauseous from movement on a screen, parallax and large moving areas most of all (WCAG).

## Rules

| Rule | Reason | An oversight looks like |
| --- | --- | --- |
| Every motion has a job you can name: feedback, state change, origin and destination, or a pointer to an action. | Motion without a job distracts and can "make them feel disconnected or physically uncomfortable" (Apple). | The same fade on every element; a hover transition on things that are not interactive. |
| Find the shortest duration that is not jarring. Simple feedback such as a toggle is about 100 ms; small interface changes (tooltips, menus, panels) stay under roughly 300 ms; a large element or a long travel may take up to about 500 ms. | "It is far more common for animations to be too long than too short" (Nielsen Norman); the ranges agree across Nielsen Norman, Carbon and Kowalski. | One duration for a checkbox and for a full-screen panel. |
| Ease out for what enters or responds; ease in and out for what moves across the screen; linear only for constant motion. Exits may be a little faster than entrances. | Starting fast feels responsive and the slow end lets the eye settle; strictly linear movement "appears unnatural" (Carbon). | Linear slides; an ease-in on something the user just tapped, which feels like a delay. |
| Motion follows the gesture and returns the way it came. | "Feedback motion that doesn't make sense can make them feel disoriented": what slid down is not dismissed sideways (Apple). | A panel that opens from the right and closes by fading. |
| Something that appears keeps a shape: grow from near full size, not from nothing. | An element scaled from zero "comes out of nowhere"; a higher starting scale reads as a thing that was there (Kowalski). | Popovers that balloon from a point. |
| Two registers: productive motion, quick and out of the way, for work; expressive motion for rare, important moments (Carbon). | An expressive moment is a break in the rhythm; used everywhere it stops being one. | Celebration on every save. |
| Answer within 0.1 s where you can; show that work has started within 1 s; show progress and an end for anything near 10 s. | The three limits above. | A button that does nothing visible for a second; a spinner with no end on a long job. |

Required, not weighed: anything that moves, blinks or scrolls by itself for more than five seconds beside other content can be paused, stopped or hidden (WCAG 2.2, 2.2.2, level A). Beyond that, honour the reduced-motion setting, which is how motion from interaction is made optional (2.3.3, level AAA, and Apple's guidance), and do not make motion the only way something is communicated (Apple).

## Deciding for a surface

1. List the changes of state on the surface and name the job motion would do for each. Where it has none, the change happens at once. Before removing a motion that gives feedback, check that the feedback still arrives without it.
2. For the ones that remain, name the job, then set duration by size and distance, and easing by direction.
3. Decide what happens while work takes longer than a second.
4. Run it with reduced motion on, and run the frequent action ten times in a row. What annoys on the tenth run goes.

## Sources

Read for this file on 2026-11-24:

- Nielsen Norman Group: [animation purpose](https://www.nngroup.com/articles/animation-purpose-ux/), [animation duration](https://www.nngroup.com/articles/animation-duration/), [response times: the three important limits](https://www.nngroup.com/articles/response-times-3-important-limits/).
- Apple, [Human Interface Guidelines: Motion](https://developer.apple.com/design/human-interface-guidelines/motion) and [Feedback](https://developer.apple.com/design/human-interface-guidelines/feedback).
- IBM Carbon, [motion](https://carbondesignsystem.com/elements/motion/overview/).
- Emil Kowalski, [Agents with Taste](https://emilkowal.ski/ui/agents-with-taste).
- WCAG 2.2, [animation from interactions](https://www.w3.org/WAI/WCAG22/Understanding/animation-from-interactions.html).

Not read: Material Design's motion guidance; Disney's twelve principles in the original (Thomas and Johnston, *The Illusion of Life*).
