# lifeline

Three ways to reach outside your own first answer when certainty, evidence, or project coherence runs out. `inspire` researches the wider world before choosing a direction. `ground` verifies a specific claim after doubt appears. `rethink` reconstructs a drifting project from its own history and lived behavior before writing a first-principles manifesto that can govern future decisions.

## Installation

```bash
claude plugins install lifeline@laicluse-agent-fieldkit
codex plugin add lifeline@laicluse-agent-fieldkit
```

In a Claude Code session, version 2.1.275 or later, one line installs it straight from the marketplace repository:

```
/plugin install lifeline --marketplace laicluse/agent-fieldkit
```

## Skills

### `/inspire`

Online research that answers "how do others do this?", "what already exists?",
"what can we learn from published experience?" before you commit to a path.
Forward-looking and divergent: it widens the option space and ranks by quality
of the end result, not ease of implementation. Triggers on `/inspire [topic]`,
on unfamiliar territory, and on phrases like "hoe doen anderen dit?".

### `/ground`

Verify your own recent output against external sources when a claim is doubted.
Backward-looking and convergent: generation and verification are separate
processes, so it re-checks a specific claim with code search, file reads, and
the web rather than re-asserting from model weights. Triggers on `/ground`, on
skepticism signals like "dat klopt niet", and on necessity claims that justify
complexity.

### `/rethink`

Reconstruct a project's purpose, promises, responsibilities, and boundaries when recurring local fixes no longer form a coherent system. It excavates original design documents, code, repository history, runtime evidence, transcripts, and lived frustration; triangulates intended, actual, and experienced behavior; then drafts and independently stress-tests a non-prescriptive manifesto. It deliberately stops before refinement or implementation unless those are separately requested.
