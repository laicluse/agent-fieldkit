---
name: dibs
user-invocable: true
description: >-
  Claim, check, or release a vendor-neutral directory lock before mutating a repo another agent might touch.
---

# dibs

Calling dibs on a directory: a small, vendor-neutral, cross-platform lock so
only one coding agent mutates a git worktree or standalone working directory at
a time. A Claude and a Codex contend for the same lock through the same on-disk
artifact, so neither needs to know about the other's hooks.

The lock is a file created with an atomic exclusive create
(`open(O_CREAT|O_EXCL)`, the node `wx` flag) at a deterministic path keyed by
the resolved occupancy root realpath:
`${LAICLUSE_HOME:-$HOME/.laicluse}/locks/<sha256-of-realpath>.lock`. When the
target directory is inside a git worktree, the occupancy root is the nearest
ancestor with a `.git` marker; outside git, it is the target directory itself.
The record holds that realpath, holder pid, agent, session id, stable owner id,
short work description, hostname, a nonce, and an acquired-at timestamp. Liveness is pid-based
(`process.kill(pid, 0)` on the same host), not a heartbeat: a lock whose holder
process is gone is taken over by the next claimer, while a live holder is
refused. No external binary, no `flock`, no native dependency.

## Resolve the bin (cross-agent)

The CLI lives in this plugin's `bin/`. Resolve the plugin root, then call it:

```bash
resolve_dibs_root() {
  if [ -n "${DIBS_BIN:-}" ]; then dirname "$(dirname "$DIBS_BIN")"; return 0; fi
  if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; then printf '%s\n' "$CLAUDE_PLUGIN_ROOT"; return 0; fi
  if command -v codex >/dev/null 2>&1; then
    codex plugin list | awk '$1 == "dibs@laicluse-agent-fieldkit" { print $NF; found=1; exit } END { exit found ? 0 : 1 }'
    return $?
  fi
  return 1
}
ROOT="$(resolve_dibs_root)" || { echo "dibs plugin root not found" >&2; exit 1; }
DIBS="${DIBS_BIN:-$ROOT/bin/dibs}"
```

## Use the lock

```bash
node "$DIBS" claim       <dir> [--pid <n>] [--agent <name>] [--session <id>] [--owner <id>] [--description <text>] [--max-age-hours <n>] [--json]
node "$DIBS" release     <dir> [--pid <n>] [--session <id>] [--owner <id> --agent <name>] [--json]
node "$DIBS" release-all [--pid <n>] [--session <id>] [--owner <id> --agent <name>] [--json]
node "$DIBS" check       <dir> [--max-age-hours <n>] [--json]
node "$DIBS" exclude     <dir> [--json]   # never lock <dir>
node "$DIBS" include     <dir> [--json]   # the inverse: lock <dir> again
node "$DIBS" excludes    [--json]         # list defaults + configured
```

- **claim** takes exclusive occupancy of the nearest git worktree root when the
  directory lives inside git, otherwise the directory itself. It exits 0 when it
  claims a free target, re-claims one you already hold (`held-by-self`),
  reclaims one with the same stable owner (`reclaimed-by-owner`), or takes over
  a stale lock whose holder is dead (`took-over-stale`). It exits non-zero and
  names the holder (`refused: held by <agent> (pid <pid>) since <acquired-at>`)
  when a live holder exists. When the holder recorded a description, refusal
  and `check` output include it as `work: <text>`, so a blocked session can
  inspect whether an old stale lock's work has already been completed. A
  refusal means the current checkout is not your working tree: create a separate
  git worktree on a new branch (prefer `bonsai:bonsai`, or plain `git worktree`
  when bonsai is unavailable), then claim and work in that path. Do not copy the
  repository to a loose non-git directory as a substitute; that is only a spike
  and must not be presented as integrated work.
- **release** deletes the lock only if you are the holder; on the same host, PID, exact session, or stable owner plus agent can identify that holder. A retained Codex shell reads its session from `CODEX_THREAD_ID`. Releasing a lock held by someone else is refused and exits non-zero; releasing an unheld directory is a no-op.
- **release-all** releases every lock whose holder identifies as this session in one sweep, across all directories. Every supplied selector narrows the match: `--pid`, `--session`, and `--owner`+`--agent` must all match the same holder when combined. It takes no `<dir>` and needs at least one selector. A session holds more than one lock when it edits files in several git roots, so this is how the host's session-end and the `undibs` skill free all of them at once; locks held by a *different* live agent are never touched.
- **check** prints `free` or the holder plus its liveness and staleness for the
  same resolved target that `claim` would use, or `excluded` when the directory
  is on the exclude list.
- **exclude / include** are an imperative pair, mirroring **claim / release**:
  `exclude <dir>` adds a directory to the per-machine never-lock list, `include
  <dir>` is the inverse and drops it again. `excludes` prints the built-in
  defaults plus the configured entries. When the operator asks to stop locking a
  directory ("doe geen dibs op ~/foo"), run `exclude` on it rather than disabling
  enforcement wholesale.

The exclude list is the union of built-in defaults (`/tmp` plus the agent-config
homes `~/.claude`, `~/.codex`, `~/.config/opencode`, always excluded and not
removable) and a plain-text file at `${LAICLUSE_HOME:-$HOME/.laicluse}/dibs/excludes` (one
path per line, `#` comments and blank lines ignored, leading `~` expands to
`$HOME`). `claim` and `check` on an excluded directory or any path inside it
return state `excluded` and write no lock, so the occupancy hook lets the edit
through without a second lock path. Matching is by resolved realpath: excluding a
git worktree root excludes every file inside it.

