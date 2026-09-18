---
name: push-policy
user-invocable: true
description: >-
  Reference for deciding whether a push is a step of ordered work, a backup, or a release, and for leaving committed work unpushed when it is none of those.
argument-hint: ""
optional: true
scope: global
---

# /git-discipline:push-policy

git-discipline's push hooks gate push CONTENT: no wip commits, a schema-valid body.
This skill governs push CONTEXT: whether a push belongs to the work at all. The two are orthogonal. A push can be content-valid and still be the operator's call; a freely-pushable repo still owes a valid body.

## Done is not published

Finishing work and publishing work are two separate decisions. Work is done when it is committed and verified. A push is a separate act with its own reason, and completing a task never supplies that reason by itself.

Committed but unpushed work is a finished, safe state, on a feature branch and on the default branch alike. It may stay on the operator's machine for weeks. Do not report it as open, do not count the commits ahead of the remote, do not end a turn waiting for a push, and do not propose one the operator did not ask for. The reflex that turns "the work is done" into "now it should be pushed" is the error this skill exists to stop.

## A commit is not a push, and never a gate

A local commit captures your own finished work; it is expected, not asked for. Leaving that work uncommitted while calling it "operator territory" is the error, not the caution: it is dirty state handed off as a to-do. "Never commit to main" is a team-repo rule about a shared or protected branch, not a universal one; on a solo or personal repo, committing to main is the normal flow.

## Every push has a reason

Before any push, name its reason. The reason follows from one question: who reads the destination ref, and what happens when it moves? Every legitimate push falls into one of three classes.

1. **Workflow step.** The push is a mechanical part of a flow the operator already ordered, and the flow does not work without it. Examples: publishing the branch of a pull request you were asked to open or update, pushing review fixes to that branch, the `--force-with-lease` that completes a rebase of a branch that already has an upstream. Do it as part of the work, without asking and without announcing more than its result.
2. **Backup.** The destination is a ref that only the operator reads, and moving it changes nothing for anyone else: the operator's own branch, or the default branch of a private, individual repo that no deploy, CI or consumer reads from. It is an off-site copy and nothing more. Where the mode below allows it, it may happen without asking. It is never required, never a completion step, and never reported as pending.
3. **Release.** The push changes what other people or systems see or run: the default branch of a public or shared repository, any branch in a public repository, a ref a deploy, marketplace, package registry or other consumer reads, a tag. A release happens only on the operator's explicit order for this change, in their own words (push, publish, release, ship, live). Do not propose it and do not remind the operator of it; they decide when.

A push whose reason is none of these, or unclear, does not happen. Leaving the work unpushed needs no question either, because unpushed work is safe.

A statement about pushing is not an order to push. "Don't make such a fuss about pushing, nothing gets lost there" says that unpushed work is safe; it does not order a push. "It's fine that this is still local" does not either. Only an instruction to push, publish or release this change is the order.

### Examples

| Situation | Class | Action |
|---|---|---|
| The operator asked for a pull request in a repo with a protected default | Workflow step | Push the branch and create the PR. The merge stays the operator's. |
| Review fixes on a PR branch you created for the operator | Workflow step | Push them to that branch. |
| A rebase rewrote a branch that already has an upstream | Workflow step | `--force-with-lease` to that branch, never to the default. |
| Finished work on the default branch of a private dotfiles or notes repo | Backup | Allowed without asking in `auto-trunk`, never mentioned as open. |
| Finished work on the default branch of a public plugin marketplace | Release | Commit locally and stop. Push only on the operator's order. |
| A private repo whose CI deploys every push to its default branch | Release | The deploy makes it a release, whatever the mode says. |
| A pull request is green and waiting | Release (the merge) | Say once that it is ready. Do not repeat it every turn. |
| The operator says unpushed work is safe | None | Nothing to push; carry on with what was asked. |

## Reporting

Report a push only when you made one, with its class when that is not obvious. Do not list what is unpushed, and do not end a turn on a push or merge nobody ordered. A release gate you have already named once is not repeated at the end of every later turn or loop tick; the operator knows it is there.

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

The mode says which pushes are possible; the landing ref says where the change takes effect. Ask which ref the change is read from: a plugin installed from the local checkout, a dev server running from it, a deploy watching the remote default branch, a package consumer pulling a tag.

Often that ref is local. A marketplace or tool installed from the primary checkout takes effect from the local default branch, so merging there finishes the work and the remote stays untouched. When the landing ref is remote, the push that reaches it is a release, and the operator's order decides when it happens.

The landing ref decides the branch, not habit. In a trunk repo (`auto-trunk`, `gated-trunk`) the default branch is the working line; create a feature branch only when something concrete needs the isolation. If work already sits on a branch and the landing ref is the default, finishing it means merging it there with `/git-discipline:merge-to-default`. Pushing the branch and stopping leaves the change where nothing reads it, while the report says the work is done.

## Five modes

The mode bounds which push classes are possible in a repository. Within those bounds the class of each push decides whether it happens.

- **local-only**: no remote. Pushing never comes up; do not mention it.
- **auto-trunk**: a private, individual repo with a pushable default. The default branch is the working line. A push of it is a backup, allowed without asking and never required. It becomes a release as soon as something reads the remote default, such as a deploy on push.
- **gated-trunk**: a public or shared repo you can write to with a pushable default. Every push to the default branch is a release, and in a public repo so is every feature branch push. Pushes happen only as a workflow step of an ordered flow, or on the operator's order.
- **pr-flow**: a protected default. Never push the default directly. When the ordered change has to reach the default branch, pushing its branch and creating the pull request are workflow steps. The merge is a release and stays the operator's.
- **external**: no write access. A fork and a pull request, only when the operator ordered the contribution.

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
