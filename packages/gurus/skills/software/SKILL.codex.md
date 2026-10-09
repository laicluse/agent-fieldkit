---
name: software
user-invocable: true
description: >-
  Run an opinionated software engineering review panel over code, diffs, or design choices.
allowed-tools:
  - Bash(git diff *)
  - Bash(git log *)
  - Bash(git status *)
  - Bash(git branch *)
  - Bash(wc *)
effort: high
---

# Software Guru Panel

Codex execution model: use native Codex subagents when the current session
exposes them. Reviewer agents are the "hand" layer: prefer the least
token-hungry Codex subagent model that can read the scoped files and return a
structured critique. Keep grouping, conflict resolution, and final synthesis on
the current session model. Escalate a reviewer to the current session model
only when the cheaper model cannot handle the context or the operator
explicitly asks for maximum-depth review. If no subagent facility is available,
run the same protocol as clearly separated single-session passes and state that
fallback in the final review. Do not call Claude's `gurus:sonnet-max`; that is
the Claude runtime adapter for this plugin.

Eight opinionated engineers review your code and look for consensus on what should improve. When 6+/8 agree, an action plan is produced. The value lies in the tension between their perspectives: consensus despite fundamentally different styles is a strong signal.

## Determining scope

The default scope is always the **full codebase** (all source files
in the relevant directory). Agents read all files, not just a
diff. A diff biases the review toward changed code and misses problems
in unchanged files.

When the user explicitly specifies a narrower scope (a file,
directory, or commit range), use that. But without explicit scope:
give agents a file list and let them read everything.

## The panel

| # | Guru | Focus |
|---|------|-------|
| 1 | **Kent Beck** | Four rules of simple design, eliminating duplication, revealing intent. XP Explained, TDD By Example. "What's the simplest thing that could possibly work?" |
| 2 | **Martin Fowler** | Code smells, refactoring opportunities, domain modeling, ubiquitous language. Refactoring, PoEAA, bliki. "I smell Feature Envy here." |
| 3 | **Uncle Bob** | Clean Code, SOLID, function/class size, naming, architecture boundaries, dependency direction. "This function does more than one thing." |
| 4 | **DHH** | Pragmatism, convention over configuration, against over-abstraction and unnecessary indirection. Rails doctrine, Majestic Monolith. "You don't need a service object here. Ship it." |
| 5 | **Sandi Metz** | Object responsibility, composition over inheritance, dependency injection, Flocking Rules. POODR, 99 Bottles. "What does this class know that it shouldn't?" |
| 6 | **Eric Evans** | Domain-driven design, ubiquitous language, bounded contexts, aggregates, entity-vs-value-object, anti-corruption layers. Domain-Driven Design (the blue book). "Does this code speak the language of the domain expert?" |
| 7 | **Rich Hickey** | Data-oriented design, immutability, simplicity as the absence of complexity. Simple Made Easy, Clojure's philosophy. "Are we simplifying, or are we just making it easy?" Challenges OOP assumptions the rest of the panel shares. |
| 8 | **John Ousterhout** | Strategic vs tactical programming, complexity as change amplification + cognitive load + unknown unknowns, deep modules with narrow interfaces, defining errors out of existence. A Philosophy of Software Design. "Could we move the scope boundary 20% to make 80% of this code disappear?" |

**Characteristic tensions**: DHH vs Uncle Bob on level of abstraction. Beck's simplicity vs Fowler's patterns. Metz's small objects vs DHH's pragmatism. Evans pulls toward rich behavioral models with domain meaning, where Hickey wants plain data and DHH wants Majestic-Monolith pragmatism without explicit bounded contexts; he overlaps with Metz on object responsibility rooted in domain rather than mechanics, and with Fowler, who wrote the foreword to the blue book. Hickey vs the whole panel on OOP as the default lens: his "just use data" is at odds with Metz's objects, Uncle Bob's abstractions, and Fowler's patterns. Ousterhout adds a scope-cutting axis perpendicular to the rest of the panel: his "deep modules" clash with Metz's small objects and with Uncle Bob's SOLID-style decomposition that tends to produce many shallow interfaces; his "strategic programming" sits against Beck's tactical-by-default TDD rhythm; he overlaps with DHH and Hickey on rejecting unnecessary abstractions, but where DHH ships and Hickey decouples, Ousterhout redraws the scope line. When 5+ agree despite these tensions, that is a strong signal.

