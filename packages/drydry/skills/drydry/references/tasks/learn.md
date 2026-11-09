# Learn

The online research pass behind the drydry plugin. Enriches the checklist vocabulary by reading what the broader community has written about parallel-paths detection in the last year, then writes checklist-enrichment proposals to the resolved `learnings_dir` from [artifact storage](../artifact-storage.md). The operator types `/drydry:drydry learn <topic>` and the orchestrator routes here.

The premise: the coding-agent world is running into the same kind of duplication, because agents systematically generate fresh code over reusing existing code. Standing still means falling behind. A periodic `learn` pass keeps the checklist seeds and the verifier conventions current.

## Input contract

Caller supplies through `args`:

- **`topic`**: optional topic narrowing (e.g., "swift-app-intents", "rails-service-objects", "react-form-state", "design-token-drift"). When absent, `learn` runs a broad sweep across all five tracks.
- **`depth`**: optional `quick` / `normal` / `deep`. Default `normal`. Quick is one round per track; deep is two rounds plus a contrarian pass.
- **`since`**: optional date stamp (`2025-01-01`). Filters search queries to the named window. Default is the date of the most recent completed proposal for the same topic in the resolved directory, or "last 12 months" when there is no match.
- **`learnings_dir`**: optional path override for the output directory. Resolve it once using the storage contract; the default is `${LAICLUSE_HOME:-$HOME/.laicluse}/drydry/learnings/`. Use the same directory for prior-date lookup and output, and pass it to later checklist calls.

## Output contract

A markdown file at `<learnings_dir>/<unique-run-id>-<topic-or-broad>.md` with three sections:

```markdown
## Detection method chosen

<topic, completion state, resolved learnings_dir, scope, tracks, agents, search windows, sources crawled>

## New patterns

For each candidate pattern the research surfaced:

### <pattern_id>: <short title>

<one-paragraph description, sourced from the citations below>

Signatures to look for:
- `<grep-friendly regex or token>`

Sources:
- <URL>: <one-line takeaway>
- <URL>: <one-line takeaway>

Confidence: robust | probable | fragile (Round-3 contrarian verdict)

Proposed seed domain: <ios-swiftui | rails | react-typescript | markdown-prose | design-tokens | generic>

## Verifier-convention updates

<any new verifier tactic or anti-pattern the research surfaced>
```

The file is **not** auto-merged into the seed templates in `checklist`. The operator reads the file and decides which proposals to fold in.

## Workflow

Use a three-round research shape narrowed to the drydry domain.

### 1. PREPARE

1. Date: `date +%Y-%m-%d`.
2. Resolve `learnings_dir` using the storage contract and create that exact directory. If persistence is unavailable, continue the research and return the full proposal inline, explicitly noting that it was not saved for later seed consumption.
3. Read the most recent completed proposal for this topic (or broad) in `<learnings_dir>/` to set the default `since` window. Allocate a unique output filename without overwriting an existing proposal.
4. Read the sibling [checklist task](checklist.md) for the current seed templates (so the research does not re-propose existing patterns).
5. Read the current `args.topic` and decide which of the five tracks are in scope.

### 2. RESEARCH

#### Round 1: Parallel exploration (5 tracks, 1 research pass per track)

Use the host's native independent research capability for five parallel passes when available. In Claude Code this is the Agent tool with `subagent_type: Explore`; in Codex use native subagents when exposed, otherwise run the passes sequentially in the current session and record that limitation in `## Detection method chosen`. Each pass gets a track-specific brief:

