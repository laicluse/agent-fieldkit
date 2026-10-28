# intervision

Peer consultation for coding agents. Intervision is the practice of equals
reviewing each other's work, the opposite of supervision from above. This
plugin brings another coding agent in as that peer: Claude hands work to Codex,
Codex hands work to Claude, and the two reads are compared before anything
is committed or shared. The useful signal is the gap between two independent
agents: what one reviewer notices and the other misses.

Use it when a change is subtle enough that a second model family is worth the
cost: risky code, a design decision, a review that felt too agreeable, or a
diff where the failure mode is hard to see from one perspective.

## Hooks

### `peer-review-gate`

An agent cannot observe how another lab's agent loads a skill, names it, runs a hook or loops. In a repository that carries both `.claude-plugin/marketplace.json` and `.agents/plugins/marketplace.json`, the gate denies a `git commit` that ships payload the other agent runs. When Claude commits, that is every plugin file under `packages/` except Claude-only sources (`.claude-plugin/`, `SKILL.claude.md`, `hooks/hooks.json`, `agents/`), plus the generated Codex adapters under `.agents/plugins/`. When Codex commits, it is every plugin file under `packages/` except Codex-only sources (`SKILL.codex.md`, `hooks/hooks.codex.json`, `agents.codex/`). Tests, READMEs and changelogs need no peer. Files added in the same command or committed with `-a` count too, and the repository is resolved from the tool's working directory, `cd` and `git -C`. Ask that agent's peer with `second-opinion`, settle its findings, then end the commit command with `# peer-reviewed: <model-id>` naming a model of the other lab.

## Installation

```bash
claude plugins install intervision@laicluse-agent-fieldkit
codex plugin add intervision@laicluse-agent-fieldkit
```

## Commands

### `/intervision:second-opinion`

Hands the recent work to the other agent and talks it through. Claude asks Codex on **Sol**; Codex asks Claude on **Opus**. These middle-tier defaults apply independently of the caller's model. Explicit model requests override them, including Luna or Sonnet. Escalate to Astra or Fable for a concrete unresolved concern or an explicit request. Three shapes, picked by what just happened:

- **Work just done (a diff):** the peer reviews the actual change set.
- **A design just discussed (no code yet):** the peer reflects on the plan
  without touching the tree.
- **Back and forth:** continue the exchange to push a point, defend yours, or
  ask the peer to reconsider.

The exact agent-specific invocations live in the suffixed skill sources.

The peer's findings come home through three honest fates: fix, skip on cost versus
value, or reject as hollow. The exchange and any remaining disagreement are
surfaced to you.

### Model shortcuts

Each shortcut selects its model explicitly and follows the complete `second-opinion` workflow. Shortcuts are available only on the host from the other model family:

| Host | Shortcut | Peer |
|------|----------|------|
| Codex | `intervision:opus-opinion` | Claude Opus |
| Codex | `intervision:fable-opinion` | Claude Fable |
| Codex | `intervision:sonnet-opinion` | Claude Sonnet |
| Claude | `/intervision:astra-opinion` | Codex Astra |
| Claude | `/intervision:sol-opinion` | Codex Sol |
| Claude | `/intervision:terra-opinion` | Codex Terra |

In Codex, select the shortcut through the skill picker or a `$` skill mention. Claude shortcuts use slash commands. The other host does not receive these skills.

## Requirements

The peer CLI must be installed and logged in: Claude needs `codex`; Codex needs
`claude`. Reviews run against your own account and quota, so a large diff is a
real billed call. The skill preflights for the CLI and stops with a plain
message when no peer is available.

Claude-side Codex model selection lives in `bin/codex-fast-coding-model`: no
argument resolves the newest Sol slug and fails closed when Sol is unavailable.
`--tier luna`, `--tier sol`, `--tier astra`, and `--tier terra` select an explicit tier.
`INTERVISION_CODEX_MODEL` can override the catalog choice for one run.
