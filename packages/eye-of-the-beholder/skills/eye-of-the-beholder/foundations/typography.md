# Typography

Read this before choosing or changing anything about text on a screen, a page or a sheet: which face, what size, how lines are spaced, what stands out. It is not a list of typefaces. It states what each choice does to a reader, why, and what its neglect looks like.

Every rule below is followed, or broken on purpose with the reason written in the project's record. A choice that is neither is an oversight, and an oversight reads as a defect. Evidence is marked: **measured** (research), **convention** (centuries of practice, argued by the cited author), **opinion** (one author's position).

## What typography is for

Typography exists to make a text do its job. Butterick: "Good typography reinforces the meaning of the text" and it is "measured on a utilitarian yardstick", not an aesthetic one; the same face that is right on a highway sign is wrong on an invitation. Its second job is to spend the reader's attention on the message and not on the mechanics of reading. From this follow three things that hold for every decision below:

- The goal of the text decides, so know what this text must do before touching it: persuade, instruct, warn, be scanned, be looked up, be read for an hour.
- Many solutions can be right. There is no single correct answer, only fit.
- Start with the body text, "because there's more body text than anything else"; its four decisions (size, line length, line spacing, face) set most of what a page looks like. Then relate every other element to it.

## How people read

- Reading is not a smooth sweep. The eye fixes on a word for roughly 200 to 250 ms and jumps 7 to 9 letters; 10 to 15% of jumps go backwards; only three to four letters either side of the fixation are sharp, and about 15 letters in the reading direction guide the next jump (**measured** for readers of English, Larson). Everything about line length and line spacing serves these jumps and the return to the next line.
- Words are recognised from their letters, in parallel, not from the outline of the word; this is the model reading researchers accept, as Larson reports it. On that reading, the common explanation that capitals read badly because the word loses its shape does not hold, and practice is the likelier cause. The practical rule survives, the reason is different, and it means letter clarity (open forms, distinct letters, enough space between them) matters more than silhouette.
- On screens most people scan before they read: in one study 79% scanned a new page and 16% read word by word (**measured**, Nielsen Norman). One pattern found on text-heavy pages without signposts is an F: along the top, then down the left edge, missing the rest. Which pattern appears depends on the task and the layout. Headings that say what follows, front-loaded sentences, lists and one idea per paragraph are what change that pattern.
- Three layers fail separately: legibility (can the characters be made out), readability (are the words and sentences easy), comprehension (is the meaning taken) (Nielsen Norman). Typography owns the first and supports the other two.

## Text that is read

These rules are for running text: sentences and paragraphs. A control, a label or a table cell starts from its role in the interface, below, and is not measured in characters per line.

| Rule | Reason | An oversight looks like |
| --- | --- | --- |
| Line length 45 to 90 characters; about 66 for long text; 40 to 50 in multiple columns. | The longer the line, the farther the return jump and the harder it is to find the next line (**convention**, Bringhurst, Butterick; adopted by USWDS). | Text running the full width of a wide window; or a column so narrow that every line breaks a phrase. |
| Line spacing 120 to 145% of the size. Longer lines and darker or larger-bodied faces need more; short lines and lists can take less. Never tight over three lines or more. | Space between lines is what the eye follows on the return jump (**convention**; Apple gives the same direction for wide columns and constrained rows). | The browser default on a wide column; a list row with three cramped lines. |
| Body size 10 to 12 pt in print, 15 to 25 px on a screen. Judge by eye: faces of the same nominal size differ in apparent size. | Screens are read from farther away and each extra row of pixels improves the letter (**convention**, Butterick). Platform minimums: 17 pt default and 11 pt minimum on a phone, 13 and 10 on a desktop (Apple). | 12 to 13 px body on a desktop page; caption sizes used for content. |
| Set long text flush with the edge where reading starts (left for left-to-right scripts), ragged at the other, on screens. Justify only with hyphenation and a capable engine. | A fixed left edge gives each line the same starting point; justification without hyphenation opens rivers of space (**convention**, Bringhurst, USWDS). | Justified paragraphs with gaps; centred paragraphs. |
| Centre only a short phrase or a title. | A block with two uneven edges is hard to read and hard to align with anything (**convention**). | A centred paragraph of help text. |
| Mark a paragraph once: an indent after the first, or space between, never both. | Either signal is complete; two say the same thing twice (**convention**, Bringhurst). | Indented paragraphs with a blank line between. |
| Keep vertical space in measured intervals, related to the line spacing. | Headings and lists are variations against a base rhythm; text that returns "on beat" reads as one fabric (**convention**, Bringhurst). | Arbitrary margins that differ between similar blocks. |

