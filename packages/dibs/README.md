# dibs

A single-occupancy lock for a git worktree or standalone working directory. Two
coding agents, often cross-vendor (a Claude and a Codex), can start working in
the same repository at the same time and overwrite each other. dibs lets one
agent take exclusive occupancy before mutation and makes the next mutating
agent step aside. Any tool or agent can take the lock and any other can observe
it, regardless of vendor or platform.

It is deliberately not a git lock: it does not touch the index and still locks
standalone non-git directories. When a requested path lives inside a git
worktree, dibs locks that worktree root so two subdirectories in the same
checkout cannot be occupied independently. `bonsai` creates worktrees and
consumes dibs to claim the directory it hands out; the lock logic lives in
exactly one place.

## Installation

```bash
claude plugins install dibs@laicluse-agent-fieldkit
codex plugin add dibs@laicluse-agent-fieldkit
```

## CLI

```
dibs claim       <dir> [--pid <n>] [--agent <name>] [--session <id>] [--owner <id>] [--description <text>] [--max-age-hours <n>] [--json]
dibs release     <dir> [--pid <n>] [--nonce <hex>] [--json]
dibs release-all [--pid <n>] [--session <id>] [--owner <id> --agent <name>] [--json]
dibs check       <dir> [--max-age-hours <n>] [--json]
dibs exclude     <dir> [--json]
dibs include     <dir> [--json]
dibs excludes    [--json]
```

The directory-keyed verbs (`claim`, `release`, `check`) require the directory to
exist. If the path is inside a git worktree, dibs walks upward to the nearest
`.git` marker and keys the lock by that worktree root's realpath. Outside git,
the requested directory's realpath remains the key. A missing path is therefore
a clear error rather than a silently divergent key. `release-all` is the
exception: it operates on the lock store directly, reading each lock's recorded
realpath, so it still frees a worktree that has since been pruned.

- **claim** takes exclusive occupancy of the resolved lock target: the nearest
  git worktree root when one exists, otherwise the requested directory realpath.
  Exits 0 on a fresh claim, on an idempotent re-claim by the same holder
  (`held-by-self`), or on taking over a stale lock whose holder pid is dead
  (`took-over-stale`). Exits non-zero and reports the holder when a live holder
  exists. A refused claim also suggests creating a separate git worktree on a
  new branch (for example with `bonsai:bonsai`, or plain `git worktree` if you
  do not have it) and claiming that worktree path.
- **release** deletes the lock only if you are the holder. Releasing a lock held
  by another is refused; releasing an unheld directory is a no-op.
- **release-all** releases every lock whose holder identifies as the caller's
  session in one sweep (same host, matching any of `--pid`, `--session`, or
  `--owner` with `--agent`), across all directories. It takes no `<dir>` and
  requires at least one selector so it can never blindly clear the whole store.
  A session that edits files in several git roots holds several locks; this is
  how SessionEnd and the `undibs` skill free all of them at once. Locks belonging
  to a different live agent are never touched.
- **check** reports `free`, or the holder with its liveness and staleness, or
  `excluded` when the directory is on the exclude list.
- **exclude** never locks `<dir>` again; **include** is its inverse and starts
  locking it again; **excludes** lists the built-in defaults plus the configured
  entries. See *Excludes* below.

`release` is also the final cleanup step when a coding agent has completed its work and hands control back for genuinely new instructions. A green test suite, clean worktree, or commit alone is not a release condition: the current task may still continue. Nothing releases on the agent's behalf between claim and session end, so the agent decides when it is done with a directory and says so; `SessionEnd` and pid-liveness remain the fallbacks.

`--pid` is the holder pid whose liveness defines the lock; default is the
calling process's parent pid. Record the long-lived agent or session process,
not the ephemeral `dibs` invocation.

`--owner` is a stable owner key for the human/tool surface that survives a
process or thread resume. A later claim by the same `agent` and `owner` rewrites
the lock to the new pid/host instead of self-locking. The occupancy hook sets it
from `DIBS_OWNER`, then for Codex from `CMUX_TAB_ID`, `CMUX_WORKSPACE_ID`,
`CODEX_THREAD_ID`, or finally the hook session id.

