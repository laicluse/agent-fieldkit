# Reference library

A model's memory of design is dated and averaged. The reference library is the growing, dated memory that replaces it: observations of real work, what each one solves, the mechanism that transfers, and what happened when it was applied. Explore consults it before proposing and adds to it when a task taught something. Review adds the outcome.

## Where it lives

Public references live at `${LAICLUSE_HOME:-$HOME/.laicluse}/eye-of-the-beholder/references/`, shared across projects. Project-bound material (client identity, confidential captures, accepted decisions) stays in the project's visual-language document and never enters the shared library. Each entry is one markdown file; captures sit beside it in `captures/`.

## Entry

```markdown
---
source: <URL or publication>
observed: <date you looked, YYYY-MM-DD>
designed: <date of the work if known, else unknown>
task: <the concrete design problem it solves, e.g. "dense comparison of 20+ items on a phone">
mechanism: <the transferable move, e.g. "one dominant object at viewport scale, metadata as marginalia">
depends_on: <the character or content it needs, e.g. "a product with one hero object">
media: <web | app | print | motion | other>
capture: captures/<file>.png
status: observed | applied | retired
---

What you saw, in plain observation. What this entry would be wrong for.

## Applications
- <date> <kind of surface, anonymised>: expected <…>; saw <…>; kept | rejected, because <…>
```

The mechanism field is the entry's value. "Feels premium" is not a mechanism; "the only saturated color is the one action" is. An entry without a mechanism is inspiration, not knowledge, and does not go in.

## Draws

`draws.md` in the same directory logs, per task, which mechanisms were drawn and why. Draws and applications in the shared library carry only transferable, anonymised findings (the kind of surface, the mechanism, the outcome); project identity, client names and evidence captures stay in the project's own record. Before proposing, read the recent draws. A mechanism drawn three times in a row is a habit to examine, not a prohibition: a repeated draw is justified when this material calls for it, and a forced departure that damages coherence is worse than a repeat. Record the justification either way.

## Coverage, not freshness

A new entry does not make the library current. Before an open exploration, check coverage for this task and medium: are there entries that solve this problem from different directions? When coverage is thin, research first, as design reasoning describes, and add what you learn. When every proposal keeps resembling the others or a familiar default, coverage is thin by definition.

Fresh observation is not fresh design: `observed` says when you looked, `designed` says when it was made, and an old entry can be the right one. Age is a signal, not a gate: when no entry for a task has been observed in the last year, say so and look outward before proposing, but a timeless reference that still applies stays. Reopen an entry when an application casts doubt on it or its source changed; retire interpretations the applications refuted and keep the source if the observation holds.

## Adding

Add an entry when a task produced a mechanism worth transferring, when research found one, or when an application changed what an entry claims. Do not add to meet a quota. Record the application on the entry that was used, including rejections: a rejected mechanism with its reason is knowledge the next task needs.

## Seed

The plugin ships this schema and procedure, not opinions. An empty library plus the research step is the starting state; the first tasks fill it.