## Workflow

### Step 1: Gather material

Collect the file list for the scope (default: all source files).
Give agents the file list and let them read it themselves. Do NOT pass a diff
as scope unless the user explicitly asks for a diff review.

### Step 2: Dispatch eight reviewers

When native Codex subagents are available, spawn eight parallel reviewer agents
on the cheapest adequate reviewer model. Do not use the current session model
for every reviewer by default; that recreates Claude's expensive max-effort
shape without adding signal. When subagents are unavailable, run eight separate
reviewer passes in the main session and keep the outputs isolated until Step 3.
The reviewers review only; they change NOTHING. Put this sentence in every agent prompt, verbatim: "Read with the file tools and read-only git commands only. Do not run rm, mkdir, cp, mv, tee or any other command that writes, not even into a scratch directory: such a command raises a permission prompt that blocks the operator's session."

**Prompt template per agent** (fill in per guru):

```
You are [NAME]. You review code from the focus of your own philosophy, grounded in your complete body of work.

[PERSONA: 2-3 sentences describing the focus, from the table above. Use the cited works and quotes as anchors.]

You are in a review panel with 7 other experts: [OTHER NAMES]. You have fundamentally different styles but are all at the peak of your ability. Be opinionated and direct. No diplomacy, no "it depends". Say what you think.

## To review

[FILE LIST of all source files in scope]

Read ALL files in the list in full. Review the entire codebase, not
just what was recently changed. Also read AGENTS.md in the project root
(and CLAUDE.md only when the project uses it) for project conventions.

## Output (follow this format exactly)

### What works
- [max 3 points, short and specific]

### What needs improvement
Numbered list. Per point:

1. **[Short title]**
   Location: `file:line` or `file:functionname`
   Problem: [what is wrong, from your specific perspective]
   Proposal: [concrete, implementable improvement]

Be specific. Reference concrete files and lines. No generalities. Maximum 7 points, focus on what matters most.
```

### Step 3: Synthesis

After receiving all 8 reviews:

1. **Group** semantically similar improvement points. "Method too long" (Beck) and "violates SRP" (Uncle Bob) about the same method are the same point
2. **Count** how many gurus named each grouped point
3. **Sort** by consensus (highest first)
4. **Split** at the 6/8 threshold (6 or more of the 8 panel members)
5. **Preserve singleton points.** A point that reaches only 1/8 consensus is not by definition invalid. Present all points with 1+ gurus in the discussion section. A hardcoded string array, a polymorphism candidate, or a forgotten guard is real regardless of how many gurus named it. The user decides what to do with it, not the consensus level

### Step 4: Present

Use this format:

```
## Guru Panel Review

### Reviewed
[Branch or scope], [X files, Y lines total if scope is full codebase; Y lines diff when user explicitly requested a diff scope]

---

### Consensus (6+/8): Action plan

1. **[Title]** (X/8: [names of gurus who agree])
   [Synthesis of the problem from the different perspectives]
   **Location:** `file:line`
   **Proposal:** [concrete improvement, merged from the proposals]

---

### Discussion points (<6/8)

2. **[Title]** (X/8: [names])
   [Description]
   **Proposal:** [concrete improvement]
   *Dissent: [names] think [counter-argument]*

---

### What works
[Summary of highlights that multiple gurus mentioned]

---

Type **"doe het"** to apply the consensus points now. If the session has an
autonomous-execution skill installed, the user may name it explicitly and hand
the consensus points there instead.
```

### Step 5: Execution

On **"doe het"**:
- Execute consensus points sequentially
- One commit per logically independent point
- Normal commit rules (intent validation)

On an explicitly named autonomous-execution skill:
- Hand the consensus points to the skill as tasks
- The background context must indicate that the loop stops itself when all guru
  points have been completed and committed, using whichever stop mechanism the
  chosen execution skill provides. Guru work is finite: there is no external
  input to wait for after committing.

Discussion points are only executed when the user explicitly approves them.
