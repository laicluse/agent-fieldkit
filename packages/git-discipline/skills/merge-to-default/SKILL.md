---
name: merge-to-default
user-invocable: true
description: >-
  Verify and atomically merge a worktree candidate into the current default branch.
optional: true
scope: global
---

# Merge To Default

Merge the current worktree candidate as a real two-parent commit without checking out the default branch in the candidate worktree. The shared `git-discipline` executable creates the commit, validates candidate evidence, and updates the local or remote default with compare-and-swap semantics. Do not reproduce that implementation with direct Git commands.

## Resolve policy and the shared command

```bash
resolve_git_discipline_root() {
  if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; then
    printf '%s\n' "$CLAUDE_PLUGIN_ROOT"
    return 0
  fi
  if command -v codex >/dev/null 2>&1; then
    codex plugin list --json | jq -er '.installed[] | select(.pluginId == "git-discipline@laicluse-agent-fieldkit") | .source.path'
    return $?
  fi
  return 1
}

GD_ROOT="$(resolve_git_discipline_root)" || { echo "git-discipline plugin root not found" >&2; exit 1; }
"$GD_ROOT/bin/git-discipline" default
POLICY="$("$GD_ROOT/skills/push-policy/git-repo-policy")"
MODE="$(printf '%s\n' "$POLICY" | sed -n 's/^mode=//p')"
```

Repository policy determines the only valid merge target:

| Mode | Action |
|------|--------|
| `local-only` | Use `--local`; atomically update the local default ref. |
| `auto-trunk` | Use `--remote` after authorized integration. The push and any existing auto-deploy need no separate go; a remote consumer does not change the repository's mode. Honor an explicit local-only instruction. |
| `gated-trunk` | Use `--local`: the merge commit updates the local default ref and publication stays a separate decision. Use `--remote` only when the operator's order names publishing this default, in their own words (push, publish, origin, live). Invoking this skill orders the merge, not the publication; a merge order is never by itself the go for a shared ref update. |
| `pr-flow` | Do not update the default ref directly. Follow the repository's PR flow; the remote merge remains an explicit operator gate. |
| `external` | Do not update the default ref; there is no write access. |

```bash
case "$MODE" in
  local-only) TARGET=--local ;;
  auto-trunk) TARGET=--remote ;;
  gated-trunk) TARGET=--local ;;
  pr-flow) echo "Default is protected; use the repository PR flow." >&2; exit 1 ;;
  external) echo "Repository is external; default cannot be updated from this checkout." >&2; exit 1 ;;
  *) echo "Unknown git-discipline mode: $MODE" >&2; exit 1 ;;
esac
```

Raise `gated-trunk` to `TARGET=--remote` only after reading the operator's order again and finding publication in it. When the order is silent about publishing, finish on the local default and leave the remote untouched without reporting it as pending; publishing the default is a release the operator and you agree on separately.

## Prepare and verify the candidate

If the worktree is dirty, commit only the completed logical slice with `git-discipline:commit-snipe` or `git-discipline:commit-all-the-things` as appropriate. Then use the shared rebase operation; the worktree owner resolves any conflict here.

```bash
"$GD_ROOT/bin/git-discipline" rebase "$TARGET"
"$GD_ROOT/bin/git-discipline" verify "$TARGET" -- <test-command> [args...]
```

The verification command must cover the relevant behavior at the exact candidate SHA. A candidate is mergeable only when it is a descendant of the current default tip and its passing proof names that same candidate and base.

## Atomic two-parent merge

Before a merge that updates a checked-out default, check that checkout's existing occupancy mechanism when present. The shared command also claims that checkout through Dibs when `DIBS_BIN` or its published machine runtime is available; Dibs owns identity, refusal and lifecycle semantics. The session retains acquired occupancy until its normal release. If another live session owns it, perform the Dibs held-checkout activity audit before declaring a wait; a clean tree or live PID alone does not establish recent work. Resolve conflicts in the authoring checkout before the atomic merge, not by editing the canonical integration target. This requires neither Dibs nor Bonsai when the repository uses another coordination mechanism.

