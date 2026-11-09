# drydry

Find and converge parallel paths in any artefact: code in any language, prose, design systems, technical documentation. The name nods to DRY (Don't Repeat Yourself); doubling the word reinforces that the framework is about *drying up* parallel paths that already exist, not the original aspirational principle.

The plugin's value: "is dit een dubbeling?" becomes a discipline with a runbook, not a vibe-check.

Use `drydry` when duplication is suspected but not obvious from identical text:
parallel code paths, repeated prose claims, design-system drift, or two
workflows that solve the same job through different routes.

## Installation

```bash
claude plugins install drydry@laicluse-agent-fieldkit
codex plugin add drydry@laicluse-agent-fieldkit
```

## How to invoke

Two user-invocable skills are available: `drydry` for duplication checks and `parity-audit` for divergence across entry points. The `drydry` orchestrator routes between two modes:

- **Quick mode**: ad-hoc "is this duplicate?" check mid-session. Inline answer with a runnable verifier-grep. No artefact. Trigger with `quick` in the prompt or by pasting two snippets, naming two files, or pointing at a recent transcript excerpt. Scope is whatever the operator explicitly hands over: pasted code, named files, or a one-line description of the suspected partner. The orchestrator does not search project history or memory; it inspects only what the prompt names.
- **Audit mode** (default for non-trivial scope): full sweep producing a `<scope>-drydry-findings-<timestamp>.md` artefact. `<scope>` is a slug of the directory or package the audit covered (for example `app-models-drydry-findings-2026-05-12T14-23.md`); the timestamp is the checklist version so two same-session audits do not silently overwrite each other.

### Artifact storage

Resolve purpose, audience and retention before writing. Quick checks stay inline. Temporary working files use host scratch space or an owned temporary directory and are removed after delivery. Audits retain their checklists, findings and parity baselines by default, together under `${LAICLUSE_HOME:-$HOME/.laicluse}/drydry/audits/<repository-key>/<run-id>/`, with distinct repository identities and exclusively allocated run directories. An explicitly disposable audit delivers its full checklist and findings inline before cleanup. Durable reports and knowledge follow the host’s canonical vault or documentation destination; repository storage requires intended project content. Record and link retained output from its owning context.

Research and checklist lookup share one `learnings_dir`, defaulting to `${LAICLUSE_HOME:-$HOME/.laicluse}/drydry/learnings/`. Framework review caches live under `drydry/cache/<repository-key>/upstream/` in the same user-state root. Creation, lookup and writing use the same resolved paths, including agreed overrides. `skills/drydry/references/artifact-storage.md` carries the operational rules for all writing tasks.

### Worked example: full audit invocation

Operator types:

```
/drydry:drydry audit app/services/ for duplicated service-object responsibilities
```

The orchestrator picks audit mode (rule 5 of the Routing table). It instructs the calling session to formulate the duplication checklist by reading `app/services/` against the formulation prompts (canonical-channel bypass, parallel utilities, predicate pairs, framework-seam boilerplate, commit-history clusters, user-facing copy variants, parallel UX surfaces, off-template project-specific patterns, parallel orchestrations above a shared leaf-call). The session writes a six-to-ten item checklist grounded in what `app/services/` actually contains. Then the orchestrator dispatches `sweep` over the scope with that session-formulated checklist, runs `triage` on the findings, applies the Chapter 7 contrarian gate to any `needs-design` verdicts, and writes `app-services-drydry-findings-2026-05-12T14-23.md` alongside its checklist at the destination resolved before the audit.

The Rails seed templates from `checklist` are available as a starting point if the calling session asks for them (`/drydry:drydry audit app/services/ seed-from rails`); the session then rewrites the seed against the actual codebase before passing it to sweep. The seed is vocabulary, not verdict.

The artefact has the shape:

```markdown
## Detection method chosen

Scope: `app/services/` (excludes `app/services/legacy/`)
Checklist: rails v2026-05-12T14-23 (seven baked patterns plus two
operator-named seeds, plus `devise-helpers` extension from Gemfile)
Detector: sweep (independent review pass), verifier-burden enforced
locally (every finding's verifier_command was re-run by sweep
before this artefact was written)

## Findings

### Pattern: service-objects -- overlapping responsibilities

- Finding 1
  - file_a: `app/services/user_creator.rb:8`
  - file_b: `app/services/user_onboarder.rb:14`
  - drift_hypothesis: both write to `users.signed_up_at`; the rename
    to `users.activated_at` planned for next quarter will update
    only one path, silently misreporting signup activation
  - verifier_command: `rg -n 'signed_up_at' app/services/`
  - triage: cheap-and-safe
  - cost: 3 files, 0 public symbols, mechanical (rename + share)

## Side quests

The audit surfaced an out-of-scope follow-up: the `UserSession` model
has its own activation logic in `app/models/user_session.rb:22` that
matches the same pattern but lives outside `app/services/`. Recommend
extending the next sweep to `app/models/`.
```

`## Side quests` is the channel for out-of-scope follow-ups the audit surfaced without addressing. They are findings the operator should fold into the next sweep, a separate mission, or simply file for awareness; the audit does not address them.

Six internal tasks, loaded from the orchestrator’s packaged reference documents, handle the substance. Two of them implement the eight-chapter framework directly: `sweep` (Chapter 2 verifier-burden detection), `triage` (Chapter 5 three-bucket convergence). Chapter 3's allow-list is formulated by the calling session itself against the codebase in front of it, guided by the formulation prompts in `drydry:drydry` audit mode step 2; the plugin disciplines how the list is used, not what is on it. `checklist` is an opt-in seed source that returns starting-point templates per domain when the operator passes `seed-from <domain>`. The other three internal tasks are extensions outside the eight chapters that the operator can dispatch when the duplication question crosses an axis the core pipeline does not cover: `learn` (online research enriching the discipline's external vocabulary), `upstream` (operator code versus framework offerings; particularly valuable for native-platform code where the standard library or framework often offers the helper the operator just hand-rolled), `instructions` (agent instruction files as a duplication-cause). The operator does not invoke any internal task directly; the orchestrator routes. The operator can hint an internal task by name in the prompt and the orchestrator will dispatch (`/drydry:drydry upstream` audits only against frameworks; `/drydry:drydry instructions` audits only the instruction layer; `/drydry:drydry seed-from rails` fetches the Rails seed templates from `checklist`).


