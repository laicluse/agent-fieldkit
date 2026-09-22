---
name: how-plugins-work
user-invocable: true
description: >-
  Build, scaffold, or diagnose Claude/Codex plugins, skills, and marketplaces.
  Read this BEFORE creating a new plugin, marketplace, marketplace.json source,
  skill, or Codex adapter, and when generating adapters with Circus,
  not only when debugging plugin/skill resolution, slash-command misses, Unknown
  command errors, marketplace sync, or agent adapters.
---

<post-update-broadcast>
BEFORE doing the actual work below, run this one-time check only when
`CLAUDE_PLUGIN_ROOT` is set:

```bash
if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; then
  node "${CLAUDE_PLUGIN_ROOT}/bin/check-broadcast"
fi
```

If the command produces output, the how-plugins-work plugin was updated since
the last time you saw the broadcast on this machine. Show the output
verbatim in a markdown block, prefixed with one short sentence
("how-plugins-work was updated; here is what changed."). Then continue with
the rest of this skill.

If the command produces no output, say nothing about updates and proceed.

The helper writes the sentinel only when stdout was non-empty, so a silent
run does not mark the version as seen. Codex currently has no equivalent
post-update broadcast path in this plugin; skip this block silently there.
</post-update-broadcast>

# How Plugins Work

A living document on how plugin and skill names flow through Claude Code, Codex,
and future coding-agent systems. Based on empirical testing in Claude Code 2.1.x
plus local Codex CLI verification.

## The three names

A skill in a marketplace plugin has three independent names:

1. **Plugin name** (`plugin.json` > `name`): determines the namespace.
2. **Skill name** (directory name under `skills/`): determines the identity.
3. **Marketplace name** (marketplace.json > `name` or the `@marketplace` identifier): determines the source.

These three names are completely independent of each other. Claude Code and
Codex combine them in different ways in different places.

## Where each appears in Claude Code (empirically verified)

| Context | What appears | Example |
|---------|--------------|---------|
| `claude plugin list` | `<plugin>@<marketplace>` | `how-plugins-work@example-tools` |
| `claude plugin install` | `<plugin>@<marketplace>` | `claude plugin install how-plugins-work@example-tools` |
| `settings.json` enabledPlugins | `"<plugin>@<marketplace>": true` | `"how-plugins-work@example-tools": true` |
| `installed_plugins.json` key | `"<plugin>@<marketplace>"` | `"how-plugins-work@example-tools": [...]` |
| Plugin cache path | `cache/<marketplace>/<plugin>/<version>/skills/<skill>/` | `cache/example-tools/how-plugins-work/<version>/skills/how-plugins-work/` |
| `skill-budget` SOURCE column | `<plugin>` | `how-plugins-work` |
| `skill-budget` NAME column | `<skill>` | `how-plugins-work` |
| System-reminder skill list | `<plugin>:<skill>` | `how-plugins-work:how-plugins-work` |
| TUI autocomplete | `/<plugin>:<skill>` | `/how-plugins-work:how-plugins-work` |
| Skill tool invocation | `Skill("<plugin>:<skill>")` or bare `Skill("<skill>")` | `Skill("how-plugins-work")` |
| Slash command (bare) | `/<skill>` (if unique) | `/how-plugins-work` |
| Agent tool invocation | `subagent_type: "<plugin>:<name>"` | `subagent_type: "gurus:sonnet-max"` |
| Plugin-shipped agent source | `packages/<plugin>/agents/<name>.md` | `packages/gurus/agents/sonnet-max.md` |

### Observations

**Plugin name appears in five contexts:** plugin list, settings.json, installed_plugins.json, skill-budget SOURCE, and as namespace prefix in system-reminders and autocomplete.

**Skill name appears in three contexts:** skill-budget NAME, as suffix after the colon in system-reminders, and as bare slash command.

**Marketplace name appears in two contexts:** after the `@` sign in plugin list and settings.json. Never in the skill invocation itself.

**The `<plugin>:<skill>` combination** is how the model sees the skill in system-reminders and how it calls the Skill tool. When plugin and skill share the same name, you get `how-plugins-work:how-plugins-work`. The bare shortcut `/how-plugins-work` works when there are no name conflicts.

## Where each appears in Codex

Codex uses the generated `skills/<skill>/SKILL.md` runtime body for each
Codex-compatible skill, but it reads Codex metadata instead of Claude metadata.
Local CLI help verified on 2026-06-09:

| Context | What appears | Example |
|---------|--------------|---------|
| Marketplace add | primary-checkout path or Git source | `codex plugin marketplace add /path/to/primary-checkout` |
| Plugin install | `<plugin>@<marketplace>` | `codex plugin add how-plugins-work@example-tools` |
| Marketplace index | `.agents/plugins/marketplace.json` | `name: example-tools` |
| Plugin source path | `plugins[].source.path` | `./packages/how-plugins-work` |
| Plugin manifest | `.codex-plugin/plugin.json` | generated from `.claude-plugin/plugin.json` |
| Skill body | `skills/<skill>/SKILL.md` | generated Codex-compatible runtime body |
| Skill invocation in CLI/IDE | `$<skill>` mention or `/skills` picker | `$how-plugins-work`, `/skills` |
| Active install facts | `codex plugin list --json` | `pluginId`, `version`, `enabled`, `source.path` |

Important differences from Claude:

- Codex marketplace metadata lives under `.agents/plugins/`, not
  `.claude-plugin/`.
- The Codex plugin manifest is stricter JSON generated into
  `.codex-plugin/plugin.json`.
- Codex frontmatter parsing uses stricter YAML behavior; a `description` with
  YAML-special punctuation must use a folded scalar.
- Generated Codex targets are adapter files. Edit the Claude/source metadata or
  the shared `SKILL.md`, then run `circus plugins build .`.
- Claude-only frontmatter keys such as `user-invocable` stay in the shared
  source for Claude, but Codex receives a generated sanitized copy when needed.
- Codex CLI skill autocomplete lives under `$`, not `/`. Use `$<skill>` or the
  `/skills` picker for explicit skill invocation. Do not expect Claude's
  `/plugin:skill` or bare `/<skill>` skill-command behavior to work in Codex
  CLI; `/` is for built-in commands and deprecated custom prompts such as
  `/prompts:<name>`.
- In the Codex app, plugin and skill invocation also has an `@` surface, and
  enabled skills may appear in the slash command list. Treat that as an app UI
  behavior, not as proof that Codex CLI accepts `/<skill>`.
- `codex plugin list --json` is the authoritative local view for what Codex has installed and enabled right now. Its `source.path` determines the delivery model. When a local marketplace points into the primary checkout, integrating the generated files updates the source used by future sessions; do not reinstall the plugin. A cache-backed or remote source needs a separately approved runtime refresh.

## Multi-agent runtime closeout

