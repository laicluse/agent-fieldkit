---
name: testing-philosophy
user-invocable: false
description: >-
  Use when writing tests, debugging failures, reviewing test strategy, or judging suite health.
---

# Testing Philosophy

Principles and conventions for testing. The core principle: specs are specifications of expected behavior, written before the implementation exists. Not verifications after the fact. That distinction drives everything that follows.

## Specs specify, they do not verify

RSpec calls it a "spec" for a reason: it is a specification, not a test. The spec defines what "done" means before any code is written. Derive expected behavior from the requested use and the caller's contract before choosing assertions. A passing spec demonstrates the cases it exercises; it does not establish that the expectations or coverage are sufficient.

**NEVER write implementation before you have seen a failing spec.**

This is not optional. This is not "where possible". This is ALWAYS, for every feature, every bugfix, and every interface change.

**Workflow:**
1. **Red**: Write spec that specifies expected behavior -> must FAIL
2. **Green**: Implement minimal code to make the spec pass
3. **Refactor**: Clean up with green specs as a safety net

**For bugfixes:**
- Write a spec that reproduces the bug (fails)
- Fix the bug (spec turns green)
- Verify by reverting the fix -> spec MUST fail again

**For interface changes (renames, columns, constructor signatures):**
- Write the spec with the new interface (fails against the old code)
- Update the implementation (spec turns green)
- "Mechanical" and "trivial" are not exemptions

**This always applies.** Even for "trivial" changes. Even for "urgent" fixes.

**One exception: purely cosmetic changes.** CSS classes, colors, spacing, font sizes, and other visual styling do not need TDD coverage. Specs that assert specific CSS classes or design tokens make the spec harness too rigid for evolving design insight. Specify behavior, not presentation.

**RED -> GREEN -> REFACTOR is a continuous flow.** Do not pause between phases to ask for permission. If the user has given an instruction ("fix dit", "pas dat aan"), run the full TDD cycle without stopping. The only pause point is AFTER the cycle, when the result is ready for review.

## Keep specifications anchored to the requested behavior

The requested behavior bounds the work; specs express it. A missing spec for a requested outcome is a coverage gap, not permission to omit that outcome. Add the missing specification before implementing it. Do not invent requirements to justify extra tests or implementation.

## Scar tissue

The general discipline, cutting the residue of iterative fixing from any deliverable, lives in the scar-tissue skill; this section is its test-specific species: defensive test material that exists because of a past wound rather than a present requirement. A scar is justified while the wound can reopen; once the anatomy has changed so it cannot, the scar is bloat that the suite drags along forever. Species under this umbrella:

- **Absence pinning** (see below): asserting that something removed stays removed.
- **Test case hoarding**: every bug, incident, or review remark becomes a permanent test, with no pruning judgment, until the suite is too noisy to mean anything.
- **Phrasing pinning**: asserting exact wording or structure of output where only the function is the requirement; the spec then breaks on every harmless rewording.

The test of a scar is the wound: can you name the failure this spec still protects against, in terms of behavior the system has today? If yes, it is a guard. If the answer is "it went wrong here once", it is scar tissue. Bug reproductions are mandated by this philosophy and remain while they uniquely specify a current behavior or risk. A diagnostic stitch is different: it only proves that a superseded interpretation is no longer applied. During Refactor, remove it when positive coverage owns the behavior; otherwise rewrite it to guard the current requirement or risk. Turning GREEN does not make it a permanent spec.

Pruning a spec that predates the current change is deliberate and per-spec: name the spec, name why its wound is closed, and remove it in its own commit. A diagnostic stitch introduced by the current change is resolved within the same TDD cycle, before that atomic change is committed. Mass-deleting tests remains a smell (see below); scar removal at scale is a sign you are dodging failures, not curating a suite.

## Do not spec absence (absence pinning)

After removing a feature, the reflex is to assert the removal: `refute_includes`, `expect(...).not_to`, a spec that the thing is gone. Resist it. The space of things a system must NOT do is unbounded; a spec on one absence is an infinity-minus-one requirement that guards nothing while bloating the suite. Dijkstra's dictum is the root: testing shows the presence of behavior, never its absence. The removal itself is already proven by the diff and by the suite staying green without the removed feature's positive specs.

