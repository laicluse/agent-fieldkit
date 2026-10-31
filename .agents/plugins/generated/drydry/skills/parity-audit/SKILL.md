---
name: parity-audit
description: >-
  Audit every entry point promising the same outcome across a codebase, converge divergent consequences, and verify again. Runs as a named background multi-agent process; use drydry for a quick duplication check.
allowed-tools:
  - Skill
  - Agent
  - Workflow
  - Bash(git status *)
  - Bash(git log *)
  - Bash(git diff *)
  - Bash(date *)
  - Bash(ls *)
  - Bash(find *)
  - Bash(grep *)
  - Bash(rg *)
  - Bash(wc *)
  - Bash(python3 *)
  - Read
  - Write
  - Edit
  - Glob
  - Grep
---

# Parity audit

Drydry's dual. The rest of the plugin finds **duplication**: the same work written twice. This skill finds **divergence**: several entry points promise the user the same outcome, reach the same shared step, then do different things afterwards.

Divergence is harder to catch than duplication. Duplication shows up in a diff; divergence does not. Every entry point produces the same primary result, so every manual test passes. Only the follow-up effects differ, and they surface hours later as something missing: a reminder that never fired, a listener never woken, a teardown never run.

## When to use

Use this when a system has more than one way to trigger the same outcome: a button, a keyboard shortcut, a CLI flag, an API route, a scheduled job, a webhook, a voice intent, an undo, an import path, a chapter-skip in a player. Language and stack do not matter; you only need "several callers, one shared step".

Trigger phrases: "does every path do the same thing?", "why did it work from the button but not from the automation?", "we added X but only some flows got it", or an incident where the primary result was right and a follow-up was missing.

Do not use it to find copy-paste. That is `drydry:drydry`.

## The discriminator

One mechanical rule carries the audit, and it needs no domain knowledge:

> At N entry points that share a core call, count the statements **after** the core call in each entry point. If they differ, you have divergence.

This is why the work fans out: a reviewer who has never seen the domain can apply it, in any language, and the answers are comparable across reviewers.

Injected closures are the usual mechanism. A closure works for dependency inversion, but it lets each caller assemble its own subset of callbacks, so you can half-implement the set and nothing complains.

## The seven phases

Five phases carry an established name from the aspect-oriented migration literature, so you can check the step against prior work. Two do not: the comparison rule inverts the standard technique, and the closing re-mine is borrowed from another field because the refactoring literature stops one step short.

| # | Phase | Established name | What happens |
|---|-------|------------------|--------------|
| 1 | **Mine** | aspect mining | Enumerate every entry point with a side effect, grouped by *surface*, not by folder. |
| 2 | **Explore** | exploration | Read the shared core by hand, in parallel with the fan-out, until you can tell a real finding from a plausible one. |
| 3 | **Compare** | none, this inverts fan-in analysis | Record what runs after the shared call, in one schema, and diff the tails. |
| 4 | **Document** | documentation | Write the artefact. It is not a write-up, it is the baseline phase 7 diffs against. |
| 5 | **Converge** | aspect refactoring | Move the shared consequence to the strongest enforcement the substrate allows, so a new caller cannot re-introduce the divergence. |
| 6 | **Guard** | behaviour conservation | Guard at the strength you enforced on; a test is the terminal guard only when no type or check can express the constraint. |
| 7 | **Re-mine** | closed-loop remediation | Run phases 1 to 4 again, with the same instrument, and read the delta. |

### 1. Mine

Fan out. One reviewer per **entry surface**, never per directory. Divergence lives *between* surfaces; a folder-based split hides the comparison inside one reviewer's context.

Typical surfaces: direct user controls, scheduled/background work, external triggers (webhooks, intents, deep links, notifications), lifecycle hooks (launch, resume, teardown), administrative or debug paths, and anything embedded that mutates state outside your own code (an embedded browser, a third-party SDK, a vendor console).

Announce the run as a long-running background process with a name that says what it measures, and poll it between steps rather than blocking on it.

### 2. Explore

Do not wait for the fan-out before you understand the system yourself. While the reviewers run, read the shared core, its callers, and the wiring that injects its dependencies.

This step decides whether the audit is trustworthy. A reviewer who has read one subsystem produces confident, plausible, sometimes wrong claims; without your own reading you cannot tell those apart, and a confident wrong finding costs more than a missed one. Expect to correct the report, including your own earlier conclusions.

The published strategy puts exploration between mining and refactoring for the same reason: mined seeds are candidates, not findings.

### 3. Compare

Every reviewer fills the **same structured schema**. That is why many independent reads become comparable; free-text reports cannot be diffed against each other or against a later run.