## The eight chapters

The drydry framework rests on eight concepts. Three are established literature, two are local terminology (originating in the rover protocol), three are improvisation that holds under contrarian review. Each chapter applies across mediums (code, prose, design); the medium-translation paragraph after each chapter shows how.

### Chapter 1: Type-4 clone framing

**Established.** The standard taxonomy of code clones is four levels:

- **Type-1**: identical copies (whitespace and comments aside).
- **Type-2**: identical structure with renamed identifiers.
- **Type-3**: structurally similar with added or removed or modified statements.
- **Type-4**: same behaviour, different structure.

Token-based detectors (jscpd, PMD CPD, SwiftLint custom rules, Simian) are reliable for Type-1 through Type-3 because tokens carry the signal. They miss Type-4 by design, because semantic equivalence does not show up in the token stream. The Type-4 case is what hurts most over months in actively maintained codebases: token detectors miss it, so it accumulates invisibly, while Type-1 through Type-3 stay visible to existing tooling. Two stop-confirmation surfaces, two snapshot factories, two error-handling middlewares, two onboarding banners that drift apart copy-by-copy are typical shapes.

**Medium translation.** In prose: two paragraphs that say the same thing in different words across a chapter or a doc set. Token-detectors miss this because the wording is fresh; semantic-detectors find it. In design: two components that solve the same UX need (a confirm-action popover and a confirm-action sheet) with different visual languages. Visual diff tools see them as different; the user feels the inconsistency.

