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

## Checked Claude reviews

`bin/claude-review` reads a complete review request from stdin and saves one result JSON to a new `--output` path. It requires Python 3 and a Claude Code version supporting safe mode and partial stream events. Select the peer with `--model`; the default is Opus. `--input-format stream-json` accepts a user message containing images.

The runner gives the peer an explicit tool-free reviewer role and uses safe mode to isolate local coding customizations while retaining existing authentication. It watches public text and protocol events, stops as soon as it observes fabricated tool invocations, loops of empty lines, output exhaustion or refusal, and rejects incomplete or substituted-model results. Detection of continued output depends on the CLI forwarding its stream events. It never requests a continuation or fallback. Early malformed-output detection stops the observed tool-text/blank-loop failure without waiting for output exhaustion. A CLI recovery request already issued when a terminal stream event arrives cannot be recalled, so this is not a hard API-call or spend ceiling. Normal complete reviews retain the model's native allowance.

Existing billing approval remains required for metered routes. Check the effective route with `claude --safe-mode auth status --json`; do not assume a custom settings-based route remains the same in safe mode. The runner does not provide API credentials. Review artifacts omit CLI account-expiry metadata. Do not replace safe mode with bare mode: current Claude Code bare mode skips OAuth and Keychain authentication.

## Installation

```bash
claude plugins install intervision@laicluse-agent-fieldkit
codex plugin add intervision@laicluse-agent-fieldkit
```

In a Claude Code session, version 2.1.275 or later, one line installs it straight from the marketplace repository:

```
/plugin install intervision --marketplace laicluse/agent-fieldkit
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

The peer CLI must be installed and logged in: Claude needs `codex`; Codex needs `claude`. Reviews use the connected account: included subscription usage is not a separate API charge. Metered or unknown billing requires explicit approval. Claude’s session dollar estimates are not invoices and do not establish that money was charged. The skill preflights for the CLI and stops with a plain message when no peer is available.

Claude-side Codex model selection lives in `bin/codex-fast-coding-model`: no
argument resolves the newest Sol slug and fails closed when Sol is unavailable.
`--tier luna`, `--tier sol`, `--tier astra`, and `--tier terra` select an explicit tier.
`INTERVISION_CODEX_MODEL` can override the catalog choice for one run.
