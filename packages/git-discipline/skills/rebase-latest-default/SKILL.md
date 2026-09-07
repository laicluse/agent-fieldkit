---
name: rebase-latest-default
user-invocable: true
description: >-
  Rebase and verify the current worktree branch on the actual default-branch tip without using a default checkout.
optional: true
scope: global
---

# Rebase Latest Default

Rebase the current worktree's feature branch on the current default branch and attach fresh verification evidence to the resulting candidate commit. The shared `git-discipline` command owns default-branch resolution, cleanliness checks, the rebase, and candidate evidence; do not reproduce those operations with ad hoc Git commands.

## Resolve the runtime and repository mode

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

Use `--local` only for `local-only`. Every mode with an origin uses `--remote`, whose exact fetch writes only `FETCH_HEAD`; it does not refresh remote-tracking refs or change a feature-branch force-with-lease baseline.

```bash
case "$MODE" in
  local-only) TARGET=--local ;;
  auto-trunk|gated-trunk|pr-flow|external) TARGET=--remote ;;
  *) echo "Unknown git-discipline mode: $MODE" >&2; exit 1 ;;
esac

"$GD_ROOT/bin/git-discipline" rebase "$TARGET"
```

## Conflicts belong to the worktree owner

When Git stops on a conflict, inspect both intents, resolve it in this worktree, stage the resolution, and continue the rebase. Regenerate generated files from their canonical inputs instead of hand-merging them. Stop only for a genuinely ambiguous product decision. Never move conflict resolution to a default checkout or a central integrator.

## Verify the rebased candidate

Choose the relevant deterministic test command from the repository and run it through the same executable so evidence is recorded against both the candidate SHA and the current default SHA:

```bash
"$GD_ROOT/bin/git-discipline" verify "$TARGET" -- <test-command> [args...]
```

Use `bash -c '<command-1> && <command-2>'` only when one candidate needs multiple commands. Never add `-l`. A login shell re-reads the profile and can place system tooling ahead of a version manager's shims, so the suite runs on the wrong Ruby, Node, or Python and fails on the environment while the candidate itself is fine. When the repo pins its toolchain through asdf, rbenv, mise, or nvm, put those shims in front explicitly, for example `bash -c 'export PATH="$HOME/.asdf/shims:$PATH"; <command>'`. A failed command removes mergeability for that candidate. Any later commit, amend, rebase, or default-branch advance requires another verification.

## Published feature branches

If the rebase rewrote an already-published feature branch and policy permits writes, complete the rebase with `git push --force-with-lease` to that feature branch. Never force-push the default branch. A first publication and `external` mode remain operator-owned.

Report the old and new candidate SHAs, the resolved default branch and base SHA, conflict resolutions, the verification command, and whether an existing feature branch was updated.
