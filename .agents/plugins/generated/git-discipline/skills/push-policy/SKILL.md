---
name: push-policy
description: >-
  Reference for deciding whether pushing is appropriate for this repo's publication policy.
---

# /git-discipline:push-policy

git-discipline's push hooks gate push CONTENT: no wip commits, a schema-valid body.
This skill governs push CONTEXT: whether and when a push fits the repository
you are working in. The two are orthogonal. A push can be content-valid and
still be the operator's call; a freely-pushable repo still owes a valid body.

The destination is a sound push decision for THIS repo, not a fixed ceremony. Resolve the repo's mode, then act in the way that mode allows. Do not invent a ceremony where the repo does not need one, and do not publish visible changes or update shared state without the operator's go.

## A commit is not a push, and never a gate

A local commit captures your own finished work; it is expected, not asked for. Leaving that work uncommitted while calling it "operator territory" is the error, not the caution: it is dirty state handed off as a to-do. "Never commit to main" is a team-repo rule about a shared or protected branch, not a universal one; on a solo or personal repo, committing to main is the normal flow. The operator's go is owed by the push or merge that publishes visible work or reaches other people, per the mode below, never by the commit itself.

## The resolver

```bash
resolve_git_discipline_root() {
  if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; then
    printf '%s\n' "$CLAUDE_PLUGIN_ROOT"
    return 0
  fi
  if command -v codex >/dev/null 2>&1; then
    codex plugin list --json \
      | jq -er '.installed[] | select(.pluginId == "git-discipline@laicluse-agent-fieldkit") | .source.path'
    return $?
  fi
  return 1
}

GD_ROOT="$(resolve_git_discipline_root)" || { echo "git-discipline plugin root not found" >&2; exit 1; }
"$GD_ROOT/skills/push-policy/git-repo-policy" [repo-path]
```

Run it on a push decision (defaults to the current repo). It prints, one per
line: `remote`, `has_remote`, `collaboration`, `visibility`, `default_policy`,
`push_access`, `confidence`, `mode`, `hygiene`. The pure derivation functions
are covered by `test/push-policy/derive-mode.bats`.

## Three independent facts, plus access

- **collaboration**: `individual` or `shared`. Derived from distinct author NAMES (not emails) in recent history, so one person committing under several git emails still reads as `individual`. Visibility does not alter this fact.
- **visibility**: `private` or `public` (via `gh`). Public raises `hygiene` to `high` and prevents automatic publication even when collaboration is `individual`.
- **defaultBranchPolicy**: `pushable` or `protected`. `protected` means
  MEANINGFUL protection on the default branch: required pull-request reviews,
  required status-check contexts, or push restrictions. An empty 200 protection
  object is NOT protected.
- **push_access**: `write` or `external` (via `gh` viewer permission, with an
  owner-heuristic fallback against the `codingAgent.git.owners` global).

## Where the work has to land

The mode says what you may push; it does not say where the work has to arrive. Ask that second question before you pick a branch: which ref does this change take effect from? A deploy watching the default branch, a plugin or package installed from the default branch, a published artifact, a consumer that pulls it. When that ref is the default branch, a feature branch does not deliver the change at all.

The landing ref decides the branch, not habit. In a trunk repo (`auto-trunk`, `gated-trunk`) the default branch is the working line; open a feature branch only when something concrete needs the isolation. If work already sits on a branch and the landing ref is the default, finishing it means merging it there with `/git-discipline:merge-to-default`, or naming that merge as the operator's call and asking for it. Pushing the branch and stopping leaves the change where nothing reads it, while the report says the work is done.

## Five modes

- **local-only**: no remote. Never mention pushing at all.
- **auto-trunk**: a private, individual repo with a pushable default. The default branch is the working line: commit and push there, and auto-push completions. Do not ask, and do not route the work through a feature branch it does not need.
- **gated-trunk**: a public or shared repo you can write to with a pushable default. Feature branches push only when publication is already part of the operator's request. The default branch is never pushed silently, which means proposing that merge when the request needs it, not avoiding it.
- **pr-flow**: a protected default. Never push the default directly. Branch,
  then PR, then merge is the gated step that needs the operator's go.
- **external**: no write access. Fork plus PR.

**Forced continuation**: after a rebase of a branch that already has an
upstream, a `--force-with-lease` push of your own branch is the completion of
that rebase, not a new decision. Do not ask for it, unless the branch is a
protected default.

## Safe defaults when gh is absent

- no remote becomes `local-only`
- no write becomes `external`
- unknown default-branch metadata becomes `unknown`, which resolves to `pr-flow`
- unknown visibility becomes `public` (strictest hygiene)

## Config and overrides

Per-repo overrides live in git-local config under the `codingAgent.git.*`
namespace and win over detection:

- `codingAgent.git.collaboration` (`individual` / `shared`; legacy `closed` and `open` values normalize to `shared`)
- `codingAgent.git.visibility` (`private` / `public`)
- `codingAgent.git.defaultBranchPolicy` (`pushable` / `protected`)
- `codingAgent.git.pushAccess` (`write` / `external`)

A global `codingAgent.git.owners` list (set with `git config --global`) names
the repo owners you have write access to. It feeds the `push_access` fallback
when `gh` cannot answer.

Set one with, for example:

```
git config codingAgent.git.collaboration individual
```

## Self-discovery rule

Resolve the mode on any push decision. If the resolver reports
`confidence=low`, or the detected collaboration feels wrong for the work in
front of you, propose the single-line `codingAgent.git.*` override ONCE, then
proceed on your best reading. Never re-ask the same question on later pushes in
the same repo: the override is the durable answer, and a repeated nag costs
more than it protects.