## Emphasis and hierarchy

- Emphasis works by contrast, so its strength falls with every use: "if everything is emphasized, then nothing is emphasized." Bold or italic, not both, and as little as possible. Bold draws the eye because light against dark is the strongest contrast on a page; italic is gentler, and in most sans-serifs too faint to notice.
- Prefer space, then weight, then size. "The best way to emphasize a heading is by putting space above and below." Raise size by "the smallest increment necessary to make a visible difference."
- Three visual styles of heading at most; two is better. A document may be nested deeper in its markup; what is limited is how many levels must look different. More levels force "increasingly desperate attempts to make them visually distinct."
- Use a scale: a modest set of related sizes, not a new size per element. Things of equal rank look the same; a visible difference must mean a difference.
- Capitals only for less than one line: labels, short headings, captions. Add 5 to 12% letterspacing to capitals and small caps, because capitals are spaced to sit beside lowercase and crowd each other. Do not letterspace lowercase at text sizes; loosen it only below about 9 pt and tighten it in headlines.
- Never underline for emphasis; on a screen an underline means a link.
- Colour is a weak emphasis at text sizes, because small letters cover little surface; the perceived intensity of a colour depends on the size and weight of the letters carrying it. On a screen, which emits light, dark grey can be more comfortable than pure black; it is an option that depends on the ground, with contrast still met (**opinion**, Butterick).

## Text in an interface

- Name roles, not sizes. A platform text style (body, headline, title, caption) binds size, weight and line spacing to a purpose (Apple). A role is to type what a named fill is to colour: rules refer to the role, and the role is filled in once.
- An interface has two registers. Carbon keeps a type set for each: productive, a more condensed treatment for product screens where the user must stay on task, and expressive, larger and more graphic, for editorial and marketing (its productive headings are fixed, its expressive ones change with the width). Expressive type inside a tool distracts; productive type on a landing page says too little.
- Avoid light weights for small text; they are "difficult to see, especially when text is small" (Apple).
- Few faces. "Mixing too many different typefaces can obscure your information hierarchy" and makes an interface "feel internally inconsistent" (Apple).
- Text must survive the user's own size setting. Keep the relative hierarchy when sizes grow, and let content grow before chrome: someone enlarging text wants to read the content, not larger tab titles (Apple).
- Numbers that are compared or that change in place take tabular (fixed-width) lining figures, right-aligned, with the unit beside them. Old-style figures belong in running text among lowercase; lining figures belong with capitals and in tables (**convention**, Bringhurst).
- Long strings of digits and codes are letterspaced or grouped; they are "fundamentally meaningless strings" that the eye cannot chunk by itself.
- A table needs no cell borders: "the text in the cells will create an implied grid"; rules that remain are the few that separate kinds of rows.
- Labels are scanned, not read: a specific word or two, sentence case, no full stop. A label that wraps when the user enlarges text is working as intended; it is a defect only when the wrap hides meaning or blocks the control.

## Tone

- A face carries a history, and readers sense it without naming it. The classification is a map of that history: humanist and garalde serifs (the Renaissance book, the hand), transitional (the rational eighteenth century, higher contrast, vertical axis), didone (extreme contrast, early nineteenth century, fashion and display), slab or mechanistic (the Industrial Revolution, low contrast, heavy rectangular serifs, posters and machines), grotesque and neo-grotesque sans (nineteenth-century trade, twentieth-century corporate neutrality), geometric sans (constructed from circle and line, modernism), humanist sans (the proportions of the Roman capital and the hand, warmth). Choosing a class is choosing which of those the surface borrows.
- The effect is real but small. In an experiment with about 45,000 readers, one passage set in Baskerville drew about 1.5% more agreement than the average of five other faces, by the analyst's own estimate (**measured** once, on one passage; Morris and Dunning). Tone tilts belief; it does not replace content.
- A face that contradicts its text is noticed before one that fits. Fit goes unnoticed, and that is the aim.
- Anatomy changes tone and function together (**convention**; the least sourced part of this file). A larger x-height makes a face look bigger at the same size and tends to hold up at small sizes; a small x-height with long ascenders needs more size. High stroke contrast suits display sizes and tends to break up at text sizes. Open apertures tend to stay legible small. What these look like in tone is judged on the render, not deduced.
- Size is part of the design. Faces cut for small sizes have a higher x-height, sturdier strokes and looser spacing; display cuts are finer and tighter. A text face blown up looks clumsy, a display face at 13 px falls apart. Use the optical size meant for the job, or a variable font that adapts.
- Familiarity has a cost. The faces that ship with every computer are "overexposed"; they say nothing because they are on everything. That is no reason to avoid a system face for interface text, where neutrality is the job. It is a reason not to let one carry the identity.
- Mixing is optional. One family with its weights, sizes and small caps is enough for most work; a second face is tolerable, a third rarely. A mix works "when each font has a consistent role": one for what is read and one for what frames it. The two must be identifiably different, though low contrast between them can work better than high.

