---
name: drydry
description: >-
  Check "have I seen this before?" for duplicated logic, parallel paths, or work that feels familiar while being written as new, in code, prose, or design. Escalate when needed; use parity-audit for a whole-codebase audit of divergent entry points.
allowed-tools:
  - Skill
  - Agent
  - Bash(git status *)
  - Bash(git log *)
  - Bash(git diff *)
  - Bash(date *)
  - Bash(ls *)
  - Bash(find *)
  - Bash(grep *)
  - Bash(rg *)
  - Bash(wc *)
  - Read
  - Write
  - Edit
  - Glob
  - Grep
---

<post-update-broadcast>
BEFORE doing the actual work below, run this one-time check only when
`CLAUDE_PLUGIN_ROOT` is set:

```bash
if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; then
  node "${CLAUDE_PLUGIN_ROOT}/bin/check-broadcast"
fi
```

If the command produces output, the drydry plugin was updated since
the last time you saw the broadcast on this machine. Show the output
verbatim in a markdown block, prefixed with one short sentence
("drydry was updated; here is what changed."). Then continue with
the rest of this skill.

If the command produces no output, say nothing about updates and proceed.

The helper writes the sentinel only when stdout was non-empty, so a silent
run does not mark the version as seen. In agents that do not set
`CLAUDE_PLUGIN_ROOT` the broadcast is intentionally skipped; use
`/whats-new drydry` in Claude Code to re-show the section on demand.
</post-update-broadcast>

# Drydry Orchestrator

"Is dit een dubbeling?" becomes a discipline with a runbook, not a vibe-check. This skill is the **short** of the plugin's two user-invocable surfaces: you are looking at something concrete and want to know whether it already exists. It routes between two modes and dispatches the six agent-only sub-skills that do the substance.

The **long** surface is `drydry:parity-audit`: a named background process that sweeps every entry point in a codebase, compares what each does after the shared step, and re-runs itself to prove the divergence moved. Reach for that one when the question is not "is this duplicated?" but "do all the ways to do this actually do the same thing?".

The framework rests on eight concepts (see `README.md` for the full text): Type-4 clone framing, verifier-burden discipline on LLM-found hits, allow-list scoping via checklist, drift hypothesis per finding, three-bucket convergence triage, two-fates discipline, contrarian second-pass on rejects, detection method as first-class artefact. The orchestrator does not enforce all eight in every invocation; quick mode skips the heavier discipline because the scope does not need it. Audit mode applies all eight.

## Routing

Two modes. The orchestrator picks one before doing any work. The decision rules are the table below; the rationale and edge-case prose follow as commentary.

| # | Signal (from args or context) | Route to |
|---|-------------------------------|----------|
| 1 | `args` contains `quick` or `mode: quick` | quick mode |
| 2 | `args` contains `audit` or `mode: audit` | audit mode |
| 3 | `args` contains `sweep` / `checklist` / `triage` / `learn` / `upstream` / `instructions`, or `skill: <name>` | dispatch that sub-skill directly with the remaining args as its input |
| 4 | `args` or context paste names two snippets, one file, or a transcript excerpt | quick mode |
| 5 | `args` or context names a directory, package, or project root | audit mode |
| 6 | Operator phrasing is ad-hoc ("is dit dubbel?", "did I just write this?", "are these the same?") | quick mode |
| 7 | Operator phrasing suggests breadth ("walk the project", "find parallel paths", "full sweep") | audit mode |
| 8 | Operator names a domain hint (Swift, Rails, prose, design-tokens) | audit mode |
| 9 | None of the above | ask once (see "No signal" below) |

Rules 1-3 are checked first and short-circuit; rules 4-8 are inspected in order and the first match wins; rule 9 is the fallback. The autonomous-caller path overrides rule 9 (see "Skill-invoked" section).

### Rationale and edge cases

Beyond `args`, inspect recent activity with the host's read-only shell commands such as `git status`, `git log`, and `git diff` when that context helps rules 4-8.

### Default and override

Present the chosen mode in one short line before dispatching. Example:

> Two snippets in scope, no explicit mode keyword. Routing to **quick mode**. Type `audit` to switch to the full pipeline.

Or:

> Directory `app/models/` named, no explicit mode keyword. Routing to **audit mode**. Type `quick` to switch to an inline check.