A change to a plugin that ships to both Claude Code and Codex needs verified adapters and a safe delivery path for each host. Source completion does not authorize mutation of shared machine runtime state.

1. Build and check generated adapters.
2. Inspect `codex plugin list --json`. When `marketplaceSource.sourceType` is `local` and `source.path` is inside the primary checkout, merge the candidate into that primary checkout with a bumped plugin version. Codex runs a snapshot under `~/.codex/plugins/cache/<alias>/<plugin>/<version>`, so future sessions read the change only after an approved `codex plugin add`.
3. Treat Claude cache updates, first installs, non-local Codex refreshes, enablement changes, removals, and marketplace changes as machine-wide mutations. They require explicit operator approval in the current turn, even when source implementation and integration were requested.
4. After an approved mutation, verify Claude's version and active `installPath` in `~/.claude/plugins/installed_plugins.json`, or Codex's version, enabled state, and active source with `codex plugin list --json`.
5. Compare at least one changed runtime file with its active source. Matching manifest versions alone do not prove the payload arrived.
6. Existing sessions keep the hook and skill set they loaded. Never refresh a shared runtime merely to make the current source task feel complete.

The only adapter exception is a plugin that is intentionally single-agent. Prove that exception from the adapter check and the relevant marketplace catalog instead of inferring it from the agent running the current session. The `test-before-push` skill owns the complete verification and delivery decision.

## Skills CLI versus plugin installs

The `skills` CLI and the native plugin systems solve different problems. The `skills` CLI, for example `npx skills add <repo>`, can install plain `SKILL.md` files for Codex when Codex is selected as the target agent; the install may be project-local, such as under `.agents/skills/`, or user-level through the CLI's global install option. That is the lean path when the workflow is pure instructions and the active agent already has every tool it needs.

A Codex plugin is technically needed only when Codex must receive plugin runtime payload that `skills add` does not install, such as MCP registration, hooks, or bundled helper binaries. Generated/sanitized runtime views and install metadata that travels as one unit can still make a plugin the cleaner product shape, but that is an engineering judgment, not proof that a skill-only route cannot work.

Decision rule: choose `skills add` for instruction-only skills, choose a Codex plugin when the workflow depends on MCP tools or other plugin-owned runtime files, and keep both routes documented when they serve different users. The reference may still have an opinion about the cleaner product shape; say "prefer the plugin route because it keeps generated runtime views and install metadata together" when that is the judgment. Do not relabel that judgment as "technically necessary" unless a platform rule or a local install test proves the `skills` route cannot provide the needed behavior.

## OpenCode: Agent Skills without a marketplace

OpenCode does not consume the Claude or Codex marketplace manifests described above. It discovers Agent Skills from `.opencode/skills/<name>/SKILL.md`, `.claude/skills/<name>/SKILL.md`, and `.agents/skills/<name>/SKILL.md`, both project-local and in the corresponding user-level roots. It exposes each discovered skill's `name` and `description` through its native `skill` tool, and the agent loads the full body on demand with `skill({ name: "<skill>" })`. See the [OpenCode Agent Skills documentation](https://opencode.ai/docs/skills/).

OpenCode recognizes `name` and `description` as required frontmatter plus optional `license`, `compatibility`, and string-to-string `metadata`. Unknown fields are ignored rather than rejected. A shared skill may therefore parse in OpenCode while still carrying another host's metadata, but portable source should not depend on fields or invocation behavior that only one host understands.

The fieldkit's `packages/<plugin>/skills/<skill>/` source layout is not itself an OpenCode discovery path. Supporting OpenCode requires an explicit install or generated adapter that materializes a skill into one of OpenCode's supported roots. `circus plugins build` currently generates Claude and Codex runtime forms only, so this marketplace must not claim OpenCode delivery until that third adapter and a real OpenCode runtime check exist.

## Uniqueness and conflicts

### Within a marketplace

The unique key is `<plugin.json name>@<marketplace>`. The plugin name comes from `plugin.json`, not from the directory name. If two packages have the same `name` in their `plugin.json`, they claim the same key and overwrite each other on install.

Two **different plugins** in the same marketplace may contain a skill with the same name. They are namespaced: `pluginA:review` vs `pluginB:review`. But bare `/review` then becomes ambiguous.

### Across marketplaces

`superpowers@claude-plugins-official` and `superpowers@example-tools` can coexist (different keys). But `Skill("superpowers:brainstorming")` contains no marketplace, so if both have a `brainstorming` skill the resolution is unpredictable. Avoid plugin names that already exist in other installed marketplaces.

## SKILL.md frontmatter

### name

Optional. When present it must match the directory name. If they do not match, documented bugs exist: the model cannot find the skill on invocation (anthropics/claude-code#22063). The directory name is always the source of truth.

### user-invocable

**Always set explicitly.** Although the binary code (below) suggests the default is `true`, in practice skills without explicit `user-invocable: true` do not always appear in autocomplete. Always set the field explicitly: `true` for slash commands, `false` for skills that are model-triggered only.

Binary code from Claude Code 2.1.92 (the default `true` is not reliable for plugins):
```javascript
T = H["user-invocable"] === void 0 ? !0 : G0H(H["user-invocable"])
```

### disable-model-invocation

When `true`: the model cannot auto-activate the skill based on context. The skill is then only reachable via explicit slash command. Useful for skills that should never be auto-triggered (e.g. `/clipboard`, `/saysay`). Reduces the active context budget in `skill-budget`.

**The flag replaces "Use ONLY when..." prose in the description.** A description like `Use ONLY when the operator types /foo. Do not auto-invoke. <what it does>` is two layers of the same intent: the prose tries to talk Claude out of auto-triggering, while the harness already enforces it via `disable-model-invocation: true`. Pick the flag, drop the prose, and let the description describe what the skill does. Every "Use ONLY when..." token costs every session that loads the skill list, forever; the flag costs nothing.

### description

What the model sees in the skill list and uses to decide auto-invocation.
Treat it as routing metadata, not documentation. The primary reader is the
model router; the secondary reader is a human picker or autocomplete UI. Search
engines and GEO are not direct readers of `SKILL.md` frontmatter unless another
system publishes that text onto a web page.

Anthropic's [skill authoring best practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices#writing-effective-descriptions) set the shape: the description says what the skill does and when to use it, in third person, within 1,024 characters. "What it does" is the result the caller gets, not the steps the skill takes to get there. "When to use it" names the situations, requests and key terms that should select the skill. Anthropic's own examples take the form `<result>. Use when <situation>.` and run to about 170 characters.

```yaml
description: Generate descriptive commit messages by analyzing git diffs. Use when the user asks for help writing commit messages or reviewing staged changes.
```

Keep it as short as those two parts allow; every skill description is loaded on every turn. Include one boundary only when it prevents wrong activation. Procedures, edge cases, installation details, internal routing, and long alias lists belong in the body, which loads only after the skill is selected.

Three anti-patterns to avoid:

- **A compressed procedure.** "Inventory X, classify it by content, and remove the approved rows" tells the router how the skill works, not what the caller walks away with or when to reach for it. State the outcome and the situation instead.
- **"Use when the user types /X" prefix.** When the skill has `disable-model-invocation: true`, the slash command is the only way in, so the prefix is redundant. When the skill is model-triggerable, name the situation, not the slash form.
- **Embedding the skill body in the description.** Disambiguation rules, edge cases, and step-by-step procedures belong in the body, not the description.

### Frontmatter must be strict YAML

Claude Code's frontmatter parser is lenient: a plain scalar `description:` that contains `: ` (colon-space), starts with a quote, or holds other YAML-special punctuation still loads, because the parser just grabs the rest of the line. Strict YAML parsers (Ruby's psych, and the Codex `.codex-plugin` toolchain that reads the same SKILL.md) reject it with `mapping values are not allowed in this context`. The two readers then disagree on a file that looked fine in Claude Code.

