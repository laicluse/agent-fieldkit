# eye-of-the-beholder

Visual and interaction design for interfaces that communicate through their controls, layout and feedback. Start with `eye-of-the-beholder` for a new treatment, an unpleasing result, confusing controls or a redesign. It routes usability repair, image-based visual exploration and inspection of the real implementation.

## Skills

| Skill | Purpose |
| --- | --- |
| `eye-of-the-beholder` | The single entry point: inspect context, route the request and carry accepted decisions through to the real render. |
| `eye-of-the-beholder:obvious` | Resolve the current confusing interaction from context and reduce avoidable cognitive load through clearer controls, state and feedback. |
| `eye-of-the-beholder:explore` | Generate visual proposals from actual references, interpret reactions and establish an accepted target. |
| `eye-of-the-beholder:define` | Establish identity and design-system foundations when the product needs them. |
| `eye-of-the-beholder:review` | Diagnose concrete rendering defects and verify aesthetics, fidelity, meaning and interaction separately. |

## Obvious

Invoke `eye-of-the-beholder:obvious` against a screen, capture or recent result when the interface asks the user to decipher controls or read too much explanation. An invocation without a pointer uses the current conversation's relevant surface. The same skill can be selected when a UI addition introduces avoidable choices or hidden state. It investigates the task before changing copy, preserves meaningful information and accessibility, and verifies the resulting interaction. Necessary instructions and informed choices stay visible.

## Workflow

Image generation is the default for genuinely new visual form. Exact fixes and reuse of accepted components skip concept exploration. During unresolved visual exploration, each round shows visual evidence and a recommendation, asks one consequential question and waits before dependent work. An understood, authorized usability correction can proceed directly through implementation and verification. Combinations and rejection of every option are valid. If image generation is unavailable, agree a fallback instead of silently replacing it with CSS sketches.

The canonical visual-language document records accepted image anchors and scoped accepted, rejected and unresolved decisions. Concept approval, mechanism approval and implementation approval are distinct. A generated image is a concept, not proof that the interaction works: the actual implementation must be reviewed at relevant scales, densities and combined states, including motion where it matters.

This method is intended to improve collaboration; aesthetic success still needs to be established with the user. Generic anti-slop rules and passing technical checks cannot prove it.

## Host support

Install from the registered marketplace:

```bash
claude plugins install eye-of-the-beholder@laicluse-agent-fieldkit
codex plugin add eye-of-the-beholder@laicluse-agent-fieldkit
```

Both Claude Code and Codex use the same instructions; available tools must be verified per host. Image generation is supplied by the host's available tools or skills; this plugin does not bundle a generation backend. The backend must support the reference-image operation needed for the proposal; follow [backend resolution](skills/explore/generation.md) before starting. Reload the plugin catalog or start a fresh session after an update.

## Migration

The old public skills `taste-test`, `art-director`, `fat-marker-sketch` and `visual-inspection` are retired. Use `eye-of-the-beholder` as the entry point, or `explore`, `define` and `review` when deliberately selecting a stage. Update saved instructions that invoke the old names. Image classification and reference matching remain internal protocols under `skills/review`; their useful measurement tools and fixtures are retained.

## Verification

Run the image classification regression and reference comparison corpus from the repository root:

```bash
bats packages/eye-of-the-beholder/test/*.bats
node packages/eye-of-the-beholder/skills/review/reference-match/scripts/run-corpus.mjs
```

The manual workflow scenarios in `test/workflow-scenarios.md` exercise routing and approval boundaries. They are behavior probes, not proof of aesthetic quality. Test the installed workflow with an actual visual request before judging the design outcomes.