There is no single canonical name for this smell; the nearest established vocabulary is "negative requirements" (requirements engineering's untestable "shall not" clauses) and the scar-tissue family above. Working name here: **absence pinning**.

Two distinctions keep this honest:

- **A bug reproduction is not absence pinning.** A repro spec specifies correct behavior at one concrete input, even when phrased negatively ("does not raise", "does not double-charge"). It has a behavioral anchor. Absence pinning specs the non-existence of code or content with no behavior attached.
- **An exploitable leftover is a real requirement.** When the removed thing carries risk if it lingers (a revenue-affecting voucher path, an auth bypass, a vestigial endpoint customers might keep calling), an absence check is a deliberate guard. Name that risk in the spec description; if you cannot name it, the spec does not belong.

Red flag: "the test proves it was removed." Git proves it was removed.

## UI/UX bugs get end-to-end behaviour tests

When a bug involves user interaction (buttons, forms, navigation, confirm dialogs, status transitions in the browser): write a behaviour test in the project's end-to-end framework (Cucumber, Playwright, Cypress, XCUITest, RSpec system specs, whichever the project uses). Behaviour tests describe behavior from the user's perspective and exercise the full stack including the front-end runtime.

Unit specs are for server-side logic. End-to-end behaviour tests are for everything a user sees and does. The split is who-sees-it, not which framework.

## End-to-end coverage is not a substitute for unit specs on services, jobs, and stateful wrappers

A green Cucumber/Playwright/system-spec scenario proves that the happy path works through the full stack. It does not prove the internal contracts of any single layer it traverses. Error paths, status transitions, no-op gates, retry behavior, parameter passing across layers, and edge cases live below the e2e cursor and need their own RED-first specs.

The principle is broader than these examples: any class whose public surface
carries an internal contract (error classes raised, status transitions,
parameter forwarding, no-op gates, idempotency guards) needs a RED-first
unit spec, even when an e2e scenario covers the happy path through it. The
examples below name the artefact types where the trap is strongest, not the
complete set:

- **Service classes** (`app/services/<name>.rb`, `lib/<gem>/<service>.rb`, Swift `Sources/<Module>/<Service>.swift`, Go `internal/<service>/`). HTTP wrappers, third-party API clients, classifiers, parsers, generators, query objects, presenters: anything whose public surface is a few methods called from elsewhere in the app.
- **Background jobs and state machines** (`app/jobs/<name>.rb`, queue workers in any stack, Swift `BackgroundTask` subclasses, Rails `ActiveJob` subclasses). Status transitions (`queued -> running -> done | failed`), retry semantics, idempotency guards, no-op early-returns.
- **External-IO wrappers** (HTTP clients, SQL adapters, file-system adapters, shell-out wrappers). Connection errors, timeouts, malformed responses, unexpected statuses.
- **Value objects and configuration parsers** when they enforce invariants (validation, type coercion, equality semantics). A pure-data shape without invariants does not need a spec; one that rejects bad input does.

The unit-spec pass tests what the e2e cannot reach: every branch of the state machine, every named exception class, every parameter the wrapper forwards.

A spec written AFTER the implementation locks the spec to whatever the code happens to do, which is the opposite of what a spec is for. The behaviour discovered while writing the spec FIRST (which no-op gates are needed, which exceptions must be raised, which contracts cross the layer) is what shapes the implementation.

## Behaviour scenarios are domain documentation

When the project uses Gherkin-style scenarios: feature files describe behavior in domain language, not UI interactions. They are documentation that happens to be executable.

**Declarative (good):** `When I create a todo "Book a dentist appointment"` -> describes intent, survives UI redesigns.
**Imperative (forbidden):** `When I fill in the "title" field with "Book a dentist appointment" And I click the "Add" button` -> breaks on every UI change, reads like a test script rather than documentation.

The UI mechanics (which field, which button, hover for hidden elements) live in step definitions, not in feature files. When the UI changes, only step definitions change. The scenarios, and with them the behavior documentation, remain stable.

**BRIEF principles:** Business language, Real data, Intention revealing, Essential, Focused, Brief (~5 lines per scenario).

## Spec scaffolding is not progress

A scenario you write out but tag as `@wip` or otherwise exclude from the suite is not a spec. It is a wish list in code format. Step definitions that only throw `PendingException` are cruft from birth.

The TDD cycle starts at Red: a spec you have never seen run red has not completed the cycle. Write a scenario, implement the steps fully, watch it turn green. Then the next scenario. Never create multiple empty scenarios at once.

Feature files that consist entirely of unimplemented scenarios should not exist. If you are not working on that feature yet, do not write a spec for it. "Setting up the structure in advance" is planning disguised as code.

## Red Flags - You are rationalizing

If you catch yourself thinking these thoughts, STOP:
- "This is too simple to specify"
- "I'll write the spec later"
- "I'm just setting up the structure in advance"
- "I'll tag it as @wip, we'll finish it later"
- "Let me first check whether it works" / "Eerst even kijken of het werkt"
- "Let me check the implementation" / "Laat me de implementatie checken"
- "The user is in a hurry"
- "It's just a rename"
- "This is a mechanical change"
- "The e2e (Cucumber/Playwright/system spec) is green, the internals are infrastructure"
- "This is just a wrapper around an HTTP call / a job around a service"
- "The mission is spartan, fewer tests are fine" (spartan means no polish, never less measurement-of-done)

-> You are rationalizing. Write the spec first.

## Spec setup guidelines

Minimize spec-level memoization/setup. Prefer local variables within the spec itself.

## Default branch is always green

Never assume a spec might fail on the default branch. If it is on the default branch, it passes. When verifying behavior:
- Write a spec that captures the expected behavior
- When testing a fix, apply the fix locally, run the spec, then revert the fix to see the spec fail
- Never check out the default branch to "even checken of het daar ook faalt"
- When referencing the default branch, prefer the remote ref resolved from `origin/HEAD` since a local default branch may be stale

## Modifying specs is forbidden

A failing spec means: fix the CODE, not the spec. Never weaken a spec to make it pass.

**Exception:** Only when requirements have actually changed, and only after explicit confirmation from the user.

## Demo is not a spec

Manual verification (demos, console output, "let me try it" / "even proberen") is not proof that code works. Demo output varies and is not deterministic.

**Forbidden:** Running an application to verify that code works.
**Required:** Automated specs with predictable input/output.

## Reading code is not a spec

Reading source code to deduce whether something works is not verification. Grepping through implementation tells you what the code does, not whether the behavior is correct from the user's perspective. When the question is "does X work?", the answer is a spec that exercises X, not a code review that concludes it should work.

**Forbidden:** `grep`/`read` through handlers and queries to conclude that a feature works.
**Required:** Write a spec that exercises the behavior from the user's side. The spec is the proof.

## Flaky specs are an investment

**Definition of flaky:** Non-deterministic specs that are sometimes green, sometimes red without a code change.

**Flaky specs are NEVER acceptable:**
- Cost every team member time across all projects
- Erode trust in the suite
- Mask real regressions
- Investing in fixing them is always the right long-term decision

**Use "flaky" ONLY for non-deterministic specs:**
- Flaky: Spec fails sometimes due to race condition, timing issue, shared state
- Not flaky: Spec always fails due to missing mock/stub
- Not flaky: Spec always fails due to external dependency (API, database)
- Not flaky: Spec always fails due to incomplete implementation

**When you encounter a flaky spec:**
1. Stop current work
2. Gather context: spec path, command to run it, error output, failure rate
3. Hand the flaky spec off to a dedicated investigation, separate from the current work. The host arranges how (an independent agent, a sub-task, a separate session, an out-of-band run). What matters is that the investigation starts fresh with a complete brief:
   - Spec file path and line number
   - Exact command to run the spec
   - Error output from the last failure
   - Estimated failure rate (e.g. "fails ~30% of the time")
   - Hypothesis about the cause (race condition, timing, shared state, etc.)
4. NEVER automatically try to fix it during other work
5. NEVER "retry until green" or mask flakiness

## Failing specs block everything

When the suite has failures, the only correct response is: fix them. Do not deploy, do not commit, do not say "those are pre-existing failures". Failing specs are work, just like warnings. It does not matter whether they come from your change or already existed.

**Forbidden:** Proposing to deploy or commit while the suite has failures.
**Forbidden:** Dismissing failures as "pre-existing" or "not related to my change".
**Required:** Investigate failures, fix them, and get the suite green before moving on.

**Red Flags on spec failures:**
- "Seems unrelated to my changes" -> Irrelevant. It fails. Fix it.
- "Let me verify it's pre-existing" / "Laat me verifiëren dat het pre-existing is" -> The goal is fixing, not assigning blame.
- "This is a data issue, not [my thing]" -> Categorizing is not solving.
- "Quick check whether it also fails on the default branch" / "Even checken of het op default ook faalt" -> Even if it does, it is now your problem.
- git stash to prove it's "not yours" -> Wrong direction. Investigate the failure, not its origin.

**On CI failures that break unexpectedly:** When you discover that your changes break specs in places you did not expect, that is a signal that there may be more unexpected breakages. In that situation, run the full suite before committing the fix. Definitely do not amend a previous commit before you know the full picture is correct.

## Mass-deleting tests is a SMELL in refactors

When a refactor empties out an API, the behaviors the old tests documented still exist, just somewhere else. The tests must migrate with them, not be discarded. Concretely: do not remove a set of tests without identifying, per test case, where the behavior is now covered (another unit file, a Cucumber scenario, a Playwright script, an explicit `it.todo` with a reference). Cannot make that mapping? That is not a reason to thin, that is a blocker: the behavior is either gone without replacement (regression) or has become uncovered (gap in the safety net). A refactor diff that ends up ten lines larger is better than a test crash later. This applies even for a single test when it is the only piece of documentation for a behavior; it applies hard for any deletion pattern of more than a few cases at once.