Keep every frontmatter value valid under a strict parser so the file means the same thing in every consumer. When a `description` contains `: `, a leading quote, or a leading `#` / `|` / `>` / `@`, use a folded block scalar instead of an inline plain scalar:

```yaml
description: >-
  Speech mode: Claude speaks every response aloud via macOS say. /saysay off to exit.
```

`>-` folds the indented lines into one space-joined string and strips the trailing newline, so the parsed value is byte-identical to the intended one-liner, colons and quotes preserved. A plain one-line scalar stays fine when the text carries no YAML-special punctuation; reach for `>-` only when it does. Verify with a strict parser before shipping:

```bash
ruby -ryaml -e 'YAML.safe_load(File.read(ARGV[0]).split(/^---\s*$/)[1])' SKILL.md
```

## Cross-agent skill and plugin sync

Agent Skills are the portable layer. Keep `skills/<skill>/SKILL.md` as the shared source whenever the workflow can mean the same thing across Claude Code, Codex, and other skills-aware clients. Do not copy the skill body into an agent-specific tree just because a second client needs different installation metadata.

When the workflow itself differs per agent, use suffixed sources instead of
runtime branching inside one skill body:

| Source file | Meaning |
|-------------|---------|
| `SKILL.md` | Agent-agnostic source. Use only when the same instructions are valid for every target agent. |
| `SKILL.claude.md` | Claude-specific source. |
| `SKILL.codex.md` | Codex-specific source. |

Both Claude and Codex still require a runtime file named `SKILL.md`; the suffix
is a source convention, not a harness feature. `build` writes each agent's
available suffixed source as that agent's runtime `SKILL.md`, and `check` fails
when a suffixed source has not been materialized or when a stale target remains.
A suffixed source may exist as a pair when both agents support the workflow with
different instructions, or singly when only one agent has the required runtime
capability. A suffixless `SKILL.md` is never a fallback inside an
agent-specific skill; it means the skill is truly multi-agent compatible.

Plugins may also be single-agent at runtime. When a plugin has no Codex skill
source and no explicit Codex runtime payload, the generated Codex marketplace
omits the plugin instead of serving an empty or misleading command surface.

Plugin and marketplace manifests are adapter layers. Claude Code and Codex both load `skills/`, but they do not use the same manifest and marketplace files:

| Layer | Shared source | Claude Code adapter | Codex adapter |
|-------|---------------|---------------------|---------------|
| Skill body | `skills/<skill>/SKILL.md` or suffixed source | generated/loaded as `SKILL.md` | generated/loaded as `SKILL.md` |
| Plugin manifest | package identity and component paths | `.claude-plugin/plugin.json` | `.codex-plugin/plugin.json` |
| Marketplace index | curated plugin list | `.claude-plugin/marketplace.json` | `.agents/plugins/marketplace.json` |
| Runtime cache | none; cache is output | `~/.claude/plugins/cache/...` | `~/.codex/plugins/cache/...` |

Plugin-level runtime payloads follow the same rule. A suffixless/shared source
is valid only when both agents can consume it with the same semantics. When a
payload is runtime-specific, keep the source explicit: `agents/` is the Claude
subagent payload in this marketplace, while a future Codex-specific subagent
payload should live in `agents.codex/` and be materialized into generated
Codex runtime `agents/`.

### Source and target roles

Every duplicated-looking file should have one explicit role:

- **Source.** Hand-edited truth, usually the shared skill body or the primary marketplace manifest.
- **Generated target.** Agent-specific manifest or catalog written from the source by a deterministic builder.
- **Runtime cache.** Install output. Never edit it as source and never use it to prove the repo is current.
- **Forked semantics.** A deliberate divergence because two agents cannot support the same behavior. Name the drift hypothesis so future maintainers know why the fork exists.

If a file is a generated target, the repo should expose the usual three verbs:

```bash
<sync-tool> build
<sync-tool> check
<sync-tool> diff
```

`build` rewrites adapter files from the source, `check` exits non-zero on drift, and `diff` shows the exact generated change. This is the minimum contract that makes metadata duplication acceptable: a reviewer can tell whether the duplicate is another truth or a projection.

### Peer plugin runtime dependencies

When one public plugin calls another plugin's runtime files, treat that as a
packaged dependency boundary, not as a source-tree convenience. The source
checkout, generated Codex root, Claude cache, and Codex cache can all have
different shapes. A path that works under `packages/<plugin>/` is not evidence
that the installed plugin can find its peer.

Hardening rules:

- Keep explicit overrides such as an environment variable for tests or host
  wiring, but do not make regular users provide local paths to connect first-
  party plugins.
- Discover peers from the current runtime artifact, for example from the
  running helper's own file or plugin root, and preserve the public package
  boundary. Do not shell out to `claude`, `codex`, or a private helper at
  runtime just to find a sibling plugin.
- Do not hard-code `~/.claude`, `~/.codex`, a local clone path, a personal
  marketplace alias, or one agent's cache layout into shipped plugin code.
- Add a regression test that copies only shipped runtime files into a fake
  installed marketplace/cache layout and runs from that copied artifact without
  source-checkout paths. The RED result should be a real missed peer
  dependency, such as `module not found` or graceful fallback to "unavailable";
  the GREEN result should prove the user-visible behavior through the peer.
- If the peer is optional, test both the optional fallback and the installed
  peer path. Graceful degradation is not a substitute for proving the normal
  packaged path.

### Generated Codex target payloads

When Codex needs sanitized skills or agent-specific skill sources, the
marketplace should point at `.agents/plugins/generated/<plugin>`. That
directory becomes Codex's plugin root. Any helper that a generated skill
invokes must therefore exist under the generated root too; the source package
under `packages/<plugin>/` is no longer in the runtime path.

Minimum copy rules:

