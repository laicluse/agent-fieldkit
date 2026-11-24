# circus

The Circus is one source of truth for the system prompts of multiple coding
agents. Change the source once, then build the configured agent-specific
targets, such as Claude Code, OpenAI Codex, or future agents supported on the
current machine.

`circus` is le Carre's nickname for MI6 in *Tinker Tailor Soldier Spy*: a
central service briefing field agents from one source.

This plugin ships the **generator** (`bin/circus`). **Personal data** lives outside the plugin in `~/.laicluse/circus/` (override with `CIRCUS_ROOT`), so distributed code contains no user-specific doctrine or host paths.

## Installation

```bash
claude plugins install circus@laicluse-agent-fieldkit
codex plugin add circus@laicluse-agent-fieldkit
```

In a Claude Code session, version 2.1.275 or later, one line installs it straight from the marketplace repository:

```
/plugin install circus --marketplace laicluse/agent-fieldkit
```

Circus supports Claude Code and Codex from the same package source. Restart an
existing Codex session after installation; Claude Code can reload the installed
plugin with `/reload-plugins` and `/reload-skills`.

## Three Levels

**User level (`circus build`).** Source is `~/.laicluse/circus/`: `shared/*.md`
(shared doctrine), `specific/<agent>.md` (per-agent overlay), and `targets`
(`name=path`). It generates every active target listed there, for example
`~/.claude/CLAUDE.md` and `~/.codex/AGENTS.md`. Target lines may add
`supported=false` to keep an agent known but inactive, or `supported=auto`
with `detect=<command>` to skip it unless that command exists. This is one-way,
with a `<!-- GENERATED -->` banner. A handwritten target is never overwritten
silently; it is staged as `<target>.generated` for review and can be activated
with `--force`.

The build step exists because Codex does not support file imports: shared text
must be physically present in the target file, and symlinks leave no room for
per-agent content.

### One shared prompt, agent-specific additions

Every generated prompt starts with the same shared doctrine, then adds only the instructions for that agent:

```text
shared/*.md + specific/claude.md -> ~/.claude/CLAUDE.md
shared/*.md + specific/codex.md -> ~/.codex/AGENTS.md
```

The shared files keep the agents aligned; each `specific/<agent>.md` file adds agent-specific behavior without replacing that common baseline. The source and generated prompts remain local to the user's machine and are not distributed with the Circus plugin.

**Project level (`circus sync`).** Keeps a repo's `CIRCUS.md` (visible committed
ground truth), `CLAUDE.md`, and `AGENTS.md` identical. It is bidirectional:
edit any of the three, and `circus sync` folds that edit into the other two
using the last committed `CIRCUS.md` as the ancestor. On a real conflict
(`CLAUDE.md` and `AGENTS.md` changed differently), the running agent merges;
circus itself does not.

**Project level (`circus project`).** Derives a Codex stack from a repo that is authored for Claude only. The Claude files are the originals: each plugin-less skill under `.claude/skills/` becomes `.agents/skills/<skill>/` with strict Agent Skills frontmatter, and a `CLAUDE.md` whose Codex view differs from the existing `AGENTS.md` gets an `AGENTS.override.md` beside it. Every generated file carries a banner naming its original, and that banner decides what a rebuild may rewrite or remove. Skills that mention Claude Code facilities for waiting, resuming or session state are skipped and reported. `<!-- circus:only claude -->` blocks, `.circus/codex.md` and `.circus/skills` carry the differences per agent. Circus leaves ignore rules alone, so `.gitignore` decides whether collaborators see the output.

**Plugin level (`circus plugins`).** Applies the public `how-plugins-work` sync model to local marketplace repos. `SKILL.md` is shared source when behavior is agent-agnostic. `SKILL.claude.md` and `SKILL.codex.md` are agent-specific sources; they may exist as a pair for parity-by-variant, or singly when a multi-agent plugin has partial skill coverage. Claude manifests remain source; Codex manifests and `.agents/plugins/marketplace.json` are generated adapters. When suffix sources are present, circus materializes the runtime `SKILL.md` only for the agents that have source coverage. If Codex rejects a Claude-only frontmatter field, circus materializes a sanitized generated package under `.agents/plugins/generated/<plugin>/`. If Codex needs hooks, use `hooks/hooks.codex.json`; circus materializes it as runtime `hooks/hooks.json` in that generated package and keeps Claude-only hook metadata out of Codex's strict hook schema. Generated Codex hook commands execute bundled scripts from the host-provided `PLUGIN_ROOT`, with quoted paths. A missing or non-executable entry still exits 2 for PreToolUse; other events report a warning. Codex owns plugin installation, trust, cache cleanup and hook refresh; the generated adapter does not retain bundles or select sibling versions. Hook-bearing generated manifests carry a `+codex.hooks.3` adapter revision. In Codex 0.166.0, both explicit installation and discovery of changed local source versions can replace the shared cache during active work. Integration of a version bump into a registered source can therefore activate it before a separate install command; use independent user-hook publication when uninterrupted hooks are required. In Codex CLI 0.166.0, an external update during a turn removes the loaded bundle and its remaining hook fails with `os error 2`. The following turn selects the new bundle, whose changed contents require approval. In that reproduced case, a retained runtime does not prevent failure: Codex checks the original bundle before running the hook command. Claude hooks continue to follow Claude Code's native lifecycle. Circus owns the executable adapter logic; generated manifests and runtime packages remain output.

