---
name: prune
user-invocable: true
description: >-
  Safely remove a finished or abandoned git worktree while preserving unintegrated work.
---

# prune

Tear down a worktree, safely. The gate is the point: a worktree that is clean
but not yet integrated still holds work, so it is kept by default.

## Resolve the bin (cross-agent)

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

## Check, then tear down

```bash
node "$BONSAI" teardown <worktree|branch> --repo "<root>" --dry-run --json   # classify only
node "$BONSAI" teardown <worktree|branch> --repo "<root>" --json             # remove if safe
```

A worktree is removed only when it is integrated into the Git default branch
resolved from `origin/HEAD`, or from `init.defaultBranch` when that branch exists only locally, or when it is clean with nothing
ahead of that default. Otherwise teardown keeps it and returns `removed: false`
with a reason. `--dry-run` reports the same classification and warnings without
removing anything. `--force` overrides the gate and also deletes an unmerged
branch; reach for it only on a deliberate throwaway, and never wire it into an
unattended caller.

## Superseded, not merged

A branch can be finished without being an ancestor of the default branch: its
value reached that branch by reimplementation, a cherry-pick, or a rewrite
during a larger cutover. Teardown still classifies it as unintegrated, because
Git only sees the divergence. `--force` is the right tool there, but only after
an audit proves nothing is stranded. File presence is not that audit.

Compare the branch against the default branch on four axes before forcing:

```bash
git diff --name-only <default>...<branch>                       # files the branch adds or changes
git log --format='%H %s' <default>..<branch>                    # commits that never landed
git show <sha> -- '*_test.*' '*.spec.*' | grep -E '^\+(func Test|test\(|it\(|describe\()'
git grep -q "<symbol>" <default> -- <path>                      # per symbol, not per file
```

A file that exists on both sides proves nothing: the branch may have added a
test function, a fixture case, or an assertion inside a file the default branch
also carries under a different shape. Enumerate every test name and public
symbol each unlanded commit introduced, then look each one up on the default
branch by name. Port what is missing and land it before the teardown, rather
than after, so the force never has to be taken on trust.

Two outcomes are legitimate for content that is genuinely unique to the branch:
carry it over, or record why it stays gone. A temporary plan document that its
own closing gate told you to delete on completion is the second case; say so in
the report instead of reviving it.