- Copy `bin/` into the generated target when a skill calls plugin helper
  commands.
- Copy top-level runtime data files that copied helpers read. Today that means
  `CHANGELOG.md` for `bin/check-broadcast`; without it the helper is present
  but silent in Codex.
- Do not copy source-package `agents/` into generated Codex targets by default.
  In this marketplace, `agents/` is a Claude runtime payload because Claude
  consumes the source package directly. A generated Codex package should carry
  `agents/` only from an explicit Codex-specific source such as
  `agents.codex/`, materialized as runtime `agents/` by the adapter builder.
- Copy skill-local support files that live under `skills/<skill>/` alongside
  the materialized `SKILL.md`.
- Copy `hooks/lib/` when Codex-facing workflows install git-native hooks or
  otherwise call shared hook libraries. Copy the full hook payload only through
  an explicit Codex hook source: `hooks/hooks.codex.json` is materialized as the
  generated package's runtime `hooks/hooks.json`, alongside the dispatcher,
  guards, and libraries. Do not copy Claude's `hooks/hooks.json` merely because
  the source package has it; a Claude hook manifest in a Codex package is inert
  at best and misleading at worst.
- If the Codex marketplace points directly at a shared plugin root that already
  contains `hooks/hooks.json`, Codex parses that file too. That shared hook
  manifest must use the strict Codex shape: exactly one top-level key,
  `"hooks"`. Claude accepts a top-level `"description"` in hook configs; Codex
  rejects it with `unknown field 'description', expected 'hooks'`. Either keep
  the shared hook manifest strict and use host-neutral commands such as
  `${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT:-}}`, or route Codex through a generated
  package with `hooks/hooks.codex.json`.
- Make `check` compare the full generated file set, not only `SKILL.md` and
  manifest files. A stale generated helper that no longer exists in the source
  is drift.

If a global gitignore ignores dot-directories, the generated marketplace can
look correct on disk while new files stay invisible to Git. Repositories that
track Codex adapter targets should explicitly unignore them:

```gitignore
!.agents/
!.agents/plugins/
!.agents/plugins/**
```

### What belongs in shared SKILL.md

Keep shared skill text in agent-neutral language when possible: "the active agent", "the shell-command tool", "the plugin root", "the installed cache". Use Claude-specific names only when the behavior is genuinely Claude-specific, such as `/reload-plugins`, `Skill("<plugin>:<skill>")`, `CLAUDE_PLUGIN_ROOT`, or Claude hook events.

When a shared skill has a Claude-only block and still wants to be packaged for other clients, prefer one of these shapes:

- A clearly labelled Claude-only section that other clients can ignore.
- A generic instruction with runtime-specific examples underneath.
- Suffixed sources (`SKILL.claude.md`, `SKILL.codex.md`) when the workflow
  semantics differ per agent or only one agent has the required runtime
  capability.
- A generated sanitized adapter view, if a client rejects the frontmatter or body syntax outright.

Do not remove Claude frontmatter or hook guidance merely to satisfy another client. If another client needs stricter metadata, generate the stricter view or manifest beside the Claude source.

### Host-owned capability contracts

Shared skill text should describe capability contracts before concrete runtime
routes. If the workflow needs something like "keep this loop moving," "get an
independent review," "drive a browser," "send a notification," or "persist this
state," write the invariant and the expected outcome, then let the active host
satisfy it with whatever tooling exists there. Claude might use a plugin skill,
an Agent tool, or a cron helper; Codex might use a goal loop, browser tool, or
different delegation surface; a future agent may have another mechanism.

Hard-code another skill, plugin, MCP server, or helper only when that dependency
is itself the public API the workflow is about. Otherwise, name it as a
runtime-specific example under a generic host-owned contract. This keeps
cross-agent skills portable: they share the idea and the evidence requirements,
not one agent's exact implementation path.

### Direction of dependency

`how-plugins-work` defines the generic sync contract; the public Circus plugin implements it. Project-specific tooling may invoke Circus, but neither public plugin may depend on private paths, personal doctrine repositories, or local machine conventions.

## Model selection

A skill **cannot** change the session model. The model the user chose at session start (or via `/model`) runs through all turns, including turns fired by cron. A skill that outputs `/model <name>` as text behaves like a fake user input, is unreliable, and persists after the skill run, corrupting the user session.

**Subagents can.** The `Agent`/`Task` tool accepts a `model` parameter (`haiku`, `sonnet`, `opus`). A subagent runs in a separate conversation context with its own model, returns a result, and does not touch the session model. This is the correct mechanism for:

- Token savings in cron-driven loops (delegate poll work to a Sonnet subagent)
- Parallel independent tasks (multiple agents on different models at the same time)
- Reserving the session model for reasoning while mechanical work runs cheaper

**Rule of thumb:** session model = head, subagent = hand. Give subagents work that requires no interpretation (running commands, reading files and returning them raw, scraping gh). Keep interpretation and decisions on the session model.

**Effort cannot be set per invocation.** The Agent tool only accepts `model` inline, not `effort`. The only route to run a subagent at `effort: max` (or any other level) is via a plugin-shipped or user-level agent definition with the `effort` frontmatter field. See "Plugin-shipped subagents" below.

## Plugin-shipped subagents

In addition to skills, a plugin can also ship subagent definitions under `packages/<plugin>/agents/<name>.md`. This is simultaneously the only way to make a pre-configured `model` + `effort` combination available for runtime spawn, because the Agent tool only accepts `model` inline.

### Frontmatter

Supported: `name`, `description`, `model` (`sonnet`/`opus`/`haiku`), `effort` (`low`/`medium`/`high`/`xhigh`/`max`). Ignored for security reasons when the agent comes from a plugin: `hooks`, `mcpServers`, `permissionMode`. If those fields are needed, copy the agent definition to `~/.claude/agents/` or `.claude/agents/`.

Example (empirically working in a plugin marketplace):

```markdown
---
name: sonnet-max
description: Generic subagent pinned to Sonnet at maximum effort.
model: sonnet
effort: max
---

Execute the invoker's prompt and return the result.
```

### Invocation

Plugin-shipped agents follow the same `<plugin>:<name>` namespace as skills. Call via the `Agent`/`Task` tool with `subagent_type: "<plugin>:<name>"`. For the example agent in `packages/gurus/agents/sonnet-max.md`: `subagent_type: "gurus:sonnet-max"`.

**Bare name does NOT work.** Unlike skills, where `/how-plugins-work` resolves as a bare slash command when unique, the Agent tool always requires the namespaced form for plugin-shipped agents. Empirical confirmation in Claude Code 2.1.92: `subagent_type: "sonnet-max"` fails, `subagent_type: "gurus:sonnet-max"` works.

### Verification without pushing

