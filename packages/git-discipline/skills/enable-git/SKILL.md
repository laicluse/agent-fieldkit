---
name: enable-git
user-invocable: true
description: >-
  Explicit /git-discipline:enable-git: remove the repo read-only git lock.
disable-model-invocation: true
argument-hint: ""
---

# /git-discipline:enable-git

Remove the per-repo lock that `/git-discipline:disable-git` set. The lock is not
Claude-specific: while it is in place the installed `commit-msg` and `pre-push`
hooks reject commits and pushes from every caller, including Codex and a plain
shell. Removing it restores git for all of them. Has no effect when no lock is
present.

## Nothing to do here

The plugin's `UserPromptExpansion` hook handles this command at the keystroke
itself: it removes `.git/git-discipline-deny`, reports the result, and blocks
the expansion, so this file's content never reaches the model.

Reading this text means the hook did not run. Report that instead of removing
the lock: the `sentinel-protect` guard denies agent-driven removal in any case,
with no escape. Likely causes are a plugin installed without its hooks, or a
host that does not implement `UserPromptExpansion`.
