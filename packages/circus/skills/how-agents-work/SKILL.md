---
name: how-agents-work
user-invocable: true
description: >-
  Explain cross-agent instruction layers, shared capabilities with host adapters, skill discovery in running sessions, and personal versus distributed knowledge. Use when briefing agents, placing doctrine, or designing Circus plugins; use circus for commands.
---

# how-agents-work

The conceptual companion to `how-plugins-work`. That skill explains how
Claude/Codex plugins, skills, marketplaces, and runtime caches resolve; this
skill explains how Circus briefs many coding agents from one source. For the
actual commands (`circus build`, `circus sync`, `circus plugins`), see the
`circus` skill.

## Two skills, one boundary

- **`how-plugins-work`**: plugin/skill/marketplace mechanics, including name resolution,
  manifests, adapters, and caches.
- **`how-agents-work`**: the Circus orchestration model, including shared doctrine,
  per-agent specifics, generated targets, and runtime activation.

Distributed Circus code may describe the public layout and command contract.
Personal doctrine, machine-specific paths, and host-specific adapters stay in
the user-level source under `${LAICLUSE_HOME:-~/.laicluse}/circus/`; generated
targets contain that data only because the user explicitly configured them as
destinations.

## One source, many agents

The core idea at every layer is the same: author once, render per agent.

- **Doctrine layer.** Shared, agent-agnostic doctrine plus per-agent specifics are
  combined into one instruction file per agent (`CLAUDE.md`, `AGENTS.md`, …).
  One behavior, N rendered targets.
- **Plugin layer.** One Claude marketplace source generates the Codex adapters
  (manifests, sanitized skill bodies). One capability, N agent packages.

A target or adapter is **output**, never source. Edit the shared source, then
regenerate; never hand-edit a generated file (it carries a banner saying so).

## Host-owned capability across agents

The reason author-once-render-per-agent works is the ports-and-adapters
principle: a skill describes the *capability* it needs, and each host agent
supplies it with its own tooling. A skill says "open the browser" or "notify the
operator", not "run this vendor-specific command". So the shared `SKILL.md` is
the capability contract; the per-agent manifests are adapters. Hard-code a
vendor dependency only when that dependency is itself the public API.

## Picking up a new or edited skill

The tempting mental model — "discovery happens once at process start, so you
must restart" — is wrong for skills. Claude Code watches the skill directories
(`~/.claude/skills/`, a project `.claude/skills/`, and `.claude/skills/` inside
any `--add-dir`) and applies `SKILL.md` edits live, mid-session, with no
restart. The restart-only cases are narrower than the instinct assumes.

What actually needs what:

- **Edited or added `SKILL.md` in a watched skills dir** → picked up
  automatically within the running session. Nothing to do.
- **A brand-new top-level skills *directory* that did not exist when the session
  started** → not watched yet; needs a restart (or a `--plugin-dir` / install at
  the next startup).
- **Plugin components other than `SKILL.md`** — `hooks/`, `.mcp.json`,
  `agents/`, `output-styles/` of a skill-folder-that-is-also-a-plugin → live
  detection does *not* cover these; run `/reload-plugins`.

The commands re-read the installed set in place (they do not install — see
how-plugins-work) and exist in **interactive sessions only**; they are
unavailable in `-p` / print mode:

- `/reload-skills` (v2.1.152+) re-scans skill and command directories and
  reports how many are available, added, or removed.
- `/reload-plugins` re-scans active plugins and their components, reporting
  per-component counts and load errors. If the reload would change which MCP
  tools load (invalidating the prompt cache) it warns and skips unless you pass
  `--force`.

### Background agents are the trap

A background agent (`claude --bg`, managed via `claude agents`) has no remote
reload: you cannot send it a slash command, and the agent-view peek panel
(`Space`) sends a *user message*, not a command. The instinct to "just resume it
with the right flags" is wrong and actively makes a mess:

```
# WRONG — this does NOT restart the agent in place:
claude --resume <session-id> --bg
```

`--resume … --bg` **branches to a new session id** and leaves the original
sitting in the `claude agents` list, still there — it does not auto-end. You end
up with a second session beside the first, not a reloaded one (stopping the old
one afterwards is a manual cleanup, not something resume does for you). Resuming
the same id interactively is refused while it runs as bg ("…add `--fork-session`
to branch off a copy"). There is no in-place, same-id background restart.

The correct move keeps the same session id:

```
claude attach <session-id>   # converts the bg agent to interactive in this terminal
/reload-plugins              # (or just rely on live SKILL.md detection)
# press ← to detach; it keeps running in the background under the same id
```

Only when you genuinely need a fresh *process* for the same conversation (rare
for a skill reload, since live detection and `/reload-plugins` cover it): `claude
stop <id>` first, then `claude --resume <id>` interactively reuses the id. Reach
for `attach` + reload before that.

## Building a plugin with Circus

Read `how-plugins-work` first — the public mechanics live there and apply
identically: a plugin `source` must be a real subdirectory (e.g.
`./packages/<plugin>`, never the repo root), `SKILL.md` needs an explicit
`user-invocable:`, and a `description` with quotes or punctuation must be a
folded scalar (`>-`) for Codex's stricter YAML.

Circus owns adapter generation and versioning. A marketplace repo invokes the
canonical commands directly:

```sh
circus plugins build <repo>
circus plugins check <repo>
circus plugins versions --check <repo>
```

`circus plugins versions` derives the shared `major.minor` prefix from existing
plugin manifests and applies commit-count versioning without installing a copy
of the implementation into the consumer repo. Run the adapter and version
checks before committing so Claude source, Codex targets, descriptions, and
versions cannot diverge in the same commit.

## Where things live

- **Plugin mechanics** → `how-plugins-work`.
- **Operational circus commands** → the `circus` skill.
- **This skill** → the cross-agent mental model, agent-reload lifecycle, and
  personal-data boundary.
