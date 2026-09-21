# house-rules changelog

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

## [v2.0.23]

### Changed

- **Views are queries; deliberate actions are commands.** `programming-philosophy` now applies Command-Query Separation to page loads, refreshes, polling, previews, route handlers, and UI affordances so merely viewing state cannot mutate it.

## [v2.0.22]

### Changed

- **Specifications remain accountable to requested behavior.** Missing test coverage no longer makes a requested outcome optional; passing tests establish only the cases they exercise. Artifact reviews attempt the recipient's task before assessing wording.

## [v2.0.21]

### Changed

- **Scar-tissue reviews inspect document structure before wording.** Reviews evaluate the opening and outline for the intended reader, preserve necessary measurement provenance, and distinguish semantic findings from successful tooling checks or repeated pass counts.

## [v2.0.16]

### Changed

- **Generic gate jargon now triggers a naming check.** `naming-is-hard` asks agents to name the actual validation, review, confirmation, eligibility, or selection while preserving established protocol terms and literal commands.
- **Shared artifacts no longer retain their editing worklog.** `scar-tissue` now removes headings and prose whose only current function is to narrate the feedback, deliberation, or transformation that produced the artifact.

## [v2.0.15]

### Changed

- **Living docs describe the present, not their ancestry.** `scar-tissue` now removes origin repositories, import SHAs, cutover narration, and other lineage from current READMEs, runbooks, and instructions while preserving explicit audit and changelog artifacts.

## [v2.0.13]

### Changed

- **Diagnostic test stitches are temporary.** After RED and GREEN prove a repair, `scar-tissue` now resolves tests that only pin a superseded interpretation while preserving guards for current behavior and risk.

## [v2.0.10]

### Changed

- **Migration plans now converge on one implementation.** `scar-tissue` removes moved skills from their old location and reserves old plugin packages for deprecation tombstones instead of forwarding layers.
- **Backlog names now start with the human outcome.** `naming-is-hard` tells agents to write Idea, refinement, variant, slice, and epic titles for product owners without implementation context. Epic boundaries now separate independently steerable outcomes instead of components or technical layers.

## [v2.0.6]

### Changed

- **Testing doctrine now says default branch.** The examples point at Git's
  default-branch metadata so the prose no longer trains agents to treat `main`
  as universal.

## [v2.0.1]

### Breaking

- **naming-is-hard has moved into house-rules.** The standalone
  `naming-is-hard` plugin is retired. The `/naming-is-hard` skill is
  unchanged, but it now ships from `house-rules` rather than its own plugin.
  If you installed `naming-is-hard@laicluse-agent-fieldkit`, switch:

  ```bash
  claude plugins install house-rules@laicluse-agent-fieldkit
  claude plugins uninstall naming-is-hard@laicluse-agent-fieldkit
  ```

### Added

- **house-rules debuts as an opinionated craft-doctrine baseline.** It bundles
  three skills in the tradition of Beck, Martin, and Fowler:
  `programming-philosophy`, `testing-philosophy`, and the relocated
  `naming-is-hard`. `programming-philosophy` and `testing-philosophy` were not
  previously part of this marketplace; they ship here for the first time.
