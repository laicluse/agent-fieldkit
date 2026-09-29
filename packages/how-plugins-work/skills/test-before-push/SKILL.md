---
name: test-before-push
user-invocable: true
description: >-
  Verify plugin candidates, refresh existing installations, and report Claude and Codex freshness.
---

# Test before push

Run this procedure after every multi-agent marketplace plugin change before declaring the change complete, whether or not a push is planned. A linked worktree may verify a candidate but may never become a persistent marketplace source. Refresh existing installations as part of authorized plugin work; new installations and unrelated configuration changes remain separately authorized actions.

## When to use

- You are in a marketplace repo with `.claude-plugin/marketplace.json` in the root.
- The repo has generated Codex adapters under `.agents/plugins/`.
- You want the current plugin source verified and safely integrated for Claude Code or Codex.
- You are completing the change locally or preparing it for a later push.

Do not use for user-level skills in `~/.claude/skills/` or `~/.codex/skills`;
those load through the user-level skill path, not a marketplace install.

## Preconditions

Run from the repo root:

```bash
alias=$(jq -r '.name' .claude-plugin/marketplace.json)
printf 'alias=%s\n' "$alias"
git status --short
circus_bin="${CIRCUS_BIN:-$(command -v circus || true)}"
[ -x "$circus_bin" ] || {
  echo "circus@laicluse-agent-fieldkit is required for plugin builds" >&2
  exit 1
}
if git diff --cached --quiet; then
  "$circus_bin" plugins versions --check .
else
  PLUGIN_VERSIONS_GIT_CMD="${PLUGIN_VERSIONS_GIT_CMD:-git commit}" \
    "$circus_bin" plugins versions --staged .
fi
"$circus_bin" plugins build .
"$circus_bin" plugins check .
```

All checks must pass. A clean index validates the committed version with `--check`; a staged current-task slice validates and preserves the next commit-count version with the same `--staged` operation the repository hook uses. If `git status --short` prints unrelated work, stop and isolate it first. Stage the current task before this procedure when version calculation needs the final candidate slice.

## Persistent source gate

```bash
git_dir=$(git rev-parse --absolute-git-dir)
common_dir=$(git rev-parse --path-format=absolute --git-common-dir)
primary_checkout=$(dirname "$common_dir")
if [ "$git_dir" != "$common_dir" ]; then
  printf 'Candidate verified in linked worktree; integrate it into %s.\n' "$primary_checkout"
fi
```

Never run either host's `marketplace add` with a linked-worktree path. Finish candidate verification there and integrate it through the repository flow. For an already-registered local Codex marketplace, that merge only updates the source: Codex runs a version-keyed snapshot, so future sessions see the change only after a version bump and existing-install refresh below.

## Detect the Codex source mode

From the primary checkout, inspect the existing installation without changing it:

```bash
common_dir=$(git rev-parse --path-format=absolute --git-common-dir)
primary_checkout=$(dirname "$common_dir")
test "$(git rev-parse --absolute-git-dir)" = "$common_dir"
alias=$(jq -r '.name' "$primary_checkout/.claude-plugin/marketplace.json")
plugin=<plugin>
codex_source=$(codex plugin list --json | jq -er --arg id "$plugin@$alias" '
  .installed[]
  | select(.pluginId == $id and .marketplaceSource.sourceType == "local")
  | .source.path
')
case "$codex_source" in
  "$primary_checkout"/*) printf 'local-codex-source=%s\n' "$codex_source" ;;
  *) printf 'Codex is not reading this primary checkout directly.\n' >&2; exit 1 ;;
esac
```

When this check passes, integrate the candidate into that primary checkout with a bumped plugin version and regenerated Codex adapters. The listed cached version can still be stale; refresh the existing installation as described below. A local marketplace uses the canonical checkout rather than a remote upgrade. Running sessions may retain old hook paths until reload/restart.

## Existing installation refresh

Claude Code and Codex execute installed cache snapshots. Refreshing an already-installed plugin is part of authorized plugin work unless the operator explicitly excludes it; do not request the same authorization again. Inspect both hosts regardless of which host performed the edit. A first install remains a separate action requiring authorization.

```bash
claude plugins update "$plugin@$alias"  # or install on first use
codex plugin add "$plugin@$alias"       # first install, or a refresh of the version-keyed cache
```

Keep new installations, removals, enablement changes and marketplace identity/source changes within their own authorization boundaries. Use the existing registered source and respect repository publication policy; never publish or repoint a marketplace simply to bypass a release gate.

## Report both hosts

Before declaring plugin work complete, verify the existing installation on both Claude Code and Codex: version, installed/enabled state where exposed, active source/cache path, and at least one changed runtime file compared with its canonical host-specific source. Then explicitly tell the operator which version is current on each host, even when both updates succeeded. Reporting only the executing host leaves the other host's state unknown and creates avoidable drift concerns. A command's successful exit or matching source manifests alone does not prove the installed payload arrived.

Use one concise report such as "Updated and verified in Claude and Codex: <plugin> <version>; existing sessions need reload/restart." If one host is absent, excluded or blocked, name that exact state instead of implying parity. Report any required session reload separately from installed-cache freshness; do not interrupt live sessions unasked.

## Fresh session check

After a merge-only local Codex change, open a fresh session and invoke the changed capability. Existing sessions keep the hook and skill set loaded at session start. After an explicitly approved Claude update, the current session can pick up the new cache with `/reload-plugins`; reload alone never snapshots working-tree edits.

## Revert

For local-only marketplaces, there is no remote revert. Leave the primary-checkout marketplace configured until the operator explicitly changes the install source. Do not run any command below without that approval.

Only when the local clone is deliberately retired after its tested commit has been pushed, re-point the alias to the remote source without removing the marketplace:

```bash
owner_repo=$(git remote get-url origin | sed -E 's#.*github.com[:/](.+)/(.+)(\.git)?$#\1/\2#; s#\.git$##')
claude plugins marketplace add "$owner_repo"
claude plugins update "<plugin>@<alias>"
codex plugin marketplace add "$owner_repo"
codex plugin add "<plugin>@<alias>"
```

Do not run marketplace remove as a cleanup step. In Claude Code, marketplace
remove cascade-uninstalls plugins under that alias.

## Contract

Source verification, integration and refresh of existing installations are part of authorized plugin work. Completion includes an explicit report of both hosts' verified state. New installations and unrelated runtime configuration changes retain their authorization boundaries.
