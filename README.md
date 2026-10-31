# l'Aicluse Agent Fieldkit

Agent tooling for Claude Code and Codex. Most packages ship to both hosts;
runtime-specific adapters are generated from the package sources.

The GitHub Pages source for a public overview of the repository and changelog
lives in [docs/index.html](docs/index.html). Publish GitHub Pages from the
default branch's `/docs` folder to serve it as a project page.

## Installation

Add the marketplace once:

```bash
claude plugins marketplace add laicluse/agent-fieldkit
codex plugin marketplace add laicluse/agent-fieldkit
```

Then install the package you need:

```bash
claude plugins install dont-do-that@laicluse-agent-fieldkit
codex plugin add dont-do-that@laicluse-agent-fieldkit
```

Each package README has its own install block. The generated Fieldkit website
also exposes per-package install commands and a marketplace-wide install view.
Most packages ship to both Claude Code and Codex. Runtime-specific adapters are
generated from the package sources; `autonomous` remains Claude Code-only
because its keep-alive behavior is host-specific.

Coming from the retired `leclause` marketplace? Its plugins moved here; see the
[migration guide](https://github.com/epologee/leclause-skills/blob/main/docs/migration.md).

## Packages

The marketplace currently ships:

- `how-plugins-work`: reference material for plugin names, skill names,
  marketplace aliases, manifests, adapters, and runtime caches.
- `self-improvement`: routes feedback about agent behavior to hooks, skills,
  project code, or instruction files.
- `git-discipline`: parallel-worktree candidate verification and atomic two-parent default merges, plus repo-aware commit and push hooks.
- `bonsai`: git worktree lifecycle as a cross-platform CLI with setup and
  guarded teardown.
- `dibs`: single-occupancy locks so one coding agent owns a working directory
  at a time.
- `dont-do-that`: guardrail hooks for Claude Code plus `/duh`, `/just-a-question`, and `/not-your-monkey` correction skills for Claude Code and Codex.
- `eye-of-the-beholder`: visual layout review, art-direction foundation, and
  reference-matching discipline for screens, print, responsive layouts, color
  systems, and animation.
- `intervision`: bring another coding agent in as a peer to review work just
  done or just discussed. Claude hands work to Codex; Codex hands work to
  Claude.
- `lifeline`: external grounding and inspiration skills. `inspire` researches
  the outside world before a decision; `ground` checks a doubted claim against
  sources instead of repeating model confidence.
- `anger-management`: curse at your coding agent now, fix the real problem
  later. Capture commands log friction to a global pile; a delayed background
  investigation diagnoses the pattern and `repair` routes the fix.
- `drydry`: duplication-audit methodology for code, prose, design systems, and
  technical docs. Quick mode answers scoped "is this duplicate?" questions;
  audit mode produces a findings artefact with verifier commands.
- `pattern-memory`: local-first Pattern Memory for reusable implementation
  recipes. Keeps personal patterns under `${LAICLUSE_HOME:-$HOME/.laicluse}` as
  Markdown, omits private precedents from public artifacts, and gives agents a
  preflight lookup before fresh implementation work.
- `vaultsync`: local-first Git sync automation for Markdown vault repositories. Debounces Git-visible changes into verified commits, works local-only without an upstream, and syncs with upstream when one exists.
- `laicluse-agent-fieldkit`: marketplace-wide utilities.
  `/whats-new [plugin]`
  re-reads the latest CHANGELOG section of any installed plugin, or the
  marketplace-wide news without arguments. Use
  `/laicluse-agent-fieldkit:whats-new` only when a namespaced form is needed.
- `autonomous` (Claude Code): keep an autonomous mission running across turns. A startup
  capability probe decides whether keep-alive machinery (cron heartbeat,
  backoff, wake) is needed; persistent processes run without it.
- `clipboard`: copy the core content of the last answer to the macOS
  clipboard. Plain text by default, `/clipboard slack` for rich text.
- `saysay`: macOS speech mode for agents. Responses are spoken aloud while the
  normal text answer is still written.
- `gurus`: opinionated review panels for code, decisions, and prose. The
  orchestrator routes to the software, council, or writers panel.
- `rover`: dispatch a rover at a task and stay back while it decides in the
  field: a phase machine with decide, pride/trim quality gates, verify
  evidence discipline, and a stop communique.
- `house-rules`: programming, testing, and naming doctrine, including
  `naming-is-hard`.
- `whywhy`: drills a configurable why-chain into a question or goal, then
  reads the chain for assumptions, forks, and better framing.
- `circus`: builds shared and agent-specific instruction targets, keeps project-level CIRCUS.md/CLAUDE.md/AGENTS.md aligned, and generates and versions multi-agent plugin adapters.

## Development

For local development, point the marketplace at this working copy:

```bash
claude plugins marketplace add ./
codex plugin marketplace add ./
```

Host runtimes use their own adapter metadata. Claude manifests are edited in
place; Codex manifests are generated from the same package sources:

```bash
packages/circus/bin/circus plugins build .
packages/circus/bin/circus plugins check .
packages/circus/bin/circus plugins diff .
```

The GitHub Pages catalog data is generated from the same source manifests and
package changelogs:

```bash
bin/build-pages .
```

Plugin versions follow `2.0.<commit-count>` per package:

```bash
packages/circus/bin/circus plugins versions --check .
packages/circus/bin/circus plugins versions --write .
```

Enable the local git hooks in this clone:

```bash
git config core.hooksPath hooks
```

The pre-commit hook bumps versions, builds Codex adapters, and stages the
generated targets. The commit-msg hook requires `PII-Doublecheck: yes`.

The [skill discovery review](test/skill-discovery/README.md) records the description audit, routing diagnostic, and evidence limits.

## Local Storage

All first-party runtime state for l'Aicluse Agent Fieldkit uses:

```bash
${LAICLUSE_HOME:-$HOME/.laicluse}
```

Agent-harness caches stay where the harness expects them, for example
`~/.claude/plugins/cache` and `~/.codex/plugins/cache`.
