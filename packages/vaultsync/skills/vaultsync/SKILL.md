---
name: vaultsync
description: >-
  Install and operate vaultsync for the current Git checkout: a local daemon that debounces Git-visible vault changes into commits, verifies them, and syncs with upstream when one exists.
user-invocable: true
argument-hint: "[install|managed|status|pause|resume|now|doctor] [path/options]"
---

# Vaultsync

Use this when the operator asks to install or operate `$vaultsync`, especially for Markdown vault repositories such as note vaults or local knowledge stores. Vaultsync is a whole-checkout sync tool: the target is the nearest Git worktree root for the requested CWD, not a subdirectory. It follows the checkout's current branch and never creates branches or remotes.

## Command

Run the plugin CLI from this package:

```bash
vaultsync <command> [args]
```

If the command is not on `PATH`, locate this plugin's `bin/vaultsync` in the installed plugin source/cache and run it with Node:

```bash
node /path/to/vaultsync/bin/vaultsync <command> [args]
```

## Install

Install from the directory the operator means to sync, or pass an explicit path:

```bash
vaultsync install [path] --llm-command '<command that reads JSON stdin and writes JSON stdout>' [--pre-sync '<preparation command>'] [--verify '<lint command>']
```

Before installing, vaultsync prints and stores the requested CWD, resolved Git root, current branch, and upstream when one exists. Installation must not require a remote or upstream: a local-only repository still gets debounced auto-commit cycles. Installation must fail when `dibs` is unavailable or when the LLM conflict resolver probe fails. `dibs` is resolved dynamically at runtime from `DIBS_BIN`, the local plugin cache, `PATH`, and only then legacy custom registration paths; do not pin versioned plugin-cache paths in registrations. The LLM command is required because unresolved conflicts are serious sync failures; commit-message generation may fall back to a built-in message, but conflict resolution may not.

Use `--pre-sync` for a synchronous command that refreshes tracked generated files before Vaultsync publishes. Vaultsync first checkpoints dirty source content, integrates remote changes, then runs the command under Dibs before verification and push. It reruns the command after verifier repairs. Any non-zero exit blocks publication as a `pre-sync` failure while preserving the local source checkpoint for recovery. The command does not run on an unchanged daemon poll; `vaultsync now` forces a cycle and therefore runs it.

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

For verifier failures, the task is `repair_verifier` and the response is:

```json
{ "repairs": [{ "path": "relative/path.md", "content": "full replacement content", "reason": "short reason" }] }
```

Vaultsync only accepts repairs for files it included in the request. Verifier-reported files are included first, followed by current sync paths as context, with fixed limits on repair rounds, file count, and file size so a vault-wide lint backlog is repaired in bounded batches.

## Operations

- `vaultsync status [path]` shows the canonical `vaultsync.status.v1` state: branch/upstream relation, pauses, the last successful sync, uncommitted and unpushed work, and a safely redacted causal failure chain with recovery guidance when available. Other tools consume `--json` instead of reading registration files or daemon logs.
- `vaultsync managed [path]` reports whether the path resolves to a vaultsync-managed checkout. Other tools should use this CLI contract instead of reading vaultsync registration files.
- `vaultsync pause [path]` pauses with an automatic resume deadline; default is 120 minutes. Use `--minutes <n>` or `--until <time>` for a different deadline.
- `vaultsync resume [path]` clears a pause.
- `vaultsync now [path]` runs one immediate cycle without bypassing safety gates.
- `vaultsync daemon` runs the long-lived loop. The install command writes a user-level LaunchAgent on macOS.
- `vaultsync doctor [path] --llm-command '<command>'` runs preflight checks without registering the checkout.

During a mutating cycle, vaultsync claims `dibs` for the target worktree root, rejects the current machine's home directory in added Git content and outgoing commits, commits Git-visible local changes after the debounce window, runs the optional verification command, asks the configured LLM to repair bounded verifier failures, commits those repairs, and releases its dibs claim. When the current branch has an upstream, the same cycle also fetches, pulls with rebase, resolves conflicts through the configured LLM command, verifies again, and pushes the current branch. Without an upstream, fetch/rebase/push are skipped and the repo remains a local auto-commit vault until an upstream is configured. When a pause expires while another dibs holder is still active, vaultsync extends the pause by 60 minutes and repeats that rule until the lock clears. Pure remote polling fetches do not claim dibs unless local checkout state must change. Repository-specific content policy, including PII checks in prose, belongs in the configured verifier.

## Editing a managed vault: no git theater

If a checkout is vaultsync-managed (confirm once with `vaultsync managed [path]`), an agent that edits notes there does NOT own git. The daemon owns committing, running the configured verifier, rebasing, and pushing. Your entire job is: write the files, then release your own `dibs` claim on the vault (for example `dibs release <vault> --pid <your-agent-pid>`). That release is the signal the daemon waits for; it commits on its next cycle.

Do NOT, after writing to a managed vault:

- poll `git log` or `git status` waiting for the commit to appear,
- tail or read the daemon logs to confirm it is working,
- run `git add`/`git commit`/`git push` by hand.

The debounce window is intentional (commonly ~300s): a commit that has not appeared "yet" is the daemon working as designed, not a failure. Manual git in a managed vault fights the daemon's own commit, verify, and conflict-resolution cycle. Write, release dibs, move on. Only reach for `vaultsync status` or `vaultsync now` if the operator reports the sync is actually broken.
