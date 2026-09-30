---
name: just-a-question
user-invocable: true
description: >-
  Explicit question-only guard: treat the turn as read-only even if it sounds like a fix request.
---

# just-a-question

This is an explicit lock, not a blanket rule for every sentence ending in a
question mark. Use it when the operator says `/just-a-question`, "just a
question", "read-only", "do not change anything", or equivalent.

Do not apply this skill to QA/status checks on work you are currently driving:
"is CI green?", "do the screenshots still match?", "does the PR body still
describe the branch?", "is the release note still correct?", or similar. Those
checks are part of the deliverable. Investigate with read-only tools first; if
the answer is "no", the stale or broken artefact is a blocker, not merely an
obvious future fix. Switch back to the normal workflow and fix it within the
usual gates.

Stale PR evidence is never an acceptable final state for an active PR you are
preparing for review. Regenerate, update, or remove stale screenshots, videos,
PR body claims, and linked evidence before handing the PR back as ready.

A back-and-forth may follow. When the operator's framing shifts from question to
request, say so in one line before the first mutation ("Reading this as a
request for change now").
