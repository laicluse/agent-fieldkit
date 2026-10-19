---
name: install-hooks
user-invocable: true
description: >-
  Install git-discipline git hooks in the current repo so CLI/IDE commits get the same guardrails.
argument-hint: "[--force] [--dry-run]"
---

# Install Hooks

Place git-discipline's git-native hooks into the current repo, so commits
and pushes made outside Claude Code's PreToolUse layer are also guarded. In
Codex, these git-native hooks are the enforcement layer.

The hooks:

| Hook | Purpose |
|------|---------|
| `pre-commit` | Enforces repository-local branch policy: feature branches by default, direct default authoring with `trunk`, mandatory linked feature worktrees with `worktree`. Repository initialization and actual merge completion remain possible. |
| `commit-msg` | Validates the commit message against `validate-body.sh` (the same lib as the PreToolUse guard). |
| `prepare-commit-msg` | Pre-fills the editor window with a structured body template based on the staged diff. |
| `post-commit` | Detects `--no-verify` usage and logs it to `${LAICLUSE_HOME:-~/.laicluse}/git-discipline/git-discipline-no-verify.log`. |
| `post-rewrite` | Runs after `git rebase` and `git commit --amend` and validates each rewritten body. git ignores its exit status, so it warns and logs to `${LAICLUSE_HOME:-~/.laicluse}/git-discipline/git-discipline-post-rewrite.log` rather than blocking; `pre-push` is the blocking gate for these commits. It exists because `commit-msg` does not fire on rebase-picked commits. |
| `pre-push` | Blocks wip or invalid commit bodies and rejects a default update unless it is the verified two-parent merge produced by the shared `git-discipline` flow. |

## Why

The PreToolUse:Bash guard (slice 4) only covers Claude-driven commits.
Commits made directly via `git commit` from the shell or from an IDE
do not see this guard. Claude Code does not offer a native
`PreCommit` lifecycle event and will not get one
(https://github.com/anthropics/claude-code/issues/4834 closed not planned),
so the per-repo git-native hooks are the only way to cover non-Claude commits
and pushes.

All hooks share the same `validate-body.sh` as the PreToolUse guard, so
behavior never diverges.

## What the skill does

1. Verifies that we are inside a git repo (`git rev-parse --git-dir`).
2. Detects whether this repository has a local `core.hooksPath`, and picks the correct target directory (the common Git directory's `hooks/`, shared by every linked worktree, or that repo-local path). An inherited global `core.hooksPath` is never an install target; the installer creates a repo-local override instead of modifying hooks used by unrelated repositories.
3. Finds the plugin root from the `lib/install.sh` script's own location and
   bakes that absolute path into each hook (placeholder
   `__PLUGIN_INSTALL_PATH__` is replaced). Re-running after a plugin update or
   reinstall refreshes the path.
4. Per hook (`pre-commit`, `commit-msg`, `prepare-commit-msg`, `post-commit`,
   `pre-push`), copies the source from the plugin to the target dir, sets
   the executable bit, and logs the result.

## Defaults and flags

- Default: per hook, when the target file already exists with different
  content, the skill refuses to overwrite and prints the diff. Idempotent: an
  existing file with identical content is a silent no-op.
- `--force`: makes a backup for each conflicting hook
  (`<hook>.bak.<timestamp>`) and then overwrites.
- `--dry-run`: shows what would happen without writing anything.

## Worktree policy

Installing git-discipline does not make worktrees mandatory. The canonical checkout and current branch remain the normal authoring location. Use a linked worktree when isolation solves a concrete risk: the canonical checkout is live or consumed by another system, Dibs reports another coding agent there, the change is consequential enough to deserve an isolated candidate, or another concurrency or recovery concern makes shared authoring unsafe. This list is illustrative, not exhaustive.

Repositories that should always use the verified candidate flow can opt in locally:

```bash
git config --local laicluse.requireWorktree true
```

Only that local setting activates the native `pre-commit` authoring block and default-branch topology check in `pre-push`. A global setting is deliberately ignored.

## How to use

```bash
/git-discipline:install-hooks
/git-discipline:install-hooks --dry-run
/git-discipline:install-hooks --force
```

The skill runs `lib/install.sh` from this skill directory. The script detects
the plugin root from its own path and needs no further arguments.

## Conflict detection and escape hatches

- Existing hook with different content without `--force`: skill prints a
  unified diff (`diff -u`), refuses to overwrite, and exits 1.
- Existing hook with identical content: silent no-op (idempotent).
- `--no-verify` on `git commit` is the audit-logged emergency bypass for the
  git-native hooks this skill installs; the installed `post-commit` logs that
  usage to
  `${LAICLUSE_HOME:-~/.laicluse}/git-discipline/git-discipline-no-verify.log` so it is reviewable after the fact.

**Note:** inside a Claude session `--no-verify` does not bypass the
PreToolUse guards; see the `--no-verify` section of
`/git-discipline:commit-discipline` for the layer split and the
operator-only off-switch.

## Example output

```
git-discipline:install-hooks
  hooks dir   : .git/hooks (default)
  plugin path : /path/to/git-discipline
  installed   : pre-commit
  installed   : commit-msg
  installed   : prepare-commit-msg
  installed   : post-commit
  installed   : pre-push
  skipped     : (none)
  backups     : (none)
done.
```

With a conflict without `--force`:

```
git-discipline:install-hooks
  hooks dir : .git/hooks
  WARN: .git/hooks/commit-msg already exists with different content.
  --- existing
  +++ new
  @@ -1,3 +1,5 @@
  ...
  Refusing to overwrite. Re-run with --force to backup-and-replace.
exit 1
```

## Post-update procedure

After every plugin update or reinstall, the baked plugin path in the installed
hooks may be stale. Run in every repo where the hooks are active:

```bash
/git-discipline:install-hooks --force
```

This replaces the existing hooks (with automatic backup) and bakes in the
new path. Without this step the hooks will try to source the old plugin
path on the next commit, which can fail if the cache directory has been
cleaned up.
