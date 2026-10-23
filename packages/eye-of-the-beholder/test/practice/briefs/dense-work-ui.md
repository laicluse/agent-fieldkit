# Brief: dense work UI

A screen someone uses for hours a day to watch many things at once and act on the few that need it. There is no hero and no story; there is a lot of state.

## Domains

- **logistics dispatch board**: 40 vehicles, each with a status (en route, loading, delayed, idle), a driver, a next stop and an ETA; 6 of them delayed. Actions: reassign, call driver, mark resolved.
- **lab sample tracker**: 60 samples, each with a stage (received, prepped, running, review, released), an owner, a due time; 4 overdue. Actions: advance stage, flag, reassign owner.

## Constraints

- All items visible without pagination at 1440 px; at 390 px the screen may change structure but must keep the exceptions reachable in one gesture.
- Keyboard focus visible on every control.
- Status may not be carried by color alone.

## Acceptance criteria

1. The exceptions (delayed, overdue) are findable within three seconds without reading every row.
2. Every action is reachable from its row without leaving the screen.
3. Status is distinguishable with color removed.
4. Row height is stable across the longest and shortest content.
5. The two domains differ in information order or composition where their tasks differ (watching movement versus watching deadlines), not only in labels.
