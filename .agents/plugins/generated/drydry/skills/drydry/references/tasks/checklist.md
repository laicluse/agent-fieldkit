# Checklist

**Opt-in seed source, not the audit default.** The drydry audit no longer hands the calling session a canned list of patterns. The session reads the codebase and formulates the duplication checklist itself, guided by the formulation prompts in `drydry:drydry` audit mode step 2. That is the audit's allow-list; this task is not invoked by default.

This task exists for the narrow case where the calling session wants a starting point because it has no priors on the domain idiom (a fresh session on an unfamiliar Rails project, a first-time SwiftUI audit, a prose-deduplication pass against a doc style new to the operator). The operator opts in with `/drydry:drydry audit ... seed-from <domain>` or the calling session explicitly requests inspiration. The session then rewrites or extends the seed by reading the codebase before passing the final checklist to `sweep`. The seed becomes vocabulary, not verdict.

The bare seed templates ship as illustrative examples (see "Seed templates" below). They are deliberately generic; this codebase is not a generic codebase, and any audit that treats the seed as the checklist is producing a template-canning miss in waiting (the SwiftUI seed only knew View-rendering; the four user-facing String builders carrying raw plate text fell silently outside the allow-list because the canned template had no entry for them).


Read-only task: return the seed inline; do not write files or change confidence tags.

## Input contract

Caller supplies through `args`:

- **`domain`**: one of `ios-swiftui`, `rails`, `react-typescript`, `markdown-prose`, `design-tokens`, or `generic`. Maps to a baked-in seed template. Optional; when absent or unknown, the skill falls back to `generic` and emits a one-line note in the returned markdown so the caller can surface the fallback to the operator.
- **`learnings_dir`**: optional agreed directory from caller input or an existing host instruction. Resolve it using the storage contract and use the same value as learn.
- **`seed_patterns`**: optional comma-separated list of additional pattern names the operator wants in the checklist (extends the seed template).
- **`scope`**: optional path; when provided, the skill briefly inspects the scope (file extensions, framework manifest, presence of typical config files) and may extend the checklist with patterns relevant to what it finds.

## Output contract

Return a markdown checklist with six to ten items and state the resolved `learnings_dir` used for seed lookup. Each item has a `pattern_id`, a short title, a one-paragraph description, and one or two example signatures the sweep subagent can grep for.

```markdown
## Checklist: <domain> v<version>

### <pattern_id>: <short title>

<one-paragraph description of what the pattern looks like, why it
matters, and how it typically drifts>

Signatures to look for:
- `<grep-friendly regex or token>`
- `<another signature>`

### <pattern_id_2>: ...
```

Version the checklist with a full date-time stamp (`v2026-05-12T14-23`, derived from `date +%Y-%m-%dT%H-%M`) so the audit artefact's `## Detection method chosen` paragraph can cite it (Chapter 8). The timestamp form is preferred over a same-day counter because there is no persistent state holding "today's counter"; two audits an hour apart produce two distinct labels without any bookkeeping.

## Seed templates (built-in)

### `ios-swiftui`

1. `confirmation-surfaces`: confirmation popovers, sheets, and dialogs solving the same destructive-action UX need with diverged copy or styling.
2. `domain-types`: parallel structs or enums modelling the same domain concept (Permit, Plate, Visitor) with subtle field-name drift.
3. `fixture-factories`: preview-helper or test-helper factories for the same domain type that diverge on defaults (timezone, derived fields, optional-vs-required).
4. `app-intents`: AppIntent perform-body boilerplate copy-pasted across intents that ought to share a helper.
5. `live-activity-sync`: Live Activity update entries built inline at multiple sites that should share a snapshot factory.
6. `presentation-modifier-stacks`: long `.sheet().alert().confirmationDialog()` chains repeated across views with minor differences.
7. `view-modifier-extensions`: custom `.modifier()` extensions duplicated across files (button styles, card containers, badge surfaces).

### `rails`

1. `service-objects`: service classes with overlapping responsibilities (UserCreator, UserOnboarder, UserRegistration) where the boundaries drift.
2. `activerecord-scopes`: parallel scopes encoding the same predicate (`active`, `enabled`, `not_archived`) across or within models.
3. `background-jobs`: ActiveJob subclasses with similar `perform` bodies, especially around retry or idempotency handling.
4. `authorisation-paths`: two ways to authorise the same endpoint (Pundit policy + before_action; cancancan + manual check).
5. `controller-actions`: actions that duplicate request-parsing or response-shaping logic that should live in a concern or a presenter.
6. `views-and-partials`: ERB partials rendering the same component with diverged class lists or content blocks.
7. `i18n-keys`: translation keys for the same user-visible string under different paths.

### `react-typescript`

1. `form-state-hooks`: custom `useFormX` hooks built around the same shape (controlled inputs, async submission, error mapping).
2. `api-client-wrappers`: thin wrappers around `fetch` or `axios` duplicated across feature folders.
3. `error-boundaries`: ErrorBoundary components with diverged retry or fallback UI.
4. `design-token-imports`: parallel imports of the same token (`tokens.color.primary` vs `palette.primary500`) hinting at a token-system split.
5. `route-guards`: HOCs or hooks that wrap routes for auth checks with diverged unauthorised behaviour.
6. `loading-and-empty-states`: skeleton or empty-state components built per-feature instead of shared.
7. `feature-flags`: client-side flag reads scattered across the tree, often with inconsistent default handling.

