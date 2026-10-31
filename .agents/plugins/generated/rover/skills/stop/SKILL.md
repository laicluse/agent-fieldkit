---
name: stop
description: >-
  Stop a rover mission and report its actual outcome, evidence and unmet criteria.
---

# Autonomy Stop

Stop execution without confusing termination with success.

## When to use

The operator requests a stop, the work is verified complete, the authorized budget is exhausted, or a recorded negative experimental stop condition is met. A failed hypothesis does not authorize another research sequence. Preserve scope and safety gates; do not redefine failure as success.

## Procedure

1. Locate the loop file from the active mission or explicit argument. Ask only if multiple live missions are genuinely ambiguous.
2. Stop or cancel the exact owned continuation through the host's supported mechanism. Follow its state rules: mark paused only on an explicit pause request, and blocked only when the host's conditions hold. Never mark an unfinished goal complete to cancel continuation. If the host cannot represent or cancel the outcome, report that limitation; write the stopped boundary in the loop so stale wake-ups stand down without rescheduling.
3. Record `continuation: stopped`, the previous opaque handle and the actual outcome in the loop file. For an explicit temporary pause, retain the handle and record `continuation_status: paused` instead. Preserve the Dispatch and unchecked Done criteria.
4. Log a timestamp from the host clock, who requested the stop, and the concrete trigger. Attribute an autonomous negative or budget stop to the rover, never to the operator. Unmet criteria remain unmet; they do not force a return to DRIVE after a stop.
5. Preserve and commit verified task-owned work where authorized and safe. Preserve unfinished or parallel work in place and identify it accurately. Do not mutate a running experiment's contract or publish unqualified output to make cleanup look complete.
6. Report the outcome first: whether the product goal was achieved, what evidence supports it, and what remains unverified or failed. Include material limitations and the location of preserved work. Scale detail to the operator's question, not elapsed mission duration. Do not narrate the entire journey unless requested.

A stop report does not start a new review cycle. Reuse reviewed evidence, check new factual claims against artifacts, and distinguish unreviewed work. Explicit stops take precedence over pride, gurus, trim and further repairs. Never withhold a requested stop until those passes finish.

## Language

The communiqué follows the operator's active conversation language at stop. A later explicit language instruction in the conversation or `## Input` takes precedence over every inferred signal. Preserve technical terms, exact commands, quotes, and artefacts in their original language; for mixed-language prose, follow the dominant natural language used by the operator.

   Use the Dispatch language only as a fallback when the current conversation provides no clear operator-language signal and the Dispatch prose was written directly by the operator. An internally generated, normalized, or translated Dispatch is workflow scaffolding, not evidence that the operator changed language; neither are the Context, Plan, or Log. Regression case: when the operator is speaking Dutch and the rover stores an English Dispatch, the communiqué remains Dutch unless the operator explicitly requests English.

## Continuation after stopping

A stale tick, status question or new evidence is not permission to resume a stopped research sequence. Resume only on a new operator instruction that actually requests continuation, and retain the cumulative budget, failed hypotheses and existing gates. A paused build may coexist with separately authorized repair of its instructions; that does not silently resume inference.

## Optional notifications

Use a notification integration only when the operator explicitly authorized it for this mission and the capability is available. Stopping creates no new authority to send external messages, push, merge or deploy.