When `args` carries explicit intent (the keyword above), skip the proposal line and dispatch immediately.

### No signal

When `args` is empty and the conversation gives no clear scope, ask one short question:

> Two modes available: `quick` for an inline check on a small scope, `audit` for a full sweep producing a findings artefact. Which fits, and what is the scope?

Ask this question **once**. The answer is binding; do not confirm again.

## Quick mode

Cheap, scoped, no artefact. The goal is to answer "are these two paths a duplicate?" in the operator's working session, with enough rigour that the answer is not a vibe-check but also not the full eight-chapter discipline.

Steps:

1. **Identify the two (or more) candidates.** Read them: the paste, the named files, the transcript excerpt. If the operator named only one item, ask the operator to point at the suspected duplicate. (Do not invent the comparison target.)

   **Feature-with-two-faces widening (mandatory).** When the candidate is a *feature* rather than a single function or string (a button, a flow, a notification, a list-with-detail surface, anything that has both an underlying mechanism AND a user-visible presentation), drydry quick mode sweeps BOTH axes automatically, not just whichever side the operator named. The failure mode this catches: a question phrased about a feature (a share button, a status badge, a confirmation dialog, a deep-link, anything with both faces) maps verbally to one axis (usually the backend service or URL builder behind it), the session finds the canonical helper, declares reuse achieved, and then writes a fresh chrome for the other axis without realising that chrome too has prior art elsewhere in the codebase. A feature has both a backend axis (service, helper, formatter, validator, query, endpoint) and a frontend axis (component, partial, chrome, class-name combination, accessibility label, icon choice, hover state, focus state). The skill names BOTH and runs the candidate-pairing test on each before producing a verdict. When only one axis turns out to apply (a pure-backend service call with no UI surface; a pure-UI styling tweak with no logic), say so explicitly in the verdict; do not silently drop the other axis.
2. **Apply the drift-hypothesis test (Chapter 4).** Write one sentence: "what bad thing happens if these two paths keep drifting?" If the sentence is "the code is a bit messy" or "it would be cleaner to share", the finding is not yet sharp enough. For a human caller, push back: "I do not see a drift hypothesis here. Sharpen the question or accept that this is style overlap, not a duplicate." For an autonomous caller (skill-invoked path), do not push back; record the weak-hypothesis state in the returned markdown under a `weak_drift_hypothesis: <reason>` line and continue. Autonomous callers do not have a channel to answer push-back.
3. **Apply the verifier-burden discipline (Chapter 2).** Produce one runnable command (a `grep`, `rg`, `ast-grep` query, or a `find ... -exec` pair) that re-verifies the duplication without the LLM in the loop. Show the command and its expected output.
4. **Verdict.** One paragraph. Three possible verdicts:
   - **Duplicate, cheap-and-safe to converge.** Name the convergence direction in one sentence and the cost.
   - **Duplicate, but needs design.** Name the open question that has to be resolved before convergence (which side wins, what to name the unified abstraction, how callers migrate).
   - **Not a duplicate.** Explain why the structural similarity does not imply a shared behaviour contract.
5. **Side quests, if any.** If the inspection surfaced something out-of-scope ("we should also look at X", "Y feels related"), list it as a side quest. Do not detour to address it now.

Output is inline conversational, no markdown file. Broader review gates do not run in quick mode; the scope does not warrant the cost.

## Audit mode

Full eight-chapter discipline. Produces a `<scope>-drydry-findings-<checklist-version>.md` artefact in the current working directory. The independent contrarian second-pass on rejects (Chapter 7) is mandatory. Broader panel review is **deferred to a follow-up decision** (see Side quests).

**The drydry plugin is a methodology guide, not a pattern enforcer.** It owns the eight-chapter discipline (drift hypothesis, verifier-burden, allow-list scoping, Type-4 framing, contrarian second-pass, two-fates discipline, three-bucket triage, detection-method-as-artefact); it does **not** own a canned list of what duplication looks like in your codebase. The calling session has the codebase in front of it; the plugin does not. The session formulates the checklist for the audit; the plugin disciplines how that checklist is used.

**`drydry:learn` is not part of the audit pipeline.** It is a one-off enrichment that updates the discipline's external vocabulary (research write-ups, framework-specific conventions) and is invoked explicitly via `/drydry:drydry learn <topic>`. Audit mode does not trigger a fresh `learn` itself.

