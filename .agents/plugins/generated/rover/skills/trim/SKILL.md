---
name: trim
description: >-
  Run an independent subtraction review before a rover mission is stowed.
---

# Autonomy Trim

What did we write that should not be here?

Not "what is wrong" (pride's job). Not "what is missing" (end-user and technical). Trim asks the inverse: relative to what the Dispatch actually asked for, did the diff overshoot, and if so, which lines should leave?

Every other INSPECT pass surfaces findings that *add* to the diff. Pride says "fix this duplicate helper", gurus says "this needs an extra abstraction", end-user says "add a confirmation step". Each finding individually looks actionable, and the rover's reflex is to address it. But the cumulative effect is that a two-line core grows into a two-hundred-line shipment, much of which the operator never asked for. Trim is the counterweight: the one pass that is biased toward subtraction.

## Why this matters inside an autonomous loop

Code costs are paid forever. A line shipped has to be read by every future maintainer, can host a bug, gets caught up in every refactor that touches its neighbourhood. Tokens spent producing it are cheap; the line itself is permanent surface. The same is true of prose: every paragraph in a prompt or doc that does not earn its weight erodes the reader's attention budget for the parts that do.

The rover, left to its own devices, ships what every pass asked for. That works on missions where the dispatch was complex enough to absorb the additions. It fails on missions where the dispatch was small and the INSPECT passes generated proposals at their normal rate; the diff then carries far more weight than the operator wanted to move.

Trim closes this gap by asking, at the end of INSPECT, the one question no other pass asks. The findings are weighed with the same three-fates rubric `rover` defines: fix (remove), cost-value-skip with structured rationale (keep with reason), or reject-as-non-issue (the trim reviewer was wrong about this chunk, confirmed by a pride second pass).

## When to run

**Auto-triggered by `rover`.** Final INSPECT pass, after the gurus pass and before STOW. Trim runs once the rover believes the work is complete and reviewed by the other passes; trim then asks whether the result is *minimal*.

(If the rover finds additional work in DRIVE after trim ran, run trim again on the new batch before STOW.)

**Manually via `/rover:trim`:**
- `/rover:trim` reviews the uncommitted changes plus commits on the current branch not yet on the default branch
- `/rover:trim <ref>` reviews a specific commit range, for example `<default>..HEAD` or `HEAD~3..HEAD`
- `/rover:trim uncommitted` reviews only the uncommitted diff

Useful outside a rover session whenever a diff feels heavier than the change required.

## How

Use the host's delegated-agent mechanism when available, preferably a fresh reviewer with no prior context. Claude can use its Agent tool; other hosts may expose a different delegated-agent or work-loop mechanism. If the host exposes no delegated agent, run the same review as a separate no-prior-context pass in the active session and log that fallback. Give the reviewer the artefact, the Dispatch text (so it knows what was actually asked for), and the brief below.

For code artefacts, give the reviewer the diff plus this brief:

> You are reviewing recent code changes for what should not be there. Not bugs, not smells; the inverse. Your job is to find lines, helpers, abstractions, comments, configurations, or files that were added during the mission but do not earn their weight relative to what the Dispatch asked for.
>
> The Dispatch text is included below. Read it first; it states the destination. Then walk the diff with these tests:
>
> 1. **Carry-its-weight test.** Does removing this chunk change observable behaviour? If you can delete it and every test still passes, every endpoint still answers, every UI element still renders the same, the chunk does not earn its weight.
> 2. **Mission-relevance test.** Is this directly in service of what the Dispatch asked for, or did it grow out of an INSPECT finding that itself was marginal? Cascading additions from marginal findings are the first to leave.
> 3. **Defensive-addition test (YAGNI).** Was this added for a case that has not materialised and may never? Code defending against a hypothetical, configuration for a path nobody takes, an option with one possible value, a base class with one subclass: these are defensive overshoot.
> 4. **Over-explanation test.** Does this comment explain WHAT the code does (the code already does that) or explain WHY (which justifies its existence)? Did the rename make the original comment redundant? Comments that are out of sync with the code below them are worse than no comment; flag both kinds.
> 5. **Cumulative-weight test.** Step back from individual chunks. Relative to what the Dispatch asked, did the cumulative diff overshoot? If the core was two lines and the diff is two hundred, the bulk of the overshoot is what you need to find.
>
> For each finding: file:line, what you see, why it does not earn its weight, the concrete removal (delete lines X-Y, inline this helper into its single caller, collapse this two-line guard into one).
>
> Be willing to find nothing. A tight diff is real. But if you find nothing, list what you examined and why each section earned its weight, in one sentence per section. Vague "looks tight" is rejected.

For prose artefacts (research briefs, plans, analysis documents, letters, summaries, PR descriptions, communiqués, prompts, SKILL.md edits), give the reviewer the artefact plus this brief:

> You are reviewing a written deliverable for what should not be there. Not unclarity, not unsupported claims; the inverse. Your job is to find sentences, paragraphs, sections, lists, or headings that were added during the mission but do not earn their weight relative to what the Dispatch asked for.
>
> The Dispatch text is included below. Read it first; it states the destination. Then walk the artefact with these tests:
>
> 1. **Carry-its-weight test.** Does removing this sentence change what the reader takes away? If you can delete it and the surrounding paragraph still communicates the same point, the sentence does not earn its weight.
> 2. **Mission-relevance test.** Is this directly in service of what the Dispatch asked for, or did it grow out of an INSPECT finding that itself was marginal? Cascading additions from marginal findings are the first to leave.
> 3. **Restatement test.** Does this sentence restate what the previous one already said in slightly different words? Does this paragraph repeat the section heading in narrative form? Does the bullet list spell out what the lead paragraph already named?
> 4. **Defensive-explanation test.** Is this caveat hedging against a misreading no thoughtful reader would make? Is this aside addressing an objection nobody raised? Defensive prose protects the author, not the reader.
> 5. **Cumulative-weight test.** Step back from individual paragraphs. Relative to what the Dispatch asked, did the cumulative artefact overshoot? Especially for prompts, SKILL.md edits, and rule-laden documents: each rule the reader has to hold while reading the next one is a weight; rules that do not bite often enough to justify the weight should leave.
>
> For each finding: the exact phrase or passage, what you see, why it does not earn its weight, the concrete removal (strike sentence X, collapse paragraph Y into its first sentence, remove bullet Z).
>
> Be willing to find nothing. A tight document is real. But if you find nothing, list what you examined and why each section earned its weight, in one sentence per section. Vague "reads tight" is rejected.

## Gathering the artefact and the Dispatch

Trim runs on whatever the rover produced this mission. Start by collecting two payloads:

1. **The diff or artefact.** Same logic as `pride` (see "Gathering the diff" in `pride`). For prose-only missions, feed the full text of the artefact files or sections. For mixed missions, run trim twice with the appropriate brief for each, or combine both payloads with the matching briefs.
2. **The Dispatch text.** When the rover invokes trim, the Dispatch lives in the loop file's `## Dispatch` section. Feed it verbatim to the reviewer so it knows what was actually asked. For manual invocation, ask the user for the original task description, or accept that the reviewer will work without it (in which case it leans harder on the carry-its-weight and over-explanation tests, and lighter on mission-relevance).

The reviewer compares the diff against the Dispatch; that comparison is the core of the cumulative-weight test.

## Bias toward subtraction

Pride is biased toward addition (find what is missing, what would hurt the user, what risk slipped through). Trim is biased toward subtraction (find what should not be there). Both biases produce false positives; both are useful. The rover applies the three-fates rubric to both, and the rubric handles the false positives.

Specifically: a trim finding the rover believes is wrong (the chunk does earn its weight) does not vanish without process. Either the rover removes it (fate 1: trim was right), or it logs a fate-2 cost-value rationale explaining why the chunk earns its weight on this mission's scope, or it routes it to fate 3 (reject-as-non-issue, pride second-pass confirms trim was hollow). Same rubric as every other INSPECT finding.

The asymmetry is by design. Without a subtraction pass, addition wins by default in every other INSPECT pass. With one, the rover at least has a counterweight that asks the inverse question once per mission.

## What to do with findings

**Inside a running loop (auto-triggered):**

1. Write findings to the loop file's `## Log` section under a `[HH:MM] Trim findings:` header
2. For each finding, name the fate and the rationale: fate 1 (remove) lists the lines to delete; fate 2 (keep with cost-value rationale) lists why the chunk earns its weight on this mission; fate 3 (reject-as-non-issue) triggers a pride second pass on the trim finding itself
3. After processing, commit any removals as a separate "trim" commit so the diff history shows build, review fixes, and subtraction as distinct steps. This commit lands inside INSPECT, before STOW.
4. INSPECT cannot transition to STOW without a `[HH:MM] Trim findings:` block on record for the current mission

**Invoked manually (`/rover:trim`):**

1. Print findings to the conversation
2. Apply the removals before returning. Trim is not a report-generating skill; it is the pass that closes the gap between "looks done" and "is also lean".
3. If the removals require an external-action gate the rover cannot take, complete all local removals and name the remaining gate once at the end. Never ask mid-removal whether to continue, and never turn the gate into a command for the user to run.

## Trim is not STOW

STOW is mechanical cleanup: debug prints, commented-out code, unused imports, half-finished refactors, scaffolding, what-vs-why comments. Yes/no answers. STOW runs after trim and cleans up any mechanical residue trim's removals left behind.

Trim is the judgment pass: a paragraph that says nothing, a defensive guard for a case that will not happen, a base class for the one subclass that exists, an over-elaborated explanation, the cumulative weight of fifteen fix-it findings that added two hundred lines for a five-line ask. Cost-vs-value answers.

The two passes complement each other:

| Pass | Question | Type | When |
|------|----------|------|------|
| Trim | What does not earn its weight relative to the Dispatch? | Judgment, three-fates | End of INSPECT, before STOW |
| STOW | What is mechanically obvious leftover? | Yes/no, mechanical | After INSPECT, before STANDBY |

A finding that trim flags as "earns its weight, keep" can still be mechanically wrong (a leftover debug print inside an otherwise load-bearing helper). STOW catches that. Conversely, a finding STOW would not touch (a paragraph that explains a decision in three sentences when one would do) is trim's job. Different questions, different answers.

If trim uncovers something that requires more than removal (a refactor, a behaviour change, a logic adjustment), the rover goes back to DRIVE rather than performing the change inside trim. Trim is removal only.

## Anti-patterns

| Smell | What it actually means |
|-------|------------------------|
| "Pride already reviewed it" | Pride finds what is wrong, not what is excess |
| "Gurus didn't flag it" | Gurus reviews substance, not weight |
| "Every line was added for a reason" | Every line was added for a reason that felt sufficient at the time; trim re-weighs against the Dispatch |
| "The diff is small already" | Trim still runs; the cumulative-weight test against a small Dispatch finds even small overshoot |
| "It is just one paragraph" | Documents that ship with one unearned paragraph per section accumulate fast across releases |
| "STOW will catch it" | STOW catches mechanical residue, not judgment-level overshoot |

## Token awareness

This skill sends a diff payload plus the Dispatch text to an independent reviewer when the host can provide one, or runs a separate review pass in the active session when it cannot. For large branches, prefer `git diff --stat` first and then targeted diff reads. Do not dump a 5000-line diff into the reviewer; summarise and focus. The Dispatch text is always small; include it verbatim.
