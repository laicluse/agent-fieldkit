# Circus changelog

## [v2.0.7]

### Fixed

- Plugin builds preserve project skills under `.agents/skills/`. Adapter checks cover generated plugin files without claiming those project skills as generated output.

## [v2.0.6]

### Fixed

- **A plugin build no longer takes the generated runtime away while it refills it.** The build cleared `.agents/plugins/generated/<plugin>/` before copying the new tree in, so anything running out of that directory in the meantime failed: a `git push` whose hook lives there reported a missing plugin binary, and a Codex session could read a half-written tree. Builds now stage the whole tree first and replace each target in place, so a reader sees either the old file or the new one.

## [v2.0.5]

### Improved

- **Retained Codex hook runtimes now carry their actual source version and stronger regression coverage.** Concurrent first invocations converge on one complete snapshot, paths with spaces stay valid, both plugin-root variables point at the retained runtime, and direct roots plus ambiguous or missing recovery inputs keep their existing behavior.

## [v2.0.4]

### Fixed

- **Codex plugin updates no longer break hooks in parallel sessions.** Generated hook commands retain an immutable runtime per plugin version in `PLUGIN_DATA`, and hook-bearing manifests carry a Codex-only adapter cachebuster, so Codex can deliver the wrapper and remove its old cache directory without invalidating hook registries already loaded by running or resumed sessions.

## [v2.0.3]

### Fixed

- **Generated Codex hooks now explain when their session runtime has disappeared.** `PreToolUse` fails closed with a restart instruction, while other lifecycle events emit a readable warning instead of cascading exit-127 failures.

## [v2.0.1]

### Added

- **Circus is now part of l'Aicluse Agent Fieldkit.** The public plugin owns multi-agent doctrine builds, project instruction sync, Codex adapter generation, and marketplace versioning from one implementation.
