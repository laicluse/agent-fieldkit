---
name: undibs
description: >-
  Release the dibs occupancy locks this session holds. By default it sweeps
  every directory the session locked in one go; pass a path to release just one.
  Triggers on /undibs, "release the lock", "unlock this worktree", "give up
  dibs", or "free this directory".
---

# undibs

The deliberate counterpart to calling dibs: hand the directories back so the next agent can claim them. Use it when the current work is complete and control returns for genuinely new instructions, at the end of a long session, when a stale lock is in the way, or when the operator asks to free a worktree by hand. This is the only mid-session release there is; a lock otherwise lasts until `SessionEnd` or until pid-liveness sees the holding process is gone.

A single session can hold more than one lock: the occupancy hook claims a lock
per git-root for every directory it edits, so a session that touched several
repos or worktrees holds several locks. By default `undibs` sweeps **all** of
them at once, keyed by this session's holder pid (plus owner/session when known),
so nothing is left locked behind you. It only ever removes locks that identify as
this session's; a lock held by a *different* live agent is never touched.

## Resolve the bin (cross-agent)

The CLI lives in the dibs plugin's `bin/`. Resolve the plugin root, then call it:

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

## Release every lock this session holds (default)

Find the session's long-lived holder pid with the shared walk the occupancy hook
uses to *claim* (so claim and release agree on the same pid), then sweep:

```bash
. "$ROOT/bin/holder-pid.sh"
PID="$(dibs_holder_pid)"
node "$DIBS" release-all --pid "$PID" --json
```

`release-all` enumerates the lock store and removes every lock whose recorded holder identifies as this session. Every supplied selector narrows the same holder match; the shared holder PID is therefore the exact default sweep boundary and must not be broadened with owner or session selectors. It reads each lock's own realpath, so it still frees a worktree that has since been pruned. Report the JSON `count` and the `released[].realpath` list back to the operator.

## Release a single directory

When the operator names one specific worktree, release just that path:

```bash
DIR="${1:-$PWD}"
node "$DIBS" release "$DIR" --json
```

Report the outcome from the JSON `state` (and `ok`):

- `released` (`ok: true`): the lock was yours and is now gone; the directory is
  free.
- `not-held` (`ok: true`): nothing to release; the directory was already free.
- `held-by-other` (`ok: false`): a *different* live agent still holds it. Do not
  force it; name the holder (the `holder` record carries the agent, pid, and
  acquired-at) so the operator can decide.

When the holder is a dead process, prefer letting the next `claim` self-heal it
through pid-liveness rather than releasing on the dead holder's behalf; reach for
an explicit release only when a live process you control holds the lock or the
operator asks to clear it.

## Release boundary

A green test suite, a clean worktree, or a finished commit alone is not a release condition. Release when the work itself is complete and the agent is handing control back for genuinely new instructions. Keep Dibs while asking a question whose answer is needed to continue the same work. Judging that boundary is the agent's own call and no hook makes it: a lock held one turn too long costs one `undibs`, while a lock released one turn too early costs a collision that surfaces only after another agent has written.
