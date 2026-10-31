---
name: pride
description: >-
  Run an independent pride check that surfaces issues the main rover missed.
---

# Autonomy Pride

Are you proud of this work?

Not "do the tests pass." Not "did CI go green." Proud. As in: you would show this to a thoughtful colleague without flinching. Every file. Every line.

Most of the time, the answer without this check is an unthinking "yes" because CI is green. The pride check forces a harder look.

## Why this matters inside an autonomous loop

In an ordinary workflow, code review and "sleeping on it" catch the pride-level issues: the one dumb helper, the four duplicate fixes, the `|| true` that swallows a real error. An autonomous loop has none of those. The loop commits, pushes, moves on. Without a pride check, the loop's INSPECT phase validates the happy path against CI and declares success. The rest ships unreviewed.

The pride check injects an independent skeptic before the loop transitions to its "done" states. If the loop is good at what it does, the pride check usually finds something real. When it finds nothing, it has to explain what it examined and why nothing was flagged. Vague "looks good" is rejected.

**Review supports truthful outcomes.** Resolve findings before claiming success. A stop, exhausted budget or failed hypothesis instead requires an honest report of unmet criteria, not another repair or reviewer cycle. Apply the bounded disposition rules from rover.

## When to run

Review a coherent batch of changed implementation or measured results before successful handoff. Cover risky source and publication boundaries before execution. Reuse a valid review for unchanged documentation, status messages and the final summary; material changes require a focused delta review. A stop or negative-result report does not require a new review cycle. Research claims need actual evidence, not merely review of a plausible plan.

**Manually via `/rover:pride`:**
- `/rover:pride` reviews the uncommitted changes plus commits on the current branch not yet on the default branch
- `/rover:pride <ref>` reviews a specific commit range, for example `<default>..HEAD` or `HEAD~3..HEAD`
- `/rover:pride uncommitted` reviews only the uncommitted diff

## Close findings without restarting discovery

After a completed full review, a repair review carries the original scope, the actual previous findings, their dispositions, the complete diff since the reviewed commit, affected source context and current verification. Do not resend an unchanged repository-sized packet or present the repair review as a fresh full review. Freeze the source revision before dispatch; changes made while it runs are unreviewed and require an explicit delta handoff. Reopen the whole review only when a concrete change or new evidence invalidates the earlier assessment of the whole artefact, and state which part of that assessment no longer holds.

A second round finding another regression at the same behavior boundary is evidence that the preservation comparison was incomplete. Stop the patch-and-review cycle and compare the original and replacement state transitions, including reversals, failure recovery and dependent side effects. For example, preserving a native cancellation in a day view also requires checking its correction back to a normal appointment, check-ins and reminders. Repair the missing behavior contract and the related cases together before another review. More review tokens are not evidence that this understanding has improved. Keep genuine defects open; this checkpoint does not excuse incomplete work or authorize a scope change.

## How

Use the host's delegated-agent mechanism when available, preferably a fresh reviewer with no prior context. Claude can use its Agent tool; other hosts may expose a different delegated-agent or work-loop mechanism. If the host exposes no delegated agent, run the same review as a separate no-prior-context pass in the active session and log that fallback. Give the reviewer the artefact, the loop's Context section if one exists, and the matching brief below.

For code artefacts, give the reviewer the diff plus this brief:

> You are reviewing recent code changes with a skeptical eye. You have not seen the implementation decisions, the plan, or the reasoning. Ignore sunk cost.
>
> For every changed file, find:
>
> 1. **Duplicate fixes.** Is the same change applied in four different places because of a repeated rubocop/lint warning? That is a smell. The underlying rule is either wrong or the abstraction is missing.
> 2. **Type smells.** Are there `casecmp?`, string comparisons, or `.to_s` calls where the source returns a different type (symbol, number)? These often compile but silently misbehave.
> 3. **Ugly helpers.** Is there a method whose job is to paper over an awkward interface? Name it, show the better alternative.
> 4. **Defensive filtering.** Are there guards that skip "unexpected" values? That often hides the real bug upstream.
> 5. **Shell noise.** Shell commands of the form `X && Y || echo "..."` are swallowing errors. Any `|| true` on a non-idempotent command is suspect.
> 6. **Race conditions.** New async code, new background jobs, new state mutations: is there a window where two callers step on each other?
> 7. **Stale documentation.** README, comments, or docstrings that describe behavior that is no longer accurate after this change.
> 8. **The question the user would ask.** Read the diff as if you are the user who asked for this work. What would make them say "why did you..."?
> 9. **Unsupported success claims.** Find unmet requirements being presented as complete or silently removed. An explicit negative result, stop or exhausted budget must remain reportable without triggering more work. Distinguish honest limits from false claims of delivery.
>
> For each finding: file:line, what you see, why it is a problem, and the concrete fix.
>
> Be blunt. A finding is better than a compliment. If there is nothing to find, say so explicitly, but try hard first.

