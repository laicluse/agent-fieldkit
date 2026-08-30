# house-rules

An opinionated baseline for software craft, in the tradition of Kent Beck,
Robert C. Martin, and Martin Fowler. These are chosen conventions among
defensible options, not universal law: house rules, not received wisdom. Adopt
them, adapt them, or argue with them.

Use it when the agent needs a shared craft baseline before naming, coding,
refactoring, testing, or reviewing. These skills are deliberately written as
doctrine: they should steer judgment, not replace project-specific evidence.

## Installation

```bash
claude plugins install house-rules@laicluse-agent-fieldkit
codex plugin add house-rules@laicluse-agent-fieldkit
```

## Skills

### `/naming-is-hard`

Canonical naming and wording doctrine for any "what should this be called?"
task: code symbols, domain language, branches, worktrees, commits, pull
requests, docs, UI copy, and Dutch/English mixed wording. The full doctrine
lives in `skills/naming-is-hard/references/naming-doctrine.md`.

### `programming-philosophy`

Principles for writing, refactoring, and reviewing code: intent-revealing
names, source-of-truth predicates and correlated-proxy detection, the downgrade
and feature-disable bans, DRY with judgment, vertical slicing, cruft tolerance,
scope discipline, error handling, and host-owned capability contracts (ports and
adapters) for published agent tooling. Model-invocable.

### `testing-philosophy`

TDD workflow (Red-Green-Refactor), specs-specify-not-verify, Cucumber/Gherkin
conventions, scar-tissue and absence-pinning smells, flaky-test discipline, and
test-suite health. Model-invocable.

### `scar-tissue`

Doctrine for consolidating superseded residue, keeping living artifacts focused on current responsibilities, and resolving diagnostic stitches during Refactor. An explicit stitch marker creates a session-local cleanup obligation that must be resolved before handoff. Model-invocable.
