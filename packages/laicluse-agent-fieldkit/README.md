# laicluse-agent-fieldkit

Marketplace-wide utilities for the laicluse-agent-fieldkit marketplace. This
plugin ships `/whats-new` for Claude Code and Codex, using each agent's own
installed-plugin index.

Install it when you want the marketplace itself to announce what changed,
without installing a separate utility per plugin.

## Installation

```bash
claude plugins install laicluse-agent-fieldkit@laicluse-agent-fieldkit
codex plugin add laicluse-agent-fieldkit@laicluse-agent-fieldkit
```

In a Claude Code session, version 2.1.275 or later, one line installs it straight from the marketplace repository:

```
/plugin install laicluse-agent-fieldkit --marketplace laicluse/agent-fieldkit
```

This command covers plugins installed from `@laicluse-agent-fieldkit`.
Existing installs under the previous marketplace identity need to be removed
and reinstalled from Fieldkit.

## Commands

### `/whats-new [plugin-name]`

With a plugin name (e.g. `git-discipline`): reprints the latest CHANGELOG
section of that installed plugin without touching its broadcast sentinel,
so the regular post-update broadcast still fires exactly once.

Without arguments: prints the latest marketplace-wide news from
`MARKETPLACE-CHANGELOG.md` plus an index of installed plugins that ship a
per-plugin CHANGELOG.

Use `/laicluse-agent-fieldkit:whats-new` only when a namespaced form is needed.