### Plugin listing copy

`interface.codex.json` at a plugin's package root can supply a distinct `shortDescription` subtitle. The package manifest's `description` supplies the longer task summary. Both remain author-owned sources; `.codex-plugin/plugin.json` and `.agents/plugins/` remain generated output. Existing packages without this file keep their current fallback behavior.

```json
{"shortDescription": "Inspect connected devices"}
```

Use one nonempty line, at most 240 characters; public directory submission has a stricter 30-character subtitle limit. This UI copy does not change skill selection or invocation policy.

## Usage

```
circus build [--force] [name]   generate user targets from shared + specific
circus sync [path]              sync project CIRCUS.md/CLAUDE.md/AGENTS.md
circus project build [repo]     derive .agents/skills and AGENTS.override.md from the Claude originals
circus project check [repo]     drift check for the derived project stack
circus project diff [repo]      show what a project build would change
circus check                    drift report (exit 1 on drift)
circus diff                     show what a build would change
circus plugins build [repo]     generate Codex plugin adapters from Claude metadata
circus plugins check [repo]     drift check for generated plugin adapters
circus plugins diff [repo]      show adapter diff without writing
circus plugins versions {--check|--write|--bootstrap|--staged} [repo]  check or update marketplace plugin versions
circus list                     root, doctrine, specific, mapping
circus edit                     open the source data in $EDITOR
```

## Add an Agent

1. Add `name=~/path` to `~/.laicluse/circus/targets`.
2. Add `~/.laicluse/circus/specific/name.md` with per-agent instructions.
3. `circus build`.

Optional targets can stay in the file without being built:

```
claude=~/.claude/CLAUDE.md
codex=~/.codex/AGENTS.md
opencode=~/.config/opencode/AGENTS.md supported=false
future=~/.future-agent/AGENTS.md supported=auto detect=future-agent
```

`supported=auto` uses the target name as the detector when `detect=` is
omitted. `circus build`, `circus check`, and `circus diff` skip inactive
targets; `circus list` shows why they were skipped.

## Native hook lifecycle probe

Run `python3 packages/circus/test/native-hook-lifecycle.py` to exercise Codex CLI 0.166.0 with a disposable `CODEX_HOME`, a local test marketplace and a local mock Responses server. It checks real PreToolUse denial, approved between-turn updates, restart and resume, and the active-turn failures caused by both explicit installation and automatic local source discovery from another process. `--adapter-template` compares an older adapter; `--native` tests a bare bundled command; `--user-runtime` tests a standalone script registered as a user hook. It uses no account credentials or model service and cleans up its temporary installation. Approval writes affect only disposable test hooks. The probe refuses other CLI versions and does not test approval UI or same-version replacement.

The native lifecycle probe is a diagnostic, not an implementation of safe updates during active turns. The source report `packages/circus/docs/hook-lifecycle.md` records the reproducible comparison, positive supported behavior, source references, trust differences and delivery limitations.


## Independent Codex hooks

`circus plugins hooks sync` publishes complete immutable copies of selected installed bundles into a private machine runtime. Stable user-hook commands execute those releases independently of native plugin cache cleanup. Publication is serialized and atomic; a failed copy keeps the previous release active. A running hook finishes from its resolved release while later calls can select a complete newer release.

The publisher preserves matchers, timeouts, environment, input, working directory and unrelated user hooks. Dispatcher setup failures block PreToolUse execution; original hook exit status is preserved. It records its bundled-hook masks separately from pre-existing disabled choices and resumes interrupted reviewed activation idempotently. Stable callbacks become inactive when their plugin or declaration is withdrawn, without requiring approval to stop execution. Approving reviewed registrations and disabling their bundled counterparts happens in one native configuration batch. Hook definitions change only through a reviewed activation; periodic publication never approves newly discovered definitions or adds unselected plugins.

This route assigns executable-update control to the publisher. Native approval covers the stable user-hook definition; it does not fingerprint later independent runtime updates. Only explicitly selected installed plugins participate. The current provisioning targets macOS and uses the stable system Python interpreter.

From a clean source checkout, provision with `ansible/managed-hooks.yml`, supplying `hook_runtime_plugins` as the explicit list of existing plugin IDs. Set `hook_runtime_approve_reviewed=true` only after reviewing the exact registrations as part of authorized installation. The playbook installs the publisher and a background job that reconciles those selected runtimes every minute. The job leaves new definitions pending review, updates matching reviewed bindings and stops disabled plugins. Changed definitions keep their previous approved implementation until review; pure removals stop immediately. All corresponding bundled slots remain disabled, including newly added slots. Existing unrelated user configuration is preserved.

For immediate publication after a selected plugin update, run `circus plugins hooks sync --plugin <plugin@marketplace>` with the same selected plugin set. Existing live hosts must reload their configuration once for the initial migration; spawning a new helper does not refresh another app-server or an embedded TUI. The native lifecycle test's `--managed-runtime` scenario verifies migration during an active turn, native explicit and automatic updates, actual tool denial, exactly one event execution, and resume.