## Deciding for a surface

1. Name what each text on the surface must do: read at length, scanned, looked up, operated, announced. Decide the register, productive or expressive, per area.
2. Where the surface has running text, set it first for the longest reading: face, size, line length, line spacing, on a real paragraph. Where it has none, start from the interface roles and the content's most frequent text.
3. Define roles from there, as few as the content has kinds, each with size, weight and line spacing. Derive display and label roles from the body, by a scale.
4. Choose the class of face from the product's own material and from what the surface must make people feel and trust; then the face within the class that has the optical sizes, figures and weights the roles need.
5. Decide numbers separately: where they are compared, which figures, how units sit.
6. Check in the medium: at the user's largest text setting, at the narrowest width, in light and dark, with the longest real title and the shortest.
7. Record each rule you broke and why. Read the render and look for anything that seems unintended: two sizes that are almost the same, a lone bold word, a heading closer to the text above than to its own text, a label whose wrap hides part of its meaning. Each is a defect until it has a reason.

## Sources

Read for this file on 2026-11-24:

- Matthew Butterick, *Practical Typography*: [what is good typography](https://practicaltypography.com/what-is-good-typography.html), [why typography matters](https://practicaltypography.com/why-does-typography-matter.html), [summary of key rules](https://practicaltypography.com/summary-of-key-rules.html), [line length](https://practicaltypography.com/line-length.html), [line spacing](https://practicaltypography.com/line-spacing.html), [point size](https://practicaltypography.com/point-size.html), [all caps](https://practicaltypography.com/all-caps.html), [letterspacing](https://practicaltypography.com/letterspacing.html), [headings](https://practicaltypography.com/headings.html), [bold or italic](https://practicaltypography.com/bold-or-italic.html), [mixing fonts](https://practicaltypography.com/mixing-fonts.html), [system fonts](https://practicaltypography.com/system-fonts.html), [colour](https://practicaltypography.com/color.html), [tables](https://practicaltypography.com/tables.html), [maxims of page layout](https://practicaltypography.com/maxims-of-page-layout.html).
- Richard Rutter, [*The Elements of Typographic Style Applied to the Web*](https://webtypography.net/toc/), quoting Robert Bringhurst: sections 2.1.1 to 2.3.2, 3.1.1, 3.2.1, 3.2.2.
- Kevin Larson, [The Science of Word Recognition](https://learn.microsoft.com/en-us/typography/develop/word-recognition), Microsoft Typography.
- Nielsen Norman Group: [F-shaped pattern](https://www.nngroup.com/articles/f-shaped-pattern-reading-web-content/), [How users read on the web](https://www.nngroup.com/articles/how-users-read-on-the-web/), [Legibility, readability and comprehension](https://www.nngroup.com/articles/legibility-readability-comprehension/).
- Apple, [Human Interface Guidelines: Typography](https://developer.apple.com/design/human-interface-guidelines/typography).
- IBM, [Carbon Design System: Typography](https://carbondesignsystem.com/elements/typography/overview/).
- U.S. Web Design System, [Typography](https://designsystem.digital.gov/components/typography/).
- Errol Morris, [Hear, All Ye People; Hearken, O Earth](https://archive.nytimes.com/opinionator.blogs.nytimes.com/2012/08/08/hear-all-ye-people-hearken-o-earth/), The New York Times, 2012.
- Wikipedia: [Vox-ATypI classification](https://en.wikipedia.org/wiki/Vox-ATypI_classification), [x-height](https://en.wikipedia.org/wiki/X-height).

Not read, and worth reading before this file is extended: Ellen Lupton, *Thinking with Type*; Jost Hochuli, *Detail in Typography*; Tobias Frere-Jones, *Typeface Mechanics*; Eva Brumberger, "The Rhetoric of Typography" (2003); Material Design's type scale. The statements on anatomy and optical size above rest on the x-height source and on common practice, and are the least sourced in this file.