`release` is also the final cleanup step when a coding agent has completed its work and hands control back for genuinely new instructions. Do not release merely because the current task is committed or tests are green: the work may still continue. Nothing releases a lock on your behalf at the end of a turn, so say so with `undibs` when you are done with a directory. `SessionEnd`, pid-liveness, and owner reclaim remain the fallbacks for interrupted sessions.

`--pid` is the pid that must stay alive for the lock to count as live. Record
the long-lived holder (the agent or session process), not the ephemeral process
that runs `dibs`. It defaults to the calling process's parent pid. `--json`
prints the full result record for machine consumers.

`--owner` is a stable identity for resumed sessions. The occupancy hook sets it
from `DIBS_OWNER`, then for Codex from `CMUX_TAB_ID`, `CMUX_WORKSPACE_ID`,
`CODEX_THREAD_ID`, or the hook session id, so a Codex resume can reclaim its own
old lock even when pid, host, or thread id changed.

`--description` is the short human work description stored in the lock, and it
is **required**: `claim` refuses to create a lock without one, so no lock is
ever anonymous and a blocked agent can always tell the operator which session a
lock belongs to. The claiming agent composes it itself, the way it would name a
branch: a compact phrase of a few words, such as `dibs lock descriptions`. The
CLI compacts whitespace, turns separators such as `-`, `_`, and `/` into
spaces, and caps it at 80 characters. Re-claiming a lock you already hold
(`held-by-self`) keeps the existing description and needs no new one. `bonsai`
supplies the branch name as words for the worktree it hands out, and that beats
any environment default.

### Name the change, not the activity

The description exists for one reader: whoever finds this lock still standing
weeks later and has to decide whether the work finished or died halfway. Write
the phrase that answers them. `revert the stop-release trigger` and `finish the
plugin install` answer it. `session work`, `coding`, and `editing files` do
not, because the activity is the same in every directory a coding agent ever
locks, so naming it discriminates nothing.

`DIBS_DESCRIPTION` is the channel for a non-interactive runner that knows its
task before it starts, such as a scheduled mission: set it per run, to that
run's task. Pinning one value for every session is worse than leaving it
unset, because it satisfies the requirement while making every lock read alike
and it suppresses the prompt that would otherwise ask the agent for something
specific.

## Who calls dibs

The lock only helps if it is acquired before mutation, so the reliable
acquisition points are:

- **Pre-mutation hook.** A coding agent claims the directory at its first
  mutating file edit (`Edit`/`Write`/`MultiEdit`/`apply_patch`) or a `Bash`
  command it detects as writing, not when the session starts. Relative write targets resolve from the tool call's own workdir. When Codex omits that workdir, an existing claim lets normal target analysis use the conversation directory as its fallback basis. Without that claim, Dibs refuses ambiguous relative or implicit mutations and never claims the conversation directory silently; explicit absolute targets remain available. Occupancy only
  gates the write-output: several agents may read, think, and run commands from
  the same directory, and dibs only arbitrates who may write. Because a claim needs a description, an
  agent that writes before administering a dibs is told to run
  `dibs claim <dir> --description "<the change you are making here>"` and
  retry; once it holds the lock, later writes pass as `held-by-self`. That
  refusal is the moment the description gets composed, so the hook never
  invents one from the git branch or any other host label to avoid it. When a *different* live
  session already holds the directory, the write is refused with the holder and
  the worktree recovery suggestion. Treat that suggestion as the recovery path,
  not as advice: use `bonsai:bonsai` or `git worktree`, never a loose filesystem
  copy, before editing.
  Claude and Codex call the same CLI; the on-disk lock is the shared artifact.
  Repos that should only be mutated through linked worktrees can set local git config `laicluse.requireWorktree=true`; the hook then denies mutating the primary checkout while allowing linked worktrees. When the operator explicitly asks to work without a worktree, or a linked worktree would break path-dependent behavior such as a content vault or locally referenced symlinks, disable only that requirement with `git -C "<repo>" config laicluse.requireWorktree false`, claim the checkout, and continue there. Dibs occupancy remains active. Opt occupancy off for a whole session with `DIBS_OCCUPANCY=off`.
- **Directory handout.** `bonsai` claims the lock for a worktree it hands out
  (it consumes this one implementation; there is no second lock anywhere). The
  git-native commit hook in the branch-worktree-discipline order remains the
  backstop for agents without a reliable pre-mutation hook.

## Scope and caveats

- **Single machine.** Atomic-create semantics and pid-liveness are host-local.
  A directory shared over NFS or another network filesystem is out of scope for
  v1; cross-machine arbitration needs a lease broker, not this lock.
- **pid recycling.** A dead holder's pid reused by an unrelated live process can
  read as alive. The acquired-at timestamp and `--max-age-hours` cap bound the
  residual risk; v1 accepts it rather than adding a native process-start probe.
- **Same-user liveness.** A holder owned by another user or namespace reads as
  alive (`EPERM`), so dibs never breaks a lock it cannot prove dead; that lock
  clears only via `--max-age-hours`. Within one user on one machine, the agent
  case, liveness is exact.
- **Occupancy, not git.** This prevents two agents occupying a worktree or
  standalone directory; it uses git boundaries only to choose the default scope
  and does not replace git's own `index.lock`.