Steps:

1. **Resolve scope.** Read what the operator named: a directory, a glob, a package, a project root. To gauge size, first discover which extensions are in scope (`find <scope> -type f | sed -E 's/.*\.//' | sort -u`), then run `wc -l` against the matching files (`wc -l $(find <scope> -type f \( -name '*.swift' -o -name '*.rb' \))` substituting the extensions you discovered). If the scope is unclear, ask once.

2. **Formulate the checklist (the calling session does this work).** Drydry does not hand the calling session a canned list of patterns. Instead the orchestrator instructs the calling session to read the scope and formulate a six-to-ten item duplication checklist by walking these formulation prompts against the actual codebase:

   - **Canonical-channel bypass.** Which domain values in this codebase have a canonical formatter, view component, or helper (a `LicensePlateFormatter`, a `MoneyView`, a `with_tenant` wrapper)? For each, where in the codebase is that domain value rendered, logged, spoken, or interpolated *outside* the canonical channel? Sweep the call-sites: not just View-bodies, but also accessibility labels, confirmationDialog messages, alert titles, AppIntent display labels, log lines, push notification bodies, email subjects, anywhere the value is shaped for a human or for another system.
   - **Parallel utility functions.** Which utility-shaped functions exist in two or more different forms (`format_date_short` and `format_date_compact`; two `current_user`-shaped helpers; two `with_tenant` wrappers)? For each pair, what is the drift hypothesis if they stay divergent?
   - **Predicate pairs.** Which predicates encoding the same condition appear under different names or in different shapes (`active` / `enabled` / `not_archived`; `is_admin` / `has_admin_role`)? Predicates are particularly drift-prone when a model adds a soft-delete column and only half the call-sites learn.
   - **Repeated boilerplate around a framework seam.** Which framework-mediated entry points (AppIntent `perform()`, ActiveJob `perform()`, controller actions, route handlers, hook bodies) have copy-pasted context-resolution, error-mapping, or result-shaping logic across siblings?
   - **Commit-history clusters.** Run `git log --oneline -- <scope>` and look for clusters of commits whose messages name the same concept in different places ("refactor `X` extraction in module A", a week later "extract `X` helper in module B"). Repeated refactors of the same concept across files are evidence that one canonical implementation was never written.
   - **User-facing copy with structural variants.** Which user-visible strings (confirmation copy, error messages, empty-state text) appear in two or more variants that solve the same UX need? Drift here erodes design-system consistency. Discovery heuristic: grep across the localisation files (`Localizable.strings`, `en.yml`, `i18n/en.json`, `messages.properties`) for keys with overlapping prefixes (`confirm.`, `dialog.confirm.`, `confirmation.`), and across the codebase for inline literals (`Text("Are you sure")`, `t("dialog.confirm")`, `<button>OK</button>`). Two strings solving the same UX need are duplicates even when the wording differs by a word.
   - **Parallel surfaces for the same UX need.** Which UX needs (confirm-destructive-action, present-warning, request-input) are solved with two or more presentation surfaces (sheet + popover + alert; modal + drawer) without a documented "which one when" rule?
   - **Off-template patterns specific to this project.** What patterns does *this* codebase have that no general checklist would name? Discovery heuristic: skim the project's top-level directories and `git log --oneline | head -200` for nouns that recur in commit subjects without belonging to a standard framework concept (a custom routing convention, a homegrown event bus, a specific data-shaping idiom, a domain-specific synchronisation primitive). Each recurring noun is a candidate pattern; ask "if two files implemented this concept differently, would drift hurt?" and add a checklist entry when the answer is yes.
   - **Parallel orchestrations.** Which domain actions in this codebase have two or more entry points (AppIntent `perform`, controller-action, background job, store-method, CLI command and HTTP endpoint, scheduled job and UI button) that each orchestrate their own preflight stack of domain steps above a shared leaf-call? For each candidate, list the steps every entry point runs before reaching the leaf and lay the lists next to each other. Drift hypothesis: what specifically breaks when these stacks drift? "A bit messy" is the rejected register; the failure modes that earn the finding are auth-strategy asymmetry between branches (one logs in upfront, the other relies on a lazy retry inside a session-retry wrapper), re-implemented cleanup that is applied on one side and never propagates to the other, missed edge-case handling on one branch that the other branch carries, and week-by-week drift where a fix in one entry point is silently absent in the other. Verifier signature: a single `rg "<shared-leaf-call-name>"` across the scope must surface every entry point; more than one hit inside the same domain action is the signal. Verifier-burden discipline (Chapter 2) stands but is honestly scaled here: the grep proves both sides exist and is a hard gate, the drift hypothesis carries the weight of misalignment because the misalignment lives in reading the N call-site environments, not in the grep alone. A heavier drift hypothesis is allowed to buy a second reading step, on the condition that both sides of the pair are anchored by a single greppable leaf-call name. Illustrative shape (Swift / iOS): a `StartSessionIntentHelper.executeStartSession` (AppIntent path) and a `SessionEngine.startResidentSession` (in-app accessory bar) both end in `SessionAction.beginSegments(...)`; the AppIntent branch relies on a `withSessionRetry` wrapper around the leaf, the in-app branch does `ensureLoggedIn()` upfront, and a fix to one side's preflight stack stays invisible to the other, so one path surfaces a "session expired" notification to the user while the other path succeeds. The full anonymised fixture lives at `packages/drydry/test/orchestrations/fixture-orchestration-pair.md`.

   The calling session writes the checklist as markdown in the same shape `drydry:sweep` consumes: six to ten items, each with `pattern_id`, short title, one-paragraph description, grep-friendly signatures. Stamp the checklist with `v<YYYY-MM-DD>T<HH>-<MM>` from `date +%Y-%m-%dT%H-%M` so the audit artefact can cite it (Chapter 8). Six to ten is a sharpness target, not a hard rule. **Minimum evidence before declaring step 2 complete: every formulation prompt is either answered with at least one checklist entry or explicitly logged as "not applicable to this scope" with a one-sentence reason.** Skipping a prompt silently is the failure mode step 2.5's contrarian pass is designed to catch; declaring "no applicable patterns" is allowed but only with the reason on record. **Hard ban: the calling session does not load a canned template from `drydry:checklist` by default.** The whole point of this step is that the session has read the codebase and shaped the list to what is actually there. A canned template is the opposite of that work.

   When the operator explicitly asks for inspiration (`/drydry:drydry audit ... seed-from <domain>`, or the calling session lacks priors on the domain idiom), step 2 may dispatch `drydry:checklist` to fetch the seed examples for that domain (iOS/SwiftUI, Rails, React/TypeScript, Markdown prose, design tokens, generic) as a *starting point only*. The session still reads the codebase and rewrites or extends the seed before passing it to sweep; the seed becomes vocabulary, not verdict. Without the explicit `seed-from` keyword or operator request, checklist is not invoked.