```bash
"$GD_ROOT/bin/git-discipline" merge "$TARGET"
```

The merge is always a real two-parent commit. Squash, rebase-merge, and fast-forward are never valid here: each of them drops one of the two parents, and the history that shows which candidate was merged into which base is the point of the operation. The executable creates a merge commit whose first parent is the verified default tip, whose second parent is the candidate, and whose tree equals the candidate tree. `--local` updates only the local default, including in repositories with remotes. It uses `git update-ref <ref> <new> <expected>` when the default is not checked out, or Git's `receive.denyCurrentBranch=updateInstead` path when a clean default worktree must remain coherent. `--remote` uses a normal non-force push. If another merge wins first, the compare-and-swap fails without changing the default ref. Rebase on the new tip, rerun the relevant verification, and retry until the candidate wins or a genuine gate is reached. Do not add a long-lived merge lock.

## A refusal from the shared command is the result

The executable owns this operation end to end, so whatever it reports is the outcome of the step. When it refuses, report that refusal together with the state it found and stop. `The candidate cannot be the default branch <name>` means the candidate is already integrated: name the merge commit that carries it and finish there. A missing verification, a dirty tree, or a lost compare-and-swap race are answered by verifying, committing, or rebasing and rerunning the same command.

Never finish a refused step by hand with direct Git commands, and never substitute an adjacent action for the one that turned out to be unnecessary. A step that had nothing left to do is a complete result; hand-finishing it converts a no-op into a state change nobody ordered.

## A merge ends with the merged SHA running

When the repository has a deploy path (an Ansible playbook, a deploy script, a `.test` start flow, an autodeploy poller), the merge is not finished until that path runs the exact merged SHA. Deploying is part of the merge order, not a separate release decision, and it does not need a push: run the repository's deploy path from the clean canonical checkout on the local default. Publishing the default to its remote stays governed by the mode table above; the two decisions are independent.

Failure case this prevents: a local-only merge reported as "merged, not deployed", while the operator kept seeing the old behaviour in the live product. In a repository whose autodeploy poller reads the remote default and skips while the local default is ahead of it, a local-only merge also stalls every later deploy of that repository; deploy through the playbook directly and say in the report that the poller stays paused on that repository until the default is published.

## Deployment checkout contention means wait

Before deployment, inspect the canonical deploy checkout's occupancy and Git state. If held by another session, perform the Dibs held-checkout activity audit immediately: report the lock age, latest checkout activity, and latest holder-session activity with their timestamps. A holder active elsewhere with no recent work here is an idle lock, not evidence of an active deployment; request its release through the holder's normal workflow. If another session still owns the checkout, or it is dirty with unrelated changes or contains committed-but-unintegrated work, stop deployment and wait for the owner to finish and release it. Report the occupied checkout and the work blocking deployment; do not turn this wait into a workaround.

Do not detach, stash, reset, rebase, merge, publish unrelated work, or substitute the authoring worktree to get around that contention. Resume only the deployment step once the canonical checkout is available and can be updated to the exact merged SHA.

The canonical deploy checkout must remain attached to its named default branch throughout preview and deployment. Never check out a raw commit SHA there, even temporarily: detached HEAD hides which line owns the running product and leaves the checkout in a surprising state for the next session. When deployment requires an exact merged SHA, the default branch ref itself must point at that SHA and the clean canonical checkout must have that branch checked out. If either condition is false, stop instead of manufacturing an unnamed checkout state.

Deployment is repository-specific and must use the exact merged SHA from that clean, attached deploy checkout, never this authoring worktree.

## Remove the source worktree and branch right after merge

The merge is what the worktree existed for, so removing it belongs to this step rather than to a later tidy-up: hand the worktree and its branch to `bonsai:prune` as soon as the merge is reported. A reported merge is proven, and nothing else gates the removal.

Report the candidate SHA, verified base SHA, merge SHA, target, race retries, the removed worktree, and the deployed SHA with the proof that the running process started on it. "Not deployed" is only a valid report when the repository has no deploy path.