### `markdown-prose`

1. `duplicate-definitions`: a term defined in two places with slightly different wording.
2. `redundant-safety-paragraphs`: disclaimer, rate-limit, or auth-required notes copy-pasted across guides.
3. `repeated-examples`: the same code example or scenario reproduced verbatim or near-verbatim across pages.
4. `terms-of-art-inconsistency`: the same concept named with two terms (`tenant` vs `customer`, `user` vs `account`) within one doc set.
5. `setup-instructions`: install or first-run paragraphs repeated across guides instead of linked.
6. `versioning-notes`: per-page version markers that drift as the canonical reference moves.
7. `cross-reference-rot`: section references that no longer resolve because the target moved.

### `design-tokens`

1. `parallel-component-shapes`: two components solving the same UX need with different surface treatments (ConfirmDialog vs ConfirmSheet).
2. `spacing-token-drift`: components using ad-hoc spacing values instead of the token scale.
3. `typography-ramps`: parallel font-size scales between platforms or between teams within one design system.
4. `color-roles-vs-palette`: components using raw palette tokens instead of semantic role tokens (`color.red.500` vs `color.error.fill`).
5. `radius-and-shadow`: corner-radius and shadow values diverging across components for the same surface type.
6. `motion-curves`: parallel ease and duration values across feature areas.
7. `iconography`: two icon styles (filled vs outline) used inconsistently for the same action.

### `generic`

A fallback for projects that do not match any of the above. The seed has six baked patterns; the operator extends with seed_patterns when the project's idiom is specific enough to warrant it:

1. `parallel-helpers`: two helpers solving the same problem with different signatures.
2. `repeated-error-handlers`: try/except / try-catch / rescue blocks copy-pasted across files with the same handler body.
3. `repeated-config-blocks`: the same configuration block (timeouts, retries, headers, options struct) appearing across multiple call-sites instead of a shared constant.
4. `parallel-validation-paths`: input validation logic for the same shape duplicated across entry points (handlers, jobs, CLI commands) instead of a shared validator.
5. `parallel-logging-formats`: log lines emitted with the same domain event but different formatting or fields across the codebase, undermining grep-based observability.
6. `behavioural-clones`: same-behaviour-different-structure code (Type-4, the wedge drydry lives in).

## Workflow

1. **Read `args`.** Parse `domain`, `seed_patterns`, optional `scope`.
2. **Load the seed template.** Pick the template for the domain. If `domain` is unknown, fall back to `generic` and emit a one-line note in the returned markdown so the operator knows the seed is broad.
2.5. **Read learnings from `learn`.** Resolve `learnings_dir` using [artifact storage](../artifact-storage.md), honoring the caller's agreed override and otherwise using `${LAICLUSE_HOME:-$HOME/.laicluse}/drydry/learnings/`. Glob `*.md` in that same directory used by learn. For each completed learnings file whose proposed seed domain matches the current domain, parse the patterns rated `Confidence: robust` and append them as bonus seed items. `probable` and `fragile` proposals are skipped (the operator promotes them by editing the learnings file's confidence tag, not by re-running checklist). When the learnings directory is empty or absent, skip this step silently.
3. **Inspect the scope (if provided).** Run `ls` on the scope, sniff a manifest (`Package.swift`, `Gemfile`, `package.json`), and add domain-specific extensions to the seed (for example: if `Gemfile` contains `devise`, add a `devise-helpers` pattern).
4. **Add operator seed patterns.** Append each item from `seed_patterns` as a new pattern entry. The seed-pattern title becomes the `pattern_id`; the description is left as a one-line stub for the operator to flesh out next time.
5. **Stamp the version.** Format: `v<YYYY-MM-DD>T<HH>-<MM>` from `date +%Y-%m-%dT%H-%M`. The timestamp is the only label needed; no persistent counter is consulted.
6. **Return the seed as a starting point, with a notice.** Hand back the markdown to the caller, prefixed with a one-line notice: "This is a seed, not the audit checklist. Read the codebase, rewrite the entries to match what is actually there, add any patterns the seed has no entry for, then pass the result to `sweep`." The caller (`drydry:drydry` orchestrator or another skill) is responsible for the rewrite step before dispatching sweep.

## Rules

- **Each pattern has at least one grep-friendly signature.** Without a signature the sweep subagent cannot ground the pattern. If the seed template has no signature for a pattern, write one before returning.
- **Operator seed patterns are appended, not interleaved.** The seed template order encodes "most common first"; operator additions go at the end so the priority is preserved.
- **Seeds are vocabulary, not verdicts.** The patterns returned by this task describe shapes that *frequently* appear in the named domain. Whether they appear in *this* codebase is the calling session's question to answer by reading the code. A session that passes the seed straight through to sweep without rewriting is using drydry as a pattern-enforcer and will produce predictable misses.
- **The seed is a snapshot, not a global state.** Every invocation generates its own seed; there is no persistent "current checklist". Reproducibility comes from logging the version in the audit artefact (Chapter 8).
