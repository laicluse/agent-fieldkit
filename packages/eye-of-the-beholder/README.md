# eye-of-the-beholder

Visual and interaction design for interfaces that communicate through their controls, layout and feedback. Start with `eye-of-the-beholder` to make something better, more beautiful or clearer, for a new treatment, an unpleasing or generic result, confusing controls or a redesign. It steers away from the averaged look that unguided models and small-step improvement loops converge on, and routes usability repair, visual exploration and inspection of the real implementation.

## Design reasoning

Every skill applies one shared reasoning core instead of a style. It decides from meaning, attention, relations, character and medium; forms a visible design hypothesis before polishing; asks which choice could only exist for this product; researches dated references when proposals converge; keeps the point of comparisons visible; and judges novelty, appeal and fit separately, including everything a change reaches and motion over its whole sequence. It names no default font, palette or layout.

Three mechanisms keep that reasoning from freezing at a model's training median. A dated **reference library** (`skills/explore/reference-library.md`, stored under `~/.laicluse/eye-of-the-beholder/references/`) records real work with its transferable mechanism and what happened when it was applied, plus a draw log that makes habits visible. A **judging protocol** (`skills/review/judging.md`) with calibration pairs (`test/calibration/`) turns judge rounds into evidence instead of position bias. A **practice test** (`test/practice/`) compares plugin versions on four briefs in two domains each, on both hosts, with human verdicts first. Rendering diagnostics are an observation method; pitfalls per axis load only when that axis is scanned.

## New surfaces

A page, app or site built from nothing gets the model's default look unless something interrupts: the request was to build a working thing, so no design skill is selected. Two parts close that gap.

| Part | What it does |
| --- | --- |
| `first-surface` hook | Holds the first stylesheet, or the first page with inline styles, of a project that has no stylesheet and no visual-language record yet. The refusal points at the procedure below. It sees files written with the host's file-writing tool, not shell redirects. It passes once `visual-language.md` (or `docs/visual-language.md`) exists, and ignores temporary directories and `test`, `fixtures`, `vendor`, `dist` and `build` paths. |
| Starting a new surface (`skills/eye-of-the-beholder/design-reasoning.md`) | List the surface's own material, name the default you would have produced, compare with the surfaces made before (`surfaces.md` in the reference library), form a hypothesis, decide in proportion to the project, record it, and check the first render beside its predecessors. |

The surfaces log is what makes sameness visible across projects: a look that returns on unrelated surfaces is a default, whatever it consists of. A small or disposable project is decided by the agent and recorded as an agent decision; it is not a reason to ask and not a reason to skip.

## Skills

The entry point selects `explore`, `define` and `review` as internal stages. In Claude Code only `eye-of-the-beholder`, `eye-of-the-beholder:obvious` and `eye-of-the-beholder:unslop` appear in the slash menu; the stages are hidden (`user-invocable: false`) and stay available to the model. Codex has no setting that hides a skill from its `$` picker while keeping it available to the model, so the stages remain listed there.

| Skill | Purpose |
| --- | --- |
| `eye-of-the-beholder` | The single entry point: inspect context, route the request and carry accepted decisions through to the real render. |
| `eye-of-the-beholder:obvious` | Resolve the current confusing interaction from context and reduce avoidable cognitive load through clearer controls, state and feedback. |
| `eye-of-the-beholder:unslop` | Replace the averaged, default look of a generated surface: list every default value, derive one style from the product's story with a source for every value, decide each value by the role of its element, rebuild the styles and show old and new side by side. Features and structure stay. One word replaces a paragraph of instructions. |
| `eye-of-the-beholder:explore` (internal stage) | Form distinct design hypotheses from the product and real references, make them visible in the medium that suits the open question, interpret reactions and establish an accepted target. |
| `eye-of-the-beholder:define` (internal stage) | Establish identity and design-system foundations when the product needs them. |
| `eye-of-the-beholder:review` (internal stage) | Diagnose concrete rendering defects and verify aesthetics, fidelity, meaning and interaction separately. |

## Obvious

Invoke `eye-of-the-beholder:obvious` against a screen, capture or recent result when the interface asks the user to decipher controls or read too much explanation. An invocation without a pointer uses the current conversation's relevant surface. The same skill can be selected when a UI addition introduces avoidable choices or hidden state. It investigates the task before changing copy, preserves meaningful information and accessibility, and verifies the resulting interaction. Necessary instructions and informed choices stay visible.

## Workflow

Genuinely new visual form starts with visible proposals; the medium follows the open question: image generation for atmosphere and imagery, built typography and layout studies for text-driven surfaces, small interactive studies for behavior and time. Exact fixes and reuse of accepted components skip concept exploration. Automated improvement loops refine an accepted design hypothesis and take their judging criteria from the shared reasoning. During unresolved visual exploration, each round shows visual evidence and a recommendation, asks one consequential question and waits before dependent work. An understood, authorized usability correction can proceed directly through implementation and verification. Combinations and rejection of every option are valid. If the needed medium is unavailable, agree a fallback instead of silently substituting another.

The canonical visual-language document records accepted image anchors and scoped accepted, rejected and unresolved decisions. Concept approval, mechanism approval and implementation approval are distinct. A generated image is a concept, not proof that the interaction works: the actual implementation must be reviewed at relevant scales, densities and combined states, including motion where it matters.

This method is intended to improve collaboration; aesthetic success still needs to be established with the user. Generic anti-slop rules and passing technical checks cannot prove it.

## Host support

Install from the registered marketplace:

```bash
claude plugins install eye-of-the-beholder@laicluse-agent-fieldkit
codex plugin add eye-of-the-beholder@laicluse-agent-fieldkit
```

In a Claude Code session, version 2.1.275 or later, one line installs it straight from the marketplace repository:

```
/plugin install eye-of-the-beholder --marketplace laicluse/agent-fieldkit
```

Both Claude Code and Codex use the same instructions and the same `first-surface` hook (on `Write` in Claude Code, on `apply_patch` in Codex; it needs `node`); available tools must be verified per host. Image generation is supplied by the host's available tools or skills; this plugin does not bundle a generation backend. The backend must support the reference-image operation needed for the proposal; follow [backend resolution](skills/explore/generation.md) before starting. Reload the plugin catalog or start a fresh session after an update.

## Migration

The old public skills `taste-test`, `art-director`, `fat-marker-sketch` and `visual-inspection` are retired. Use `eye-of-the-beholder` as the entry point; it selects the `explore`, `define` and `review` stages. Update saved instructions that invoke the old names. Image classification and reference matching remain internal protocols under `skills/review`; their useful measurement tools and fixtures are retained.

## Verification

Run the image classification regression and reference comparison corpus from the repository root:

```bash
bats packages/eye-of-the-beholder/test/*.bats
node packages/eye-of-the-beholder/skills/review/reference-match/scripts/run-corpus.mjs
```

The manual workflow scenarios in `test/workflow-scenarios.md` exercise routing and approval boundaries. They are behavior probes, not proof of aesthetic quality. Test the installed workflow with an actual visual request before judging the design outcomes.