Do not use `claude agents` as a plugin-shipped-agent listing check. In current
Claude Code CLI builds, `claude agents` manages background agent sessions, and
`claude agents --json` prints active/completed sessions rather than the
plugin-shipped subagent catalog.

Three useful checks, from lightest to heaviest:

1. **`claude plugins validate packages/<plugin>`.** Catches manifest and hook
   schema problems in the local package. It does not prove the agent can spawn.
2. **Live local spawn test via `claude -p --plugin-dir ./packages/<plugin>`.**

   ```bash
   claude -p --plugin-dir ./packages/<plugin> \
     --allow-dangerously-skip-permissions --output-format json \
     "Use the Task tool with subagent_type '<plugin>:<name>'. Ask for the string PING_42."
   ```

   The JSON output contains a `modelUsage` section with the configured model as a separate key (e.g. `claude-sonnet-4-6`). Two models in `modelUsage` (session + subagent) is the strongest evidence that the subagent was truly spawned with the desired model. The `effort` value is not visible in `modelUsage` or elsewhere in the CLI output; for that it rests on a documentation assumption.
3. **Installed-cache live spawn test.** After `claude plugins update
   <plugin>@<marketplace>` or a fresh install, run the same `claude -p` command
   without `--plugin-dir` to verify the installed cache copy.

   **What `claude -p` does and does not test for cron-driven features.** Print mode is one-shot: one prompt, one answer, session over. The cron itself does not fire in `-p` (it lives on an idle interactive REPL), so auto-triggering ticks is ruled out. What `-p` can do well: test per-tick behavior by supplying a pre-constructed state and asking the session to "follow the Instructions for the current Phase as if a tick was fired". For the autonomous rover: write a stub loopfile with the desired Phase and (optionally) an aged timestamp in the Log, then start `claude -p "Read .autonomous/X.md and act on the current Phase as if a cron tick just fired."`. That validates fuse/timeout/backoff logic without waiting for real wallclock. To also confirm cron-firing itself, fall back to a fresh interactive session (`claude` in a new terminal or iTerm2 pane). Claude has shell access and can spawn `-p` itself; do not dictate this to the user when you can run it yourself.

### Local marketplace for persistent install without pushing

Persistent local marketplace sources always use the repository's primary checkout. Never register a linked worktree, even temporarily: marketplace configuration outlives the authoring session, other parallel sessions consume the same path, and worktree cleanup turns every dependent plugin into a broken install. This applies to every locally cloned marketplace, not a named allowlist.

Resolve the primary checkout from Git metadata instead of assuming a directory layout:

```bash
common_dir=$(git rev-parse --path-format=absolute --git-common-dir)
primary_checkout=$(dirname "$common_dir")
test "$(git rev-parse --absolute-git-dir)" = "$common_dir" || printf 'candidate worktree; persistent install waits for integration into %s\n' "$primary_checkout"
```

Claude Code: a directory-backed marketplace still installs cache snapshots. Adding or re-pointing the marketplace and updating a plugin are machine-wide mutations and require explicit operator approval in the current turn.

Codex: a local marketplace registration reads `.agents/plugins/marketplace.json`, follows `plugins[].source.path`, and reports that direct path through `codex plugin list --json`. Codex still runs a snapshot under `~/.codex/plugins/cache/<alias>/<plugin>/<version>`, and `codex plugin list` reports that cached version. Integrating generated changes therefore reaches future sessions only after a version bump and an explicitly approved `codex plugin add`, which is also the first-install command.

Feature-worktree validation remains transient: run source tests, adapter build/check, and host-specific ephemeral checks there. Integrate the candidate into the primary checkout. Never repoint a marketplace or reinstall a plugin to make unintegrated work loadable.

**Gotcha 1: cascade-uninstall on marketplace remove.** `claude plugin marketplace remove <alias>` does not only remove the marketplace configuration; it also uninstalls every plugin that was installed via that alias. Empirically tested in Claude Code 2.1.92: a marketplace with 18 installed plugins crashed to 0 after a single `remove`. Re-adding the marketplace does not automatically restore the plugins; each plugin must be explicitly re-invoked with `claude plugin install <plugin>@<alias>`. For a local dev session where you switch between path-based and remote-based marketplace with the same alias: this means a re-install of every plugin that comes from that alias, not just a config change.

**Reverting to remote: silent overwrite, no cascade.** The symmetric path from path-based back to remote works without `marketplace remove`: `claude plugins marketplace add <owner>/<repo>` overwrites the existing alias's `source.source` field in-place from `directory` to `github`, provided `marketplace.json`'s `name` claims the same alias again. Empirically tested in Claude Code 2.1.119: all 18 installed plugins from that alias remained intact; no cascade-uninstall, no re-install batch needed. The old `path` field stays as residue in the settings.json record, but the active `source.source: github` wins and `claude plugins update` pulls from the remote from that point. Same silent-overwrite mechanism as the gotcha-free overwrite to path-based, just in reverse.

## marketplace.json `source` must be a real subpath

The `plugins[*].source` field in `marketplace.json` passes through two layers, and the difference between them can be misleading (Claude Code 2.1.119, empirical against `epologee/apples`):

- **Schema validation.** `"source": "."` fails with `Invalid input` on `claude plugin marketplace add`. `"source": "./"` succeeds and the marketplace lands in `~/.claude/settings.json` under `extraKnownMarketplaces`. The schema therefore rejects the bare dot but accepts the slash variant.
- **Runtime resolution.** `"./"` survives schema validation but does not resolve. Symptoms:
  - `claude plugin marketplace list` does not show the marketplace.
  - `claude plugin marketplace update <name>` says `Marketplace not found`.
  - `claude plugin install <plugin>@<marketplace>` fails with `Plugin "<plugin>" not found in marketplace`.
  - The settings.json entry remains as an orphan; `enabledPlugins` has `<plugin>@<marketplace>: true` even though nothing ever installed.

**Conclusion.** `source` must be a real subdirectory, not the marketplace root. Working forms in this setup: `"./packages/<plugin>"` or `"./plugins/<plugin>"`. Single-plugin repo where the plugin claims the root: move `.claude-plugin/plugin.json` and `skills/` to e.g. `./packages/<plugin>/` and update `source` accordingly. The marketplace-level `.claude-plugin/marketplace.json` stays at repo root.

**Local-vs-remote is not a factor.** The schema test was only run against a local directory, but both local and remote marketplaces in the active setup already use subpaths. The rule is source-independent.

**Diagnostic signal chain.** When `claude plugin marketplace add` succeeds but `claude plugin marketplace list` does not show the marketplace and install fails with "Plugin not found in marketplace", `source` is the first thing to verify. Schema pass does not imply runtime pass.

## Deprecating and removing a plugin (tombstone)

There is no native "deprecate" or "remove" mechanism for a single plugin. `marketplace.json` has no `deprecated`, `removed`, or tombstone field; the entry schema is `source`, `category`, `tags`, `strict`, `version` plus manifest fields. Deleting a plugin's entry does **not** uninstall it for anyone who already has it.

