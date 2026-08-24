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

**Pride is not a deferral engine.** Its purpose is to verify that everything is done, not to produce a list of things the rover can defer to "later" or "follow-up". When pride finds something, the rover applies the three-fates rubric from `rover`'s "Three fates" section: fix in a new DRIVE cycle, cost-value-skip with a structured rationale (concrete output cost, concrete value, named canon-vraag), or reject-as-non-issue with a second contrarian pass confirming the reject as hollow. There is no "log and ship" for any finding. There is no "we will address this in a follow-up". There is no operator-accept path for rejecting findings. Pride's output drives the loop back into work or into a logged engineering call, not toward the exit.

## When to run

**Auto-triggered by `rover`.** Canonical triggers:

1. Before any rover artefact leaves the rover. "Artefact" is read broadly: diffs, commits, PRs, pushes, documentation, READMEs, research briefs, plans, summaries, letters, emails, slide decks, video scripts, generated images, audio, slash-command responses, communiqués, anything the rover produced that a human will read. Pride reviews all of it, not only code.
2. As the second pass in INSPECT, right after `verify`, so pride findings feed the DRIVE-fix loop while the artefact is still fresh. Pride runs before STOW so its findings can be fixed as real logic or content changes; STOW is strictly mechanical cleanup and cannot fix what pride flags.

(If a loop runs INSPECT, fixes things, then ships more work, run pride once per batch. Every new batch of artefact before handoff gets its own pride pass.)

**There is no exemption for research-only missions.** A loop whose output is a research brief, a plan, an analysis document, or any other prose deliverable gets the same pride pass as a loop that ships code. The artefact IS the diff-equivalent. See "Gathering the artefact" below for how to feed a prose-only deliverable to the contrarian reviewer.

**Manually via `/rover:pride`:**
- `/rover:pride` reviews the uncommitted changes plus commits on the current branch not yet on the default branch
- `/rover:pride <ref>` reviews a specific commit range, for example `<default>..HEAD` or `HEAD~3..HEAD`
- `/rover:pride uncommitted` reviews only the uncommitted diff

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
> 9. **Effort-and-scope reflexes.** The rover has a documented reflex to skip work on effort or scope grounds. Look for the *pattern*, not only the literal phrases: any sentence that (a) acknowledges the work is not complete AND (b) suggests completion is optional, deferrable, or someone else's problem. That covers literal banned phrases ("mostly done", "roughly complete", "corners cut", "good enough for now", "small issues remain", "polish for later", "almost there", "this would take too long", "too big for this pass", "out of scope because it would take too long", "warrants a separate mission"), their equivalents in whatever language the operator works in, and every paraphrase of them ("approximately landed", "substantially resolved", "the bulk is in", "a handful of edge cases are queued", "tracked in backlog for continuity", "de minimis", "fine for a 0.9"). It also covers the structural escape: a "Follow-ups", "Next up", or "Backlog" section whose bullets are rover-originated deferrals rather than operator-chosen scope, regardless of how diplomatic the wording is.
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
> 8. **Effort-and-scope reflexes.** The rover has a documented reflex to skip work on effort or scope grounds and paper over it with prose that sounds measured. Look for the *pattern*, not only the literal phrases: any sentence that (a) acknowledges the work is not complete AND (b) suggests completion is optional, deferrable, or someone else's problem. That covers literal banned phrases ("mostly done", "roughly complete", "corners cut", "good enough for now", "small issues remain", "polish for later", "almost there", "this would take too long", "too big for this pass", "out of scope because it would take too long", "warrants a separate mission"), their equivalents in whatever language the operator works in, and every paraphrase of them ("approximately landed", "substantially resolved", "the bulk is in", "a handful of edge cases are queued", "tracked in backlog for continuity", "de minimis", "fine for a 0.9"). It also covers the structural escape: a "Follow-ups", "Next up", or "Backlog" section whose bullets are rover-originated deferrals rather than operator-chosen scope, regardless of how diplomatic the wording is.
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

Pride is not a deferral mechanism. Its output is a list of things to weigh, not a list to route around. There is no "log and ship" path. Every finding goes through one of the three fates from `rover`'s "Three fates" section: fix in a new DRIVE cycle, cost-value-skip with a structured rationale, or reject-as-non-issue with the second-pass gate below.

**Inside a running loop (auto-triggered):**

1. Write findings to the loop file's `## Log` section under a `[HH:MM] Pride check findings:` header
2. For each finding, name the fate and the rationale: fate 1 (fix) lists the DRIVE target; fate 2 (cost-value-skip) lists concrete output cost (lines that would be added, files that would gain surface, maintenance burden), concrete value (severity, likelihood, who would notice), and the canon-vraag from `rover` that landed the call; fate 3 (reject-as-non-issue) triggers the second-pass gate.
3. Set Phase back to DRIVE if there is anything in fate 1
4. Do NOT forward findings to the operator mid-loop. The operator is not consulted mid-mission; the rover processes everything before the next handoff.

