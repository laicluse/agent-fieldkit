# git-discipline

Git guardrails and an optional parallel-worktree flow for agent sessions and direct CLI use. Canonical-checkout authoring remains the default. Use a linked worktree when concurrency, a live checkout, change risk, or another concrete constraint makes isolation safer; repositories that always need that flow can opt in with local `laicluse.requireWorktree=true`. Verified candidates become real two-parent default-branch merge commits through an atomic ref update, without a canonical checkout bottleneck or a long-lived merge lock.

Use it when commits and pushes need the same discipline regardless of whether
they come from Claude Code, Codex, or a direct terminal. The plugin gives the
agent workflow skills for common git moves and installs hook backstops so
message schema, wip commits, and push policy do not depend on memory.

## Installation

```bash
claude plugins install git-discipline@laicluse-agent-fieldkit
codex plugin add git-discipline@laicluse-agent-fieldkit
```

In Claude Code, the PreToolUse:Bash hooks register automatically. In Codex, the
generated adapter ships the workflow skills and omits the Claude-only
PreToolUse toggle/status skills. To catch commits made outside Claude Code, or
from Codex, install the git-native hooks into each repo:

```bash
/git-discipline:install-hooks
```

Use `--dry-run` to preview, `--force` to overwrite existing hooks. Re-run
after each plugin update or Codex reinstall so the installed hooks point at
the current plugin version.

## What it does

`git-discipline` has three parts:

1. **Parallel candidate flow.** One vendor-neutral `bin/git-discipline` implementation dynamically resolves the default branch, rebases the current worktree, records test evidence against the exact candidate and base SHAs, creates a two-parent merge commit, and updates the local or remote default ref with compare-and-swap semantics.
2. **Git workflow skills.** Thin host adapters for grouped commits, precise commits from a dirty tree, candidate rebase and verification, merging to default, resolving push policy, and installing hooks.
3. **Commit-discipline enforcement.** Two-layer hook architecture
   (PreToolUse guards plus git-native hooks) that validates a structured
   body schema: subject + WHY paragraph + Slice / Tests / Red-then-green
   trailers parsed via `git interpret-trailers`, with eight opt-out enum
   tokens. `Red-then-green` accepts three forms: `n/a (reason >= 10 chars)`,
   `<path>` (a spec file in the staged diff), or `<path>:<line> # <test-name>`
   (line is 1-based, name must match a test declaration in the staged
   blob; the `# ` separator follows the RSpec / Cucumber convention and
   keeps `path:line` clickable in iTerm2 / VSCode / Ghostty). Bare `yes`
   is no longer accepted.

Reference for the schema, examples, escape-hatches, and troubleshooting:
`/git-discipline:commit-discipline`.

## Parallel candidate command

The executable is the single implementation used by skills and native hooks:

```bash
git-discipline default
git-discipline rebase --local|--remote
git-discipline verify --local|--remote -- <test-command> [args...]
git-discipline merge --local|--remote
```

`--local` uses the configured local default ref and is intended for `local-only` repositories. `--remote` reads the actual `origin` default tip, fetches only that tip into `FETCH_HEAD` for rebases, and merges through a normal non-force push. Passing verification evidence lives under `${LAICLUSE_HOME:-~/.laicluse}/git-discipline/candidates/` as recovery and visibility state. Git commits and refs remain the source of truth: evidence is rejected as soon as the candidate or default SHA changes.

The merge commit always has the verified default tip as first parent, the candidate as second parent, and the candidate tree. A local merge uses `git update-ref` with an expected old SHA; a remote merge relies on the same topology plus a non-force push. If another candidate updates default first, the loser rebases and verifies again.

## Skills

| Skill | Command | Agents | Auto |
|-------|---------|--------|:----:|
| commit-all-the-things | `/git-discipline:commit-all-the-things` | Claude, Codex | yes |
| commit-snipe | `/git-discipline:commit-snipe` | Claude, Codex | yes (on the word "snipe") |
| rebase-latest-default | `/git-discipline:rebase-latest-default` | Claude, Codex | yes |
| merge-to-default | `/git-discipline:merge-to-default` | Claude, Codex | yes |
| push-policy | `/git-discipline:push-policy` | Claude, Codex | |
| commit-discipline | `/git-discipline:commit-discipline` | Claude, Codex | |
| install-hooks | `/git-discipline:install-hooks` | Claude, Codex | |
| run-spec | `/git-discipline:run-spec` | Claude, Codex | |
| disable-session | `/git-discipline:disable-discipline` | Claude | |
| enable-session | `/git-discipline:enable-discipline` | Claude | |
| session-status | `/git-discipline:discipline-status` | Claude | |
| disable-git | `/git-discipline:disable-git [reason]` | Claude | |
| enable-git | `/git-discipline:enable-git` | Claude | |

- **commit-all-the-things** inspects `git status` plus `git diff`, groups
  changes by intent (feature, fix, refactor, docs, config), and creates
  one commit per group. Trigger phrases include "commit everything",
  "clean up the working tree", and "commit what's left".