2.5. **Contrarian pass on the checklist (mandatory).** A calling session that formulated its own list has every incentive to declare it complete. The author of the checklist is the author of any miss. Drydry closes that gap by running an independent contrarian pass against the formulated checklist *before* sweep runs. This is the analog of Chapter 7's contrarian-on-rejects, applied to the checklist itself, and it is the structural floor under the Formulation step: the worse the calling session's priors (a rover with thin scope context, a session new to the domain idiom, a session under turn-budget pressure), the more value the contrarian recovers.

   Use the host's native independent-review capability. In Claude Code this can be an Explore subagent via the Agent tool; in Codex use native subagents when exposed, otherwise perform a separate deliberate pass in the current session and record that limitation in `## Detection method chosen`. The reviewer must have read/search access to the scope and must walk the scope independently, not reason about the calling session's checklist in isolation. Independent codebase access is what makes step 2.5 an omission detector rather than a logical-consistency checker. Pass the scope path, the formulated checklist, and this brief:

   > You are reviewing a duplication checklist for a codebase you have direct read access to. The calling session formulated this list by reading the scope; your job is to walk the scope yourself and find what the list is failing to name. You are not reasoning about the prompts in the abstract; you are grepping the code, reading files, and producing concrete file:line evidence.
   >
   > For the checklist below, find:
   > 1. **Domain-value drift the list missed.** Are there canonical formatters, helpers, or view components whose call-sites the list does not audit? Walk the scope: which domain values get rendered, logged, spoken, or interpolated outside their canonical channel, in shapes the checklist did not name?
   > 2. **Off-list patterns visible in the scope.** Are there duplication shapes you can grep right now that no checklist entry would catch? Name them with file:line evidence and grep signatures.
   > 3. **Entries that are too narrow.** Is any checklist entry phrased so tightly that obvious variants will fall outside it? An entry "raw plate text in `.text()` modifiers" misses `.confirmationDialog(...)`, `accessibilityLabel`, `LocalizedStringResource` and AppIntent display labels carrying the same value.
   > 4. **Entries without a usable grep signature.** Every entry must be greppable. Flag any entry whose signatures will not actually run.
   > 5. **Parallel orchestrations above a shared leaf-call.** Are there domain actions in the scope with two or more entry points (AppIntent, controller-action, background job, store-method) that orchestrate parallel preflight stacks above a shared leaf-call? Pick candidate leaf-call names (the final network or database call inside the domain action) and run `rg "<leaf-call-name>"` across the scope; open every call-site that comes back and lay the preflight stacks next to each other. Flag pairs whose orchestrations drift in shape or in discipline (auth strategy, cleanup placement, edge-case handling).
   >
   > Return either a list of additional pattern entries to merge (with grep-friendly signatures and one-paragraph descriptions) OR an explicit "no additional forms found" with at least three sentences naming what you examined and why the list is complete. Vague "looks good" is rejected.

   The orchestrator reads the contrarian's reply:

   - **Additional entries returned.** Merge them into the checklist and log the merge in the artefact's `## Detection method chosen` paragraph. The merged checklist is what sweep runs against.
   - **"No additional forms found" with concrete justification (at least three sentences naming what was examined and why the list is complete).** Log the contrarian pass and the justification in the artefact. Sweep proceeds against the unchanged checklist.
   - **Mixed reply (some concrete additions plus conversational tail).** Extract the concrete additions, merge them, log the merge. Discard the conversational tail; do not treat it as findings.
   - **Vague "looks good" without specifics, or a reply whose only "additions" are restatements of existing entries.** Re-run the contrarian once with a sharper brief naming a specific gap to probe (for example "you did not address App Intents; does the scope contain any?"). If the second run is also vague or hollow, log the contrarian pass as inconclusive and proceed; the audit artefact's `## Detection method chosen` paragraph records the inconclusive verdict so a follow-up audit can sharpen the formulation. Do not loop more than twice.

   This step is non-negotiable. A calling session that produced its own checklist without a contrarian pass is a template-canning audit waiting to happen: discipline on the discipline of how findings are handled, no discipline on what the discipline is allowed to see.

