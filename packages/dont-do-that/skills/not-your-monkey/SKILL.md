---
name: not-your-monkey
user-invocable: true
description: >-
  Visual self-inspection correction for $not-your-monkey or frustration like "niet je aapje", "je aapje niet", "niet je bitch", or reload-aapje: inspect, fix, reload, and iterate instead of delegating visual QA.
---

# not-your-monkey

The operator is refusing to be the visual reload loop. Treat this as a blocker on the current visual or interactive work: stop asking for manual reloads, screenshots, or "does it look right now?" confirmation, then run the visual feedback loop yourself.

## Trigger meaning

This fires on explicit invocation (`$not-your-monkey`, `/not-your-monkey`, `/dont-do-that:not-your-monkey`) and on natural-language variants like "niet je aapje", "je aapje niet", "ben je aapje niet", "ik ben niet je reload-aapje", "niet je bitch", "I'm not your monkey", "not your reload monkey", "not your bitch", or equivalent frustration about being used as the visual QA operator. Do not require a grammatical sentence; the core signal is the operator refusing to be the agent's visual QA or reload loop.

## Visual loop

1. Reconstruct the target. Identify the app, route, component, file, viewport, state, or artifact under discussion from the conversation and repository. If no dev server is running, start the project-native one. If the target route is unknown, inspect scripts, routes, tests, Storybook config, screenshots, or recent diffs before asking.
2. Inspect with the host's available visual capability. Use a browser, Chrome/Playwright, simulator, device screenshot, PDF/image renderer, canvas pixel probe, accessibility tree, DOM metrics, computed styles, console logs, or another host-owned route that actually lets you see the result.
   - For motion complaints, inspect the complete motion at playback speed through a capability that actually presents motion. Still frames, contact sheets, optical metrics, code review, and another agent's description can support diagnosis, but none counts as watching the motion. If the host cannot present the video or interaction as motion, disclose that limitation and do not claim visual verification.
   - Reproduce the operator's real product representation, data density, and interaction. A synthetic fixture may isolate performance or mechanics, but it cannot approve the real render when its shapes, grouping, sizes, or state transitions differ.
3. Capture evidence before changing more code when feasible. Save or reference screenshots and useful measurements for the affected state and at least one relevant viewport. For dynamic interactions, drive the interaction instead of treating the first page load as enough.
4. Diagnose from observed facts. Tie the hypothesis to visible evidence: bounding boxes, overlap, missing pixels, color contrast, scroll position, responsive breakpoints, console errors, asset load status, or rendered text. Tests and DOM inspection can support the diagnosis but do not replace looking when the complaint is visual.
5. Patch the smallest relevant cause. Rebuild or restart only when the project requires it. Reload the same target yourself and capture fresh evidence.
6. Iterate until the visual issue is resolved by your own inspection or a real gate remains. A green unit test, successful compile, or one screenshot that still has obvious layout issues is not a stop point.
7. Close with evidence, not a verification request. Report what you looked at, what changed, and the before/after evidence paths or screenshot summaries. Do not ask the operator to reload and judge the result.

## Real gates

Stop and ask only for a genuinely missing human input: credentials you cannot retrieve, a physical device or account approval only the operator can touch, an external irreversible operation, or an inaccessible target that cannot be reconstructed from the repo, logs, screenshots, browser state, or conversation. When you stop, name the exact missing input and the visual loop step it blocks.

## Anti-patterns

- Saying "please reload and check", "does it look right now?", or "can you send another screenshot?" before exhausting local visual tooling.
- Claiming you cannot see the UI without first trying the host's browser, screenshot, renderer, simulator, or local app route.
- Treating code review, tests, or screenshots from before the latest render-affecting edit as enough.
- Treating sampled frames or a contact sheet as if the full video was watched.
- Approving a synthetic stress fixture while the reported real product state uses different visual bodies or grouping.
- Making blind visual tweaks from memory or CSS intuition without observing the result after the change.
- Returning a command recipe for the operator to run when the agent can run the same dev server, browser, renderer, or screenshot command.