What deleting the entry actually does (Claude Code 2.x, plus open issues anthropics/claude-code#17061, #37865, #9537, #23839):

- The plugin disappears from the catalog, so fresh installs can no longer find it.
- Existing installs are **orphaned**: `installed_plugins.json` keeps `<plugin>@<marketplace>`, `enabledPlugins` keeps `true`, the cache directory stays, and **its hooks keep firing**. A byte-identical successor installed from another marketplace then double-enforces against the orphan.
- `claude plugins update <plugin>@<marketplace>` afterwards errors with "Plugin not found in marketplace".
- The only clean per-plugin removal is the user running `claude plugins uninstall <plugin>@<marketplace>`. `claude plugins marketplace remove <marketplace>` cascades, uninstalling *every* plugin from that marketplace at once, so it is wrong for a one-at-a-time migration.

Because the platform never auto-cleans on entry removal, a clean migration needs a deprecation protocol you build. The **tombstone** is that protocol: instead of hard-deleting, hollow the plugin to a husk that stops behaving and announces its own removal.

Tombstone shape (verified against the earlier git-discipline migration):

1. **Strip everything that runs.** Delete `skills/`, all guard/library hooks, `bin/`, and tests. Removing the hooks is what kills any conflict with the successor (the orphaned-hook double-enforcement above). If the source marketplace pairs per-plugin update-broadcast machinery (a changelog plus a helper script) with a sync gate, drop both together so the gate stays quiet.
2. **Keep one proactive signal.** A skill cannot announce a deprecation, because a skill only surfaces when invoked. The single mechanism that fires unprompted when the plugin loads is a `SessionStart` hook. Ship `hooks/hooks.json` with one `SessionStart` (matcher `startup|resume`) command that prints the uninstall and install lines to stdout, which Claude Code injects as context.
3. **Rewrite the descriptions.** `plugin.json` and the `marketplace.json` entry both lead with `DEPRECATED` and the exact `claude plugins uninstall` / install commands, so the husk reads as a tombstone in `/plugin` and in plugin list.
4. **Keep the marketplace entry alive.** This is the point: the entry must stay so that the next `claude plugins update <plugin>@<marketplace>` actually delivers the stripped husk (hooks gone) and the SessionStart notice. Delete the entry and the consumer is back to a silent orphan.

Why this works at all: hook loading is **registration-driven**, not catalog-driven. At session start the agent loads hooks from every plugin registered in `installed_plugins.json` and enabled in `enabledPlugins`; the marketplace catalog is only consulted at install/update time. Deleting an entry changes neither registration, so the old hooks keep loading forever. The tombstone cleans up by **replacement, not removal**: `claude plugins update` rewrites the registration's `installPath` to the husk snapshot, and the next session load finds no guard hooks there to load. Verified empirically: after updating the earlier git-discipline migration tombstone, the active cache held four files and zero guards. Two delivery conditions remain: the update must actually arrive (a user who never updates and has no auto-update keeps the full old version, hooks included; no marketplace mechanism can reach them), and already-running sessions keep the old hook set until a restart or `/reload-plugins`.

Division of labour with a marketplace-level announcement: a marketplace-wide changelog or news channel carries the migration story (pull-based, read on demand), while the per-plugin tombstone is the proactive push that nags a still-installed copy until the user removes it.

Precondition before hollowing out a **public** plugin: the successor marketplace must already be public and carry actionable migration instructions for external users. Hollowing a plugin that points users at a marketplace they cannot add strands them. Verify with `gh repo view <owner>/<successor> --json visibility` and confirm the successor plugin is registered in its `marketplace.json` before tombstoning.

Scope: tombstones exist for consumers you cannot see. A single-user, local-only marketplace has exactly one consumer, so a plain entry-plus-package delete combined with a local `claude plugins uninstall` is already the complete removal; building a husk there is ceremony without an audience.

## Reading env vars from settings.json

The `env` section of `~/.claude/settings.json` exports variables to child bash processes that Claude Code spawns. Those values are **not visible in Claude's conversation context**. A skill that wants to condition behavior on an env var must query the value via bash. Claude does not "know" the value on its own and will guess.

Two anti-patterns that often occur together:

1. **Implicit check.** SKILL.md writes "if `VAR` is not set, do X" without a prescribed bash step that queries the value. Claude must then realize a check is needed and usually guesses "unset".
2. **Passive code fence.** SKILL.md puts the action bash in a ```bash block without an imperative label. Claude may read it as an example and skip execution.

**Pattern:** one explicit "RUN THIS FIRST" step that combines bash check and action and prints a marker output that the next step branches on. No condition line elsewhere in the markdown that leans on implicit knowledge about an env value.

```bash
# First action of every invocation:
state="${VAR:-unset}"
[ "$state" = "on" ] && do_the_thing &
echo "state=$state"
```

Then a decision table driven by `state`, not by markdown prose:

| `state` | Next action |
|---------|-------------|
| `on` | Continue normally; no reveal |
| `off` | Continue normally; no reveal |
| `unset` | Append one-time reveal-PS at end |

**First-run reveal via the env var itself.** An elegant mute without a state file on disk: `on`/`off` both suppress the hint, absent shows it once. Only robust if step 1 hard-reads the value; otherwise the elegance breaks and the hint is shown randomly.

Empirically observed in whywhy v1.0.10 (2026-04-22): the reveal-PS appeared for a user who had had `WHYWHY_JINGLE=on` in settings for 3 days, while the jingle did not play. Both symptoms of Claude not having read the env value: the reveal condition guessed "unset", and the afplay fence was not executed.

**Session-lifetime footnote.** Env updates in `settings.json` are only seen by new Claude Code sessions. A session that started before a settings commit keeps the old values until restart. When diagnosing strange behavior ("var is set to on but skill behaves as unset"), compare the session start time with the commit that added the var before blaming the skill itself.

## Symlinks and cross-platform

Marketplace repos should be symlink-free. Every skill lives in one place under `packages/<plugin>/skills/<skill>/`, without shared source via symlinks. Pre-commit and CI reject symlinks in the repo. The reason is Windows: Git for Windows has `core.symlinks=false` as default, so on clone symlinks are converted to text files containing the target path, and runtime resolution in Claude Code fails. A symlink-free layout works on macOS, Linux, and Windows without extra consumer setup.

Anthropic docs do mention that Claude Code preserves symlinks in the install cache ([Plugins reference, Plugin caching and file resolution](https://code.claude.com/docs/en/plugins-reference)), but that requires the symlinks to survive the clone in the first place. The three alternatives explored in an earlier experiment (`git-subdir`, `rsync -aL` materialization via release branch, `CLAUDE_CODE_PLUGIN_SEED_DIR`) all turned out to require more consumer setup than a flat, symlink-free layout. The repo is aligned accordingly.

## Hooks

Hooks (SessionStart, PreToolUse, PostToolUse, Stop, and the other lifecycle events) do NOT live in `plugin.json`. A `hooks` key in `plugin.json` is rejected by `claude plugins validate` with `hooks: Invalid input`, and on install silently stripped without a runtime error. The working path is a separate `<plugin>/hooks/hooks.json` (or a custom location via `"hooks": "./path"` in plugin.json).

### Schema

The schema has a double `hooks` nesting that is easy to get wrong. Working example for SessionStart:

```json
{
  "description": "Optional: surfaces in claude plugins inspect.",
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|resume",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/install.sh"
          }
        ]
      }
    ]
  }
}
```

The outer `"hooks"` is the object that groups events; within each event entry there is a **second** `"hooks": [...]` array containing the actual commands. Omit that nesting and the plugin validates but the hook array comes through the validator as the wrong type.

Codex is stricter than Claude here. When Codex reads `hooks/hooks.json`, the
top-level object must contain only `"hooks"`. Claude's optional top-level
`"description"` is useful for `claude plugins inspect`, but it is not portable
to a Codex-facing hook config. Keep that description only in a Claude-only
source, or use an explicit `hooks/hooks.codex.json` source for Codex and let the
adapter materialize it as runtime `hooks/hooks.json`.

### Matcher syntax

`matcher` is always a regex string, not an object. For PreToolUse / PostToolUse it matches on tool name (`"Bash"`, `"Edit|Write"`). For SessionStart it matches on source: one of `startup`, `resume`, `clear`, `compact` (or a pipe combination like `"startup|resume"`). Omitting `matcher` means fire on all sources; for an install hook that has nothing to do on `/clear` or an auto-compact, `"matcher": "startup|resume"` is the efficient choice.

Confirmed in Claude Code 2.x: `claude plugins validate` accepts both a missing matcher and the regex string. The object format `{"source": [...]}` does NOT work, despite some LLM suggestions naming that form.

### Validate before shipping

`claude plugins validate <path>` is the canonical pre-ship sanity check for every plugin manifest or hooks change. It runs against the local source path (not the install cache) and catches schema violations that would otherwise only become visible on a colleague's first install, often silently.

```bash
claude plugins validate ./packages/<plugin>
```

Run it after EVERY change to `plugin.json` or `hooks/hooks.json`. Not a replacement for a real install test, but a free first filter.

## Versioning

The `version` field in `plugin.json` is updated automatically by the marketplace
pre-commit hook. The format is `1.0.{commits}` where `{commits}` is the number
of commits that touched `packages/<name>/` or `skills/<name>/`. In
multi-agent repos, the same hook must rebuild generated Codex manifests after a
Claude manifest version bump; otherwise `.claude-plugin/plugin.json` and
`.codex-plugin/plugin.json` drift in the same commit.

## What lands in the plugin cache

Claude Code installs a plugin from the repo subpath specified in `marketplace.json` (usually `packages/<plugin>/`) and drops the full contents of that subpath into the cache. That means: `.claude-plugin/`, `skills/`, the plugin-level `README.md`, `bin/`, **and** `hooks/` (including the `hooks/hooks.json` manifest plus all hook scripts) all land there. Files outside the subpath (for example the repo-root `README.md` or the repo-root `bin/`) do not come along, because the plugin source starts at `packages/<plugin>/`, not at the repo root.

Empirically tested against a cached marketplace plugin:

```
$HOME/.claude/plugins/cache/<marketplace>/<plugin>/<version>/
├── .claude-plugin/
│   └── plugin.json
├── README.md            (plugin-level, not repo-root)
├── bin/
│   └── relative-cron    (consumer-facing helper)
└── skills/
    └── <skill>/...
