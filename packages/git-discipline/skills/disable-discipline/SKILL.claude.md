---
name: disable-discipline
user-invocable: true
description: >-
  Explicit /git-discipline:disable-discipline: turn off the git-discipline guards for this session.
disable-model-invocation: true
argument-hint: ""
---

# /git-discipline:disable-discipline

Disable the git-discipline PreToolUse:Bash guards for the current session. All
guards (commit-format, commit-subject, commit-body, commit-trailers,
git-dash-c, push-wip-gate) are torn down until the operator runs
`/git-discipline:enable-discipline`. Other sessions are not affected; the
sentinel is session-specific.

This covers the guards that run inside this session only. The per-repo
`/git-discipline:disable-git` lock is orthogonal and keeps firing regardless,
for every caller.

## Nothing to do here

The plugin's `UserPromptExpansion` hook handles this command at the keystroke
itself: it writes the session sentinel, reports the result, and blocks the
expansion, so this file's content never reaches the model.

Reading this text means the hook did not run. Report that instead of writing
the sentinel: the `sentinel-protect` guard denies agent-driven writes in any
case, with no escape. Likely causes are a plugin installed without its hooks,
or a host that does not implement `UserPromptExpansion`.

## When to use

Only when the operator explicitly types this command. Never suggest it to get
past a blocked commit. The guards exist for a reason; bypassing them is the
operator's choice.

Typical use: a session that deliberately works outside the normal commit
schema (a series of trivial fixup commits, a rebasing session, or an
experimental branch where the discipline does not apply temporarily).

## Recovery

Restore the guards with `/git-discipline:enable-discipline`. Check the state
with `/git-discipline:discipline-status`.