3. **Dispatch `drydry:sweep`.** Pass the scope and the (now contrarian-reviewed) session-formulated checklist. The sub-skill uses an independent detection pass with verifier-burden discipline; hits without a runnable verifier are dropped. The sub-skill returns a findings list with tuples `(pattern_id, file_a:line_a, file_b:line_b, drift_hypothesis, verifier_command)`.

4. **Dispatch `drydry:triage`.** Pass the findings list. The sub-skill classifies each finding into cheap-and-safe / partial / needs-design with a one-line cost note.

5. **Apply Chapter 7 (contrarian second-pass on rejects).** For every finding the sub-skill classified as `needs-design` (which includes the `by-design` sub-case where convergence is blocked by a framework or external API), run a second independent contrarian pass with this brief: "is this rejection hollow?" A reject is final only if the contrarian independently confirms it as hollow.

6. **(Optional) Dispatch `drydry:upstream`.** When the operator named a framework (Rails, Devise, SwiftUI, React) or when the project has a recognisable manifest (Gemfile, Package.swift, package.json), include a cross-toolbox section: does the operator have helpers that duplicate framework functionality?

7. **(Optional) Dispatch `drydry:instructions`.** When the project has agent instruction files (`AGENTS.md`, `CLAUDE.md`, or equivalents), include an instruction-file audit section: do the instructions themselves cause DRY violations?