```

Older cache versions of the same plugin may have a different layout, depending on what was in the repo at the time of that install. Inspecting a cache against an old version proves nothing about the current source layout; test against a fresh `claude plugins update`.

## The path to the active install

The authoritative source for "which version is running now" is `~/.claude/plugins/installed_plugins.json`:

```bash
jq -r '.plugins["<plugin>@<marketplace>"][0].installPath' ~/.claude/plugins/installed_plugins.json
```

That path is the **plugin root in the cache**, not the repo root. It contains `.claude-plugin/`, `skills/`, `bin/` (if the plugin source has it), and the plugin-level `README.md`. Concrete path templates:

| Target | Correct path | Wrong path |
|--------|-------------|----------|
| Skill resource | `$installPath/skills/<skill>/<file>` | `$installPath/packages/<plugin>/skills/<skill>/<file>` |
| Bin script | `$installPath/bin/<script>` | `$installPath/packages/<plugin>/bin/<script>` |
| Plugin manifest | `$installPath/.claude-plugin/plugin.json` | (no other) |
| Hooks manifest | `$installPath/hooks/hooks.json` | `$installPath/.claude-plugin/plugin.json` (see Hooks section) |
| Hook script | `$installPath/hooks/<script>` (referenced via `${CLAUDE_PLUGIN_ROOT}/hooks/<script>` in hooks.json) | (absolute paths; do not work cross-machine) |

The `packages/<plugin>/` prefix only exists in the source repo, not in the cache. The `ls -1dt ... | head -1` trick against `~/.claude/plugins/cache/<marketplace>/<plugin>/` points to the same path but relies on mtime ordering and is therefore not stable; the `jq` lookup works deterministically.

For Codex, use the structured plugin list. It reports both installed version
and active source path:

```bash
codex plugin list --json \
  | jq -r '.installed[] | select(.pluginId == "<plugin>@<marketplace>") | .source.path'
