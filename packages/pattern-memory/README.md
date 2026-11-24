# pattern-memory

Pattern Memory is a local-first registry for reusable implementation patterns. It helps coding agents reuse known interaction contracts, build conventions, architecture recipes, and named implementation principles before they invent a fresh version.

The plugin ships the mechanism, not your private content. Real pattern files live in personal local state under `${LAICLUSE_HOME:-$HOME/.laicluse}/patterns` by default. Public docs and generated examples describe only sanitized mechanics; concrete app names, private repository paths, local paths, and origin stories stay in private `precedents` fields and must never be surfaced in public artifacts.

## Installation

```bash
claude plugins install pattern-memory@laicluse-agent-fieldkit
codex plugin add pattern-memory@laicluse-agent-fieldkit
```

In a Claude Code session, version 2.1.275 or later, one line installs it straight from the marketplace repository:

```
/plugin install pattern-memory --marketplace laicluse/agent-fieldkit
```

## Local Store

The default store is:

```bash
${LAICLUSE_HOME:-$HOME/.laicluse}/patterns
```

The store is a standalone git repository. It must sit outside project working trees so pattern files cannot be accidentally staged into a product repository.

Initialize it from an installed plugin:

```bash
node "$PLUGIN_ROOT/bin/pattern-memory" init
```

The helper creates:

```text
README.md
SCHEMA.md
INDEX.md
patterns/example-map-like-canvas-interaction.md
```

## Commands

### `pattern-memory init`

Creates the local Pattern Memory root, writes starter docs when missing, runs `git init` when needed, and generates `INDEX.md`.

### `pattern-memory index`

Rebuilds `INDEX.md` from Markdown frontmatter. The index deliberately omits `precedents` so private pointers are not repeated in a skim-friendly file.

### `pattern-memory search <query>`

Searches pattern titles, slugs, tags, triggers, exemplars, applicability fields, and body text. Output includes the matching file path and sanitized metadata, never private `precedents`.

### `pattern-memory validate`

Checks schema fields, allowed lifecycle values, the local root boundary, and index freshness.

## Pattern Schema

Each pattern is a Markdown file with YAML-style frontmatter:

```yaml
---
slug: map-like-canvas-interaction
type: pattern
status: draft
visibility: public-example
triggers:
  - canvas pan zoom
  - wheel event
  - trackpad pinch
exemplars:
  - map-like canvas
precedents: []
applies_to:
  - browser canvas
tags:
  - ui
  - interaction
last_verified: 2026-07-04
---
```

Use these body sections:

- `Use when`
- `Invariants`
- `Recipe`
- `Verification`
- `Anti-patterns`
- `Do not surface`

## Privacy Contract

`exemplars` are sanitized handles that may appear in summaries, generated docs, and agent replies. `precedents` are private recall pointers for implementation only. Agents may inspect precedents to find real code, but must not copy precedent values into commits, PR bodies, public docs, generated examples, or chat intended for third parties.

## Agent Workflow

Pattern Memory is a candidate source, not the source of truth. The intended order is:

1. Search Pattern Memory for matching triggers, exemplars, tags, and applicability.
2. Read matching pattern files.
3. Inspect the current repository and any private precedent code that is relevant and available.
4. Treat the current repository as ground truth.
5. Implement only after reconciling the pattern with the codebase in front of the agent.

## Requirements

Node.js and git on `$PATH`. No database, private knowledge-base plugin, remote service, or agent-specific storage backend is required.