- **commit-snipe** stages only the files (or hunks) that belong to the
  current conversation's work and leaves the rest untouched. Auto-fires
  on the word "snipe".
- **rebase-latest-default** delegates default resolution, rebase, and SHA-bound verification to `bin/git-discipline`. Conflicts stay with the feature-worktree owner; no default checkout or central integrator resolves them.
- **merge-to-default** resolves repository policy, reruns relevant verification at the candidate SHA, and invokes the atomic two-parent merge. `local-only` updates the local ref; `auto-trunk` and explicitly ordered `gated-trunk` merges use a normal remote push; `pr-flow` and `external` retain their repository gates. Source cleanup remains with `bonsai:prune` after merge and any required deployment are proven complete.
- **push-policy** decides whether and when a push fits the current repo. It ships a resolver (`skills/push-policy/git-repo-policy`) that reads independent per-repo facts (collaboration, visibility, default-branch protection, push access) and derives one of five modes (`local-only`, `auto-trunk`, `gated-trunk`, `pr-flow`, `external`), each with its own push behavior. Per-repo overrides live under git-local `codingAgent.git.*`. `rebase-latest-default` and `merge-to-default` consult it; the push hooks gate content and are orthogonal to this context decision.
- **commit-discipline** is the canonical reference for the body schema,
  error-codes, opt-out enum, and escape-hatches.
- **install-hooks** copies the git-native `pre-commit`, `commit-msg`, `prepare-commit-msg`,
  `post-commit`, `post-rewrite`, and `pre-push` hooks into the current repo so commits
  made outside Claude Code still get validated. `--force` overwrites
  existing hooks (a backup is taken automatically); `--dry-run` previews.
- **run-spec** runs a single test/spec file through the project's
  auto-detected runner (RSpec, Jest, Vitest, Go test, pytest) and prints
  a PASS/FAIL summary. No cache side-effects.
- **disable-session** writes a sentinel file at `${LAICLUSE_HOME:-~/.laicluse}/git-discipline/git-discipline-disabled-<session_id>`
  that tells the dispatcher to skip all guards for the current session. Other
  sessions are not affected. Only fire on explicit user invocation.
- **enable-session** removes the session sentinel (and the global fallback
  sentinel if present), restoring guards for the current session.
- **session-status** reports the current session_id, which sentinels exist,
  whether guards are active or disabled, the active plugin version, and the
  list of guard scripts in the install.
- **disable-git** writes `.git/git-discipline-deny` (per-repo, never committed) and
  locks git for Claude. While the sentinel exists, only read-only inspection
  is allowed (status, log, diff, show, blame, rev-parse, branch / tag in
  list form, remote -v, config --get, `bisect view`, `worktree list`,
  `submodule status`, `stash list/show`, `notes list/show`); every mutation
  (commit, checkout, switch, restore, reset, merge, rebase, cherry-pick,
  revert, push, pull, fetch, add, rm, mv, stash, clean, branch -d, tag
  v0.1, ...) is denied. Optional argument becomes the reason printed in the
  deny message. With `/git-discipline:install-hooks` active, the `commit-msg` and
  `pre-push` git-native hooks honour the same sentinel, so direct shell
  `git commit` and `git push` are also blocked. Other shell mutations
  (`git reset`, `git checkout`, ...) are not covered CLI-time because
  git-discipline installs no hooks for them; Claude is fully locked at PreToolUse
  time regardless.
- **enable-git** removes `.git/git-discipline-deny`, lifting the lock.

## Hooks

PreToolUse:Bash dispatcher chain (`hooks/dispatch.sh`):

| Guard | Triggers on | Blocks |
|-------|-------------|--------|
| `git-dash-c.sh` | any `git -C <dir>` command | `git -C` |
| `repo-deny.sh` | any `git <mutation>` while `.git/git-discipline-deny` exists | every git command outside the read-only allow-list |
| `commit-format.sh` | `git commit` | editor-mode commits without `-m` |
| `commit-subject.sh` | `git commit -m` | subjects past 50/72, lowercase first, trailing period |
| `commit-body.sh` | `git commit -m` | bodies that fail `validate-body.sh` |
| `commit-body-posttool.sh` | PostToolUse, any commit-graph writer (commit/rebase/cherry-pick/revert/merge/am) | bodies of the commits the command wrote (rebase/cherry-pick/merge/amend paths the string parser cannot see) |
| `commit-trailers.sh` | `git commit -m` | `Co-Authored-By:` with `@anthropic.com` email |
| `push-destination.sh` | `git push` | push whose destination releases, deploys, rewrites or cannot be classified (held until `# push-agreed`), or that the repository's agreement rules out (refused) |
| `push-wip-gate.sh` | `git push` | push range containing a `Slice: wip` commit |
| `push-body-gate.sh` | `git push` | push range containing a body that fails `validate-body.sh` |

Git-native hooks (installed per-repo via `/git-discipline:install-hooks`,
sourced from `skills/commit-discipline/git-hooks/`):

