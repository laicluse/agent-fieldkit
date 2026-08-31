---
name: vaultsync
description: >-
  Install and operate vaultsync for the current Git checkout: a local daemon that debounces Git-visible vault changes into commits, verifies them, and syncs with upstream when one exists.
---

# Vaultsync

Use this when the operator asks to install or operate `$vaultsync`, especially for Markdown vault repositories such as note vaults or local knowledge stores. Vaultsync is a whole-checkout sync tool: the target is the nearest Git worktree root for the requested CWD, not a subdirectory. It follows the checkout's current branch and never creates branches or remotes.

## Command

Run the stable machine CLI:

```bash
vaultsync <command> [args]
```

Plugin startup publishes the newest complete runtime under `${LAICLUSE_HOME:-$HOME/.laicluse}/vaultsync/runtime` and installs the launcher at `${VAULTSYNC_BIN_DIR:-$HOME/.local/bin}/vaultsync`. If the command is not found, add that bin directory to `PATH`; do not call or persist a versioned plugin-cache path.

```bash
export PATH="$HOME/.local/bin:$PATH"
vaultsync <command> [args]
```

## Install

Install from the directory the operator means to sync, or pass an explicit path:

```bash
vaultsync install [path] --llm-command '<command that reads JSON stdin and writes JSON stdout>' [--pre-sync '<preparation command>'] [--verify '<lint command>']
```

Before installing, vaultsync prints and stores the requested CWD, resolved Git root, current branch, and upstream when one exists. Installation must not require a remote or upstream: a local-only repository still gets debounced auto-commit cycles. Installation must fail when `dibs` is unavailable or when the LLM conflict resolver probe fails. `dibs` is resolved dynamically at runtime from `DIBS_BIN`, the local plugin cache, `PATH`, and only then legacy custom registration paths; do not pin versioned plugin-cache paths in registrations. The LLM command is required because unresolved conflicts are serious sync failures; commit-message generation may fall back to a built-in message, but conflict resolution may not.

Use `--pre-sync` for a synchronous command that refreshes tracked generated files before Vaultsync publishes. Vaultsync first checkpoints dirty source content, integrates remote changes, then runs the command under Dibs before verification and push. It reruns the command after verifier repairs. Any non-zero exit blocks publication as a `pre-sync` failure while preserving the local source checkpoint for recovery. The command does not run on an unchanged daemon poll; `vaultsync now` forces a cycle and therefore runs it.

Existing `--verify` installs remain supported as an unchanged legacy validator. For independent tool-owned validation, manage a named entry instead:

```bash
vaultsync validator add <name> [path] --command '<command>' --repair none
vaultsync validator add <name> [path] --command '<command>' --repair automatic --repair-authority diagnostics
vaultsync validator list [path] [--json]
vaultsync validator remove <name> [path] [--json]
```

Adding or removing a named validator changes only that entry and is idempotent, so concurrent installers can own separate names on the same physical checkout. `none` grants no repair authority. `automatic` requires either `diagnostics`, which limits writes to regular files named by that validator's own absolute or checkout-relative diagnostics, or `diagnostics-and-changed`, which also permits current sync paths. Symlinks and checkout escapes are never repair candidates. Vaultsync runs every configured validator even after failures and reports the outcomes separately. It does not register the checkout with the validator tool itself.

## LLM Command Contract

The configured command receives one JSON object on stdin and must write one JSON object to stdout. The protocol field is `vaultsync.llm.v1`.

For commit messages, the task is `commit_message` and the response is:

```json
{ "message": "Substantive English commit message with body and Slice trailer" }
```

If the command exits non-zero, vaultsync keeps safely redacted stderr as the primary failure even when its fallback commit also fails. A wrapper may emit one stderr JSON line using `vaultsync.llm.error.v1` with `message` and `recovery`; plain stderr remains supported.

For conflicts, the task is `resolve_conflict` and the response is:

```json
{ "resolved": "file content without conflict markers" }
```