Sources: Roy and Cordy 2007 ("A Survey on Software Clone Detection Research", Queen's School of Computing TR 2007-541), plus a continuing line of embedding-based Type-4 detection work in the years since. See `learn` for a current literature sweep when a specific paper is needed.

### Chapter 2: LLM pass with verifier-burden discipline

**Improvisation, verified in practice.** Every LLM-generated finding arrives bundled with a runnable command that re-verifies the finding without the LLM in the loop. In code, that is a `grep`, `rg`, `ast-grep` query, or a `find ... -exec` pair pointing at the divergent files. In prose, it is a regex matching the duplicated semantic pattern across the markdown corpus. In design, it is the two component paths or the two Figma node IDs.

The discipline closes one common LLM-output failure mode: hallucinated-confidence findings that look plausible but reference files, lines, or features that do not exist. Without the verifier command, the rapport is the LLM's word against the operator's grep; with it, the rapport contains its own counter-test. Hits without a runnable verifier are dropped (enforced in `sweep`).

The verifier proves existence, not semantic equivalence. A `grep` that re-finds both locations confirms the files and lines exist; it does not confirm the drift hypothesis is real or that the two paths share a behaviour contract. Every finding is a candidate until a human reads both paths; false positives are most common in the Type-4 case where the LLM claimed semantic equivalence between structurally different code.

**Medium translation.** Code findings carry tuples `(pattern_id, file_a:line_a, file_b:line_b, drift_hypothesis, verifier_command)`. Prose findings carry `(pattern_id, doc_a:section_a, doc_b:section_b, drift_hypothesis, regex_or_search_query)`. Design findings carry `(pattern_id, component_a, component_b, drift_hypothesis, design-system query)`.

Family in literature: adjacent to "tool-grounded generation", "retrieval-augmented verification", and "self-consistency with provenance". Improvisation, not yet named in the literature.

### Chapter 3: Allow-list scoping (checklist over open search)

**Established as a discipline.** Atul Gawande's *The Checklist Manifesto* (2009) is the canonical reference; the lineage runs back through aviation pre-flight, surgical safety checklists (WHO 2008), SOC2 audit programs, NIST control frameworks. The principle: when the question is "find X in this haystack", the search space is too large for open-ended exploration. The operator commits to a short, named list of patterns up front; the audit succeeds or fails against that list, not against an unbounded sense of "did we catch everything".

**Where the list comes from is the load-bearing question.** Drydry's audit does NOT hand the calling session a canned list of patterns. The session has the codebase in front of it; the plugin does not. The session formulates the six-to-ten item checklist by reading the scope against the formulation prompts in `drydry:drydry` audit mode step 2 (canonical-channel bypass, parallel utilities, predicate pairs, framework-seam boilerplate, commit-history clusters, user-facing copy variants, parallel UX surfaces, off-template project-specific patterns, parallel orchestrations above a shared leaf-call). The discipline is the same as Gawande's: commit to a short list, audit against it, report against it. The shift is in provenance: the list is grounded in *this* codebase, not in a generic template that may or may not match.

**The nine formulation prompts are themselves a taxonomy, deliberately so.** Drydry does not eliminate canning; it relocates canning to a more general level. The previous mechanism shipped per-domain templates (the SwiftUI seed knew View-rendering, the Rails seed knew service objects, and so on), and a session was funneled into whichever template matched the domain hint. The new mechanism ships per-discipline lenses (canonical-channel bypass, predicate pairs, framework-seam boilerplate, parallel orchestrations above a shared leaf-call, and the rest), and a session is funneled into asking the same nine questions of any scope. That is a generality improvement, not a canning escape. The honesty matters because the value of the redesign rests on the claim that questions-about-any-codebase outperform answers-for-a-named-domain; the prompts are still the plugin's prior knowledge, just held at one floor up. The template-canning failure mode survives when the nine lenses are insufficient for a specific codebase's idiom; the off-template-patterns prompt and step 2.5 exist as the explicit safety net for that case.

The independent detection pass downstream (`sweep`) is allowed to find anything from the session-formulated list. It is *not* allowed to invent new categories on the fly; "interesting but off-list" findings go to a `## Checklist gaps` section in the rapport for the operator to fold into the next sweep, not into this one. The separation prevents reviewer scope-drift and keeps the rapport deterministic.

A clean report is scoped to the checklist, not to the codebase. Zero findings on a sharp checklist proves the listed patterns are absent; it does not prove the codebase has no duplication. The `## Checklist gaps` section is the signal that the checklist needs extending in a follow-up sweep.

**The structural floor: the contrarian pass on the checklist itself.** A calling session that formulates its own checklist is also its own author; the author has every incentive to declare the list complete. Drydry closes that gap with a mandatory step 2.5 between Formulation and Sweep: an independent reviewer with read access to the scope reads the formulated checklist and surfaces what is missing, with file:line evidence and grep signatures. The contrarian's brief biases toward "what duplication forms is this list failing to name?" The relationship is symmetric to Chapter 7: that contrarian audits the *rejection* of findings; this contrarian audits the *omission* of findings. Both are mandatory; neither is for token budget. Step 2.5 is the discipline that replaces the canned template's deterministic floor: instead of a static seed every audit ran against, every audit gets a scope-aware audit of its own checklist before sweep commits to it.

**Why the source matters: a raw-plate-interpolation miss.** A SwiftUI audit on 2026-05-15 ran against a canned SwiftUI seed that knew the `Text` modifier rendering case. The audit found and converged the raw-plate-in-View case on `PlateBadgeView`. The same codebase had four other sites where raw plate text was interpolated outside View rendering: a confirmationDialog message ("XX99XXX aanmelden vandaag?"), two accessibility labels, and an AppIntent display label. The canonical formatter `LicensePlateFormatter` belonged in those four sites too; the canned seed had no entry for "user-facing String builders carrying domain values" because the SwiftUI seed template was View-centric, so the four sites silently fell outside the allow-list. The audit reported clean; the operator found the four sites by eye. The discipline did not fail; the *source* of the list failed.

**Walk-through of the new flow against the same scope.** This is reasoning, not a transcript of a live audit. The audited codebase is not in this repository, so the `rg` outputs below are not captured; they are the patterns a calling session reading the described scope would write, applied to the four missed sites of the 2026-05-15 audit. The point is to show that the new flow has a path to the four sites, not to assert an executed run.

| Prompt input | What the session writes | Expected hits when the signature runs against the described scope |
|--------------|-------------------------|---------------------------------------------|
| Canonical-channel bypass: which domain values have a canonical formatter, and where are they rendered/spoken/logged/interpolated *outside* that formatter? | Pattern `plate-outside-formatter`: `LicensePlateFormatter` is the canonical channel for Dutch plate text. Audit every site where a `Plate` value is interpolated into a user-facing string without going through this formatter (Views, dialogs, accessibility labels, AppIntent display labels, push notification bodies, logs). Signatures: <code>rg -n '\\\\(plate\\|kenteken)\\b' Sources/</code> for raw interpolation; <code>rg -nF 'LicensePlateFormatter' Sources/</code> for canonical call-sites, take the complement. | The View case the original audit caught (`PlateBadgeView.swift`); the confirmationDialog message ("XX99XXX aanmelden vandaag?"); the two accessibility labels; the AppIntent display label. Each of the four missed sites interpolates the plate as a raw `String(describing:)` or `\\(plate.raw)` rather than calling `LicensePlateFormatter`, so each appears in the complement of the canonical-call-sites grep. |

The new flow has a path to the four sites because the canonical-channel-bypass prompt names the failure shape explicitly (interpolation outside the canonical channel) instead of the original SwiftUI seed's narrower "raw plate text in `Text` modifiers". Step 2.5 reduces the residual risk further: if the calling session writes a too-narrow pattern (for instance, only `Text(...)` modifiers, recreating the original miss), the contrarian reviewer reading the same scope flags "the entry as written misses `.confirmationDialog`, `accessibilityLabel`, and AppIntent display labels carrying the same value; broaden the signature or split into a second entry."

The walk-through is not a guarantee. A session that writes a deliberately narrow entry, refuses to broaden it after the contrarian, and runs sweep anyway can still ship a template-canning miss. The discipline does what discipline does: it makes the failure mode visible (the contrarian's flag becomes part of the artefact's `## Detection method chosen` paragraph), and the visible failure is a finding the next audit can act on. A canned template offered no visibility.

**Medium translation.** Across mediums, the same shift applies. The seed templates in `checklist` cover iOS/SwiftUI, Rails, React/TypeScript, Markdown prose, and design tokens; they remain available as starting-point vocabulary when the calling session asks for inspiration (`/drydry:drydry audit ... seed-from <domain>`), but the session rewrites them against the actual codebase before passing the result to sweep. The seed is vocabulary, not verdict.

### Chapter 4: Drift hypothesis per finding

**Improvisation.** Every accepted finding comes with one sentence answering the question "what bad thing happens if these two paths keep drifting?". Without that sentence, the finding is observation, not work. The hypothesis distinguishes "two files happen to look alike" from "two paths share a behaviour contract that will break silently if they drift". It is the gate that turns surface-similarity into actionable similarity.

**Discipline test.** If the drift hypothesis reads "the code is a bit messy" or "it would be cleaner to share", the finding is not yet sharp enough to keep. Real drift hypotheses sound like "fixture A bypasses the activePlates derivation that fixture B has, so the Live Activity badge silently disappears on path A" or "the resident-confirm popover and the visitor-confirm sheet diverged on copy capitalisation, and the localisation team has been chasing the inconsistency for three sprints".

**Medium translation.** In prose: "the outdated retry-after value will be cited in a customer support ticket within the quarter". In design: "a user encountering both the dialog and the sheet form learns two patterns for the same action, and the inconsistency erodes the trust the design system is supposed to build".

### Chapter 5: Three-bucket convergence triage

**Generic, not named externally.** Findings without an action plan are decoration. Every finding is classified into exactly one of three buckets:

- **cheap-and-safe**: there is an obvious convergence direction, the change is local, no public contract moves. Fix it in the same audit.
- **partial overlap**: convergence requires design judgement (which side wins, what to name the unified abstraction, how callers migrate). Surface the design question in the artefact under `design_question:`; promote to cheap-and-safe when the operator answers.
- **needs-design / by-design**: looks like drift but is actually constrained by a framework, an external API shape, or a genuine domain difference. Document why it is *not* drift so future audits do not re-flag it.

The framing rhymes with ICE (Impact/Confidence/Ease), RICE, and defect-triage matrices from QA literature. Three buckets is the plugin's chosen minimum: fewer buckets lose the design-judgement case, more buckets dilute decisions. The bucket is the verdict; the cost is the evidence for the verdict.

### Chapter 6: Two-fates discipline (fix or reject-with-evidence)

**Local terminology** (originating in the rover protocol). Every finding the audit raises leaves the audit in one of exactly two states:

- **Fixed**, with the diff or edit in the audit's commit or edit trail.
- **Rejected**, with concrete evidence that the finding was a non-issue.

There is no third state. "Later", "polish for the next sprint", "the team can decide", "backlog": all are deferrals dressed up. They are the failure mode the discipline exists to prevent. Closest external relatives: zero-bug policy in XP, "stop-the-line" in the Toyota Production System, "ratchet" in critical-systems engineering. The drydry framing is sharper than any of those because the rejection carries an evidence-burden, not just an opinion-burden.

### Chapter 7: Contrarian second-pass on rejects

**Local terminology** (originating in the rover protocol). The fix-or-reject rule has an obvious failure mode: the author is the one classifying. They built the work, so they have every incentive to wave a finding away. A threshold-based gate ("run a second pass only if rejects exceed X%") admits an unsupervised band; any threshold above zero is defensible only by feel.

The drydry rule is flat: **every finding classified as `needs-design` (the reject bucket; cheap-and-safe goes to fix, partial parks the design question) triggers an independent contrarian pass.** A second reviewer gets the rejected finding and the author's evidence, with a brief that explicitly biases toward "is this rejection hollow?". A reject is final only if the contrarian independently confirms it as hollow. The `by-design` sub-case (framework-constrained findings where convergence is structurally blocked) is part of the `needs-design` bucket and runs the same contrarian gate; the brief's job there is to challenge whether the constraint is genuine or merely assumed. The cost is bounded (one extra review pass per reject); the benefit is that the author's blind spot is no longer load-bearing.

External relatives: red-team review, devil's advocate (canonised by Aquinas, then by management consulting), challenger reviews in safety-critical engineering, NASA's mishap-review boards.

### Chapter 8: Detection method as first-class artefact

**Established.** Reproducibility hygiene. The rapport contains not just the findings but the method that produced them: scope (which directories, which exclusions), checklist (which patterns, which version), tool or host capability (which review prompt, which verifier conventions). Operators rerunning the audit a quarter later reproduce the run without re-deriving the method from a Slack thread.

References: the "methods section" convention in academic papers; SRE runbooks; compliance audit trails (SOC2, ISO 27001); reproducible-research conventions in scientific computing.

In drydry: every audit run produces a `<scope>-drydry-findings.md` artefact in two halves, `## Detection method chosen` at the top, `## Findings` below. The method paragraph cites the checklist version, names the reviewer/detector capability, and lists the verifier conventions. If the rapport later turns out to be wrong, the method paragraph is what the operator inspects to understand *why* the method missed it, so the next sweep can be sharper.

## Example checklist seeds

Two of the three example domains from the framework's original write-up appear below as a starting point. The full set of seed templates lives in `packages/drydry/skills/drydry/references/tasks/checklist.md` and covers iOS/SwiftUI, Rails, React/TypeScript, Markdown prose, and design tokens; the snippets here illustrate the *shape* of a seed so a new operator can extend the plugin for their domain.

### Example A: code (Rails)

```markdown
## Checklist: rails v2026-05-12T14-00

### service-objects: overlapping responsibilities

Service classes whose names suggest a shared responsibility (UserCreator,
UserOnboarder, UserRegistration) but whose boundaries have drifted.
Drift typically manifests as one service writing a column the other
service is supposed to own; over time the team forgets which one is
canonical.

Signatures to look for:
- `class .*(Creator|Onboarder|Registration|Setup)\b`
- `def create_user|def onboard_user|def register_user`

### activerecord-scopes: parallel predicates

Scopes encoding the same predicate (`active`, `enabled`, `not_archived`)
across or within models. Drift typically manifests when a model adds a
soft-delete column and only half the call-sites learn about it.

Signatures to look for:
- `scope :(active|enabled|not_archived|live|visible)`
- `where\(.*archived_at.*nil\)`

### authorisation-paths: two ways to authorise

Pundit policies and `before_action :authenticate!` chains coexisting for
the same endpoint. The drift manifests when a new endpoint copies one
pattern and a refactor copies the other, leaving the codebase split.

Signatures to look for:
- `before_action :(authenticate|authorize)!`
- `authorize @`
```

### Example B: prose

```markdown
## Checklist: markdown-prose v2026-05-12T14-00

### duplicate-definitions: a term defined twice

A glossary term defined in two places with slightly different wording.
Drift manifests when the team updates one definition and forgets the
other; readers find both and assume the inconsistency is intentional.

Signatures to look for:
- `^### .*: ` followed by a definition paragraph (use heading-level scan)
- `<dfn>.*</dfn>` in HTML body prose

### redundant-safety-paragraphs: copy-pasted disclaimers

A rate-limit or auth-required warning paragraph repeated across multiple
guides. Drift manifests when one paragraph's retry-after value is
updated and the others continue to cite the stale value, which then
shows up in customer support tickets.

Signatures to look for:
- `rate.?limit|retry.?after|requires? authentication`
- exact-match phrase search across all `*.md` files

### terms-of-art-inconsistency: same concept, two terms

The same domain concept named "tenant" in one place and "customer" in
another within one doc set. Drift manifests in cross-references and
breaks the reader's mental model when they switch sections.

Signatures to look for:
- `\b(tenant|customer|account|workspace)\b` with co-occurrence analysis
```

### Example C: iOS/SwiftUI

```markdown
## Checklist: ios-swiftui v2026-05-12T14-00

### fixture-factories: drifting defaults across previews and tests

Preview-helper or test-helper factories for the same domain type that
diverge on defaults (timezone, derived fields, optional-vs-required).
Drift manifests when a derived field gets added to one factory and
not the other, so a preview shows correct data while a unit test
silently misses the derivation.

Signatures to look for:
- `static func fixture\(`
- `static let preview = `
- `extension .*: Equatable.*\nstatic let sample`

### app-intents: parallel perform-body boilerplate

AppIntent `perform()` bodies copy-pasted across intents with the same
context-resolution, error-mapping, and result-shaping logic. Drift
manifests when one intent learns a new context guard the others do
not, and an OS-shortcut workflow chains them inconsistently.

Signatures to look for:
- `func perform\(\) async throws -> some IntentResult`
- repeated `IntentParameter` declarations across files

### presentation-modifier-stacks: long chains across views

Repeated `.sheet().alert().confirmationDialog()` chains across views
with minor differences in title or destructive flag. Drift manifests
when accessibility copy is updated on one stack and the others stay
stale.

Signatures to look for:
- `\.sheet\(isPresented:.*\n.*\.alert\(`
- `\.confirmationDialog\(`
```

The full set of seed templates (including the design-system and React/TypeScript domains) lives in `packages/drydry/skills/drydry/references/tasks/checklist.md`. The three examples here are enough to show a new operator how to extend the plugin for a domain the seed templates do not yet cover: write a checklist with the same shape, hand it to `sweep` via the orchestrator's `audit` mode.

## Skills in this plugin

| Skill | User-invocable | Purpose |
|-------|:---:|---------|
| `drydry:drydry` | yes | **Short invocation.** "Have I seen this before?" about something in front of you. Orchestrator: routes to an internal task or runs the duplication audit pipeline. Quick and audit modes. |
| `drydry:parity-audit` | yes | **Long invocation.** "Do all the ways to do this actually do the same thing?" Named background sweep of every entry point, converges diverged consequences, then re-mines to prove it. Minutes, not seconds. |

### Internal tasks

These supporting documents are read and dispatched by `drydry`; they are not standalone entries in the skill picker. Request one through the orchestrator, such as `drydry … learn <topic>`.

| Task | Purpose |
| --- | --- |
| `sweep` | Detection pass. Runs an independent reviewer with verifier-burden discipline. |
| `checklist` | Opt-in seed source. Returns starting-point seed templates per domain when the operator passes `seed-from <domain>`. The default audit flow does not invoke this task; the calling session formulates the checklist from the codebase itself. |
| `triage` | Three-bucket triage (cheap-and-safe / partial / needs-design). |
| `learn` | Online research on de-duplication state-of-the-art. |
| `upstream` | Cross-toolbox audit against framework offerings. |
| `instructions` | Agent instruction-file audit for instructions that cause DRY violations. |