`--description` stores a short human work description in the lock record. Use a compact phrase of a few words, for example `stale dibs lock cleanup` or `finish plugin install`. dibs compacts whitespace, turns separators such as `-`, `_`, and `/` into spaces, caps the field at 80 characters, and shows it in `check`, refused `claim` output, and occupancy hook denials as `work: <text>`. Use this for quick inspection of old locks: when the described work is visibly complete and the holder is stale, the next session can clear the leftover lock with more confidence. The CLI also reads `DIBS_DESCRIPTION`; the occupancy hook passes it through when set and refuses to invent one from a branch or another host-specific label. `bonsai` supplies the branch name as words when it hands out a worktree.

## How it works

A lock is a file written with an atomic exclusive create (`open(O_CREAT|O_EXCL)`,
the node `wx` flag) at
`${LAICLUSE_HOME:-$HOME/.laicluse}/locks/<sha256-of-realpath>.lock`. The
realpath is the resolved occupancy root: a git worktree root when the requested
directory is inside one, otherwise the requested directory itself. The record is
JSON: realpath, holder pid, agent, session, owner, description, hostname, nonce,
acquired-at.

To acquire, dibs tries the atomic create. On collision it reads the record and
checks liveness with `process.kill(pid, 0)` on the same host. A dead holder
(or a foreign-host lock past the optional age cap) is broken and taken over; a
live holder is respected and reported. Release deletes the file only for the
holder.

This is the portable, dependency-free primitive. `flock(1)` is not shipped on
macOS, the `flock(2)` syscall needs a native binding and a session-lived holder
process, and both are host-only. Atomic exclusive create is present everywhere
node runs (macOS, Linux, Windows), gives the same mutual exclusion with zero
dependencies, and self-heals through pid-liveness.

## Scope and non-goals

- **Single machine.** Atomic-create semantics and pid-liveness are host-local.
  Directories shared over NFS or another network filesystem are out of scope
  for v1; cross-machine arbitration is a lease-broker problem, not this lock's.
- **pid recycling.** A recycled pid can read as a live holder. The acquired-at
  timestamp and `--max-age-hours` cap bound the residual risk; v1 accepts it
  rather than probing process start-time natively. When set, `--max-age-hours`
  deliberately overrides liveness: a lock older than the cap is broken even if
  its pid still reads alive, which is the recycling mitigation. Left unset (the
  default), pid-liveness is authoritative and a live holder is never broken. The
  recorded `nonce` identifies a specific claim for logs and observability and is
  not consulted for liveness; `release --nonce <hex>` optionally binds a release
  to one specific claim so a recycled pid cannot release a lock it did not take.
- **Same-user liveness.** `process.kill(pid, 0)` reports a process owned by
  another user or living in another namespace as alive (`EPERM`), so dibs never
  breaks a lock it cannot positively prove dead; such a lock clears only through
  the `--max-age-hours` cap. Within one user on one machine, the agent case,
  liveness is exact.
- **Occupancy, not git.** dibs prevents concurrent occupancy. It uses git
  worktree boundaries only to pick a sane default scope; it is not a git lock
  and does not replace git's own `index.lock`.

## Enforcement hooks

The lock only helps if it is acquired before mutation. dibs ships
`hooks/occupancy.sh`, a vendor-neutral hook that enforces single occupancy for
mutating file edits, not only the worktrees `bonsai` hands out. It is registered
for both agents (`hooks/hooks.json` for Claude, `hooks/hooks.codex.json` for
Codex, materialized into the generated Codex adapter) and shells out to this
plugin's own CLI, so there is no second lock path.

- **SessionStart** does not claim the working directory. A read-only question in
  a directory another live agent holds stays quiet and does not occupy the
  directory.
- **PreToolUse** claims the directory before mutating file edits (`Edit` /
  `Write` / `MultiEdit` / `apply_patch`) and conservative shell mutations
  (`Bash`) such as `cp`, `mv`, `rm`, `touch`, mutating `git` subcommands,
  package installs, and shell redirection. Read-only shell commands stay quiet.
  Bash targets are resolved from shell structure and command semantics: heredoc and message bodies are ignored, redirects gate their output, Git mutations gate their `-C` / `--git-dir` context, copy-like commands distinguish sources from destinations, and `~` / environment-backed paths are expanded without evaluating the command. Relative targets use the tool call's own workdir. When Codex omits that workdir, an existing claim lets normal target analysis use the conversation directory as its fallback basis. Without that claim, Dibs refuses ambiguous relative or implicit mutations and never claims the conversation directory silently; explicit absolute targets remain available. Codex shows only `Dibs lock required for changes.` because hook context is operator-visible; the Dibs skill supplies the agent recovery procedure. It hard-denies (exit 2) when a *different*
  live session holds the target, reporting the holder and how to recover. The
  recovery text points the blocked agent at a separate git worktree on a new
  branch, so the safe next move is visible at the denial point.
  The agent's own session is recognised by the lock's stable owner id first and
  the hook session id second, so a drifted worker pid or resumed Codex thread
  never self-locks the agent out. A legacy ownerless Codex resume is reclaimed
  at the first write. A free directory, a self-healed dead holder, and any
  non-refusal dibs result all pass (fail-open).
