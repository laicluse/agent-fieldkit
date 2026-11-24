---
name: unslop
user-invocable: true
description: >-
  Replace the averaged, most-likely look of a generated surface with decided craft, without changing what the product does. Use for "unslop", "slop", "defaultism", "looks AI-made", "stagiairwerk", "ziet eruit als elk ander project", "allemaal hetzelfde", "altijd beige", or when earlier requests to improve the look only produced small adjustments.
---

# Unslop

Slop is defaultism: convergence on the mode. A model asked for a number says 7; asked for a page it gives the ground, the type pairing, the corner radius and the hover that occurred most often in its training. Each value is defensible alone. Together they are the aesthetic average, and to a practised eye the average reads as beginner's work.

Unslop replaces those values with decisions a craftsman would make for this surface. It covers appearance, colour, shape, on-screen wording, behaviour and repeated patterns. It leaves alone what the product does: features, information order, structure and data are the owner's, and stay as they are. Wording, feedback and transitions may change; their meaning, the states, the conditions and the steps of a task may not. Where design reasoning advises changing the order or the copy of a generic page, this boundary takes precedence. Moving to the second most likely value is not unslop; neither is adding things on top of what is there.

Apply [design reasoning](../eye-of-the-beholder/design-reasoning.md) throughout. A request that names unslop or slop delegates the visual decisions: decide yourself, build it, show it. An invocation without a pointer means the surface the conversation or the working directory is about.

## Procedure

1. **Capture what is there.** Render the surface with realistic data and keep the capture.
2. **Inventory the mode.** List every visible decision with its current value, layer by layer: ground and palette, type, shape (radius, border, shadow, containers inside containers), spacing and density, labels and on-screen wording, icons, behaviour (hover, transition, feedback, confirmation). Mark each value you would have produced for any subject. Mark separately every value that repeats across elements with different roles: one radius, one border, one transition everywhere is the clearest trace of the mode. Include what you added yourself in this session.
3. **Derive the style from this product, with evidence.** A style picked by association (a children's feast, so primary colours) is the mode one step further, and so is the look you would give any surface once asked to unslop it. Write that look down first; the result may not match it. Then write the product's story in a few lines: who uses it, for which occasion, and which objects, names, dates and habits are in it. Collect real material: what the owner supplied or owns first, then real work you open and look at in this session, kept as captures. A style recalled from memory has not been looked at. Record the direction in the project's visual-language record before any style, different from the latest entries in `surfaces.md` of the [reference library](../explore/reference-library.md), and give every colour, typeface and form its source: sampled from which capture, following from which fact of the story, or chosen by the user. A value without a source is a default. Swap the subject as a test: reasoning that holds as well for another product has not used this one.
4. **Decide each marked value by role.** For each one ask what a practised designer would do for this element on this surface. A value follows from the role of its element: a status block, a text row, a field and a toggle do not share a shape because they share a page. Remove decoration that serves no role. Keep what the user chose or supplied, and keep conventional controls conventional.
5. **Build the styles from an empty file.** Editing the old stylesheet toward the new one keeps its values. Where styles live in utility classes, component variants or shared tokens, restate every value there instead of adjusting some. Change markup only where a decided form needs it; features, order and data stay.
6. **Compare renders.** Place the new render beside the capture from step 1 and against the latest surfaces in the log, which holds descriptions; captures stay in their projects. Go through the inventory: a marked value that survived needs its reason written down. When a deterministic slop detector is available, run it; a clean result is a floor, not proof. Check the narrow width and the states the surface has.
7. **Show and record.** Show old and new side by side, add the surface to `surfaces.md`, and leave the verdict on beauty to the user. A rejected direction becomes a constraint for a new style in step 3, not a list of adjustments.

## Limits

Accessibility, legibility and the real task outrank novelty. Unslop establishes that each visible value was decided for this surface; whether the result is good is the user's judgement of the render.
