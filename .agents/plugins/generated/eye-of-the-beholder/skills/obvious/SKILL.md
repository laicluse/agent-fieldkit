---
name: obvious
description: >-
  Clarify confusing UI so the next action, current state and consequences are apparent.
  Use for unclear controls, over-explaining UI, excessive helper copy, cognitive
  or mental load, choice overload, hidden state, spec leakage, whether an action
  belongs inline, in a modal or on its own page or cell, or feedback such as
  "why must I think about this", "onduidelijke knop", or "te veel uitleg".
  Also use proactively when UI added or changed in the current task needs
  explanation to be usable.
---

# Obvious

Design language is not written language. Reduce the work of understanding and operating the interface; do not merely shorten its explanation. A paragraph beside an ambiguous button is a reason to inspect the interaction, not a request for a better paragraph.

## Resolve the live target

An invocation such as `obvious`, with no explicit pointer, refers to the relevant surface in the current conversation, recent output or supplied capture. Resolve that target and the user's task from context. Do not search for the literal skill name, reinterview established decisions or audit every project. Ask only when materially different targets remain plausible.

Use this lens proactively when an authorized UI addition needs substantial explanation, introduces an extra decision or mode, or makes the user infer hidden state. Do not activate it for ordinary prose editing or launch an unrelated redesign because a familiar term appears.

An explicit invocation against an existing surface requests repair of that interaction within the current task boundaries, unless the user asks only for discussion, assessment or proposals. Proactive repair stays within UI added or changed in the current task; report burdens elsewhere without silently fixing them. Preserve accepted visual language, capabilities and independent preferences.

## Find the burden before changing the copy

Inspect the actual surface, its controls and relevant states. Read the implementation to resolve uncertainties; separate observed problems from hypotheses. Attempt the user's task using only what a product user could perceive, without the development conversation.

Inventory the surface's actions and their established visual grammar before editing labels. Include shared navigation and repeated controls: fixing one settings link while leaving the same action spelled out in the app bar is an incomplete pass. Distinguish visible labels from accessible names; accessibility does not require every name to be printed.

Account for the user's expected familiarity, mental model and repeated use rather than assuming every screen needs first-time onboarding. Identify the concrete work the interface imposes: interpreting an ambiguous action or affordance, recalling information instead of recognizing it, comparing unnecessary options, integrating distant explanations, discovering a hidden mode, tracking system status the interface does not show (pending, saved, failed, stale), predicting consequences, or deciphering developer terminology. Information scent, hierarchy, mapping and feedback are design questions; a keyword match is not a diagnosis.

For each suspect explanation, identify the recognition, decision, action, recovery or informed consent it enables. Distinguish necessary domain complexity from avoidable interaction cost. More text can reduce uncertainty; fewer words or clicks can increase it. If the evidence supports no avoidable burden, preserve the design rather than manufacturing a redesign.

## Make a proportionate design move

Choose the simplest interaction that preserves the task's information and user agency. Consider clear action/object labels, spatial grouping, proximity, familiar conventions, sensible defaults, meaningful constraints, visible state, direct feedback and actions available at the moment of need. A requirement the product can maintain may remove a redundant toggle; independent user preferences still need independent control. For expert or repeated use, protect density, spatial stability, shortcuts and direct access; a change that eases first use but costs every later use needs a specific justification.

Give an action the space its task needs, no more. A direct action or a small contextual input (toggle, follow, retry, rename in place, a one-field add) runs from its control where it sits; it earns no dialog or page of its own. A short, bounded input or a deliberate confirmation may interrupt with a modal when blocking helps: information the current process cannot continue without, or a consequence the user must see before an action that cannot be easily undone. Substantial editing, multi-step work, comparison, or anything that needs the background in view gets its own task space, a page or a cell beside the content, never a modal. Decide from the task's length, frequency, stakes and need for context, not from the HTML element, the number of fields, or whether a form or disclosure already exists; a task users repeat often belongs on the main surface even when it would fit a dialog. Keep the interruption to what the interruption is for: necessary confirmations, errors, feedback and focus return stay with the action wherever it runs. Sources for this placement rule: [NN/g, modal and nonmodal dialogs](https://www.nngroup.com/articles/modal-nonmodal-dialog/), [Carbon, modal guidelines](https://www.carbondesignsystem.com/building-blocks/core/components/modal/guidelines) and [GOV.UK, button](https://design-system.service.gov.uk/components/button/).

Compare the candidate with the current interaction by the decisions and inferences each requires. Prefer one defensible solution; show alternatives only for a consequential unresolved trade-off. Do not add configuration to avoid making a design decision.

For standard actions in toolbars and repeated rows, prefer conventional icons: a gear for settings, a magnifier for search, a chevron for disclosure. Preserve established visual grammar. For each visible word, identify what it adds beyond the icon, object and context; omit it if removal preserves recognition, meaning and predictable consequences. Retain object names where needed to identify the target, and page headings. Give controls specific accessible names that include any visible label text, keyboard access and, where useful, tooltips. Do not invent cryptic icons, hide primary controls, silently choose on the user's behalf, erase useful information, or move redundant prose into tooltips. Progressive disclosure must preserve discoverability and keep task-critical state visible. Retain necessary task instructions, errors and recovery, consequences and consent, onboarding, accessible names, keyboard access and focus behavior. Color alone cannot carry essential meaning.

Development rationale, pipeline ordering, acceptance criteria and values from a brief are not product copy merely because they are true. Keep them outside the UI unless the product user needs them to make the current decision. Removing all help is not the goal. Preserve text required by law, policy or an identified content owner unless changing that requirement is explicitly authorized.

Carry an already-authorized, understood correction through implementation without another generic approval round. Pause only for an unresolved trade-off that changes user agency, capability or task scope; present that specific decision before dependent changes. Use [explore](../explore/SKILL.md) for genuinely unresolved new visual form, not as a mandatory proposal round for a label, grouping or established control change. When a clarity change also changes appearance, judge it with [design reasoning](../eye-of-the-beholder/design-reasoning.md). Do not invent a new identity to fix usability.

## Verify the task, not the word count

Exercise the relevant states and transitions in the real runtime: what can the user recognize, what action is available, what changes, and what feedback confirms it? Include applicable empty, populated, pending, error and combined states, repeated use, keyboard/focus, accessible labeling and announcement of relevant status changes to assistive technology. Select cases that can invalidate this particular change rather than running a ritual checklist.

Inspect the fresh render in product context and review the whole touched surface, including surviving explanations. Use [review](../review/SKILL.md) for the rendering protocol. If runtime access is unavailable, disclose that limit and distinguish a proposal from a verified result. Never infer user acceptance or a measured usability improvement from fewer words, a screenshot, model agreement or passing technical tests.

Report the burden found, the interaction changed or deliberately preserved, the task exercised and any unresolved limitation briefly. Do not turn the diagnosis into more explanatory product text or an unsolicited UX lecture.
