---
name: bonsai
user-invocable: true
description: >-
  Create a ready git worktree from the freshest default branch and prime its `.bonsai` files.
  Worktree is sometimes misspelled as "work tree" (e.g. when dictated); treat both spellings as this skill.
---

# bonsai

Worktree lifecycle as a small CLI. ("Worktree" is sometimes transcribed as two
words, "work tree", when dictated; the two mean the same thing.) This skill
makes a ready-to-use worktree:
it creates the branch off the freshest Git default branch and primes the tree
from the repo's `.bonsai` file list. It refuses a checkout that vaultsync reports
as managed, because a vaultsync root is a sync target rather than a worktree
factory. It does not launch an agent and does not write a start command anywhere;
it returns facts and stops.

## Resolve the bin (cross-agent)

The CLI lives in this plugin's `bin/`. Resolve the plugin root, then call it:

```bash
resolve_bonsai_root() {
  if [ -n "${BONSAI_BIN:-}" ]; then dirname "$(dirname "$BONSAI_BIN")"; return 0; fi
  if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; then printf '%s\n' "$CLAUDE_PLUGIN_ROOT"; return 0; fi
  if command -v codex >/dev/null 2>&1; then
    codex plugin list | awk '$1 == "bonsai@laicluse-agent-fieldkit" { print $NF; found=1; exit } END { exit found ? 0 : 1 }'
    return $?
  fi
  return 1
}
ROOT="$(resolve_bonsai_root)" || { echo "bonsai plugin root not found" >&2; exit 1; }
BONSAI="${BONSAI_BIN:-$ROOT/bin/bonsai}"
```

## Make the worktree

```bash
node "$BONSAI" create <branch> --repo "<canonical checkout root>" --json
node "$BONSAI" setup  "<worktree path from create>" --repo "<canonical checkout root>" --json
```

`create` resolves the freshest Git default branch from `origin/HEAD`, or from
repository-local `init.defaultBranch` when the configured branch exists only locally. Global initial-branch preferences do not identify an existing repository's default. It asks the vaultsync CLI whether the source checkout is managed, makes
`<root>/worktrees/<dir>` (slashes in the branch flatten to dashes in the dir),
refuses a branch that already exists, and prints `{ worktree, branch, base,
baseSha, port }`. `setup` copies the `.bonsai`-listed files from the canonical
checkout and installs dependencies per directory using the package manager each
lockfile names.

Relay the worktree path and the dev-server port to the operator. The port is a
deterministic hint in 3100-3999; use it for a dev server in the worktree so it
does not collide with the main checkout. Tearing the worktree down later is
`/prune` (the teardown subcommand).

Branch policy and project constraints choose whether a worktree is appropriate; Bonsai executes an explicit lifecycle request and does not choose feature-versus-trunk authoring or publication permission. Use the project's occupancy mechanism when present. Without Dibs or git-discipline, Bonsai remains usable; it does not invent replacement locks or authoring rules.
