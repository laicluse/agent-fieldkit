---
name: ground
description: >-
  Verify claims on any skepticism or doubt signal about the agent's own output, including "dat klopt niet", /ground, or questions about factual accuracy.
---

<post-update-broadcast>
BEFORE doing the actual work below, run this one-time check only when
`CLAUDE_PLUGIN_ROOT` is set:

```bash
if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; then
  node "${CLAUDE_PLUGIN_ROOT}/bin/check-broadcast"
fi
```

If the command produces output, the lifeline plugin was updated since
the last time you saw the broadcast on this machine. Show the output
verbatim in a markdown block, prefixed with one short sentence
("lifeline was updated; here is what changed."). Then continue with
the rest of this skill.

If the command produces no output, say nothing about updates and proceed.

The helper writes the sentinel only when stdout was non-empty, so a silent
run does not mark the version as seen. `/whats-new lifeline`
re-shows the section on demand without touching the sentinel.
</post-update-broadcast>

# Ground

Verify your own recent output against external sources when the user doubts its accuracy. The user is right in ~99% of cases when they are skeptical. That does not mean you are unintelligent, but that you are trained to produce an answer slightly too fast with slightly too little context. That answer sends us down the wrong path, and that is more expensive than a few tokens of verification.

## Core principle

Generation and verification are separate processes. The model that generates is not the same "process" as the model that verifies, even with the same weights. The isolation between generation and verification is what makes this effective (Chain of Verification, Dhuliawala et al. 2023).

## Workflow

```dot
digraph ground {
  rankdir=TB;
  "User doubts" -> "1. IDENTIFY";
  "1. IDENTIFY" -> "2. SEARCH LOCALLY";
  "2. SEARCH LOCALLY" -> "Found?" [label=""];
  "Found?" -> "4. SYNTHESIZE" [label="yes, sufficient"];
  "Found?" -> "3. SEARCH EXTERNALLY" [label="no or insufficient"];
  "3. SEARCH EXTERNALLY" -> "4. SYNTHESIZE";
}
```

### 1. IDENTIFY

Re-read your own recent output. Which concrete claims are verifiable? Formulate a sharp verification question per claim. Not: "is it correct?" But: "In which version was `Hash#dig` introduced according to the Ruby changelog?"

**Prioritize with multiple claims.** When your output contains many verifiable claims: start with the claim the user's skepticism most likely targets (closest to the context of their doubt). Verify at most 3 claims per `/ground` invocation. If there are more, report which ones you verified and which are still open.

**Isolation is mandatory.** Do not answer the verification questions from your model weights. That is the same source that produced the original claim. Your model weights are the suspect, not the witness.

### 2. SEARCH LOCALLY

Use the tools you have:

| Source | Tool | Example |
|--------|------|---------|
| Codebase | Grep, Read | `Grep "has_many.*through"` in models |
| Configuration | Read | Gemfile.lock for version numbers |
| Tests | Read, Bash | What do the specs actually test? |
| Docs in repo | Read | README, CHANGELOG, inline docs |
| Runtime | Bash | `ruby -e "puts ..."`, `rails runner "..."` |

For knowledge claims (version numbers, API behavior, language features) step 2 is often quickly exhausted. That is fine, move on to step 3. Step 2 shines for code claims: "this method does X" is locally verifiable by reading the code.

### 3. SEARCH EXTERNALLY

When local sources are insufficient:

| Source | Tool | When |
|--------|------|------|
| Official docs | WebFetch | API reference, changelogs |
| Stack Overflow | WebSearch | Known patterns, edge cases |
| GitHub issues/PRs | WebSearch | Bugs, breaking changes |
| Blog posts | WebSearch + WebFetch | Real-world experience, tutorials |

The source does not need to be academic. A Stack Overflow answer with 200 upvotes is usable. An obscure blog with a working code example too. The point is: more than just model weights.

### 4. SYNTHESIZE

Present the result honestly:

- **Wrong:** "I was wrong. [Claim] is incorrect. [Source] says [fact]."
- **Nuance:** "Partly correct. [Part A] holds, but [Part B] is different: [fact + source]."
- **Confirmed:** "Verified. [Source] confirms [claim]. [Link/quote]."

No hedging ("I wasn't entirely precise"), no rewriting as if you always meant it correctly. If you were wrong, say so. The user already knows.

## Default stance

When the user types `/ground` or expresses doubt, the working hypothesis is: **the user is right and my output contains an error.** This is not blind obedience, it is Bayesian: the user has a track record of being right ~99% of the time when skeptical. Start by looking for where you are wrong, not by defending why you are right.

**Honest in both directions.** When verification confirms your claim, say that too. Do not inflate nuances into errors because you expect to be wrong. The default stance directs your search (look for errors, not confirmation), but the conclusion follows the evidence.

**When verification is impossible.** If local and external sources are exhausted without an answer: honestly say "I cannot verify this with the available tools. My claim was based on training data and I cannot confirm whether it is current." No pretending, no hedging.

## Proactive trigger: claims of necessity that justify complexity

Ground does not only fire after the user doubts you. It fires the moment you are about to assert that an existing or proposed design is technically *necessary* ("X needs its own route / layer / abstraction / iframe / service because Y"). A necessity claim is the most expensive kind of confident error: it does not just state a fact, it freezes complexity in place by making it look unavoidable. Before you write "this has to be separate because...", run IDENTIFY + SEARCH on the "because" the same way you would for any verifiable claim. Most of the time the honest answer is "this is a choice, possibly a convenient one, not a necessity" and the complexity was never load-bearing.

When the user pushes back on such a claim ("dat is onzin", "waarom dan wel"), that is a ground trigger, not a debate invitation. Do not produce a second rationalization to defend the first. Ground immediately: re-read the artefact in front of you (the user often pastes the very screenshot that refutes you), find the evidence, and concede or correct. A second defense after a single push-back is the confabulation compounding itself.

## Red Flags

| Thought | Reality |
|---------|---------|
| "I'm fairly sure this is correct" | You thought that when you wrote it too. Verify. |
| "Let me nuance my previous answer" | Rewriting is not verification. Find a source. |
| "This is general knowledge" | General knowledge is the #1 source of confident errors. |
| "Let me explain what I meant" | The user is not asking for explanation, but for evidence. |
| "The user misunderstands my answer" | No. Find evidence first before concluding that. |
| "Quick check in my training data" | That IS your training data. Use tools. |
| "It's just a minor detail" | Minor details drive major decisions. |
| "This needs its own route/layer/abstraction because..." | A necessity claim that justifies complexity. Ground the "because" before asserting it; usually it is a choice, not a necessity. |
| "Let me explain why the existing design is correct" | Defending complexity with an unverified rationale. The user is questioning whether it should exist, not asking for a justification. Ground first. |
| "The user pushed back, let me clarify my reasoning" | A second rationalization after one push-back is the confabulation compounding. Re-read the artefact, find evidence, concede or correct. |
