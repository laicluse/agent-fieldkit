---
name: dibs
description: >-
  Claim, check, or release a vendor-neutral directory lock before mutating a repo another agent might touch.
---

# dibs

Calling dibs on a directory: a small, vendor-neutral, cross-platform lock so
only one coding agent mutates a protected git worktree or standalone working directory at a time. Explicitly excluded directories allow concurrent authoring without a lock; Markdown vaults can use that policy independently of production-code checkouts. A Claude and a Codex contend for the same lock through the same on-disk
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

- **claim** takes exclusive occupancy of the nearest git worktree root when the directory lives inside git, otherwise the directory itself. It exits 0 when it claims a free target, re-claims one you already hold (`held-by-self`), reclaims one with the same stable owner (`reclaimed-by-owner`), or takes over a stale lock whose holder is dead (`took-over-stale`). It exits non-zero and names the holder (`refused: held by <agent> (pid <pid>) since <acquired-at>`) when a live holder exists. When the holder recorded a description, refusal and `check` output include it as `work: <text>`. On any live-holder refusal, before switching worktrees or closing the turn, report the holder, the exact claim description, lock time, and latest observable activity to the operator. If the description is generic or absent, say that the work's purpose is unknown; do not substitute an inferred task. Run `check` for dirty-file activity; if the worktree is clean, report that explicitly and check the latest commit time instead. Distinguish the age of the lock from the age of the work, and state whether the evidence indicates active work or an idle checkout. A refusal means the current checkout is not your working tree: create a separate git worktree on a new branch (prefer `bonsai:bonsai`, or plain `git worktree` when bonsai is unavailable), then claim and work in that path. Do not copy the repository to a loose non-git directory as a substitute; that is only a spike and must not be presented as integrated work. Removing a linked worktree and deleting its branch needs only that worktree's claim; the shared `.git` metadata is not the primary checkout, so a held primary checkout never blocks that cleanup.
- **release** deletes the lock only if you are the holder; on the same host, PID, exact session, or stable owner plus agent can identify that holder. A retained Codex shell reads its session from `CODEX_THREAD_ID`. Releasing a lock held by someone else is refused and exits non-zero; releasing an unheld directory is a no-op.
- **release-all** releases every lock whose holder identifies as this session in one sweep, across all directories. Every supplied selector narrows the match: `--pid`, `--session`, and `--owner`+`--agent` must all match the same holder when combined. It takes no `<dir>` and needs at least one selector. A session holds more than one lock when it edits files in several git roots, so this is how the host's session-end and the `undibs` skill free all of them at once; locks held by a *different* live agent are never touched.
- **check** prints `free` or the holder plus its liveness, staleness, and Git worktree activity for the same resolved target that `claim` would use, or `excluded` when the directory is on the exclude list.
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
return state `excluded` and write no lock, so the occupancy hook lets the edit through without a second lock path. `excluded` is a successful policy result, not a failed claim. Workflows must respect it: do not remove an exclusion, create a substitute lock, or ask for temporary locking merely because their instructions mention a claim. Same-file conflicts remain the writers' responsibility; reread a file before replacing it and reconcile concurrent changes. Matching is by resolved realpath: excluding a
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

Before each new claim, describe the intended work in that directory with a short, concrete phrase drawn from the current request, such as `fix Dibs lock reporting`. The description is a snapshot of intent at claim time; later changes in scope do not make that snapshot wrong. Do not use an agent identity, session label, or generic activity as the description. Pass it with `--description`; a non-interactive runner may set `DIBS_DESCRIPTION` for one run, never as a session-wide default. The CLI requires a nonempty description, normalizes whitespace and separators, and caps it at 80 characters. Re-claiming a lock already held by the same process retains its original description. `bonsai` supplies the branch name for a worktree claim.

## Who calls dibs

The lock only helps if it is acquired before mutation, so the reliable
acquisition points are:

- **Pre-mutation hook.** A coding agent claims the directory at its first
  mutating file edit (`Edit`/`Write`/`MultiEdit`/`apply_patch`) or a `Bash`
  command it detects as writing, not when the session starts. Relative write targets resolve from the tool call's own workdir. When Codex omits that workdir, an existing claim or explicit directory exclusion lets normal target analysis use the conversation directory as its fallback basis. Without either, Dibs refuses ambiguous relative or implicit mutations and never claims the conversation directory silently; explicit absolute targets remain available. Occupancy only
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
  Repos that require linked worktrees can set local `codingAgent.git.branchPolicy=worktree` (legacy `laicluse.requireWorktree=true` is also recognized); the hook then denies mutating the primary checkout while allowing linked worktrees. When the operator explicitly asks to work without a worktree, or a linked worktree would break path-dependent behavior such as a content vault or locally referenced symlinks, change only the requirement that conflicts with that authorized workflow, record its prior value and restore temporary overrides afterwards. For a legacy-only requirement, `git -C "<repo>" config laicluse.requireWorktree false` is sufficient; do not also change branch policy. Claim the checkout, and continue there. Dibs occupancy remains active. Opt occupancy off for a whole session with `DIBS_OCCUPANCY=off`.
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

Branch policy owns the authoring line; Dibs only enforces occupancy and the worktree location requirement. Feature-versus-trunk commits need git-discipline or the repository's own Git hooks. Dibs does not require git-discipline or Bonsai to be installed.

Bootstrap a worktree-only repository with `git commit --allow-empty`, record its initial branch with repository-local `init.defaultBranch`, then create its feature worktree outside the primary checkout (or use Bonsai). A plain-Git destination inside `worktrees/` requires an existing ignore rule. Completing an existing merge or aborting a conflicted merge/rebase may claim the primary checkout even in worktree mode. These exceptions cover only commit and merge/rebase-abort commands without other parsed writes; occupancy still blocks a different live holder. Resolve ordinary file changes in the authoring worktree.

A non-forced Git worktree-add targeting a nonexistent checkout in the primary repository's own ignored `worktrees/` area changes shared Git administration rather than authoring in its source checkout. It may run while the source is occupied; claim the new checkout before authoring there. An existing destination and other file writes in the command still follow normal occupancy checks.