| Hook | Purpose |
|------|---------|
| `pre-commit` | when local `laicluse.requireWorktree=true`, blocks commits in the primary checkout and on the default branch; otherwise it does not constrain authoring location |
| `commit-msg` | runs `validate-body.sh` on every non-Claude commit |
| `prepare-commit-msg` | pre-fills the editor with a layer-classified template |
| `post-commit` | logs `--no-verify` usage to `${LAICLUSE_HOME:-~/.laicluse}/git-discipline/git-discipline-no-verify.log` |
| `post-rewrite` | validates rebase/amend-rewritten bodies; warns and logs (git ignores its exit status) since `commit-msg` does not fire on rebase-picked commits |
| `pre-push` | validates candidate topology and proof, then re-runs the wip and body gates |

Both layers source the same `hooks/lib/validate-body.sh`, so behavior never
diverges between Claude-driven and CLI-driven commits.

## Example commit message

```
Drop invalid meter reading on transaction events

When StartTransaction or StopTransaction messages arrive with a
meter reading that fails domain validation, we previously rejected
the entire event, which masked session starts and stops in analytics.
This change keeps the transaction event but discards just the bad
reading, restoring the visibility we lost.

Tests: spec/services/session_spec.rb#start_event_with_bad_reading,
       spec/services/session_spec.rb#stop_event_with_bad_reading
Slice: handler + service + spec
Red-then-green: spec/services/session_spec.rb:42 # start_event drops invalid meter reading
Verified: red-then-green
Resolves: https://example.org/backlog/issues/1234
```

The `Slice` value can also be one of eight opt-out tokens: `docs-only`,
`config-only`, `migration-only`, `spec-only`, `chore-deps`, `revert`,
`merge`, `wip`.
Opt-out commits drop the `Tests:` requirement; the documentation /
config / chore-deps tokens additionally drop the `Red-then-green:`
requirement.

## Bypass

Escape-hatches, each logged for later auditing:

- `git commit --no-verify` (git-native layer only, logged to
  `${LAICLUSE_HOME:-~/.laicluse}/git-discipline/git-discipline-no-verify.log` via the `post-commit` hook; see the
  `--no-verify` section of `/git-discipline:commit-discipline` for the layer
  split and the operator-only PreToolUse off-switch)
- `GIT_DISCIPLINE_ALLOW_AI_COAUTHOR=1` to allow a single `@anthropic.com`
  `Co-Authored-By:` trailer
- `GIT_DISCIPLINE_ALLOW_CONJUNCTION=1` or the magic-comment `# allow-conjunction:
  <reason>` in the body to permit a subject that contains ` and `, ` + `,
  or ` & ` when the joined form is genuinely atomic
- `GIT_DISCIPLINE_ALLOW_WIP_PUSH=1` or the magic-comment `# allow-wip-push` to
  push a range that contains `Slice: wip` commits (logged to
  `${LAICLUSE_HOME:-~/.laicluse}/git-discipline/git-discipline-wip-pushes.log`). Note: `# allow-wip-push` only
  works when Claude issues the push (the PreToolUse:Bash guard reads the
  bash command string). For terminal-issued `git push`, only
  `GIT_DISCIPLINE_ALLOW_WIP_PUSH=1` works.
- `GIT_DISCIPLINE_TRIVIAL_OK=1` to skip body-validation for a single trivial commit
  (set automatically by the PreToolUse guard for diffs of <= 1 file and
  <= 5 insertions)

See `/git-discipline:commit-discipline` for the full schema, opt-out matrix, and
troubleshooting guide.

## Test suite

```bash
bash packages/git-discipline/test/run-bats              # 500+ BATS cases
bash packages/git-discipline/test/smoke/smoke-test.sh   # 22-case end-to-end smoke
```

The BATS suite is split per concern:

- `validate-body/` covers the body schema rules.
- `block-mode/`, `shadow-mode/`, `wip-gate/`, `template-fill/` cover the
  guard glue per slice.
- `install-hooks/` covers the per-repo install scenarios (empty repo,
  existing hooks, `core.hooksPath`, worktree).
- `parallel-flow/` covers default resolution, worktree rebase, SHA-bound verification, atomic local and remote merges, race loss, and native authoring guards.
- `migrated-hooks/`, `migration/` cover compatibility with previous hook
  behavior.

The smoke suite spins up disposable git repos and exercises the full hook
chain end-to-end.

## Audit

Verify that no body-less commits slipped through.
The script ships inside the plugin at `bin/audit-no-body-commits`; resolve
its path from the active install so it survives plugin updates:

```bash
GIT_DISCIPLINE=$(jq -r '.plugins["git-discipline@laicluse-agent-fieldkit"][0].installPath' \
  ~/.claude/plugins/installed_plugins.json)
python3 "$GIT_DISCIPLINE/bin/audit-no-body-commits"
python3 "$GIT_DISCIPLINE/bin/audit-no-body-commits" --branch main --since 2026-04-01
python3 "$GIT_DISCIPLINE/bin/audit-no-body-commits" --exclude-trivial
```

Lists every commit on the branch with a single-line message (or below the
trivial threshold), useful for checking that the push gate held.
