# Icons and pictograms

Read this before adding, choosing or drawing an icon. An icon is a word in a picture language the user may not speak; it earns its place only when it is recognised faster than the word it replaces.

Every rule below is followed, or broken on purpose with the reason written in the project's record. A choice that is neither is an oversight. Evidence is marked: **measured**, **convention**, **opinion**.

## What an icon can and cannot do

- Understanding an icon "is based on previous experience". A few enjoy "mostly universal recognition": home, print, the magnifying glass for search. Outside those, the same picture means different things in different products (observed in usability studies, Nielsen Norman; not a measured share).
- An icon that is not understood at once is "visual noise that hinders people from completing a task." A label removes the ambiguity: "a word is worth a thousand pictures" (Tognazzini, quoted by Nielsen Norman).
- What icons are good at: they make compact targets, they are found again quickly once learned, and a set in one style gives a product a recognisable hand.
- An interface icon "expresses a single concept" with "streamlined shapes"; detail that works in a large illustration makes a small glyph "confusing or unreadable" (Apple).

## Rules

| Rule | Reason | An oversight looks like |
| --- | --- | --- |
| Give an icon a visible text label unless it is one of the few universal ones, a convention of the platform in a toolbar or a repeated row, or one the product has taught. An unlabelled icon still has an accessible name and a tooltip. | Without a known meaning the user must guess or try. | A toolbar of unfamiliar unlabelled glyphs; a tooltip as the only explanation of a new picture. |
| If no fitting picture comes to mind within a few seconds, use the word. | A concept with no obvious picture will not be recognised from an invented one (Nielsen Norman's five-second rule). | An abstract glyph for "reconcile", "archive policy" or "insights". |
| Use the picture people already know for the thing, tied to the object or action itself. | Familiar metaphors are recognised; clever ones are decoded. | A new drawing for search or settings. |
| One set, one hand: the same size, level of detail, stroke weight or fill, corner treatment and perspective throughout. | Similar-looking things are read as one family; a stray style reads as a foreign part (Apple). | Outline icons beside filled ones; two stroke weights; a library icon next to a hand-drawn one. |
| Match the weight of an icon to the text beside it, and size it to that text. | Equal weight gives equal emphasis; a heavy icon beside light text shouts (Apple; Carbon pairs 16 and 20 px icons with 14 and 16 px text). | Thin icons next to bold labels. |
| Align by eye, not by box: add room around an asymmetric glyph until it looks centred. | Geometric centring of an unbalanced shape looks off-centre (Apple). | An arrow that sits visibly low in its button. |
| The style of the set is part of the identity, so decide it: outline or filled, geometric or drawn, plain or detailed. A product that already has an icon language keeps it; a new one chooses from its own character. | A stock set picked without looking is on every generated page and says nobody chose. | The default icon library, untouched, in a product whose other choices were made. |
| An icon that must be recognised has at least 3:1 against what is next to it (see [colour](colour.md)); one that stands in for text is held to the contrast of text. | It must be seen before it can be recognised. | A pale status glyph on a tinted ground. |

Required, not weighed: an interactive icon meets the target-size requirement in [space](space.md) (platform guidance asks for about 44 on touch screens) and has an accessible name; an icon that carries meaning without being a control has a text alternative (WCAG 2.2, 4.1.2 and 1.1.1).

## Deciding for a surface

1. List where a picture would be recognised faster than a word. Those are the candidates; everything else is text.
2. Decide the style of the set from the product, and the one size and weight that sit with the text they accompany.
3. For each icon decide: label visible, or one of the cases where the picture alone is known.
4. Look at them together at the real size. Any that differs in weight, detail or alignment from its siblings is a defect until it has a reason.

## Sources

Read for this file on 2026-11-24:

- Nielsen Norman Group, [icon usability](https://www.nngroup.com/articles/icon-usability/).
- Apple, [Human Interface Guidelines: Icons](https://developer.apple.com/design/human-interface-guidelines/icons).
- IBM Carbon, [icons: usage](https://carbondesignsystem.com/elements/icons/usage/).
- WCAG 2.2, [target size (minimum)](https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum.html).

Not read: the Isotype literature (Otto and Marie Neurath, Gerd Arntz) on pictorial statistics; ISO 7001 public information symbols. The rule on the stock outline set is an observation about generated pages, not a sourced finding.