8. **Write the artefact, including the checklist itself.** Two files are written in the current working directory:

   - `<scope>-drydry-checklist-<version>.md` contains the session-formulated checklist after the step 2.5 contrarian merge, verbatim. The checklist is its own artefact, not an ephemeral intermediate. Persisting it lets a second audit run on the same scope diff against the first checklist (catching vocabulary drift between developers and between weeks), and lets a reader of the findings file see exactly what the sweep was allowed to look for.
   - `<scope>-drydry-findings-<checklist-version>.md` carries two sections. `## Detection method chosen` records the checklist version, who formulated the checklist, the formulation prompts that produced entries versus the ones logged "not applicable", the contrarian's verdict on step 2.5, the sub-skills invoked, and the verifier conventions (Chapter 8). `## Findings` has one subsection per checklist item with the verified hits, drift hypotheses, triage, and contrarian verdict if applicable. Add `## Checklist gaps` when the sweep surfaced "interesting but off-list" hits (Chapter 3 keeps them out of the findings proper). Add `## Side quests` when out-of-scope follow-ups surfaced.

   The two filenames share the version timestamp so they can be read together; two audits against the same scope in the same session produce two pairs and do not silently overwrite.

9. **Report.** One short summary to the operator: scope, number of findings, triage breakdown, path to the artefact.

The artefact is written to the project root by default, named `<scope>-drydry-findings-<checklist-version>.md` (matching step 8 above), where `<scope>` is a slug of the directory or package the audit covered. The operator decides whether to convert findings into commits, or to address them out-of-process; that decision is not the orchestrator's.

## Skill-invoked (autonomous callers)

When this orchestrator is invoked by another skill rather than typed by the operator (a rover at INSPECT, an auto-loop, or any future caller that passes context through `args`), the operator is not in the loop and cannot answer a routing question. Routing must complete from `args` alone.

Detection: `args` carries explicit mission context as a single prose string (not a structured dict). The string carries some combination of a scope, a checklist, a mode keyword, a domain hint, a directory path; the orchestrator parses keywords out of it. Examples that route correctly: `"audit packages/somerepo/src/ for SwiftUI duplication"`, `"audit packages/somerepo/src/ seed-from ios-swiftui"`, `"quick: are these two files duplicates? <path1> <path2>"`, `"sweep packages/somerepo/src/ with this checklist: ..."`. Treat any non-empty caller-supplied context as the autonomous path.

Rules in this mode:

- **Never ask the operator.** The "ask once" fallback in the No-signal section does not apply. If the implicit signals are weak, pick a default and dispatch.
- **Default when ambiguous:** if `args` references a directory, package, or multi-file scope -> audit mode; if `args` references two snippets, one file, or a transcript excerpt -> quick mode; if `args` names a sub-skill explicitly, dispatch that sub-skill directly.
- **Caller-named mode wins.** `mode: quick` or `mode: audit` in `args` (or the equivalent bare token `quick` / `audit`) bypasses inference. The Routing section above lists both forms as equivalent; either is accepted here too.
- **Caller-named sub-skill wins.** `skill: sweep` (etc.) in `args`, or the bare token `sweep` / `checklist` / `triage` / `learn` / `upstream` / `instructions`, dispatches that sub-skill directly with the remaining args as its input.
- **In audit mode, the calling skill is responsible for the Formulation step.** The orchestrator does not bootstrap a checklist for autonomous callers any more than it does for human operators; the caller reads the scope and writes the checklist before dispatching sweep. Autonomous callers that want the baked seeds as a starting point pass `seed-from <domain>` in `args`.
- **The contrarian-on-checklist pass (step 2.5) is the autonomous caller's safety net.** A rover at INSPECT or any other agent caller will reliably produce a thinner checklist than a human operator who has been in the codebase for hours, because the caller has not lived in the scope the way an operator has. Step 2.5 runs anyway. The contrarian reviewer reads the scope, the caller's formulation gets audited against the actual code, missing forms get merged in. The structural floor is the contrarian pass, not the calling session's priors. Skipping step 2.5 is what produces a template-canning miss; the orchestrator does not skip it.
- **No proposal line, no override prompt.** Produce the verdict or the artefact directly.
- **Broader review gates** are the caller's responsibility, not the orchestrator's. A rover at INSPECT has already scheduled its own review passes; the orchestrator does not double-up.

The contract: a skill-invoked call always produces a verdict (quick mode) or an artefact (audit mode) and never bounces back a question.

## Sub-skills

