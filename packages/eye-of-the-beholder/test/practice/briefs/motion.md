# Brief: motion

One transition, judged on a recording, never on stills. The question is continuity: does the viewer keep track of what moved where, and does the tempo fit the distance and the task?

## Domains

- **reading app**: a list of 30 articles; tapping one opens the article in place. Back returns to the same scroll position.
- **dispatch tool**: a list of 30 vehicles; selecting one opens its detail beside the list without hiding the list. Selecting another swaps the detail.

## Constraints

- The transition must run at the display's native frame rate in the recording; report the measured rate.
- Reduced-motion preference must be honoured with a non-animated equivalent.
- No element may disappear before its container has finished moving.

## Acceptance criteria

1. In the recording, the selected item is visibly the origin of the detail (shared element, position or continuity of shape).
2. Elements that belong together move at one tempo; no element snaps while others animate.
3. The reduced-motion variant reaches the same end state with no movement.
4. Back or swap restores the list exactly, including scroll position.
5. The two domains differ in tempo or choreography where their tasks differ (reading settles, dispatching keeps context), not only in content.