```

That path is Codex's active plugin root. For a local marketplace in development
it may be a generated directory in the working tree, for example
`.agents/plugins/generated/<plugin>`; for other marketplace sources it may be a
cache snapshot. Do not infer freshness from the working tree alone. Compare the
reported `version` with the generated `.codex-plugin/plugin.json`; if Codex
still reports an older version after a commit or rebuild, refresh the
marketplace/install before testing the skill in a new Codex thread.

Skills that need to call their own helper binaries should resolve the active
root, not hard-code `${CLAUDE_PLUGIN_ROOT}` into a Codex path. A shared skill
can use a small resolver with agent-specific branches:

```bash
resolve_plugin_root() {
  if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; then
    printf '%s\n' "$CLAUDE_PLUGIN_ROOT"
    return 0
  fi
  if command -v codex >/dev/null 2>&1; then
    root="$(codex plugin list --json \
      | jq -er '.installed[] | select(.pluginId == "<plugin>@<marketplace>") | .source.path')" \
      || return 1
    printf '%s\n' "$root"
    return 0
  fi
  return 1
}
```

## `/reload-plugins` and `/reload-skills`: re-read the installed set, do not update it

`/reload-plugins` is a TUI slash command that re-loads the currently-installed plugin set into the running session without a full restart. Its output looks like:

```
Reloaded: 32 plugins · 0 skills · 7 agents · 8 hooks · 0 plugin MCP servers · 0 plugin LSP servers
```

What it does: re-reads `installed_plugins.json` and re-binds every plugin, agent, hook, skill, and MCP/LSP server from each plugin's active `installPath` (the cache snapshot). It is the in-session alternative to the session restart that the troubleshooting steps below otherwise flag with 🚦.

What it does NOT do: it is not `claude plugins install` / `update`. It does not bump a cache version, does not rewrite `installPath` or `lastUpdated`, and does not re-resolve a `directory`-source marketplace against your working tree.

Empirically tested in Claude Code 2.1.156, with a marketplace registered as a `directory` source pointing at the working copy. The working tree carried a new helper function in a hook file, committed on local `main`, while the active install still pointed at the previous cached version. After `/reload-plugins`:

- The plugin stayed at the old version, with identical `installPath` and `lastUpdated`; no new cache directory appeared.
- The active `installPath` still served the old code: grepping the cached hook file found no new helper function, even though the working-tree file had it.

Conclusion: editing a directory-backed marketplace's working tree and running `/reload-plugins` does NOT make the edit live; the reload re-loads the same stale cache snapshot. To pick up working-tree edits you must first `claude plugins update <plugin>@<marketplace>`, which copies the current working tree into a fresh cache version and rewrites `installPath`; only then does `/reload-plugins` (or a restart) load the new code. `/reload-plugins` usefully replaces the restart in the second half of that loop, never the update in the first half. The update snapshots the working tree as-is, including any uncommitted changes, so land or stash unrelated work first if you want a clean snapshot.

`/reload-skills` is the skill-catalog counterpart and behaves the same way against the same cache snapshots. Its output looks like:

```
Reloaded skills: 148 skills available (no changes)
```

It re-reads the full skill catalog (every plugin's `skills/` plus user-level skills) and reports the count, with a `(no changes)` suffix when the reloaded set is byte-identical to what was already loaded. It is complementary to `/reload-plugins`: the plugin reload re-binds plugins, agents, hooks, and MCP/LSP servers but reported `0 skills`, while the skill reload owns the `148 skills`. The same empirical run confirmed it does not pull working-tree edits either: after `/reload-skills`, how-plugins-work stayed at version 1.0.25 with the identical `installPath`, and the new section marker was still absent from the active cache SKILL.md while present in the working tree. So `(no changes)` here means "the installed cache snapshot is unchanged", not "your working-tree edits were checked and skipped". Reload never looks at the working tree. The update-then-reload loop above is the same for skills.

Both reload commands act on the session you type them in. A running **background
agent** (`claude agents` / `/agents`, dispatched with `claude --bg`) is a
separate process that loaded its plugins at its own start, and
`/reload-plugins` cannot reach it. After `claude plugins update`, those agents
keep running the old version until their process restarts. In Claude Code, the
Claude-only `/restart-claude-agents` command in this plugin does that restart:
it stops each background agent and resumes its session with
`claude --bg --resume`, re-applying the agent's original launch flags from its
job state, so a fresh process loads the current plugins while the agent keeps
its conversation, permissions, and goal.

## Troubleshooting: "Unknown command: /xyz"

Observed symptom: user types `/rover` (or `/autonomous:rover`) and Claude Code replies `Unknown command`. Diagnose and fix. Do not narrate steps for the user to execute; Claude has shell access and can run the same commands. Dictating install commands is condescending when Claude can just install.

**Step 0 (mandatory, no exceptions).** Run `claude plugins list` yourself before forming any hypothesis. This command is the single source of truth. If the plugin is absent, every theory about prefixing, namespacing, or skill resolution is noise.

1. **Plugin not listed.** Run `claude plugins install <plugin>@<marketplace>`. The Claude process inherits the CLI so this just works. The only thing that is not Claude's to do is loading the freshly-installed plugin: the user runs `/reload-plugins` (in-session, no restart) or restarts the session. Flag that with 🚦 and wait for user go.

2. **Plugin listed but disabled.** Patch `~/.claude/settings.json` `enabledPlugins` to `"<plugin>@<marketplace>": true`. This is a user-level file; ask first before editing.

3. **Marketplace source out of date.** Check the source with `claude plugin marketplace list`. A directory source reads the primary checkout: integrate the branch there and update the plugin, no push needed. Only a GitHub source needs the remote, and publishing there is a release to agree on first. Never re-point a marketplace at a working copy or worktree.

4. **Skill missing `user-invocable: true`.** Without the flag the skill is model-triggered only and no slash command appears. Edit the frontmatter.

5. **Skill name collision across enabled plugins.** Bare `/<skill>` only resolves when unique. Use `/<plugin>:<skill>` via autocomplete.

6. **Stale cache path.** Cached versions live under `~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/`. A long-running session may point at an older cached skill set. Flag 🚦 for a restart, or `/reload-plugins` to re-bind the installed set in-session (note: reload re-reads the same `installPath`; it does not pick up working-tree edits without a prior `claude plugins update`, see the `/reload-plugins` section).

Never advise the user to prefix or de-prefix a slash command without having run step 0. "Namespacing is required" is a guess when the actual failure is almost always install state, enable state, or a stale session. And never dictate `claude plugins install ...` at the user; run it.

## Troubleshooting: Codex plugin install misses

Observed symptom: a Codex session does not see a plugin or skill expected from a
local marketplace.

1. Run `codex plugin marketplace list` and confirm the marketplace name and root.
2. Run `codex plugin list --json` and confirm the plugin appears under the
   expected marketplace, with the expected `version`, `enabled`, and
   `source.path`.
3. Run `codex plugin add <plugin>@<marketplace>` if the plugin is not installed.
4. For Git-backed marketplace snapshots, run `codex plugin marketplace upgrade
   <marketplace>` before reinstalling when the remote changed. For local
   marketplace development, rebuild the generated adapters first.
5. If the plugin exists in Claude metadata but not Codex, run
   `circus plugins check .`. Drift means the Codex adapter files are stale;
   a clean check means the omission is intentional single-agent coverage.
6. If `codex plugin add` cannot find the plugin, inspect
   `.agents/plugins/marketplace.json` first, then the package
   `.codex-plugin/plugin.json`.

Do not inspect `~/.codex/plugins/cache` as source. It is a runtime snapshot.

## Experiment metadata

- Original experiment: short plugin name, 2026-04-06
- Renamed to plugin = skill name, 2026-04-07
- Cache layout + installPath verification: 2026-04-19
- Claude Code version: 2.1.92
- Marketplace source: local directory
- Codex CLI command forms verified via local `codex plugin --help`, 2026-06-09
