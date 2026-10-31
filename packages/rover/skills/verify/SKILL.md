---
name: verify
description: >-
  Define rover Done criteria and gather evidence against each criterion.
user-invocable: true
argument-hint: "[--propose <loop-file> | <loop-file> | free text]"
effort: high
---

# Autonomous Verify

Evidence discipline for autonomous work. The operator is not watching, so every claim of progress or completion has to rest on something the operator could check without being present.

Two disciplines, one skill:

1. **Write Done criteria up front.** Before the rover starts building, it commits to what "done" looks like in concrete terms.
2. **Gather evidence against those criteria.** Actively verify each criterion by running, observing, or measuring. Report what is proven, what is unverified, what failed.

## Why this matters for an autonomous rover

Without Done criteria, the rover has no endpoint. It stops when it is tired, when tests happen to be green, or when the phase machine nudges it along. None of that is "finished." The operator reading the loop file later has no way to audit whether the work actually matches the original goal.

Without active evidence, the rover coasts on proxies: "CI green," "the code compiles," "the test file exists." None of these prove the feature does what the user asked for. Proxies are the autonomous-work equivalent of driving at night without headlights.

## Mode 1: propose Done criteria (`--propose`)

Invocation: `/rover:verify --propose <loop-file>` or called by rover at end of SURVEY.

