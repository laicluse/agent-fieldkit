# Design reasoning

Read this before proposing, changing or judging anything visual. It governs every route in this plugin. It is a way of reasoning, not a style: no layout, palette, font or technique below is a default.

## Why output converges

Left without direction, a model produces the most common answer in its training data, and an evaluation loop of small accepted steps settles on the nearest safe optimum. A list of forbidden techniques only moves that median somewhere else. Quality has to be designed toward, not merely defended.

## Follow the rules of the discipline, or break them on purpose

Design has had rules for a long time, with reasons behind them. How they are filled in is what makes one design differ from the next; each design still follows them or breaks them deliberately. Anything that looks unintended is a defect. A default is neither following nor breaking: it does not know the rule exists.

Before deciding on a plane, read its foundation: [typography](foundations/typography.md), [colour](foundations/colour.md). Each states the rule, its reason and what its neglect looks like. Record in the project's record every rule you broke and why. Requirements of accessibility and of law are not rules of this kind: they are met, not weighed. Then read the render for anything that looks unintended, and treat each as a defect until it has a reason.

## Reason from the material

Decide from what this surface must do, not from what such surfaces usually look like:

- **Meaning**: what must the viewer understand, believe or decide, in what order?
- **Attention**: which structure of attention does the task need? One dominant element, several equal ones, or a calm field that rewards scanning.
- **Relations**: what belongs together, what contrasts, what follows what?
- **Character**: what is specific to this product, its content and its users?
- **Medium**: what can this medium do that a static picture cannot: type, scale, interaction, time, real data?

Then act with deliberate design moves: enlarge, reduce, compress, isolate, repeat, interrupt, reveal, sequence, choreograph. For every move, state what it achieves on this surface. A move you cannot justify here is a habit.

## Form a hypothesis before polishing

When appearance is open, or a request asks to make something better, more beautiful or more convincing, form a design hypothesis first: the idea that gives this surface its character, and what a viewer should take from it. Propose it from the product, its content and the conversation; the user should not need design vocabulary. Make it visible and judge it before investing in refinement.

When the direction is open, produce genuinely different hypotheses. They differ in idea, composition, typography, imagery or tempo, not in a palette swap on the same layout. Restyling the same structure, section order and copy is one hypothesis in different clothes: when the existing words, the order of the page or the absence of real material make it generic, a new hypothesis changes those, with real material and the owner's own voice, before it touches styling. A theme taken from a name or a metaphor is styling, not a hypothesis, unless the content itself carries it. One decision per round does not mean one variable per round. Polish loops come after a direction holds, never instead of one.

Ask of every candidate: **which visible choice could only exist here?** A candidate whose every choice would fit any product has no character yet. Conventional controls need not become unique; the product-specific choices must be explainable from this material.

## Starting a new surface

A new page, app or site whose look nobody has decided gets that look decided before its first styles. This holds when it is small, private or disposable, and when the request was only to build it. Skipped, the step is filled by the model's default, and every surface made that way looks like the others.

1. **Material.** List what is on this surface and around it: the names, dates, objects, numbers and occasions, who looks at it, on what device, in what mood. Character comes from here.
2. **Name your default.** Write down the look you would produce without deciding: its ground and accent, its type pairing, its containers and its labels. No element of that description is forbidden; a surface that matches it as a whole has not been designed. A default explained afterwards from the material is still the default: when the explanation would fit another subject as well, start from a different part of the material.
3. **Recent surfaces.** Read `surfaces.md` in the [reference library](../explore/reference-library.md), the looks of the surfaces made before this one. Repeating their ground, type and container form needs a reason from this material. A missing log is an empty one.
4. **Hypothesis.** Form the design hypothesis as above, from the material and the library, and derive ground, type, the form of things and the layout from it.
5. **Decide in proportion.** When the user follows along and the look matters to them, show directions through explore. When they delegated, or asked only for a working thing, decide yourself, record it as an agent decision and keep building. A throwaway project is no reason to ask and no reason to skip.
6. **Record first.** Write material, the default you named, the hypothesis and the choices that follow in the project's visual-language record before the styles.
7. **Sibling test.** Look at the first render beside the most recent surfaces in the log. When it could be swapped for one of them, the hypothesis did not reach the styles. On delivery, add this surface to `surfaces.md`; where the library cannot be written, keep the entry in the project record.

## Look outward, deliberately

The model's memory of design is dated and averaged. The [reference library](../explore/reference-library.md) is the growing, dated memory that replaces it: consult it before proposing, and when its coverage of this task is thin or proposals keep resembling each other, research references that solve this concrete problem in different ways, including other media and older work. Inspect the real work, record its source and when you observed it, and name the transferable mechanism, not an adjective. A recent capture does not prove a recent design; fresh references are input, not a guarantee of fresh work. Record what each applied mechanism did, kept or rejected, so the library becomes knowledge rather than inspiration.

## Keep the point visible

Make the intended conclusion obvious. In a comparison or demonstration, keep irrelevant factors comparable and keep every difference that actually causes the effect; equalizing too much removes the evidence. Truth and legibility are both requirements. Decoration, delight and atmosphere are legitimate goals and need no informational justification, as long as they serve the chosen character.

## Judge what you changed, and what it touched

Judge the render, not the code. Separate three judgements: is it novel, is it appealing, does it fit? None implies the others.

- A first-impression read and a squint read test immediate interpretation and coarse hierarchy; they do not prove beauty or daily usability.
- Compare against references at the same scale and density.
- Inventory what a change can reach: shared components, surfaces, states, breakpoints and transitions. Check every variant of a changed shared primitive, not only the surface you were looking at.
- Judge motion over its whole sequence in the runtime; stills only show key states.
- Independent judges follow [judging](../review/judging.md): a stated decision, abstract labels, both orders, ties, pointed differences, calibration against known human verdicts before any trust. Agreement among judges is not the user's acceptance.
