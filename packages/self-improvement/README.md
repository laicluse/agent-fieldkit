# self-improvement

Routes feedback about agent behavior to the strongest durable target: hooks,
skills, project code, or instruction files.

Use it when the operator says a behavior should change permanently, not only
for the current answer. The skill keeps the fix close to the source of the
behavior: hook when it must be enforced, skill when it is a workflow, project
code when the project owns the behavior, and instruction text only when the
rule really belongs there.

## Installation

```bash
claude plugins install self-improvement@laicluse-agent-fieldkit
codex plugin add self-improvement@laicluse-agent-fieldkit
```

In a Claude Code session, version 2.1.275 or later, one line installs it straight from the marketplace repository:

```
/plugin install self-improvement --marketplace laicluse/agent-fieldkit
```

## Command

### `/self-improvement`

Reads recent feedback from the conversation, classifies the issue by
enforcement strength and scope, then applies the change in the right source.
It may add, edit, shorten, merge, or remove instructions.

## Auto-trigger

Activates when the user:

- gives feedback on agent behavior ("don't do that", "do this instead")
- says "remember this" or "onthou dit"
- asks to create or improve skills, hooks, plugins, or instruction files
- asks to consolidate or trim instructions