1. Read the loop file's `## Dispatch`, `## Context`, and `## Plan` sections. Dispatch is the source of truth; Context is interpretation; Plan is the proposed deliverable.
2. **Plan-vs-Dispatch check (mandatory).** Compare the action verbs in Dispatch against the deliverables described in Plan. If Dispatch contains action verbs (build, ship, fix, port, install, deliver, enable, make work, implement) and the Plan only describes producing research, documentation, or analysis without naming the actual implementation as the deliverable, refuse to generate Done criteria. Log the mismatch, send the rover back to SURVEY to rewrite the Plan so it includes the actual implementation, and only then return to Done-criteria generation. The rover does not ask the operator to confirm research-only scope; the Dispatch's verbs are the answer. Always compare against Dispatch, never against Context alone; Context can itself have shrunk the dispatch.
2a. **Success-signal floor (mandatory).** The action-verb check above guards against the Dispatch shrinking. This step guards the opposite failure: a deliverable that faithfully executes the Dispatch's verbs yet misses the operator's actual target, because nothing transcribed how the operator recognises the result as working. Those recognition tests become Done criteria here at SURVEY, where the no-fate-2 floor already lives (see "Done criteria are not findings"), so a later finding that the deliverable fails one of them cannot be cost-value-skipped. Two sources, in priority order:
   - **State-pair distinguishability (the mechanical base, phrasing-independent).** If the Dispatch names two or more user-visible states, modes, or statuses (recording vs idle, loading vs ready, valid vs error, connected vs lost), write a Done criterion for EVERY pair: "state A and state B are distinguishable at a glance, not only by the colour, opacity, or animation of a shared mark." Range over every pair; never narrow a multi-state signal down to the subset that is easiest to satisfy (a criterion that covers three easy states while the operator's real concern was the fourth pair is exactly the narrowing this forbids). This base fires regardless of which words the operator used.
   - **Stated success-signals (recall booster on top).** Scan the Dispatch for wording where the operator states how the result reads as working: glance / at a glance / without inference / distinct / obvious / unmistakable / tell-apart / can't-confuse / "see which X we are in" / "must feel different" / "must be visible". Transcribe each verbatim into a binary, observable criterion phrased as the operator phrased it. This keyword list raises recall; it is not the floor. A success-signal phrased without any of these words is still caught by the state-pair base when it concerns states; the base, not the list, is the structural guarantee.
   - **Auditable coverage (anti-under-transcription).** Record under the criteria: the raw operator-goal quote, the success-signals extracted, the state-pair matrix, and an explicit "not extracted, because…" line for any nearby intent language deliberately left out. Under-transcribing to dodge a binding floor later must be visible on the operator's read, never silent. And "not transcribed into a criterion" must NEVER be treated downstream as "out of intended scope" when the original Dispatch text carries the intent; that only moves target-drift from the Dispatch into SURVEY.
3. Derive 3 to 10 criteria (plus every success-signal criterion from step 2a; those are floors, not counted against the cap). Each criterion is:
   - **Concrete:** names a specific file, command, endpoint, UI element, or observable state
   - **Observable:** you can run, see, or measure it, not just "know" it
   - **Binary:** either met or not met, not a spectrum
   - **Aligned with the Dispatch's action verbs:** if Dispatch says "make X work on Windows," at least one criterion must directly assert that X works on Windows. Doc-quality criteria alone (file exists, word count is high enough, formatting passes a lint) do not satisfy an action-verb dispatch.
4. Write the criteria into the loop file under `## Done criteria` (create the section if missing).

### Good vs bad criteria

| Bad | Good |
|-----|------|
| "The settings page works" | "`GET /settings` returns HTTP 200 when logged in as a user" |
| "Form validation is correct" | "Submitting the form with an empty name shows an inline error next to the name field, no DB write happens" |
| "Fast enough" | "`/settings` first-paint under 200ms at p95 on the staging box" |
| "Tests pass" | "`bin/rspec spec/settings_spec.rb` exits 0 with 12 examples, 0 failures" |
| "Looks good" | "Screenshot at 1440x900 shows form below header, no horizontal scroll, no overlap with nav" |

Vague criteria are how missions drift. The rover catches this up front by insisting on sharp ones.

## Mode 2: gather evidence (default)

Invocation: `/rover:verify <loop-file>`, or bare `/rover:verify` in a session where a loop file is obvious, or called by rover at end of INSPECT.

1. Read the `## Done criteria` section.
2. For each criterion, determine the verification tactic:

| Criterion type | Tactic | Evidence |
|----------------|--------|----------|
| Code runs | Execute it (unit test, script, CLI) | Command output, exit code |
| HTTP endpoint | `curl -sSv` with expected inputs | Status code, response body |
| UI element | Navigate and screenshot | PNG path + described observation |
| UI state change | Before and after screenshots | Two PNGs, described diff |
| DB mutation | Query the DB after the action | Row count, specific field values |
| File on disk | `ls` / `stat` / `cat` | Path + relevant content |
| Third-party integration | Trigger it, inspect the other side | Log entry, API response, webhook payload |
| Logged behavior | Run, grep the log | Matched log line with timestamp |

3. For each criterion, attach the evidence under its row in the loop file. Format:

```markdown
## Done criteria

- [x] `GET /settings` returns 200 when logged in
      Evidence: `curl -s -o /dev/null -w "%{http_code}" http://app.test/settings` → 200 at 10:14
- [x] Submitting empty name shows inline error
      Evidence: screenshot `/tmp/settings-empty-name.png`, error visible next to name field
- [ ] p95 first-paint under 200ms
      Unverified: no staging box available in dev. Ran locally only: 180ms average over 5 runs.
- [ ] Tests pass
      Failed: `bin/rspec` → 12 examples, 1 failure. See log.
```

4. Report a summary:
   - Criteria met with evidence
   - Criteria unverified (why, what would be needed to verify)
   - Criteria failed (what the evidence showed, next DRIVE target)

## Mode 3: standalone use

Outside a rover session, `/rover:verify "free text describing the work"` lets a user ask "did I really finish what I claimed?" for any recent work. The skill:

1. Asks for or infers a short Done-criteria list from the free text and the recent diff
2. Gathers evidence
3. Reports

This is useful after any non-trivial task, not just autonomous loops.

## Proxies are not verification

The rover is tempted by proxies because they are cheaper than real evidence. Reject them:

| Proxy | Why it fails | Real verification |
|-------|--------------|-------------------|
| "CI is green" | Tests a file I cannot run | Run the relevant scenario locally |
| "The code compiles" | Syntax check, not behavior | Execute the code path |
| "The test file exists" | File existence, not passage | Run the test, see it pass |
| "Curl returns 200" | Status code, not content | Assert on response body |
| "The feature should work" | Unchecked hypothesis | Run the feature end-to-end |
| "I followed the pattern" | Pattern imitation, not correctness | Prove this instance behaves |
| "No errors in the console" | Absence is not presence | Confirm the positive outcome happened |
| "The pipeline works on one example, so the matrix criterion is met" | Single-instance evidence does not satisfy a quantitative criterion | Run the full matrix, produce every output the criterion names, list each one |
| "The simulator boot loop would burn context, so I tick the criterion now" | Cost is a fate-2 candidate for findings; Done criteria have no fate-2 path | Produce evidence within the authorized budget or report the criterion unmet; never tick it to stop |

When a proxy is the only thing available, label it: `unverified, only proxy evidence: <X>`. Honesty beats a false green.

## Unmet criteria and negative results

Mark missing evidence `unverified: <specific reason>` and measured failures `failed: <evidence>`. Never substitute mocks for unmeasured model quality, silently remove a criterion or mark the product goal complete because an experiment ended.

A contradiction of a success signal in the original Dispatch remains an unmet criterion even if SURVEY missed it. Do not cost-value-skip that criterion into a success claim. Repair it within the authorized scope and budget when evidence supports a remedy. An explicit stop, exhausted budget or negative experimental stop condition takes precedence: preserve work and report unmet criteria without another DRIVE or review cycle. Follow host continuation status rules rather than inventing a successful or paused state.

Before another attempt after failure, require the observed cause, relevant change and falsifiable prediction. Rewording or a new reviewer alone does not meet that requirement. A failed hypothesis does not prove a universal capability limit and does not authorize a new research sequence.

## Anti-patterns

| Thought | What it actually is |
|---------|---------------------|
| "I'll verify at the end" | No you will not, you will run out of steam. Verify per change. |
| "This is too obvious to verify" | Obvious things fail too. 30 seconds of evidence beats 5 minutes of debugging later. |
| "Verification would take forever" | If verifying the mission takes longer than doing it, the mission is probably too big. Split. |
| "The tests cover it" | Tests are a form of verification, but rarely the full criterion. What did the user see? |
| "I already checked" | Show the evidence. If you cannot cite it, you did not check. |

## Quantitative criteria need quantitative evidence

A Done criterion that names a count or a matrix (`bin/capture-shots produces 40 PNGs`, `all 10 scenes render`, `both locales receive a preview`, `every endpoint returns 200`) is met only when every named instance is produced and listed. Proving the mechanism on one instance proves the mechanism; it does not prove the criterion. The two are not the same.

The temptation is structural: when the matrix is wide (40 outputs, hours of simulator boots, a long sweep) and the mechanism is verified on one example, the rover wants to upgrade "mechanism proven" to "criterion met" because the marginal cost of the remaining N-1 runs feels disproportionate to the marginal information. That trade is wrong twice. First, the criterion was committed to during SURVEY precisely because the matrix matters; the rover does not get to redefine the criterion at INSPECT to be the part it already finished. Second, the rover routinely discovers that the mechanism works on the first instance but fails on the second or third (a scene flag the schema does not expose, a locale-specific font fallback, a device-class path the mechanism hardcoded). The matrix runs are the discovery surface, not the formality.

If the full matrix has not run, mark the criterion unverified with the missing evidence. Do not infer a complete pass from one example. Continue only within the authorized scope and budget; a stop or negative experimental boundary ends execution with the criterion still unmet, without restarting DRIVE.

## Interaction with other skills

- **`decide`** picks which path to take; `verify` proves the chosen path worked. Complementary.
- **`pride`** asks "would the user hate this?" (contrarian, smell-finding); `verify` asks "did this do the thing?" (evidence-gathering). Different questions, no overlap. The rover runs both before declaring done.
- **`rover`** invokes `verify --propose` at end of SURVEY and `verify` (default) at end of INSPECT. A rover mission without Done criteria is not started; a rover mission without ticked criteria is not finished.
