# vaultsync

vaultsync turns a Markdown vault or note repository into a local-first sync backend. It watches a whole Git checkout, debounces Git-visible changes into commits, runs an optional verifier, and keeps the current branch reconciled with its upstream when one exists. It is built for prose-heavy repositories such as Markdown vaults, local knowledge stores, and other free-form text collections where small edits should become durable without every application reinventing sync.

Remote sync is optional. A repository without a remote or upstream still gets the core behavior: debounced auto-commits plus verification. When an upstream is configured later, vaultsync starts fetching, rebasing, resolving conflicts through the configured LLM command, and pushing the current branch. It follows the branch already checked out and never creates branches or remotes.

## Installation

```bash
claude plugins install vaultsync@laicluse-agent-fieldkit
codex plugin add vaultsync@laicluse-agent-fieldkit
```

The plugin ships a `vaultsync` CLI. If the command is not on `PATH`, run the installed plugin's `bin/vaultsync` with Node.

## Capabilities

- Registers a Git checkout as a vaultsync target.
- Reports whether a checkout is vaultsync-managed through `vaultsync managed`,
  so other tools can ask the CLI instead of reading vaultsync storage directly.
- Stores runtime state under `${LAICLUSE_HOME:-$HOME/.laicluse}/vaultsync`.
- Installs a user-level macOS LaunchAgent for the daemon loop.
- Debounces dirty Git state before committing.
- Refuses machine-local home paths in new commits and outgoing history before shared content can be pushed.
- Generates substantive English commit messages through the configured LLM command, with deterministic git-discipline-safe trailers.
- Preserves a failed commit-message provider as the primary diagnosis when the fallback commit also fails, including safely redacted stderr and the secondary commit failure.
- Publishes one `vaultsync.status.v1` status contract with sync phase, recovery guidance, last successful sync, and pending staged, unstaged, untracked, and unpushed work.
- Runs an optional verifier before a cycle is considered clean.
- Asks the configured LLM command to repair bounded verifier failures for included text files.
- Claims `dibs` during mutating cycles so another agent does not edit the same checkout concurrently.
- When an upstream exists, fetches, rebases, resolves conflicts through the LLM command, and pushes the current branch.
- When no upstream exists, skips remote operations and remains a local auto-commit vault.

## Commands

```bash
vaultsync install [path] --llm-command '<json command>' [--pre-sync '<command>'] [--verify '<command>']
vaultsync managed [path] [--json]
vaultsync status [path] [--json]
vaultsync now [path] [--json]
vaultsync pause [path] [--minutes <n> | --until <time>] [--reason <text>]
vaultsync resume [path]
vaultsync doctor [path] --llm-command '<json command>'
vaultsync daemon
```

`install` resolves the requested path to the nearest Git worktree root and records that whole checkout. The current branch is the sync branch. The branch's upstream is recorded when present; missing upstream is allowed and means local-only mode.

`--pre-sync` registers a synchronous preparation command such as a tracked-file generator. Vaultsync runs it under the checkout's Dibs lock after integrating remote changes and before verification and publication, then reruns it after verifier repairs. A non-zero exit blocks push as a `pre-sync` failure while preserving any local source checkpoint for recovery. On unchanged daemon polls the command does not run; `vaultsync now` always runs it.

`managed` reports whether the requested path resolves to a vaultsync-managed
checkout. It is the public integration point for tools that need to avoid
operating inside vaultsync roots; they must call the CLI instead of depending on
vaultsync's registration storage layout.

`status --json` emits the canonical `vaultsync.status.v1` contract. Consumers should use this output instead of registration files or daemon logs. Each vault status identifies whether sync is `synced`, `pending`, `degraded`, `blocked`, `paused`, `disabled`, or `unmanaged`; a failure keeps its primary phase, safely redacted message and detail, optional recovery action, and ordered secondary failures. Pending state separates uncommitted paths from unpushed commits, and `lastSuccessfulSyncAt` is not overwritten by a failed cycle.

vaultsync resolves `dibs` dynamically at runtime. `DIBS_BIN` remains an explicit override, otherwise vaultsync checks the installed plugin cache, `PATH`, and only then any legacy custom path in an older registration. New registrations do not pin versioned plugin-cache paths, so plugin updates do not leave vaultsync pointing at a removed `dibs` binary.

`pause` always has an automatic resume deadline. The default is 120 minutes. If a pause expires while another live `dibs` holder still owns the checkout, vaultsync extends the pause by 60 minutes and repeats that rule until the lock clears.

The built-in shareability gate rejects the current machine's home directory in added Git content, generated commit messages, and outgoing commits. Keep executable locations and other machine-specific values in environment overrides or user-level configuration. The optional verifier remains responsible for repository-specific content policy; vaultsync does not claim to remove PII from arbitrary prose.

## LLM Command Contract

The configured LLM command reads one JSON object from stdin and writes one JSON object to stdout. The protocol field is `vaultsync.llm.v1`.

For commit messages:

```json
{ "message": "Substantive English commit message body" }
```

When the provider command exits non-zero, vaultsync preserves its safely redacted stderr. A wrapper may supply a provider-specific message and recovery action as one stderr line without coupling vaultsync to that provider:

```json
{ "protocol": "vaultsync.llm.error.v1", "message": "OAuth session expired.", "recovery": "Re-authenticate the configured provider and retry sync." }
```

Plain stderr remains supported. Vaultsync recognizes a generic expired OAuth session and recommends re-authenticating the configured provider; it does not name or hard-code a provider.

vaultsync keeps the LLM-generated subject and body but canonicalizes the required trailers:

```text
Tests: n/a (docs-only)
Slice: docs-only
Red-then-green: n/a (no executable behaviour changed)
Visual: <changed HTML viewer, when present>
Vaultsync-Reason: <cycle reason>
```

For conflicts:

```json
{ "resolved": "full file content without conflict markers" }
```

Remote/upstream content is authoritative. If local-only material cannot be merged cleanly, the resolver may preserve it in a sidecar file named like `name.conflict-extra-info.md`, but the original path must keep the remote truth intact.

For verifier failures:

```json
{ "repairs": [{ "path": "relative/path.md", "content": "full replacement content", "reason": "short reason" }] }
```

vaultsync only accepts repairs for files included in the request. Verifier-reported files are included first, followed by current sync paths as context, with fixed limits on repair rounds, file count, and file size.

## Verification

Run the package tests from the source checkout:

```bash
npm test --prefix packages/vaultsync
```

The tests cover local-only installs without upstream, remote-backed sync cycles, managed sync hooks that explicitly permit `--no-verify`, verifier failure recording, and verifier repair loops.
