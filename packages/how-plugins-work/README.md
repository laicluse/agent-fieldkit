# how-plugins-work

Reference for Claude Code and Codex plugin naming, skill resolution,
cross-agent skill sync, and the `plugin:skill` invocation pattern.

Use it when plugin behavior is confusing: a slash command is missing, a skill
resolves in one agent but not another, generated adapters drift, or a
marketplace change needs to be tested in both runtimes before publication.

## Installation

```bash
claude plugins install how-plugins-work@laicluse-agent-fieldkit
codex plugin add how-plugins-work@laicluse-agent-fieldkit
```

In a Claude Code session, version 2.1.275 or later, one line installs it straight from the marketplace repository:

```
/plugin install how-plugins-work --marketplace laicluse/agent-fieldkit
```

## Commands

### `/how-plugins-work`

Loads the reference: how slash-command names map to plugins, how sub-skills
resolve, when the `plugin:skill` form is required, how shared skills can be
packaged for multiple agents, and where plugin caches fit.

### `/test-before-push`

Canonical procedure for rolling multi-agent marketplace changes out to Claude Code and Codex locally before declaring the work complete, whether or not a push follows.

### `/restart-claude-agents` (Claude Code)

Restarts running Claude Code background agents so a fresh process loads updated
plugins, preserving each agent's conversation, permissions, and goal. The
companion to `/test-before-push`: where that tests plugin changes before
pushing, this rolls them into agents already running the old version. Lists the
running background agents first, restarts the idle ones by default, takes agent
ids to target specific ones, and never touches interactive sessions.

## Auto-trigger

Activates when diagnosing:

- "Unknown command" errors after a fresh install
- Slash-command autocomplete misses
- Confusion between plugin name, skill name, and command name
- Sub-skills that work in isolation but not when invoked from another skill
- Cross-agent marketplace or manifest drift between shared skills and
  agent-specific adapters
- Accidental exposure of agent-specific skills to a client that cannot run them