| Sub-skill | When the orchestrator dispatches it | When the operator may hint it |
|-----------|-------------------------------------|-------------------------------|
| `drydry:sweep` | Always in audit mode (step 3) | When the operator already has a checklist and wants the detection pass directly |
| `drydry:checklist` | Only when the operator passes `seed-from <domain>` or the calling session explicitly requests inspiration. Never the audit-mode default. | When the operator wants the baked seed templates for a new domain as a starting point ("/drydry:drydry seed-from rails") |
| `drydry:triage` | Always in audit mode (step 4) | When the operator already has a findings list and wants it triaged |
| `drydry:learn` | Never in a normal audit run; this is a one-off enrichment | When the operator says "wat zegt de wereld over duplication?" or "update the discipline's external vocabulary" |
| `drydry:upstream` | Conditionally in audit mode (step 6) when a framework is detected or named | When the operator says "audit alleen tegen Rails/SwiftUI/React conventies" |
| `drydry:instructions` | Conditionally in audit mode (step 7) when agent instruction files exist in scope | When the operator says "audit alleen mijn instructies" |

All six are agent-only (`user-invocable: false`). The operator never types `/drydry:sweep`; the operator types `/drydry:drydry sweep <scope>` or hints the sub-skill in their prompt and the orchestrator routes.

## Rules

- **Routing is fast.** At most one question before dispatching. A second question is a failure mode.
- **Explicit intent wins.** When `args` names a mode or a sub-skill, skip the proposal line.
- **Do not detect duplicates yourself.** The orchestrator routes and writes the artefact; detection happens in `drydry:sweep`. Stay neutral on which findings are "real".
- **Quick mode does not run broader review gates.** Audit mode runs Chapter 7's contrarian second-pass on rejects; panel review is a deferred decision (see Side quests).
- **Hits without a runnable verifier are dropped.** This is enforced in `drydry:sweep`, not here, but the orchestrator may discard a hit that resurfaces without one.
- **The drift hypothesis is the gate.** A finding without a sharp drift hypothesis is not a finding; it is style overlap. Both modes apply this.
- **Verifier proves existence, not semantic equivalence.** The runnable command (`grep`, `rg`, `ast-grep`) confirms both locations exist; it does not confirm the drift hypothesis is real or that the two paths share a behaviour contract. Every finding is a candidate until a human reads both paths. False positives are most common in the Type-4 case (semantic equivalence claimed across structurally different code); the verifier alone cannot catch a wrongly-classified semantic match.
- **A clean report is scoped to the checklist, not to the codebase.** Chapter 3's allow-list discipline means the sweep finds only what the checklist names. Zero findings on a sharp checklist proves the listed patterns are absent; it does not prove the codebase has no duplication. The `## Checklist gaps` section in the artefact is the signal that the checklist needs extending in a follow-up sweep.
- **The calling session, not the plugin, formulates the checklist.** The plugin owns the discipline (allow-list scoping, verifier-burden, drift hypothesis, the rest of the eight chapters); the session owns the substance (which patterns this codebase has). A canned-template default produces predictable misses (the SwiftUI seed only knew View-rendering, so a SwiftUI audit on 2026-05-15 missed four user-facing String builders carrying raw plate text outside the `PlateBadgeView` formatter). The Formulation step exists to prevent that failure mode. Seed templates remain available via `drydry:checklist` for explicit opt-in, but the default audit reads the codebase first.
- **The checklist itself goes through a contrarian pass before sweep.** Step 2.5 is the structural floor under the Formulation step: an independent reviewer with read access to the scope reads the calling session's checklist and surfaces what the list is failing to name. The contrarian gate prevents the predictable failure of the Formulation step (a session that under-formulates declares its own work complete) by giving an independent reader veto power before sweep commits to a narrow scope. The relationship to Chapter 7 is symmetric: Chapter 7 audits the rejection of findings, step 2.5 audits the omission of findings. Both are mandatory; neither is for token budget.

## Side quests (deferred decisions, do not address in this skill)

- **Broader review gates on `drydry:drydry` itself.** Quick mode skips them for cost reasons; audit mode runs the Chapter 7 contrarian pass on rejects but not on the whole artefact, and panel review is not invoked at all. The full artefact and public-surface review gates the rover applies at INSPECT do not apply when a human operator types `/drydry:drydry` directly. Decide whether to add them once the plugin has seen real use.
- **Out-of-process follow-ups.** When a finding's convergence has to happen out-of-process (a separate session, a separate mission), the artefact currently logs it under `## Side quests` without a structured handoff format. Concrete trigger to formalise: the first audit run where the operator triages a finding as cheap-and-safe but names a separate session for the convergence work. At that point, add a structured handoff format (mission slug, scope, evidence pointers) to the artefact template.
