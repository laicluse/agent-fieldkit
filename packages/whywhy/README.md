# whywhy

Drill N layers deep into a question or goal (default 10). The agent
autonomously asks and answers "why?" itself, builds a chain of reasoning, then
analyzes the chain for a better direction toward the goal.

The classic five-whys exercise, but autonomous and slightly deeper. Useful when the surface-level answer feels too convenient.

Use it when the current framing feels wrong, not when you need factual lookup.
The output is a reframing aid: it exposes assumptions, weak links, and deeper
goals so the next action can be chosen with less self-justification.

## Installation

```bash
claude plugins install whywhy@laicluse-agent-fieldkit
codex plugin add whywhy@laicluse-agent-fieldkit
```

In a Claude Code session, version 2.1.275 or later, one line installs it straight from the marketplace repository:

```
/plugin install whywhy --marketplace laicluse/agent-fieldkit
```

## Commands

### `/whywhy [n] <question, goal, or statement>`

Generates an `n`-deep "why?" chain (default 10), then analyzes the chain for:

- assumptions that broke down
- layers where the reasoning forked
- a better-framed goal at one of the deeper layers

Argument can be a question, a stated goal, or a claim to interrogate.

## Auto-trigger

Activates when the user types `/whywhy` with content, and is model-invocable: it
activates whenever a task is about drilling into the root cause of a decision,
goal, or problem. Does not auto-fire on free conversation.

## Requirements

Node.js on `$PATH` for the post-update broadcast check (`bin/check-broadcast`).
The skill itself is plain Markdown and needs nothing beyond a reader.