**Invoked manually (`/rover:pride`):**

1. Print findings to the conversation
2. Fix every finding before returning. Pride is not a report-generating skill; it is a check that closes the gap between "looks done" and "actually done". Manual invocation means the user wants the work fixed, not a menu of what could be fixed.
3. If the fix requires an external-action gate the rover cannot take, complete all local fixes and name the remaining gate once at the end. Never ask mid-fix whether to continue, and never turn the gate into a command for the user to run.

### Every reject gets a second pass

Fate 3 (reject-as-non-issue) is the suspect move. The rover built the work, so it has every incentive to wave a finding away; a second reader who did not build it is the most reliable correction available. A threshold-based gate ("run pass 2 only when rejects exceed N%") quietly contradicts this principle by admitting a band where rejects pass unreviewed. Any ratio above zero is arbitrary and defensible only by feel, and feel about rejects has no reason to be well-calibrated: the author's incentive to keep a reject standing is exactly the incentive the second pass exists to counter.

So the rule is flat: **any fate-3 reject triggers a second pride pass** before it is final. Run pride a second time with a different reviewer when the host can provide one, or a separate stricter pass in the active session when it cannot ("the author rejected the following findings as non-issues; tell me which rejects are hollow and which ones are real"), reconcile the two reports, log both runs in the loop file. A fate-3 reject is only final after the second-run reviewer independently agrees (concrete-evidence-of-non-issue, per `rover`'s fate-3 definition). If the second pass says the finding is real, the rover fixes it (fate 1) or, if cost outweighs value, applies fate 2 with a structured rationale.

**Fate 2 (cost-value-skip) does not trigger a second pride pass.** The structured rationale itself is the evidence: concrete output cost, concrete value, named canon-vraag from `rover`. "Bewuste keuze" without that structure is not a fate-2 rationale, it is a feeling, and feelings do not retire findings. "Out of scope" is never a fate-2 rationale inside an autonomous rover: scope is the Dispatch's job, not the rover's; the rover weighs output cost against value, not scope-fit. Neither is "pre-existing" or "not introduced by this mission" a fate-2 rationale: authorship and timing are not output-cost arguments, see `rover`'s "Origin is not a scope argument".

**The one exception: a fate-2 skip that cannot prove the finding is purely additive DOES get the second pass.** Fate-2 had no skeptic, and that is exactly where the opposite error lives: an author retiring a correction-toward-intent by calling it a marginal addition (the guard against scope-creep turned against a return-to-target). So extend the second-pass trigger by one case, in line with `rover`'s "Fate 2 is for ADDITIVE findings only": before a fate-2 skip on an end-user or technical finding is final, the rover must show the finding maps to no committed Done criterion, no state-pair, and no success-signal the Dispatch stated. If it cannot point at that absence, the skip is not the author's to make alone: run the second pass, asking the second reader one objective question against the original Dispatch text, "does the built artefact contradict this success-signal the operator wrote, or fail this distinguishability the Dispatch's states imply?" If yes, the fate-2 skip is invalid; the finding is an unmet Done criterion, back to DRIVE. Output cost is never a valid skip for a success-signal contradiction, the same way cost is never a valid reason to tick an unmet Done criterion. This does not broaden the second pass to ALL fate-2 skips (that would add ceremony without a forcing function); it fires only on the detectable trigger, a skip whose purely-additive proof the author cannot produce.

There is no operator-accept path for any fate. The operator is not consulted mid-mission. The rover does not retire a finding unilaterally outside the three fates, and the operator is not consulted to retire one either.

### Banned closing language

The following phrases are evidence the rover is handing off half-finished work. Any of them in an outbound artefact (commit messages, communiqués, PR descriptions, prose deliverables, mid-loop status lines visible to the operator) sends the rover back to DRIVE, no exceptions:

- "mostly works", "mostly done", "largely addressed", "grotendeels"
- "roughly done", "roughly complete", "a rough pass"
- "corners cut", "some corners", "hier en daar corners"
- "good enough for now", "good enough for v1", "good enough for this pass"
- "nits remaining", "kleine puntjes over", "small issues remain"
- "will follow up later", "later polish", "polish-for-later"
- "not quite there", "not fully done", "almost done"

The pattern these share: an acknowledgement that the work is not complete, paired with a suggestion that completion is optional. Pride rejects that combination in outbound artefacts. Either the work is complete or it is not; if it is not, every remaining item is a tracked finding routed through one of the three fates (see `rover`'s "Three fates").

These phrases are NOT banned inside the mission-internal fate-2 cost-value rationale blocks in the loop file's pride or gurus findings log. Inside that structure the same wording is the conclusion of a logged engineering call (concrete output cost, concrete value, named canon-vraag), not a hand-wave. Pride reviews outbound artefacts; the rover's own findings log is not an outbound artefact, so the structured fate-2 form is allowed there even when its words overlap with phrases banned elsewhere.

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
