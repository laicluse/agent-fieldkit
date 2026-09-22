# how-plugins-work changelog

The post-update broadcast (see `bin/check-broadcast`) shows the topmost
section once per machine whenever the installed `version` in
`.claude-plugin/plugin.json` changes. Entry headers record the version at
which the entry was written; a pre-commit hook auto-bumps `plugin.json` on
every commit, so the header may lag the shipped version. Header numbers are
informational, the broadcast is positional. Use the `--force` flag on the
helper to re-read at any time.

Categories:

- **Breaking**: user must adapt
- **Added**: new commands, new optional behavior
- **Changed**: non-breaking adjustments worth knowing about
- **Fixed**: silent unless the bug was user-visible

Patch-level fixes that change nothing the user can observe are intentionally
omitted; the broadcast budget is for things the user benefits from knowing.
The helper writes the sentinel only when stdout is non-empty, so a CHANGELOG
without a `## [vX.Y.Z]` section stays silent on every update.

## [v2.0.43]

### Changed

- **Skill descriptions now lead with the result and selection situation.** The authoring guidance uses Anthropic's documented shape and a concrete example while keeping procedures, edge cases, and routing details in the skill body.

## [v2.0.39]

### Fixed

- **Local Codex marketplace changes now finish by integration, not reinstallation.** The workflow inspects `source.path`, merges the verified candidate into the primary checkout, and requires explicit operator approval before any machine-wide Claude or Codex plugin mutation.

## [v2.0.38]

### Changed

- **Persistent local marketplace installs now use only the primary checkout.** Feature worktrees remain valid for source tests and adapter checks, but Claude and Codex registration waits until the candidate is integrated and the primary checkout contains that SHA.

## [v2.0.34]

### Fixed

- **Runtime activation can now precede the final commit without version drift.** `/test-before-push` validates a clean index with `plugin-versions --check`, but uses the repository's staged next-version calculation when the current slice is staged, then builds and checks adapters before installing either runtime.

## [v2.0.33]

### Changed

- **Multi-agent plugin work now closes both runtime loops before completion.** The general reference and `/test-before-push` require local installation and payload verification in both Claude Code and Codex even when no push is planned; intentional single-agent packages remain the only exception.

## [v2.0.32]

### Changed

- **Peer plugin dependencies now have an installed-layout test rule.** The
  reference tells plugin authors to prove plugin-to-plugin runtime lookups from
  copied installed artifacts, without hard-coded harness cache paths or private
  helper routes.

## [v2.0.29]

### Changed

- **Codex skill-only installs are now distinguished from plugin installs.** The reference now treats `npx skills add <repo>` with Codex selected as the lean path for instruction-only skills, and reserves Codex plugin metadata for workflows that need MCP registration, hooks, helper binaries, or other plugin-owned runtime payload.
- **Codex plugin guidance now separates preference from necessity.** The reference can recommend a plugin as the cleaner product shape when it keeps generated runtime views and install metadata together, but only calls it technically necessary when a platform rule or local install test proves the skill-only route cannot provide the needed behavior.

## [v2.0.17]

### Changed

- **Agent-specific skill sources may now be single-sided.** A lone
  `SKILL.claude.md` or `SKILL.codex.md` means the skill is intentionally absent
  from the other agent's runtime catalog; paired suffixed sources still cover
  workflows that both agents support differently.

### Fixed

- **`/restart-claude-agents` is Claude-only.** The generated Codex package no
  longer advertises a command that depends on Claude Code background-agent
  state and `claude --bg --resume`.

## [v2.0.16]

### Added

- **`/restart-claude-agents` restarts running background agents so a fresh
  process loads updated plugins.** A running agent holds its plugins in memory
  from launch; there is no in-process reload, so picking up a changed plugin
  means a new process. The command stops each background agent and resumes its
  session with `claude --bg --resume`, re-applying the agent's original launch
  flags from its job state (permission mode, disallowed-tools deny list,
  settings, goal). An unattended `bypassPermissions` agent comes back in the
  same mode with its safety net and mission intact, keeping its conversation
  context. Lists first, restarts idle agents by default, takes agent ids to
  target specific ones, and never touches interactive sessions. Companion to
  `/test-before-push`: where that tests plugin changes before pushing, this
  rolls them into agents already running the old version.

## [v2.0.13]

### Changed

- **Generated Codex payloads now split runtime-specific `agents/`.** Source
  package `agents/` is treated as Claude runtime payload, not shared plugin
  data. Codex generated roots carry `agents/` only from an explicit
  Codex-specific source such as `agents.codex/`.
- **The Claude subagent verification note no longer claims `claude agents`
  lists plugin-shipped agents.** Current Claude Code uses that command for
  background agent sessions; use `claude plugins validate` for schema and a
  live `claude -p --plugin-dir ...` Task-spawn for runtime proof.

## [v2.0.5]

### Changed

- **First public l'Aicluse release.** `how-plugins-work` now ships from
  `how-plugins-work@laicluse-agent-fieldkit` with major version 2.

## [v1.0.4]

### Added

- **Agent-specific skill source convention.** `SKILL.md` is now reserved for
  truly agent-agnostic skill sources; paired `SKILL.claude.md` and
  `SKILL.codex.md` sources are generated into runtime `SKILL.md` targets when
  behavior needs to differ per agent.

## [v1.0.3]

### Changed

- **Project status moved out of the mechanics reference.** `how-plugins-work`
  now stays focused on plugin naming, marketplace aliases, adapter sync, caches,
  and local install mechanics; repo transition state belongs in repo-level docs.

## [v1.0.1]

### Changed

- **Multi-agent local marketplace baseline.** The skill now covers both Claude
  Code and Codex local marketplace installs, and stores broadcast state under
  `${LAICLUSE_HOME:-~/.laicluse}`.

## [v1.0.31]

### Added

- **Cross-agent sync vocabulary.** The skill now explains how to keep shared `SKILL.md` sources, Claude manifests, Codex manifests, marketplace indexes, and runtime caches in separate source/adapter/cache roles.

## [v1.0.27]

### Changed

- **Haiku no longer suggested as a subagent target.** Token-savings example lists Sonnet only (Sonnet has its own usage allocation; Haiku does not); the factual reference about supported `model` values still includes `haiku`.
