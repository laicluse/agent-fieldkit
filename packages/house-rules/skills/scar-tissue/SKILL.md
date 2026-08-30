---
name: scar-tissue
description: >-
  Use when corrective work, migrations, living docs, or temporary diagnostic tests leave superseded residue, or before handoff.
user-invocable: true
---

# Scar tissue

Keep the result, not the log of every failed attempt to build it.

Scar tissue is residue from the fixing rather than structure the current system needs: a correction layered over superseded content, a temporary test whose subject is gone, a migration wrapper without a current consumer, or prose and commit history that narrate the struggle instead of the result.

## Catch it without creating ceremony

Repeated edits are normal. The trigger is not an edit count; it is an old and a new intention surviving together in the current artifact. When that happens, inspect the affected artifact and its directly related changes, then consolidate them into the form they would have had if the final decision were known at the start.

Working plans, task notes, unreleased docs, and uncommitted changes are edited in place. Append a correction only when an external reader depends on seeing the history, such as in published changelogs, released documentation, or pushed commits.

Before handoff, ask what each suspicious layer serves today. Remove duplicated, superseded, or unowned material. Keep guards against a current failure mode, compatibility paths with a named current consumer, published history, and tests that assert live behavior. Repository-specific Git, test, migration, and task-tracking rules determine how the host performs that review.

## Give living documents a present-tense identity

A living README, runbook, instruction file, or product overview introduces the artifact as it exists now. Origin repositories, import SHAs, cutover dates, former names or platforms, and sentences explaining what no longer owns the system are historical residue even when they are accurate. Git already owns lineage. An explicit audit, changelog, migration record, or forensic report may retain it because historical evidence is that artifact's current responsibility.

Do not surface or link lineage from a living document unless a named current reader needs it to operate the system or make a live decision. After a migration or correction, scan the affected living documents for old names and paths, source SHAs, `imported from`, `formerly`, and `no longer`; rewrite them around the current identity and responsibility. For example, a service README says what the service is and how to run it, while an import audit may record where its tree came from.

## Remove the worklog from the artifact

Instructions, feedback, and deliberation used to shape an artifact are worklog, not artifact content. A heading or sentence such as "In plain language," "Updated after feedback," "Revised plan," or "we removed the timeline" is scar tissue when its only current function is to narrate the editing conversation. Remove it or replace it with the actual present-tense subject. Preserve that history only when the artifact is itself an audit, changelog, decision record, or another form whose current responsibility is to carry it.

## Resolve stitches during Refactor

A diagnostic stitch is a temporary test introduced to prove that a superseded interpretation has been removed, rather than to specify behavior the system owns now. That interpretation may come from a misunderstood prompt, a false assumption, or advancing understanding. A guard uniquely protects a current requirement or risk; a stitch only describes the interpretation being retired.

Use the stitch for RED and GREEN. During Refactor, keep or rewrite it when it uniquely guards current behavior; remove it when positive coverage already owns the intended behavior. After removal or rewrite, temporarily revert the fix and confirm that the surviving specification goes RED, then restore the fix and confirm GREEN. A stitch introduced by the current change does not enter that change's commit.

When a layer is explicitly marked as a suspected stitch, treat the marker as a session-local cleanup obligation, not as proof that the layer is disposable. Before handoff, inspect the marked layer against the system's current responsibilities: remove it when it only proves a retired interpretation, rewrite it when it should become a positive specification or current guard, or preserve it only with a named current responsibility.

For example, a request to make a dental bridge printable might be misread as a request to configure a Windows network bridge. `does not modify Windows network adapters` can prove that interpretation is gone during repair; `queues the dental bridge model for the configured resin printer` is the specification that remains.

## Explicit invocation

The skill name is a noun phrase, not a literal search request. Operators often enter `$house-rules:scar-tissue` through autocomplete to ask for residue in the artifact currently under discussion. Resolve that artifact from context and inspect it; do not search for the literal words `scar-tissue` unless those words themselves were identified as the problem.

Being invoked points at a suspected scar, not a blank cheque for broad cleanup. Read the flagged artifact first. Cut a clear scar without asking, preserve something load-bearing and name its current responsibility, and surface only genuine judgment calls where removal could damage current behavior.

## Migration without residue

A migration ends with one canonical implementation at the destination. Apply the owning migration or deprecation protocol when external consumers require a transition; do not invent a forwarding path merely because the old path once existed.