| Track | Focus | Sources |
|-------|-------|---------|
| `clone-detection` | Type-4 clone literature and embedding-based detection updates since the requested `since` date | Google Scholar, arxiv.org, ACM digital library, ASE/ICSE/MSR proceedings |
| `llm-failure-modes` | LLM and agent write-ups on "agents prefer generating over reusing", "fresh code vs existing helper" | Anthropic and OpenAI blogs, simonwillison.net, HN comments on agent posts, awesome-ai-agents |
| `framework-dedup` | Framework-specific dedup patterns (Rails refactor guides, SwiftUI view-composition, React custom-hooks) | thoughtbot, evilmartians, Hacking with Swift, Kent C. Dodds, Sundell, Majid |
| `design-system-convergence` | Design system literature on component drift and token convergence | Brad Frost, Nathan Curtis, design.systems, Figma blog |
| `prose-dedup` | Documentation and content dedup (single-sourcing, content fragments, docs-as-code) | Google developer doc style, write-the-docs, Diátaxis |

Each agent's brief:

```
You are a research subagent for the drydry plugin.

Track: <track name>
Focus: <track focus>
Since: <since date>
Existing drydry checklist patterns to NOT re-propose: <list>

Tasks:
1. WebSearch for new ideas, tools, and patterns in this track since
   <since date>. Use multiple query angles.
2. For each promising result, WebFetch the full page and read it.
3. Identify candidate patterns that drydry's existing checklist does
   not already cover.
4. For each candidate: write a paragraph, list two grep-friendly
   signatures, cite two sources with one-line takeaways.

Return a markdown report. Do not invent citations. Do not paste
abstracts; explain in your own words. Skip patterns where you cannot
produce a runnable signature.
```

Privacy: no project names, no employer names, no operator names in queries. Track focus stays on the technique, not the case.

#### Interim synthesis (depth: normal and deep)

Read the five reports. Identify:

1. Patterns that appear in multiple tracks (high-confidence candidates).
2. Patterns that appear in one track with weak sourcing (parking lot).
3. Contradictions or active debates (mark for the contrarian round).
4. Verifier-convention insights orthogonal to the patterns themselves (new grep tactics, new ast-grep idioms, new design-token-inspector tools).

#### Round 2: Depth (depth: normal and deep)

For the top three to five high-confidence candidates from the interim synthesis, run one deeper research pass per candidate: read more sources, find counter-examples, confirm the signatures actually grep cleanly against open-source codebases the host can browse on GitHub.

#### Round 3: Contrarian (depth: deep only)

For the patterns surviving round 2, run one stronger contrarian review with this brief: "find evidence that this pattern is wrong, redundant with an existing drydry pattern, or specific to a niche the operator does not work in". Classify each surviving candidate as `robust` / `probable` / `fragile` based on whether the contrarian could refute it.

### 3. WRITE

Synthesise the surviving candidates into the output file at `<learnings_dir>/<unique-run-id>-<topic-or-broad>.md`. Group by proposed seed domain. Mark incomplete output as such and mark it completed only after synthesis is finished. Include the Detection method paragraph (Chapter 8) so the operator can reproduce the research.

### 4. NOTIFY

Return to the caller: count of new pattern proposals, by-domain breakdown, path to the artefact, and a one-line summary of any verifier-convention updates.

## Rules

- **No auto-merge of seed templates.** This task writes proposals to disk; the seed templates in `checklist` are never mutated by `learn`. The reader on the next audit run is the `checklist` task: it reads the same resolved `learnings_dir` and globs its Markdown files and appends `robust`-confidence patterns to the seed it generates (see that skill's workflow step 2.5). `probable` and `fragile` proposals stay write-only until the operator promotes them.
- **Citation hygiene.** Every pattern carries at least two sources with one-line takeaways. A pattern with one weak source goes into the `## Parking lot` section, not into `## New patterns`.
- **Signature-first.** A candidate without a grep-friendly signature is dropped. Drydry's downstream `sweep` needs the signature; an unproveable pattern is decoration.
- **Token budget.** Quick depth is one round per track (5 passes); normal is round 1 + round 2 (~10 passes); deep is rounds 1+2+3 (~14 passes including one stronger contrarian review). The skill logs the budget choice in `## Detection method chosen` so the operator can reproduce.
- **Privacy.** No project names, employer names, or operator names appear in any external query. The skill works on technique, not on the operator's specific situation.
