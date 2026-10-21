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

## Requirements

The peer CLI must be installed and logged in: Claude needs `codex`; Codex needs
`claude`. Reviews run against your own account and quota, so a large diff is a
real billed call. The skill preflights for the CLI and stops with a plain
message when no peer is available.

Claude-side Codex model selection lives in `bin/codex-fast-coding-model`: no
argument resolves the newest Sol slug and fails closed when Sol is unavailable.
`--tier luna`, `--tier sol`, and `--tier astra` select an explicit tier.
`INTERVISION_CODEX_MODEL` can override the catalog choice for one run.