- **SessionEnd** (Claude only) sweeps every directory the session locked, with `release-all` keyed by the session's holder pid plus the available session or owner identity. Codex also retains pid-liveness self-heal and owner-based reclaim for interrupted sessions that never emitted a SessionEnd.

Dibs deliberately registers no `Stop` hook. An earlier version released on every completed turn, deciding "completed" by reading the assistant's closing message for a trailing `?`, `？` or `🚧`. Sessions that open a closing line with a marker rather than ending on one never matched, so each turn swept every lock the session held and the directory read as free to the next agent. Turn boundaries are not work boundaries, and closing prose is not a protocol. A lock now lasts until the agent releases it, the session ends, or the holding process is gone.

Repos that should only be mutated through linked worktrees can opt in locally:

```bash
git config laicluse.requireWorktree true
```

When that config is true, the occupancy hook denies mutating the primary
checkout and still allows linked worktrees for the same repository. This is
local git config by design: dibs stays a general lock by default, and only repos
that explicitly ask for worktree-only mutation get the extra guard.

If the operator explicitly asks an agent to work without a worktree, or a linked worktree would break path-dependent behavior such as a content vault or locally referenced symlinks, disable only the worktree requirement and keep the occupancy lock:

```bash
git -C "<repo>" config laicluse.requireWorktree false
dibs claim "<repo>" --description "<what you are doing>"
```

Opt out of enforcement for a session with `DIBS_OCCUPANCY=off`. `bonsai`'s
claim-at-handout is unaffected and complementary.

## Excludes

Some directories should never take an occupancy lock: the agent-config homes,
where two sessions each editing their own runtime config must not steer each
other aside and the git-native commit hook is the backstop. dibs keeps a
per-machine exclude list. `claim` and `check` on an excluded directory (or any
path inside it) return state `excluded` and write no lock, so the occupancy hook
passes the edit through untouched. Exclusion lives in the CLI, not the hook, so
there is a single decision point.

The list is the union of built-in defaults and a plain-text config file at
`${LAICLUSE_HOME:-$HOME/.laicluse}/dibs/excludes` (one path per line, `#`
comments and blank lines ignored, a leading `~` expands to `$HOME`). Every
install ships with `/tmp` (transient scratch) and the agent-config homes
(`~/.claude`, `~/.codex`, `~/.config/opencode`) excluded by default; those cannot
be included back. Manage the rest with the imperative pair `exclude`/`include`:

```bash
dibs excludes            # list built-in defaults and configured entries
dibs exclude ~/project   # never lock this directory again
dibs include ~/project   # lock it again (the inverse of exclude)
```

Matching is by resolved realpath: an excluded git worktree root also excludes
every file inside it, the same scope `claim` would otherwise lock.

## Library

`bin/dibs-lib.mjs` exports `claim`, `release`, `releaseAll`, `check`, and
`formatHolder` as pure node ES modules with no third-party imports. Consumers in the same
marketplace import it directly so there is a single lock implementation and no
parallel path:

```js
import { claim } from '../../dibs/bin/dibs-lib.mjs';

const result = claim({ dir, pid: process.ppid, agent: 'my-tool' });
if (!result.ok) console.warn(`held by ${result.holder.agent}`);
```

An embedder that hands out a directory on behalf of a long-lived caller (as
`bonsai` does) records that caller's pid, not its own short-lived process.
`bonsai` reads `DIBS_HOLDER_PID`, `DIBS_AGENT`, and `DIBS_SESSION` to label the
holder, `DIBS_OWNER` to preserve identity across resumes, `DIBS_DESCRIPTION` to
override the recorded work description, and `DIBS_LIB` to point at an alternate
lib path. The CLI honours `DIBS_BIN` for a fixed binary path.
