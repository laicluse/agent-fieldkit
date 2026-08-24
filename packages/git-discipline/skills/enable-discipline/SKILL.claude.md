---
name: enable-discipline
user-invocable: true
description: >-
  Explicit /git-discipline:enable-discipline: re-enable the git-discipline guards for this session.
disable-model-invocation: true
argument-hint: ""
---

# /git-discipline:enable-discipline

Re-enable the git-discipline PreToolUse:Bash guards for the current session.
Removes the session sentinel that `/git-discipline:disable-discipline` created.
Has no effect when the guards are already active.

A separate global sentinel (`git-discipline-disabled-global`) affects every
session and is not removed by this command; the hook reports when it finds one
still in place.

## Nothing to do here

The plugin's `UserPromptExpansion` hook handles this command at the keystroke
itself: it removes the session sentinel, reports the result, and blocks the
expansion, so this file's content never reaches the model.

Reading this text means the hook did not run. Report that instead of removing
the sentinel: the `sentinel-protect` guard denies agent-driven removal in any
case, with no escape. Likely causes are a plugin installed without its hooks,
or a host that does not implement `UserPromptExpansion`.

## Check status

Use `/git-discipline:discipline-status` to see which sentinels are active and
what the current guard state is.
