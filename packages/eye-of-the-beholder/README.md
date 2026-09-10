# eye-of-the-beholder

Collaborative visual design anchored in images. Start with `eye-of-the-beholder` for a new visual element, an unpleasing result or a redesign. It selects the workflow, develops proposals with image generation and resolves one consequential design decision at a time before implementation.

## Skills

| Skill | Purpose |
| --- | --- |
| `eye-of-the-beholder` | The single entry point: inspect context, route the request and carry accepted decisions through to the real render. |
| `eye-of-the-beholder:explore` | Generate visual proposals from actual references, interpret reactions and establish an accepted target. |
| `eye-of-the-beholder:define` | Establish identity and design-system foundations when the product needs them. |
| `eye-of-the-beholder:review` | Diagnose concrete rendering defects and verify aesthetics, fidelity, meaning and interaction separately. |

## Workflow

Image generation is the default for genuinely new visual form. Exact fixes and reuse of accepted components skip concept exploration. Each round shows visual evidence and a recommendation, asks one consequential question and waits before dependent work. Combinations and rejection of every option are valid. If image generation is unavailable, agree a fallback instead of silently replacing it with CSS sketches.

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