Minimum fields per action: name, entry surface, location, trigger, primary effect, the shared call it ends in, the depth at which it enters the shared path, and the load-bearing field, **everything that runs after that shared call**.

Classic aspect mining looks for **high fan-in**: one method called from many places. This phase inverts it. Many callers of one method is the starting condition, not the finding; the finding is that they disagree about what happens next.

Give the reviewers the failure story that motivated the audit so they know which axis to scan. On a re-run, tell them the story may no longer match the code and that they must report what the source says today, or they will confirm the narrative instead of reading the source.

### 4. Document

Produce one reviewable artefact and treat it as an instrument, not a report. It has two jobs: to be read now, and to be diffed against later. An artefact you cannot regenerate the same way next quarter fails the second job, so the schema and the surface list are part of the deliverable.

Drydry calls this detection method as a first-class artefact. The migration literature makes documentation its own phase for the same reason.

### 5. Converge

Put the shared consequence **inside** the shared path. A helper each door must remember to call is still N call sites, and forgetting to call it is the failure you are removing.

Prefer one capability that names the whole consequence set over several optional hooks, because you cannot half-implement it. Then check what you achieved: moving the trap from "forget the call at N call sites" to "forget the injection at one construction site" is progress, but if the un-injected default is silent and total, you have hidden the trap, not closed it. Make the empty case something a caller has to name explicitly.

Not every difference should be converged, but the bar is high and the burden of proof is on the difference.

**Justify per element, never per door.** A voice trigger may owe the user a spoken confirmation because nobody is looking at the screen. That justifies *the confirmation*. It does not justify that same door also taking a different persistence path, a different teardown, or a different end reason. Once you accept one justified element as cover for the whole tail, you have stopped auditing.

For every statement in the tail that a sibling door does not have, name the constraint that forces it. A constraint is something the door cannot escape: the app process is dead, there is no screen, there is no session. "It grew here" and "this surface has always done it" are history, not constraints.

Two paths that are ninety percent parallel and differ on ten percent are the dangerous case. If only that ten percent is genuinely forced, the other ninety is not justified difference, it is a design that was never pulled together, and the audit reports it as divergence. Report the justified element and the unjustified remainder as separate lines. A finding that reads "explained by design" without a per-element constraint is one you waved through.

Converge one consequence at a time, so the system is never half-migrated in a way you cannot ship. This is the literature's incremental integration: one commit per converged consequence, each green.

**Move the consequence to the strongest enforcement, not just the deepest call site.** Depth places the code; it does not stop the next caller. Putting the shared step at the deepest common point is still weak if a new door can bypass it, which is why a re-mine keeps surfacing the same shape of finding: the fix was placed, not enforced. The level that decides whether a class recurs is what holds the fix in place, from weak to strong:

1. convention or comment: nobody enforces it, it always comes back
2. review or audit: costs per instance, forever
3. a test that pins behaviour: holds only on the paths a fixture touches
4. a lint or static check that blocks the edit: holds wherever the pattern is syntactically detectable
5. a type or API where the wrong state does not compile: the fault cannot be written
6. a single authoring site where the question cannot arise: nothing left to enforce

The distinction that matters is level 4 versus level 5: a check rejects the fault, a type makes it unwritable.

Which level is reachable depends on the substrate, so set that ceiling before you converge. A statically typed language reaches level 5 (newtypes, non-optional fields, exhaustive switches). A dynamic language reaches level 4 (a custom lint or AST rule). Config reaches level 4 (policy-as-code) or level 6 (one module is the only way to declare the thing). Prose reaches level 4 (a schema on the frontmatter). **Default to the strongest reachable level.** Dropping to a weaker one is a logged cost-value decision that names what reaching the stronger level would cost, never a silent default. A convergence held only by a convention or a review is an open finding, not a closed one, however many call sites it touched today. It is closed only when you can name what enforces it and answer yes to "can I delete the rule and keep the code correct?"

### 6. Guard

The refactoring literature calls the obligation **behaviour conservation**: the change must preserve observable behaviour. A divergence audit sharpens it, because the behaviour to conserve is *per door*, and the doors did not agree before you started. Decide which door was right, then conserve that.

Parity tests that compare what goes **into** the shared call catch half the problem. The other half is a test that puts the observed effects of two doors against the same spy. Guards belong at the exit, not only at the entrance.

But the guard is whatever now enforces the convergence, not automatically a test. If you converged to a type where the wrong state does not compile, the compiler is the guard and an exit-parity test is redundant; a reader will mistake it for the thing holding the line. If you converged to a lint or AST rule, that rule is the guard, and it covers callers no fixture will reach. The exit-parity test is the terminal guard only when nothing stronger can express the constraint, which is the honest case for a consequence that lives in observable side effects rather than in a representable type. Match the guard to the level you reached; do not write a test by reflex because this phase is named after behaviour conservation. A test that re-checks a compiler-enforced invariant is a second, weaker copy of a guarantee you already have.

