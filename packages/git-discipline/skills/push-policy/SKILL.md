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

## Independent authoring policy

Use this plugin's `branch-policy` skill to choose where to work. This policy governs publication, never whether to author on a feature branch, trunk or a linked worktree. Its mode names do not select a branch strategy.

## Done is not published

Finishing work and publishing work are two separate decisions. Work is done when it is committed and verified. Whether a push follows depends on what that push does in this repository, never on the fact that the work is finished.

Committed but unpushed work is a finished, safe state, on a feature branch and on the default branch alike. It may stay on the operator's machine for weeks. It is not data loss, it is not open work, and it is no reason to end a turn waiting. The reflex that turns "the work is done" into "now it should be pushed" is the error this skill exists to stop.

## A commit is not a push, and never a gate

A local commit captures your own finished work; it is expected, not asked for. Leaving that work uncommitted while calling it "operator territory" is the error, not the caution: it is dirty state handed off as a to-do. Branch policy and repository rules decide which branch may receive that commit, independently of publication permission.

## What a push does depends on where it goes

`git push` is one technique with very different consequences: a copy for safekeeping, the update of a pull request, a release to other people, a deploy, a rewrite of shared history. The consequence follows from three things: which remote, which ref, and who or what reads that ref. Find the row for the push before you make it.

| Destination | Consequence | On your own? |
|---|---|---|
| Your own branch, private repository | A copy. Nobody notices. | Yes, without mention. |
| Your own branch, public repository, first push | Its content becomes public. | When the ordered work includes a pull request or a publication. |
| A branch with a pull request, `--force-with-lease` after a rebase included | CI runs and reviewers are notified, which is what the pull request is for. | Yes. It is part of the work. |
| Default branch, solo private repository (`auto-trunk`) | A copy after authorized integration. | Yes, without mention. |
| Default branch, public or shared repository (`gated-trunk`) | A release: other people and their installs receive it. | No. Agree with the operator first. |
| Default branch, pull request repository (`pr-flow`, or undetermined) | The agreement is that the default branch changes only through a pull request merge. | Never. Push a branch and use the pull request. |
| Default branch of a checkout a sync daemon manages | The daemon publishes it. | Never. Follow the registered sync workflow. |
| A tag | A version, often the trigger for a release, a deploy or a package update. | No. Agree first. |
| A remote other than the repository's own | A deploy target, or somebody else's repository. | No. Agree first. |
| Plain `--force`, a rewrite of a default branch, a ref deletion, `--all`, `--mirror`, `--tags` | Overwrites or reaches more than one change. | No. Agree first. |
| Anything else, or a row you cannot point to with confidence | Unknown. | No. Agree first. |

The last row makes the list complete. Pushing on your own needs a positive match: you can name the consequence, and it falls inside what the operator ordered. A case nobody thought of ends at "agree first", never at "probably fine".

The rows rest on the agreement for the repository, not on what the remote enforces. Branch protection is a paid feature on some plans, so a repository can be pull-request-only by agreement while the remote would accept a direct push. Such a push is not attempted; a remote that would reject it is only a safety net. An agreement the forge cannot show is declared with the `codingAgent.git.*` overrides below, and a declared fact counts as much as a measured one.

Agreeing is a normal exchange in the conversation, not a ceremony. Say once what the push would do and why it matters now, and let the operator answer. A remark about pushing is not agreement: "don't make such a fuss about pushing, nothing gets lost there" says that unpushed work is safe, which is the opposite of an order to push. Agreement names this push: this repository, this release.

The `push-destination` guard applies the table to every `git push` a coding agent runs, including one aimed at another repository than the session's own. The "Yes" rows pass silently. The "agree first" rows are denied with their consequence, and run once the same command ends in `# push-agreed`, which you add only after the operator agreed in this conversation. The "Never" rows have no token.

## Reporting

Report a push only when you made one that the operator would not expect. Do not list what is unpushed, do not count commits ahead of the remote, and do not end a turn on a push or merge nobody asked about. When a release matters for what the operator is trying to achieve, mention it once; a gate you have already named is not repeated at the end of later turns or loop ticks.

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

The landing ref decides where completed work must arrive. If work sits on a feature branch and its consumers read default, integrate it through the repository's merge workflow. The authoring branch remains the independent branch-policy decision; a push regime never makes direct default-branch authoring permissible.

## Five modes

The mode is the repository's regime. It decides the default-branch rows of the table above.

- **local-only**: no remote. Pushing never comes up; do not mention it.
- **auto-trunk**: a private, individual repo with a pushable default. Publishing the default is a backup and follows authorized integration without a separate release decision. Branch policy still chooses the authoring line.
- **gated-trunk**: a public or shared repo you can write to with a pushable default. Work is committed locally, often for weeks; a push of the default branch is a release that the operator and you agree on first. Branches for a pull request push as part of that work.
- **pr-flow**: the default branch changes only through a pull request merge, whether the forge enforces that or the operator declared it. Never push the default. Pushing a branch and creating or updating its pull request are part of the work; the merge is the operator's.
- **external**: no write access. A fork and a pull request, agreed with the operator first.

## Safe defaults when gh is absent

- no remote becomes `local-only`
- no write becomes `external`
- unknown default-branch metadata becomes `unknown`, which resolves to `pr-flow`
- unknown visibility becomes `public` (strictest hygiene)
- a repository whose facts could not be read at all reports `confidence=low`, and a default-branch push there waits for agreement even in `auto-trunk`
- declared facts count as measured ones: with visibility, push access and default-branch policy all set through overrides, confidence is `high` without the forge

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
