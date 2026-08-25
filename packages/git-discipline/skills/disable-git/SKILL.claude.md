---
name: disable-git
user-invocable: true
description: >-
  Explicit /git-discipline:disable-git: make the current repo read-only for git write commands.
disable-model-invocation: true
argument-hint: "<reason>"
---

# /git-discipline:disable-git

Set a per-repo lock that puts git write commands out of reach for a while.
Read-only inspection keeps working (status, log, diff, show, blame, rev-parse,
branch list, tag list, etc.). Anything that mutates working directory, index,
refs, or remote (commit, checkout, switch, restore, reset, merge, rebase,
cherry-pick, revert, push, pull, fetch, add, rm, mv, stash, clean, branch -d,
tag v0.1, ...) is blocked.

The lock is a sentinel file at `.git/git-discipline-deny` inside the repo (or
the main worktree's `.git/` when invoked from a linked worktree). It is
per-repo, never committed, and not visible in `git status`.

## A reason is required

A lock outlives the session that set it, so the command refuses a bare
invocation: pass the reason as the argument. It is stored in the sentinel with
the date, and both are quoted back on every denied git command. Locks written
by earlier versions carry no reason and keep denying without one.

## The lock explains itself

Whoever meets the lock may never have seen the deny message: a fresh agent
session, a colleague in a plain terminal, you weeks later. So the sentinel is
written with a comment header naming the plugin that set it, what it blocks,
and that lifting it is the operator's call. The deny messages say the same,
and they tell an agent it cannot lift the lock itself rather than handing it a
command that is operator-invoked only.

## Who the lock stops

The lock is not Claude-specific, and its reach depends on the caller.

- **Every caller, including Codex and a plain shell**: when
  `/git-discipline:install-hooks` is active in the repo, the git-native
  `commit-msg` and `pre-push` hooks read the same sentinel, so `git commit`
  and `git push` are rejected no matter who runs them. Other write commands
  (`git reset`, `git checkout`, ...) have no git-native hook to carry the
  check, so they stay available to a shell and to agents without the
  PreToolUse guard.
- **Inside Claude Code**: the `repo-deny` PreToolUse guard covers every
  mutating subcommand, not just commit and push.

## Nothing to do here

The plugin's `UserPromptExpansion` hook handles this command at the keystroke
itself: it writes the sentinel, reports the result, and blocks the expansion,
so this file's content never reaches the model.

Reading this text means the hook did not run. Report that instead of writing
the sentinel: the `sentinel-protect` guard denies agent-driven writes in any
case, with no escape. Likely causes are a plugin installed without its hooks,
or a host that does not implement `UserPromptExpansion`.

## Scope of the lock

- Allowed (read-only inspection): `status`, `log`, `diff`, `show`,
  `blame`, `rev-parse`, `rev-list`, `name-rev`, `describe`, `reflog`,
  `shortlog`, `cat-file`, `ls-files`, `ls-tree`, `ls-remote`,
  `for-each-ref`, `grep`, `whatchanged`, `merge-base`,
  `symbolic-ref`, `var`, `version`, `help`, `remote -v`,
  `config --get`, `branch` / `tag` in list form,
  `bisect view` / `bisect log`, `worktree list`,
  `submodule status` / `summary`, `stash list` / `show`,
  `notes list` / `show`.
- Blocked: everything else.

## Recovery

`/git-discipline:enable-git` removes the sentinel.
