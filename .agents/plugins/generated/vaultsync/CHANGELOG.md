# vaultsync changelog

The post-update broadcast shows the topmost section once per machine whenever the installed `version` in `.claude-plugin/plugin.json` changes. Keep entries short; categories are Breaking, Added, Changed, Fixed.

## [v2.0.18]

### Added

- **One checkout can run multiple independent validators.** Named, idempotently managed validators all run in each validation pass and expose separate results without changing the checkout's physical-root identity.

### Changed

- **Automatic repair authority is explicit per named validator.** A validator can be read-only or authorize bounded repairs from only its own absolute or checkout-relative diagnostics, optionally extended to the current change set; symlinks and checkout escapes remain outside repair authority.
- **Concurrent validator owners preserve each other's configuration.** Named-entry updates serialize against daemon state writes, and replaced validators no longer inherit stale outcomes from an earlier command.
- **Legacy verification remains migration-free.** Existing `verifyCommand` and `vaultsync install --verify` registrations keep their historical behavior and can coexist with named validators.

## [v2.0.17]

### Fixed

- **CLI, daemon, and callback entrypoints survive plugin cache updates.** Plugin startup atomically publishes a complete immutable runtime behind one stable machine launcher, and older parallel sessions cannot downgrade the active version.
- **The macOS LaunchAgent no longer pins a versioned plugin cache or Node installation.** Existing daemons restart through the stable launcher after a newer runtime is published.

## [v2.0.16]

### Fixed

- **Failed generators roll back their Git-visible writes.** A partially writing `pre-sync` command restores the exact pre-hook worktree and index, so failed output cannot enter history or recreate a generated-file conflict during recovery.
- **Commit narrative comparison follows complete Git trailer syntax.** Provider-specific trailers with multiline or compact values no longer hide repeated WHY prose from the change-specific fallback.

## [v2.0.15]

### Fixed

- **Failed generated output is repaired before a retry can checkpoint it.** A partially writing `pre-sync` command can no longer place its failed output in remote history on the next successful cycle.
- **Commit narrative comparison follows Git trailer semantics.** Provider-specific verification and review trailers no longer hide repeated WHY prose from the change-specific fallback.

## [v2.0.14]

### Fixed

- **Repeated generated commit narratives fall back to change-specific reasoning.** Consecutive sync commits no longer fail `duplicate-why` when the configured commit-message provider repeats recent prose.

## [v2.0.13]

### Fixed

- **Tracked generators run only after remote integration.** Two peers can refresh the same derived file without making the generator create an avoidable rebase conflict, and a remote commit integrated during pull is always reflected before verification and push.

## [v2.0.12]

### Added

- **Tracked generators can run as a fail-closed pre-sync phase.** `vaultsync install --pre-sync '<command>'` registers a synchronous preparation command whose failure blocks publication with explicit `pre-sync` status.

## [v2.0.10]

### Fixed

- **Commit-message provider failures remain the primary sync diagnosis.** Structured status now preserves safely redacted generator stderr, secondary commit failures, the last successful sync, staged and unpushed work, and a reliable recovery action; staged changes retry without Git repair.
- **Fallback commit reasoning is specific to each staged change set.** Consecutive syncs no longer reuse a fixed WHY when commit-message generation is unavailable.

## [v2.0.9]

### Fixed

- **Shared vaults reject machine-local home paths before commit or push.** Portable commands and user-level configuration now stay separate from Git-visible vault content, while corrective commits can remove an existing leaked path.

## [v2.0.8]

### Fixed

- **Generated HTML viewers no longer block managed vault syncs.** Commit-message normalization records a changed HTML artifact as `Visual:` evidence when the configured LLM did not supply its own visual trailer, keeping Tilt viewer updates compatible with git-discipline.

## [v2.0.4]

### Added

- **Managed-checkout status is now a CLI contract.** `vaultsync managed [path] --json` reports whether a path belongs to a vaultsync-managed checkout, so other tools can integrate without depending on vaultsync's storage layout.
