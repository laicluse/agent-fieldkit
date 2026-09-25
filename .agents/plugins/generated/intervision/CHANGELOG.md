# intervision changelog

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

## [v2.0.18]

### Changed

- **Peers are picked by tier: Luna, Sol, Astra.** The Codex catalog no longer
  lists a Spark or mini coding model, so the helper resolves the newest Luna
  slug for the routine pass and `--tier sol` / `--tier astra` for escalation,
  failing closed when a tier is missing. The skill names the Claude ladder
  (Sonnet, Opus, Fable) alongside it.

## [v2.0.16]

### Fixed

- **Codex now gives Claude enough time to finish peer reviews.** A silent but
  live Claude process is treated as working, gets at least 20 minutes, and is
  never interrupted or declared blocked on elapsed time alone.

## [v2.0.14]

### Fixed

- **Branch review works without a remote.** Second-opinion snippets now fall back from `origin/HEAD` to an existing local `init.defaultBranch` before requiring an explicit range.

## [v2.0.13]

### Fixed

- **Branch-diff snippets no longer guess `main` or `master`.** Intervision
  reads Git's `origin/HEAD` metadata and asks for an explicit range when Git
  has no default-branch metadata.

## [v2.0.12]

### Fixed

- **Branch-diff examples resolve the default branch first.** The second-opinion
  snippets started reading `origin/HEAD` instead of assuming `main`.

## [v2.0.10]

### Changed

- **Claude-to-Codex second opinions resolve the cheap model dynamically.**
  The first pass now reads `codex debug models`, prefers the advertised Codex
  Spark or ultra-fast coding model, then falls back to a mini coding model
  before using the legacy Spark slug only when the catalog cannot be read.

## [v2.0.9]

### Changed

- **Claude-to-Codex second opinions now start on Codex Spark.** Routine peer
  checks use `gpt-5.3-codex-spark` first and escalate to the configured Codex
  default only when the cheap pass is uncertain, misses a concrete concern, the
  change is high-risk, or the operator asks for more depth.

## [v2.0.5]

### Fixed

- **Codex-to-Claude peer checks now use a clean headless Claude invocation.**
  Local stop hooks no longer replace Claude's actual second-opinion answer, and
  language checks must keep the full text under review instead of narrowing to
  one suspicious word.

## [v2.0.1]

### Changed

- **intervision now ships from the public laicluse-agent-fieldkit marketplace.**
  Install the Fieldkit copy for the current Claude-to-Codex and Codex-to-Claude
  peer review workflow.
- **`second-opinion` is multi-agent.** Claude asks Codex via `codex exec`,
  while Codex asks Claude via `claude -p`. Runtime state lives under
  `${LAICLUSE_HOME:-~/.laicluse}/intervision`.

## [v1.0.7]

### Added

- New plugin. `/intervision:second-opinion` brings Codex in as a peer to review
  work just done or just discussed via `codex exec`, surfaces its independent
  read, and goes back and forth. Needs the `codex` CLI installed and logged in.
