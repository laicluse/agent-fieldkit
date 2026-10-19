# bonsai

Worktree lifecycle as a small, cross-platform CLI. Bonsai owns one thing well:
creating, priming, and tearing down git worktrees, git-natively, with a safety
gate so work is never thrown away by accident.

It is deliberately distinct from raw `git worktree`: bonsai resolves the
freshest Git default branch, refuses to use a vaultsync-managed checkout as a
worktree factory, follows the `<root>/worktrees/<dir>` convention with a
self-ignoring `.gitignore`, primes a tree from a `.bonsai` file list, and guards
teardown. It emits facts (`--json`), never a start command or clipboard payload;
whatever launches an agent in the worktree composes its own briefing.

Use `bonsai` when an agent needs isolated workspace state without inventing a
repo-specific worktree ritual. It is especially useful before starting parallel
agent work, handing a mission to another runtime, or cleaning up old worktrees
without losing unmerged commits.

## Installation

```bash
claude plugins install bonsai@laicluse-agent-fieldkit
codex plugin add bonsai@laicluse-agent-fieldkit
```

## CLI

```
bonsai create <branch> --repo <root> [--base <ref>] [--json]
bonsai setup  <worktree> --repo <root> [--no-install] [--json]
bonsai teardown <worktree|branch> --repo <root> [--force] [--dry-run] [--json]
```

- **create**: resolve the freshest Git default branch from `origin/HEAD` when
  available, refuse a vaultsync-managed checkout through the vaultsync CLI, make
  the worktree + branch (slashes in the branch flatten to dashes in the dir),
  refuse an existing branch, and print `{ worktree, branch, base, baseSha, port
  }`. The port is a deterministic dev-server hint in 3100-3999.
- **setup**: copy the `.bonsai`-listed files from the canonical checkout
  (`--repo`) and install dependencies per directory by the manager each lockfile
  names. Install is best-effort; failures warn rather than block.
- **teardown**: remove a worktree only when it is integrated into the Git
  default branch, or clean with nothing ahead of that default. Otherwise it is
  kept with a reason. Warns on orphaned unpushed commits and on a diverged
  default. `--dry-run` classifies without removing; `--force` overrides the
  gate.

## Skills

- `bonsai`: make a ready worktree (create + setup).
- `setup`: prime an existing worktree.
- `prune`: tear down behind the safety gate.

## Coordination and authoring

Branch policy and project constraints decide whether to use a worktree. Bonsai carries out the explicit lifecycle request; it does not select feature-versus-trunk authoring or authorize publication. When Dibs is available, creation claims the resulting worktree through that plugin. Without Dibs, creation succeeds with an explicit warning that no occupancy lock was acquired. Git-discipline is not a runtime dependency. Without Bonsai, Git's worktree commands remain usable with the project's setup and coordination procedure.

## Files

- `bin/bonsai`: CLI dispatcher.
- `bin/bonsai-lib.mjs`: pure functions (base resolution, port, copy, install
  detection, teardown classification).
- `test/*.bats`: CLI contract tests.
