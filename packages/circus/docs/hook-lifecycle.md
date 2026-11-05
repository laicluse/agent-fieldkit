# Hook updates during parallel Codex work

Measured on 2026-11-05 with Codex CLI 0.166.0 on macOS ARM64. This was the latest stable release returned by GitHub's releases API on that date. The installed binary, rather than a local source checkout, ran every lifecycle experiment below. Source references are pinned to `rust-v0.166.0`.

## Finding

A shared plugin update can break hooks in another process's active turn. The plugin installer activates the new bundle and removes older version directories. A loaded hook still fingerprints its original bundle before executing its command. If that directory has disappeared, verification returns `No such file or directory (os error 2)` before any command-level fallback can run.

The retained wrapper and the host-root adapter reproduce the same failure. Removing retained snapshots simplifies execution but does not fix updates during active turns. The candidate must not be delivered as a structural resolution of that problem.

## Reproducible evidence

`test/native-hook-lifecycle.py` uses disposable configuration and marketplace directories, a real app-server plus a native installer process for explicit updates, two app-server processes sharing configuration for automatic discovery, and a local mock Responses server. No account credentials or model service are used. Approval writes apply only to its test hooks inside the disposable home; they are not a production trust migration.

| Scenario | Retained wrapper | Host-root adapter | User hook with standalone script |
| --- | --- | --- | --- |
| Approved `PreToolUse` rejects a real command | Command prevented | Command prevented | Command prevented |
| Explicit plugin update between turns | New bundle requires approval, then executes | New bundle requires approval, then executes | Not tested separately |
| Restart app-server and resume conversation | Approved installed bundle executes | Approved installed bundle executes | Current standalone script executes |
| Another process installs a newer version during a held model response | Old `Stop` hook fails before wrapper execution | Old `Stop` hook fails before command execution | Updated standalone script executes |
| Another process discovers a newer local source through `plugin/list` during a held response | Discovery installs the new bundle; old hook fails | Discovery installs the new bundle; old hook fails | Updated standalone script executes |

Run the candidate with `python3 packages/circus/test/native-hook-lifecycle.py`. Use `--adapter-template /path/to/older/templates/plugin-adapters` for a repeatable comparison with the retained implementation, `--native` for a bare bundled command, and `--user-runtime` for the independent user-hook experiment. The diagnostic refuses other Codex versions so a changed host contract cannot silently inherit these conclusions.

The user-hook fixture has user registrations and an empty bundled-hook configuration, representing the intended migrated state. It does not test coexistence of user and bundled registrations. It atomically replaces one standalone script outside the plugin cache. It proves the lifecycle and approval distinction, not complete publication of a multi-file runtime. A production publisher would also need complete immutable releases, serialized publication, version selection, and tests for interrupted publication and transitively required files.

## Positive host behavior

Codex refreshes loaded hook sources when constructing the next turn. An update performed between turns therefore selects the new bundle. Changed plugin contents require approval before execution. A fresh app-server can resume the same conversation against the approved installed version. These are supported recovery paths; they do not protect the remaining events of an already active turn.

Local marketplace discovery also schedules native cache reconciliation when source versions change. Consequently, omitting explicit `plugin add` commands is insufficient to defer activation. A safe activation scheme must account for native discovery and startup refresh as well as explicit installs. Integration into a registered source checkout can expose the new version before a separate install command is run.

## Supported architectural choices

Bundled hooks keep Codex responsible for verifying plugin contents. A structural fix must coordinate bundle lifetime with executing hooks or prevent every update route from invalidating active bundles. This adapter does neither. A maintenance window or process isolation is a possible design direction, not a verified implementation in this branch.

User-level hooks are an official registration surface. A complete machine-owned runtime can keep their executable paths independent of the plugin cache; the fixture demonstrates successful active-turn updates and resume. Their trust contract differs: Codex approves the user hook definition, while the publisher controls subsequent executable updates. Plugin bundle content approval does not apply to that standalone script. Migration requires an explicit decision about that responsibility, ordinary approval of new definitions, and removal of duplicate bundled registrations because hook sources are additive.

The existing machine-owned CLI runtimes are separate from the retained hook wrapper. Removing the ineffective wrapper does not justify removing daemons' or stored callbacks' independent runtimes.

## Sources and limits

- [Official plugin packaging](https://developers.openai.com/plugins/build/plugins) specifies bundled hooks and host-provided `PLUGIN_ROOT` and `PLUGIN_DATA`.
- [Official hooks documentation](https://learn.chatgpt.com/docs/hooks) describes user configuration, additive sources and hook approval.
- [Execution-time verification](https://github.com/openai/codex/blob/rust-v0.166.0/codex-rs/hooks/src/engine/command_runner.rs#L228) precedes command execution; [plugin trust](https://github.com/openai/codex/blob/rust-v0.166.0/codex-rs/hooks/src/engine/plugin_trust.rs#L28) fingerprints the loaded root.
- [Native installation](https://github.com/openai/codex/blob/rust-v0.166.0/codex-rs/core-plugins/src/store.rs#L648) removes old version directories. [Cache reconciliation](https://github.com/openai/codex/blob/rust-v0.166.0/codex-rs/core-plugins/src/manager.rs#L3111) includes local source version changes.
- [Upstream refresh change](https://github.com/openai/codex/pull/42990) positively specifies successive-turn refresh, including upgrade and rollback. Its test is not an active-turn retention guarantee.
- [Hook discovery](https://github.com/openai/codex/blob/rust-v0.166.0/codex-rs/hooks/src/engine/discovery.rs#L844) creates content verification for plugin handlers; ordinary user handlers have no plugin root.

These experiments do not establish native Windows behavior, same-version replacement safety, approval UI behavior, or race-free publication of a real multi-file runtime. The reported screenshot's symptom is reproduced; no persisted event identified its particular failed hook, so the exact hook identity remains unproven.
