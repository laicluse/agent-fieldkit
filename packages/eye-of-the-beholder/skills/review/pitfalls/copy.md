# Copy pitfalls

Read when persistent interface copy is part of the surface under review. Interaction clarity is [obvious](../../obvious/SKILL.md)'s job; this file holds the review-side checks.

Judge copy at the frequency the user meets it. A sentence that helps once becomes dominant noise in a loop repeated dozens of times per session. Before keeping a visible label, caption, helper sentence or disclosure, multiply its reading cost by the expected repetitions.

Resolve ambiguity in this order: topology and proximity, control wording, visual hierarchy, then persistent explanatory copy. Secondary styling lowers contrast; it does not lower reading cost enough to rescue redundant copy.

Three questions for every visible sentence: does it carry information that changes for this object, is it needed to choose the next action, and would it still earn its space on the hundredth repetition? Three times no: remove it, do not fade it. Keep an accessible name without charging sighted users the repetition cost. Put genuinely occasional instruction behind contextual help, and keep disclosures for details of the current object.

| Symptom | Competing explanations | Distinguishing check | Move |
|---|---|---|---|
| A paragraph next to a control | The control is ambiguous; the paragraph is onboarding that stayed | Attempt the task without the paragraph, as a product user | Fix the control, then drop the paragraph; route to obvious when the interaction itself is unclear |
| Copy that explains the development rationale | Brief or spec text promoted to product copy | Ask whether a product user needs it for the current decision | Keep it out of the UI |
| A label on a conventional control | Icon, object and context already carry the meaning; the audience or density makes the word necessary | Remove the word and check recognition and predictable consequence with the intended users in mind | Omit it when recognition holds; keep it when it does not; keep the accessible name either way |
| One label fixed, the same action spelled out elsewhere | Incomplete pass over shared navigation and repeated controls | Inventory the surface's actions and their grammar | Fix every occurrence |
