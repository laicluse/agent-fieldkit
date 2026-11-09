# Triage

The three-bucket triage pass behind the drydry audit pipeline. Takes a findings list (output of `sweep`) and classifies each finding into cheap-and-safe / partial / needs-design with a one-line convergence cost.

Read-only task: return the classification inline; do not write files.

## Input contract

Caller supplies through `args`:

- **`findings`**: the markdown structure returned by `sweep`, either inline or as a path to a markdown file.
- **`scope`**: the directory or package the findings were collected over. Used to estimate convergence cost (count of call-sites, presence of public exports).

## Output contract

Return the findings list, with one `triage:` and one `cost:` line added per finding:

```markdown
## Pattern: <pattern_id>

- Finding 1
  - file_a: `<path>:<line>`
  - file_b: `<path>:<line>`
  - drift_hypothesis: <as-is from sweep>
  - verifier_command: <as-is from sweep>
  - verifier_expected: <as-is from sweep>
  - triage: cheap-and-safe | partial | needs-design   (the by-design case is a sub-class of needs-design; the bucket label stays needs-design)
  - cost: <one-line convergence cost: file count touched, public-API surface affected, migration complexity>
```

When a finding is classified as `needs-design`, also include a `design_question:` line capturing the open decision (which side wins, what to name the unified abstraction, how callers migrate). When `partial`, include a `next_step:` line naming the smallest action that would unblock convergence.

## The three buckets (Chapter 5)

### cheap-and-safe

There is an obvious convergence direction. The change is local. No public contract moves. Both call-sites are caller-owned; no external consumers.

Signals:

- Both files are within the same package or module
- The unified shape is obvious (factory, helper, partial, shared component)
- Touched file count is small (typically <=5 within the audit scope)
- No public method or exported symbol changes name or signature

Convergence path: apply the unified abstraction in the same audit. Both paths migrate to the new shape; the diff is local; reviewers see the convergence at a glance.

### partial

Convergence requires design judgement, but the judgement is small and the operator can resolve it inside the audit if they make one decision. Typical pattern: the unification is clear except for one open question.

Signals:

- The two paths agree on what they do but disagree on a name, a parameter order, or which side owns the shared abstraction
- A public symbol moves but the rename is mechanical (one find-and-replace, no client-side reasoning)
- Touched file count is moderate (5 to 20)
- The operator can answer the design question in one short conversation

Convergence path: surface the design question in the findings artefact under `design_question:`. When the operator answers, the finding promotes to cheap-and-safe.

### needs-design

The finding looks like a duplicate from outside, but a real constraint or genuine domain difference makes convergence either non-trivial or wrong. Document why so future audits do not re-flag it (Chapter 7's contrarian second-pass gates this verdict). When the blocking constraint is a framework or external API ("by-design" in informal speech), the verdict and the artefact entry are still `needs-design`; the constraint becomes the body of the `design_question:` line.

Signals:

- A framework constraint forces the parallelism (e.g., AppIntent's `perform()` signature requires concrete types; type erasure costs more than the duplication)
- The two paths share surface but encode genuinely different domain rules (a "user" in onboarding and a "user" in billing may be the same word and different concepts)
- The unification would break a public contract with downstream consumers outside the scope
- The unification would require a multi-quarter migration the operator has no appetite for

Convergence path: document the verdict and the constraint in the findings artefact. The orchestrator's audit-mode step 5 runs an independent contrarian pass to verify the verdict is not hollow (Chapter 7).

## Workflow

1. **Read the findings.** Parse the markdown structure from `args.findings`.
2. **Read the scope context.** For each finding, briefly inspect file_a and file_b to count: (a) call-sites of the duplicated function or component, (b) whether either path crosses a package or module boundary, (c) whether either path is exported (public API surface).
3. **Classify.** Apply the bucket signals above. When multiple signals fire across buckets, the most conservative wins: cheap-and-safe requires every signal to point to local; partial requires the design question to be small and isolatable; needs-design otherwise.
4. **Estimate cost.** Write one line per finding: `<N> files touched, <M> public symbols moved, <complexity tag>`. Complexity tags: `mechanical` (rename only), `local-refactor` (extract method or component), `interface-migration` (public contract changes), `framework-bound` (constrained by an external API shape).
5. **Add design questions and next-steps.** For `partial`, name the next-step in one sentence. For `needs-design`, name the design question.
6. **Return.** Hand back the annotated findings markdown to the caller.

## Rules

- **The bucket is the verdict; the cost is the evidence for the verdict.** A `cheap-and-safe` classification with a cost of "30 files touched, interface migration" is contradictory; promote it to `partial` or `needs-design`.
- **No fourth bucket.** Chapter 5 is explicit: three buckets, no `later`, no `backlog`, no `polish next sprint`. Either fix it (cheap-and-safe), park the design question (partial), or document the by-design constraint (needs-design).
- **Triage is not approval.** This task does not decide whether the operator will fix the finding; it decides how much room the convergence needs. The caller acts on the triage.