For prose artefacts (research briefs, plans, analysis documents, letters, summaries, PR descriptions, communiqués), give the reviewer the artefact plus this brief:

> You are reviewing a written deliverable with a skeptical eye. You have not seen the mission, the sources, or the reasoning. Ignore sunk cost. The author cannot defend themselves; your job is to find what the operator would push back on.
>
> For the whole document, find:
>
> 1. **Confidence laundering.** Hedged evidence presented as firm conclusion. Phrases like "likely," "appears to," "suggests that" stacked up into a confident claim. Flag each jump from hedge to certainty.
> 2. **Unsourced claims.** Specific facts, numbers, names, dates, quotes, or URLs without a citation or a verifiable source. Training-data invention is a real risk: product names, conference tracks, speaker lists, locations, dates.
> 3. **Over-claims.** Statements that go further than the evidence supports. A single example presented as a pattern. A correlation presented as a cause. A possibility presented as a plan.
> 4. **Ungrounded references.** URLs that were not actually fetched, repos that were not actually read, studies that were not actually cited, people who may not exist. Flag every external reference that could not be verified.
> 5. **Missing caveats.** Limitations, counter-evidence, alternatives that the author knew about but did not mention. What would a hostile reviewer say is absent?
> 6. **Scope creep in prose.** Sections that drifted beyond the stated mission. Recommendations that the author was not asked for. Conclusions that assume facts not in evidence.
> 7. **The question the user would ask.** Read the document as if you are the user who commissioned it. What would make them say "where did you get this?" or "did you actually check?" or "why did you include this?"
> 8. **Unsupported success claims.** Find unmet requirements being presented as complete or silently removed. An explicit negative result, stop or exhausted budget must remain reportable without triggering more work. Distinguish honest limits from false claims of delivery.
>
> For each finding: the exact phrase or passage, what you see, why it is a problem, and the concrete fix (strike it, rewrite it, add a source, add a caveat).
>
> Be blunt. A finding is better than a compliment. If there is nothing to find, say so explicitly, but try hard first.

## Gathering the artefact

Pride runs on whatever the rover produced. Start by naming the artefact:

1. **Code artefact.** A diff exists. Use the git range logic below to collect it.
2. **Prose artefact with no committed diff.** A research brief, plan, analysis, letter, or summary that lives as a file in the repo, in `.autonomous/<NAME>.md`, or as a drafted response in the loop file. Feed the full text of that file or section to the reviewer as the review target.
3. **Mixed.** The rover produced both code and prose. Run pride twice with the appropriate brief for each, or give the reviewer both payloads with a clear separator and both briefs.
4. **Generated media (images, audio, video, slides).** Describe the artefact in words (filename, purpose, summary of contents, any claims embedded in captions or voice-over), feed that description to the reviewer with the prose brief, and run pride on the source text of any embedded claims.

If the rover cannot identify an artefact to hand to pride, there is nothing to hand off either. The pride gate is not satisfied by absence of output; it is only satisfied by a reviewed artefact.

### Gathering the diff

The skill argument (`$1` as the skill tool passes it) determines the range:

```bash
ARG="${1:-}"

case "$ARG" in
  "" )
    # No arg: "branch so far" plus any uncommitted work.
    DEFAULT=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##')
    DEFAULT_REF=""
    [ -n "$DEFAULT" ] && DEFAULT_REF="origin/$DEFAULT"
    if [ -z "$DEFAULT_REF" ]; then
      CONFIGURED_DEFAULT=$(git config --get init.defaultBranch 2>/dev/null || true)
      if [ -n "$CONFIGURED_DEFAULT" ] && git rev-parse --verify "refs/heads/$CONFIGURED_DEFAULT" >/dev/null 2>&1; then
	DEFAULT_REF=$CONFIGURED_DEFAULT
      fi
    fi
    [ -n "$DEFAULT_REF" ] || { echo "pride: cannot determine default branch from origin/HEAD or init.defaultBranch; invoke /rover:pride with an explicit range." >&2; exit 1; }
    RANGE="${DEFAULT_REF}..HEAD"
    INCLUDE_UNCOMMITTED=true
    ;;
  uncommitted )
    RANGE=""
    INCLUDE_UNCOMMITTED=true
    ;;
  *..* | *...* )
    RANGE="$ARG"
    INCLUDE_UNCOMMITTED=false
    ;;
  * )
    RANGE="${ARG}..HEAD"
    INCLUDE_UNCOMMITTED=false
    ;;
esac

DIFF=""
if [ -n "$RANGE" ]; then
  DIFF=$(git diff "$RANGE")
fi
if [ "$INCLUDE_UNCOMMITTED" = true ]; then
  DIFF="${DIFF}$(git diff HEAD)"
fi
```