Remote/upstream content is the truth. If the conflict cannot be merged cleanly, the resolver may preserve local-only material in a sidecar file named like `name.conflict-extra-info.md`, but it must still return resolved content for the original path that keeps the remote truth intact.

For validator failures with automatic repair authority, the task is `repair_verifier` and the response is:

```json
{ "repairs": [{ "path": "relative/path.md", "content": "full replacement content", "reason": "short reason" }] }
```

Vaultsync includes the validator name in the request and only accepts repairs for files authorized by that validator's policy and included in that request. Diagnostics from another validator never grant repair authority. Fixed limits on repair rounds, file count, and file size keep vault-wide lint backlogs bounded.

## Operations

- `vaultsync status [path]` shows the canonical `vaultsync.status.v1` state: branch/upstream relation, pauses, the last successful sync, uncommitted and unpushed work, configured validators with their last outcomes, and a safely redacted causal failure chain with recovery guidance when available. Other tools consume `--json` instead of reading registration files or daemon logs.
- `vaultsync managed [path]` reports whether the path resolves to a vaultsync-managed checkout. Other tools should use this CLI contract instead of reading vaultsync registration files.
- `vaultsync pause [path]` pauses with an automatic resume deadline; default is 120 minutes. Use `--minutes <n>` or `--until <time>` for a different deadline.
- `vaultsync resume [path]` clears a pause.
- `vaultsync now [path]` runs one immediate cycle without bypassing safety gates.
- `vaultsync daemon` runs the long-lived loop. The install command writes a user-level LaunchAgent on macOS.
- `vaultsync doctor [path] --llm-command '<command>'` runs preflight checks without registering the checkout.

The LaunchAgent and any per-vault callback command must invoke the stable `vaultsync` launcher. Independent Claude and Codex plugin updates converge on the newest installed runtime; older sessions cannot downgrade it. The daemon holds a machine-level singleton lease, and LaunchAgent reconciliation terminates stale Vaultsync daemon processes from older releases before starting the current runtime. Vaultsync keeps its immutable releases and never cleans coding-agent plugin caches.

During a mutating cycle, vaultsync claims `dibs` for the target worktree root, rejects the current machine's home directory in added Git content and outgoing commits, checkpoints Git-visible local changes after the debounce window, runs every configured validator, applies only validator-authorized repairs, commits those repairs, and releases its dibs claim. Any validator failure blocks push while preserving the checkpoint and the complete set of outcomes. When the current branch has an upstream, the same cycle also fetches, pulls with rebase, resolves conflicts through the configured LLM command, validates again, and pushes the current branch. Before an automatic cycle contacts an SSH remote, vaultsync asks OpenSSH which agent socket applies and proceeds only when that agent advertises identities; local checkpointing and validation continue while remote work waits. `vaultsync now` is explicit operator intent and still attempts the remote immediately. Without an upstream, fetch/rebase/push are skipped and the repo remains a local auto-commit vault until an upstream is configured. When a pause expires while another dibs holder is still active, vaultsync extends the pause by 60 minutes and repeats that rule until the lock clears. Pure remote polling fetches do not claim dibs unless local checkout state must change. Repository-specific content policy, including PII checks in prose, belongs in configured validators.

## Editing a managed vault: no git theater

If a checkout is vaultsync-managed (confirm once with `vaultsync managed [path]`), an agent that edits notes there does NOT own git. The daemon owns committing, running the configured verifier, rebasing, and pushing. Your entire job is: write the files, then release your own `dibs` claim on the vault (for example `dibs release <vault> --pid <your-agent-pid>`). That release is the signal the daemon waits for; it commits on its next cycle.

Do NOT, after writing to a managed vault:

- poll `git log` or `git status` waiting for the commit to appear,
- tail or read the daemon logs to confirm it is working,
- run `git add`/`git commit`/`git push` by hand.

The debounce window is intentional (commonly ~300s): a commit that has not appeared "yet" is the daemon working as designed, not a failure. Manual git in a managed vault fights the daemon's own commit, verify, and conflict-resolution cycle. Write, release dibs, move on. Only reach for `vaultsync status` or `vaultsync now` if the operator reports the sync is actually broken.