### 7. Re-mine

Run the audit again, with the same instrument, after the change. This is not ceremony:

- it catches what the convergence pass left behind, one layer out
- it tells you whether divergence was removed or merely **moved**, which is invisible without a second measurement
- it re-baselines the artefact so the next run has something to diff against

For a class you converged to a type or a single authoring site, do not re-scan. Verify in one line that the constraint still holds (the field is still non-optional, the rule is still in the config) and move on. Re-scanning a compiler-enforced class wastes a reviewer and invites a false "still clean" reading that treats an unrepresentable fault as merely absent this time. Read the count delta as a measure of the fix, not only of the code: a class converged to a strong level should drop toward zero and stay there across runs; a class held by a convention or a review stays flat, because the fix never removed the ability to write the fault. A flat count for a finding you reported as converged means it was placed, not enforced, and belongs back in Converge at a stronger level.

Report counts honestly. A second pass usually enumerates more finely than the first; more rows is more resolution, not more surface. Say so, or the delta lies.

## Discipline

These cut across every phase; the phase-specific rules live with their phase.

- **Findings are hypotheses until a test reproduces them.** Every behaviour change gets a test that is red first for the stated reason, then green. A divergence you cannot make fail on demand is one you do not understand yet. That test proves you understood the finding; it is not automatically the guard that keeps it from returning. When a type or a check can express the constraint, the red-then-green test stays as the proof and the type or check becomes the guard (see Guard).
- **A finding only the audit can see is not finished.** Either a test now fails, or the report names why no test can reach it. Otherwise the next run rediscovers it and you learn nothing.
- **Ship the convergence in slices that each stand alone.** One consequence per commit, each green, so an interrupted audit leaves a working system rather than a half-migration.
- **Say what you did not look at.** Surfaces you skipped, a subsystem the fan-out could not reach, an artefact you could not capture. An audit that reports only what it found reads as complete when it is not.

## Output

A single reviewable artefact with: what changed since the last run, the remaining findings ranked by consequence (not by effort), a convergence map of which entry points promise the same thing and where their shared step now sits, and the full inventory grouped by surface.

Rank by what it costs the user when the follow-up is missing. Where a missing consequence is expensive and a redundant one is cheap, say so, and let that asymmetry drive the ranking.

Every near-parallel pair gets a line, including the ones you are about to excuse. For each difference the report names the constraint that forces it, or it names no constraint and the difference stands as a finding. "Mostly the same, and the rest is by design" is not a reportable state: split it into the forced element and the remainder, and count the remainder.

## Prior art

The parts have established names; the whole loop does not. Grounded 2026-07-21:

- **Crosscutting concern / code scattering / code tangling** name the phenomenon: one concern spread across regions of the program, versus several concerns overlapping in one region. <https://www.sciencedirect.com/topics/computer-science/crosscutting-concern>
- **Shotgun surgery** (Fowler, *Refactoring*, 1999) names the maintenance symptom: one change forces many small edits across many modules. <https://sourcemaking.com/refactoring/smells/shotgun-surgery>
- **Join point, pointcut, advice** name the mechanics. What this audit finds is *after advice* hand-inlined at every call site instead of applied once at a join point. <https://en.wikipedia.org/wiki/Pointcut>
- **Aspect mining** names phase 1: reverse engineering to find crosscutting concerns in a system that was not written with them factored out. Its classic technique, **fan-in analysis**, looks for one method called from many places. This skill inverts it: it looks for many places that call one method and then *disagree about what happens next*. <https://arxiv.org/pdf/cs/0609147>
- **Integrated crosscutting concern migration strategy** (Marin et al.) is the closest published whole, and supplies phases 1, 2, 4 and 5: mining, exploration, documentation, refactoring. It has no re-mine step. <https://arxiv.org/abs/0707.2291>
- **Behaviour conservation** and **incremental integration** name what phase 6 owes: a migration must preserve observable behaviour and must be able to go in stage by stage alongside the original. In a divergence audit the first obligation needs a decision first, because the doors disagreed before you started. <https://arxiv.org/abs/cs/0503015>
- **Closed-loop remediation** names phase 7, borrowed from compliance and security because the refactoring literature has no equivalent: a finding is not done when it is fixed, it is done when re-verification confirms it is gone. <https://nhimg.org/glossary/closed-loop-remediation/>

Composite name for the practice: **tail parity audit**. "Tail" is the statements after the shared call, which is where the divergence lives and what the discriminator counts. If you prefer to stay entirely inside published vocabulary, call it closed-loop aspect mining.
