# bonsai changelog

The post-update broadcast shows the topmost section once per machine whenever
the installed `version` in `.claude-plugin/plugin.json` changes. Keep entries
short; categories are Breaking, Added, Changed, Fixed.

## [v2.0.33]

### Fixed

- **A handed-out worktree is labelled with its branch again.** The lock recorded `DIBS_DESCRIPTION` ahead of the branch name, so a caller that pinned that variable session-wide gave every worktree it ever created the same label. The branch names the change the worktree exists for, so it now wins; the environment value remains the fallback for a caller that names no description.

## [v2.0.32]

### Fixed

- **Local-only repositories use their configured default branch.** Worktree creation and teardown now resolve `init.defaultBranch` when `origin/HEAD` is absent and refuse ambiguous repositories instead of treating the currently checked-out feature branch as the default.

## [v2.0.31]

### Fixed

- **Default-branch lookup no longer guesses branch names.** `bonsai create`
  and `bonsai teardown` read Git's `origin/HEAD` metadata instead of falling
  back to local `main` or `master` branches. Repositories without `origin/HEAD`
  use the current checkout only where Bonsai needs a local context fallback.

## [v2.0.30]

### Fixed

- **Default branches come from Git metadata.** `bonsai create` and `bonsai
  teardown` started reading `origin/HEAD`, so repositories with a non-`main`
  default branch no longer start or classify worktrees from the wrong base.
- **Vaultsync roots are not worktree factories.** `bonsai create` asks the
  vaultsync CLI whether the source checkout is managed and refuses to create a
  worktree there when it is.

## [v2.0.29]

### Fixed

- **Installed bonsai now finds the installed dibs peer.** `bonsai create`
  keeps claiming dibs locks when the plugins run from separate installed cache
  directories, instead of silently falling back to an unlocked worktree.

## [v2.0.28]

### Added

- **Worktree locks now carry the branch as a work description.** The dibs lock
  created by `bonsai create` records the branch name as words, so later
  inspection shows what work the lock represented.

## [v2.0.21]

### Fixed

- **No more worktree-in-a-worktree**: `bonsai create` now anchors new worktrees
  at the main working tree even when `--repo` (or the cwd) points at a linked
  worktree, instead of nesting `worktrees/<name>` under that worktree. A caller
  such as conveyor that grounds an order inside a worktree no longer produces a
  `repo/worktrees/a/worktrees/b` layout.

## [v2.0.0]

### Added

- **Worktree CLI**: `bonsai create`, `bonsai setup`, and `bonsai teardown`
  manage the full worktree lifecycle git-natively, with `--json` facts output.
- **Safety gate on teardown**: a clean-but-non-integrated worktree is kept by
  default; removal needs integration or an explicit `--force`. Warns on orphaned
  unpushed commits and on a diverged default branch.
- **Skills**: `bonsai` (create + setup), `setup`, and `prune`, agent-neutral and
  resolving the CLI cross-agent.

### Breaking

- Dropped the clipboard / start-command mechanism and the macOS-only
  requirement. Bonsai now emits facts and launches nothing. Install
  `bonsai@laicluse-agent-fieldkit`.
