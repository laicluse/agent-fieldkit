# self-improvement changelog

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

## [v2.0.10]

### Changed

- **Corrections stay concise.** Durable fixes use one actionable rule and a concrete failure example without restricting unrelated judgment.

## [v2.0.0]

### Changed

- **First l'Aicluse release.** The skill is now agent-neutral and routes
  feedback across hooks, skills, project code, and instruction files instead
  of assuming Claude-only `CLAUDE.md` targets.
