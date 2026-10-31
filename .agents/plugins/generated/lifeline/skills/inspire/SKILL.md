---
name: inspire
description: >-
  Research unfamiliar domains, new designs, and competing approaches. Use for research requests, "hoe doen anderen dit", "wat bestaat er al", or when external perspectives would inform the task.
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

# Inspiratie

Online research that answers: "how do others do this?", "what already exists?", "what can we learn from published experience?" Results flow back into the conversation as internalized knowledge or as a discussion point.

## When to use

### Triggers

1. **Explicit**: `/inspire` or `/inspire [topic]`
2. **Proactive**: Claude detects moments where external research adds value
3. **Implicit**: user says something like "hoe doen anderen dit?", "kijk even wat er bestaat", "wat is de standaard aanpak?"

### Proactive detection signals

- Unfamiliar territory (new framework, unknown standard, unfamiliar domain)
- Design decision with multiple possible directions
- Evaluative question about an approach
- First time a particular concept appears in the conversation

### Do not search when

- Routine work in a familiar domain
- Questions purely about the project's own codebase
- User explicitly opts for speed ("doe maar gewoon", "geen research nodig")

## Depth

Claude determines depth based on complexity and user signals. Iterative: keep searching until there is enough understanding.

| Level | When | Search rounds |
|-------|------|---------------|
| Quick | Factual question, consensus topic | 1-2 |
| Normal (default) | Design question, multiple approaches | 2-4 |
| Deep | User signals ("diepe duik"), complex domain | 4-8 |

**Increase depth**: "diepe duik", "research dit grondig", "hoe pakken teams dit aan"
**Decrease depth**: "snel even checken", "is er een standaard"
**Automatic escalation**: when the first round surfaces contradictory information or surprises.

## Research tools

Two complementary tools, both first-class:

**WebSearch** for broad exploration: what exists, what terms people use, which sources surface. Starting point for unfamiliar territory.

**WebFetch** for targeted reading: documentation pages, GitHub discussions, blog posts, Reddit/HN threads, framework-specific guides. Use WebFetch when:
- WebSearch surfaces a promising source (read the full page, not just the snippet)
- You already know where the information lives (official docs, known communities)
- You want to dig deeper into a specific perspective or implementation

WebFetch is not a secondary step after WebSearch. Sometimes WebFetch is the starting point (known documentation URL).

## Workflow

```
1. FORMULATE
   - Derive topic (from argument or conversation context)
   - Check local codebase first (Grep/Glob) for existing patterns
   - Determine starting level (quick/normal/deep)
   - Formulate 1-3 initial search questions
   - Identify known sources reachable directly via WebFetch

2. SEARCH
   - WebSearch for broad exploration
   - WebFetch for direct sources (docs, GitHub, forums)
   - WebFetch for deeper reading of promising search results
   - Parallelize independent search actions

3. EVALUATE
   - Consensus or diversity?
   - Surprises or contradictions?
   - Enough information for the depth level?

   No -> reformulate, increase depth, back to 2
   Yes -> proceed to 4

4. DETERMINE OUTPUT MODE
   - Absorb or Discuss? (see below)
```

## Output mode

### Absorb (no discussion)

When:
- A clear consensus approach is found
- Confirms the current direction
- Unambiguous answer to a factual question

Action: briefly mention what you found, apply it, keep working. No report, no list of sources.

### Discuss (present options)

When:
- Multiple valid approaches with real trade-offs
- Choice depends on project-specific factors

Action: present concisely with trade-offs and sources. No exhaustive list, only the options that genuinely matter. **Rank by quality of the end result, not by ease of implementation.** "The fastest path" is not a recommendation; "the most promising" is. Criteria: accuracy, extensibility, community/momentum, and how well it serves the user's end goal.

### Discuss (challenge direction)

When:
- Findings call the current approach into question
- Significant risks or anti-patterns discovered

Action: present as a counter-argument. Aligns with the evaluative-questions rule in CLAUDE.md.

## Interaction with plan mode

In plan mode: include findings as a context section in the plan, not as standalone output.
Outside plan mode: apply directly or discuss, depending on output mode.

## Red Flags

If you catch yourself thinking any of the following, that is the signal that you SHOULD search:

| Thought | Reality |
|---------|---------|
| "My knowledge is probably accurate enough" | Probably is not certain. Look it up. |
| "This is a stable protocol/framework, it does not change" | Stable does not mean your knowledge is complete. |
| "For an architecture discussion, research is not needed" | Architecture discussions are EXACTLY where research pays off most. |
| "I can answer this from my training" | You can, but are you missing existing libraries, community patterns, or known pitfalls? |
| "This is too simple to look up" | Simple questions often have surprisingly nuanced answers. |
| "Research slows down the conversation" | A wrong direction costs more time than 30 seconds of searching. |
| "I will look it up later if needed" | It is needed now. The question has been asked. |
| "X is the fastest path" | Fastest is not best. Rank by quality of the end result. |
| "X wins because it runs in the browser" | Ease of implementation is not a quality criterion. What delivers the best result? |

**The core rule**: when you are unsure whether to search, that uncertainty is the evidence that you should. Doubt = uncertainty = research needed.