`*...*` matches the symmetric-difference form (`<default>...HEAD`) which git treats differently from `<default>..HEAD`. Passing it through to git is correct.

Pass the collected diff to the reviewer. Large diffs: `git diff --stat "$RANGE"` first, pick hot files, truncate per-file reads to 300 lines with a note, rather than dumping a 5000-line blob.

## What to do with findings

Pride findings need evidence-based dispositions before successful delivery: fix, exclude with scope/cost rationale, or reject with concrete evidence. An unmet criterion cannot be excluded into a success claim. Explicit stops, exhausted budgets and negative experimental outcomes take precedence over more repairs; report unresolved findings honestly.

**Inside a running loop (auto-triggered):**

1. Write findings to the loop file's `## Log` section under a `[HH:MM] Pride check findings:` header
2. For each finding, record a fix, evidence-based rejection, or scope/cost exclusion. Include execution cost and maintained complexity; never exclude an unmet criterion into a success claim.
3. Return to DRIVE for authorized repairs only while no stop or budget boundary applies.
4. Report material uncertainty and unmet criteria honestly; resolve routine findings independently within the active mandate.

**Invoked manually (`/rover:pride`):**

1. Print findings to the conversation
2. Fix every finding before returning. Pride is not a report-generating skill; it is a check that closes the gap between "looks done" and "actually done". Manual invocation means the user wants the work fixed, not a menu of what could be fixed.
3. If the fix requires an external-action gate the rover cannot take, complete all local fixes and name the remaining gate once at the end. Never ask mid-fix whether to continue, and never turn the gate into a command for the user to run.

### Bounded challenge of disputed findings

Batch disputed material findings into one independent challenge with the original intent and concrete evidence. Correct real defects within the authorized budget; do not dismiss an unmet Done criterion as marginal. If the disagreement remains unresolved, report it and withhold a success claim. Do not recursively review the challenge or launch a fresh full review for an unchanged artefact. Explicit stops and budget limits take precedence over another review.

### Success claims must match evidence

Do not present "mostly works", "almost done" or "good enough for now" as successful completion of unmet criteria. An honest negative or stopped outcome is not a forbidden success claim. Report what failed, what remains unknown and what work was preserved. Such reporting does not restart DRIVE or a review cycle.

## What counts as "nothing found"

Genuinely clean work exists. But "I checked and it looks fine" is not a review. If the reviewer returns "nothing found," require it to list:

- What it examined (files, patterns, specific risk areas)
- Why nothing was flagged (specific, not generic)

One sentence minimum per risk category. "No race conditions because the new code runs inside a single database transaction" beats "no race conditions found."

If the reviewer returns a vague "looks good," reject and re-run with stronger prompting.

## Anti-patterns

| Smell | What it actually means |
|-------|------------------------|
| "The tests pass" | Proxy for correctness, not review |
| "Copilot already reviewed" | Bot review is a first pass, not the pride check |
| "I already thought about this" | You thought about the happy path |
| "The PR description covers it" | Descriptions sell, they do not review |
| "This is good enough for v1" | Haste projection. See `decide` |
| "There is no diff, so nothing to review" | The artefact is the review target, not the diff |
| "It is just research, pride does not apply" | Research briefs are where confidence laundering lives. Apply it harder. |
| "I will run pride after the push" | Pride runs before. After is too late. |
| "The operator will catch it on review" | That is exactly the review the rover exists to stand in for |

## Token awareness

This skill sends a diff payload to an independent reviewer when the host can provide one, or runs a separate review pass in the active session when it cannot. For large branches, prefer `git diff --stat` first and then targeted diff reads. Do not dump a 5000-line diff into the reviewer; summarize and focus.
