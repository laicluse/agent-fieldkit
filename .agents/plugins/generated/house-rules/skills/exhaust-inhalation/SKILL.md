---
name: exhaust-inhalation
description: >-
  Detect and repair personal circumstances or authoring discussion leaking into generated artifacts, including instructions, code, tests, commit messages and UI. Use when such a leak is spotted or suspected, or when translating conversational background into persistent output.
---

# Exhaust inhalation

Context can guide making an artifact without belonging in it. Exhaust inhalation happens when the requester's circumstances or the authoring conversation become artifact content without serving its intended purpose and authorized audience. A correct feature can still carry this leak.

## Resolve the artifact and its audience

An explicit invocation points at the artifact under discussion and requests repair within the existing task, unless the operator asks only for assessment or advice. In assessment mode, propose the repair and state verification limits without mutating or claiming completed repair. Resolve it from the conversation; do not search for the skill name or start an unrelated audit. Use this lens proactively on output being created within the authorized task when background context is becoming persistent content.

Establish what the artifact is for, who can read it and what disclosure is authorized. Include code, comments, tests, identifiers, fixtures, documentation, commit messages, UI and persistent agent instructions. An instruction file's audience includes future sessions within its scope. A private artifact still needs this assessment.

Distinguish domain requirements, configured preferences and necessary evidence from facts about the requester and the making process. Their arrival through chat is not grounds for removing them. Relevance does not authorize disclosure of personal information; permission to use or remember context does not authorize publishing it. Explicitly requested personal content belongs only in the artifact and audience authorized for it. Existing privacy boundaries remain binding.

## Find the premise, then repair its spread

Read the actual artifact from its recipient's task, without filling gaps from the authoring conversation. Identify which personal or process premise entered it. Ask whether the content describes the artifact's behavior and useful rationale, or merely why this requester asked for it. A hypothetical different requester is a diagnostic, not a reason to erase authorized personalization.

Follow that same premise across directly related changes and outputs, including names, fixtures, metadata and commit text. Replacing a name with “the operator” or turning one person's circumstances into “some users” can preserve the leak. Keyword searches help locate copies but cannot establish that an abstraction is appropriate.

Keep required domain content and evidence. Rephrase useful behavior in domain terms; remove personal occasion and process narrative that do not belong. For example, “I need this for tonight's demonstration” can guide urgency without becoming a permanent “Tonight's demonstration” heading in an export screen. An explicitly requested event announcement may legitimately contain its date.

Repair both the affected output and its producer within the authorized scope: templates, instruction sources and generators can reproduce a leak after a surface edit. Regenerate affected derivatives. Do not relocate removed context into a memory or another artifact unless that destination and purpose are authorized. Coordinate with active writers and follow existing history and publication gates; neither the invocation nor audience relevance expands authorization. If dissemination is uncertain, verify the actual state rather than assuming local or public exposure.

For UI, inspect the interaction with the host's available clarity workflow, such as the `obvious` skill: improve the control rather than relocate chat rationale into help or a tooltip. Preserve necessary task guidance, errors, recovery, consequences, consent and accessibility. Use [scar-tissue](../scar-tissue/SKILL.md) for superseded attempts and editing worklog. A scar-tissue stitch may track an unresolved suspicion; an already-authorized repair needs no stitch.

## Verify without repeating the leak

Inspect the resulting complete artifact and relevant derivatives, metadata and commit text. Exercise affected behavior; inspect a fresh render when UI changes. Check both that the premise is gone and that necessary requirements, evidence and authorized personal content remain. A domain rule supplied in chat, a source date and an explicitly requested personal letter are useful counterexamples to indiscriminate removal.

Report inspected surfaces, concrete repairs and remaining limits in the conversation. Do not reproduce the personal detail in a shared cleanup note, regression fixture, changelog or commit message to explain the repair. Preserve necessary incident evidence only in an explicitly authorized destination. Tool checks and peer agreement do not certify leak-free content.
