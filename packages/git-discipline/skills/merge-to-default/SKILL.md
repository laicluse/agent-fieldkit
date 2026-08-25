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
| `auto-trunk` | Use `--remote`; the non-force push is normal completion. |
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

Raise `gated-trunk` to `TARGET=--remote` only after reading the operator's order again and finding publication in it. When the order is silent about publishing, finish on the local default and report that the remote is untouched; the operator can order the push as its own step.

## Prepare and verify the candidate

If the worktree is dirty, commit only the completed logical slice with `git-discipline:commit-snipe` or `git-discipline:commit-all-the-things` as appropriate. Then use the shared rebase operation; the worktree owner resolves any conflict here.

```bash
"$GD_ROOT/bin/git-discipline" rebase "$TARGET"
"$GD_ROOT/bin/git-discipline" verify "$TARGET" -- <test-command> [args...]
```

The verification command must cover the relevant behavior at the exact candidate SHA. A candidate is mergeable only when it is a descendant of the current default tip and its passing proof names that same candidate and base.

## Atomic two-parent merge

```bash
"$GD_ROOT/bin/git-discipline" merge "$TARGET"
```

The merge is always a real two-parent commit. Squash, rebase-merge, and fast-forward are never valid here: each of them drops one of the two parents, and the history that shows which candidate was merged into which base is the point of the operation. The executable creates a merge commit whose first parent is the verified default tip, whose second parent is the candidate, and whose tree equals the candidate tree. `--local` rejects repositories with remotes. It uses `git update-ref <ref> <new> <expected>` when the default is not checked out, or Git's `receive.denyCurrentBranch=updateInstead` path when a clean default worktree must remain coherent. `--remote` uses a normal non-force push. If another merge wins first, the compare-and-swap fails without changing the default ref. Rebase on the new tip, rerun the relevant verification, and retry until the candidate wins or a genuine gate is reached. Do not add a long-lived merge lock.

## A refusal from the shared command is the result

The executable owns this operation end to end, so whatever it reports is the outcome of the step. When it refuses, report that refusal together with the state it found and stop. `The candidate cannot be the default branch <name>` means the candidate is already integrated: name the merge commit that carries it and finish there. A missing verification, a dirty tree, or a lost compare-and-swap race are answered by verifying, committing, or rebasing and rerunning the same command.

Never finish a refused step by hand with direct Git commands, and never substitute an adjacent action for the one that turned out to be unnecessary. A step that had nothing left to do is a complete result; hand-finishing it converts a no-op into a state change nobody ordered.

## Deployment checkout contention means wait

Before deployment, inspect the canonical deploy checkout's occupancy and Git state. If it is held by another session, dirty with unrelated changes, or contains committed-but-unintegrated work, stop deployment and wait for that owner to finish and release it. Report the occupied checkout and the work blocking deployment; do not turn this ordinary wait into a workaround.

Do not detach, stash, reset, rebase, merge, publish unrelated work, or substitute the authoring worktree to get around that contention. Resume only the deployment step once the canonical checkout is available and can be updated to the exact merged SHA.

Keep the source worktree and branch until merge and any required deployment are proven complete; cleanup belongs to `bonsai:prune`. Deployment is repository-specific and must use the exact merged SHA from a clean deploy checkout, never this authoring worktree.

Report the candidate SHA, verified base SHA, merge SHA, target, race retries, and deployment state when deployment was part of the order.
