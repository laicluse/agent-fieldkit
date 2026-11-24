# gurus

Opinionated panels that challenge work from multiple perspectives. Three
panels live under this plugin: `software` for code review, `council` for
critical thinking on an idea or decision, and `writers` for prose review. An
orchestrator skill routes between them.

Use `gurus` when one agent answer is not enough: code needs adversarial review,
an idea needs pressure, or prose needs craft feedback from more than one angle.
The panels are opinionated by design; they should produce concrete edits,
risks, or decisions rather than polite agreement.

## Installation

```bash
claude plugins install gurus@laicluse-agent-fieldkit
codex plugin add gurus@laicluse-agent-fieldkit
```

In a Claude Code session, version 2.1.275 or later, one line installs it straight from the marketplace repository:

```
/plugin install gurus --marketplace laicluse/agent-fieldkit
```

## Sub-skills

| Skill | Use for | Panel |
|-------|---------|-------|
| `gurus:software` | Code review | Eight engineering personas (Beck, Fowler, Uncle Bob, DHH, Metz, Evans, Hickey, Ousterhout). Consensus across 6 of 8 yields an action plan. |
| `gurus:council` | A decision or idea | Five adversarial lenses (pre-mortem, first-principles, opportunity-finder, stranger, action) plus anonymised peer review plus chairman synthesis. |
| `gurus:writers` | Prose review (essay, script, manuscript, narrative copy) | Six writers (Didion, Saunders, Rovelli, Watts, Gladwell, Urban). Consensus across 4 of 6 yields an action plan of edits, cuts, and rewrites. |
| `gurus:gurus` | Orchestrator: you are not sure which panel fits | Reads the context (diff present, abstract question, or prose under discussion), proposes a default, lets you override, then dispatches. Not itself a review; only a router. |

## Commands

### `/gurus`

Entry orchestrator. Routes to `gurus:software` when a diff or code scope is in context, to `gurus:writers` when prose files (`.md`, `.txt`, body-prose `.html`) or a pasted paragraph are under discussion, to `gurus:council` when the question reads like a decision or idea. Propose the default in one line, accept a one-word override (`software`, `council`, or `writers`), then dispatch. Direct invocation of `/gurus:software`, `/gurus:council`, or `/gurus:writers` skips the routing step.

### `/gurus:software`

Runs the software panel against the full codebase by default; pass an explicit scope (file, directory, or commit range) to narrow the review. Each guru returns a short critique, and consensus across 6 of 8 produces an action plan. The value sits in the tension between perspectives: agreement across fundamentally different styles is a strong signal.

### `/gurus:council`

Runs five advisors against a brief. Every advisor writes a lens-specific review (pre-mortem assumes the idea fails, first-principles strips assumptions, opportunity-finder seeks the adjacent bigger win, stranger answers with zero context, action demands a concrete next step). Responses are anonymised, peers blind-review each other, and a chairman synthesises one verdict plus one concrete next step. Pattern based on Ole Lehmann's "board of advisors" skill, itself inspired by parallel LLM-critique patterns that Andrej Karpathy (among others) has advocated. Claude runs all voices through `gurus:sonnet-max`; Codex uses native subagents when available and otherwise marks a single-session fallback.

One invocation runs eleven advisor jobs (five lenses, five peer reviews, one chairman). In Claude those are `gurus:sonnet-max` agents at `effort: max`; in Codex they are native subagents when available. The two review phases run in parallel where the runtime supports it, so typical wall time is 2 to 4 minutes there; token cost is substantial. See `skills/council/SKILL.md` for the full panel, lens briefings, and prompt templates. See `skills/software/SKILL.md` for the eight-guru software panel.

### `/gurus:writers`

Runs the writers panel against a piece of prose: a markdown draft, a script, a manuscript chapter, narrative HTML editorial, voiceover copy. Each writer reads the entire piece and returns a short critique grounded in their own craft, and consensus across 4 of 6 produces an action plan of edits, cuts, and rewrites. Writers quote the prose they are reacting to so the action plan is editable rather than abstract. The value sits in the tension between crafts: a sentence that survives Didion's restraint, Saunders's warmth, Rovelli's precision, Gladwell's hook instinct, Urban's accessibility, and Watts's depth has earned its place. See `skills/writers/SKILL.md` for the full panel.

## When to use which

- **Before merging a non-trivial PR**: `gurus:software`.
- **When refactoring touches conceptual boundaries**: `gurus:software`.
- **When "moet ik X of Y?" is the actual question**: `gurus:council`.
- **When Claude's previous answer felt sycophantic**: `gurus:council`.
- **Before publishing an essay, script, or manuscript chapter**: `gurus:writers`.
- **When voice, pacing, or opening feels off in a piece of prose**: `gurus:writers`.
- **When you are not sure**: `/gurus` and let the orchestrator decide.

## Agent model

Claude receives `gurus:sonnet-max`, a generic plugin-shipped subagent pinned to
Sonnet at maximum effort (`model: sonnet`, `effort: max` in frontmatter).
Every guru and advisor dispatches through that subagent so every voice runs on
the same engine ceiling. The definition lives in `agents/sonnet-max.md`.

Codex receives Codex-specific skill bodies. They use native Codex subagents when
the current session exposes them and prefer the least token-hungry reviewer
model that can handle the scoped work; the current session model keeps routing
and final synthesis. Otherwise they run the same panel protocol as a structured
single-session review and mark that as a fallback rather than pretending
independent agents were spawned. The generated Codex package intentionally omits
`agents/sonnet-max.md`; that file is Claude runtime only.
