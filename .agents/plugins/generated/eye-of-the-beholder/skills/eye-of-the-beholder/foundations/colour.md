# Colour

Read this before choosing or changing any colour. It does not hold a palette: the colours of a product come from that product. It states how a palette is built so that it carries meaning, survives both appearances and can grow.

Every rule below is followed, or broken on purpose with the reason written in the project's record. A choice that is neither is an oversight. The contrast thresholds are requirements, not rules to weigh. The method of families and roles is one proven way to build a palette, taken from shipped work; another method with the same properties is as good.

## A palette is a system with a concept

- Start from a concept that joins the subject of the product to what the interface is for. The subject supplies the colours; the interface supplies the jobs they do. A ground and a handful of flat colours is not a palette.
- Take the colours from a source: a colour the user chose or accepted for this product, the owner's own imagery and objects, or real work around the subject, measured from a capture. A colour recalled from memory is a default. Record where each one came from, and any adjustment made to it with the reason.
- The character follows the concept. It may be playful or strict; neither is the starting point.

## Two layers

**Families.** Each source colour becomes a family of tints: one hue walked from light to dark in steps of OKLCH lightness, with chroma eased at the extremes. Equal lightness steps are not equal visual distances once chroma varies, so look at the ramp and adjust. Ten or eleven steps per family is common, not required. A palette is a mix of such families, including a neutral family that carries most of the surface.

**Roles.** Rules never use a tint directly. They use a role, and a role is named by purpose:

- Levels: the fills that make depth. The base of the page, a secondary base, an elevated surface, a further elevated or floating one, an input.
- Functions: fills that say what something does, whatever level it sits on. An action, a destructive action, a branded surface, and the group for the subject of the product (its states, kinds or quantities).
- Features: whatever sits on a fill, named with that fill. Text and icons are defined as a pair with their ground (a primary, a secondary and where needed a tertiary feature per fill), so contrast is decided once.
- States are variants of one role and change fill and feature together: highlighted, selected, disabled.
- Separators and shadow are roles of their own.

An element takes its function fill when it has one, otherwise the fill of its level. A worked example, a delete button inside a dialog:

```
light                                   dark
elevated-fill:          neutral-50      elevated-fill:          neutral-700     the dialog
feature-on-elevated:    neutral-950     feature-on-elevated:    neutral-50      its text
destructive-fill:       red-700         destructive-fill:       red-600         the button
feature-on-destructive: red-50          feature-on-destructive: red-50          its label
destructive-fill-highlighted: red-800   destructive-fill-highlighted: red-500   pressed
```

The label is checked against the button, and the button's edge against the dialog it sits on.

Roles are filled in separately for light and dark. The same role can point to a different step, or a different family, in each.

## Rules

| Rule | Reason | An oversight looks like |
| --- | --- | --- |
| A colour that marks a state or a kind is reserved for it wherever reuse could be read as that state. Other families may decorate. | A viewer learns the mapping once; a second use breaks it. | The status red reused in a heading. |
| Ration contrast. What needs action differs most from its surroundings; what is settled recedes. Saturation alone does not decide this. | The eye goes to the strongest difference first. | Every state equally loud, so nothing leads. |
| Required: text has 4.5:1 against the fill it is actually rendered on, large text 3:1, and the parts of a control or graphic that are needed to recognise it 3:1 against what is next to them (WCAG 2.2 AA). 7:1 for text is the stricter AAA level, a choice. Check mechanically, in both appearances. | Contrast that is right by eye in one appearance fails in the other. | Hint text that vanishes in dark mode. |
| Layers are visible, by a difference in fill or by an edge with 3:1 against the surface around it. | A level that cannot be seen is not a level. | An input with the fill of its panel and a faint border. |
| Every family has a job. A family nobody uses is removed or given a role. | Unused colour is noise in the system. | A swatch sheet richer than the page. |
| Colour is never the only carrier of a meaning that matters; a word, a shape, a pattern or a position carries it too. | Colour vision differs and screens differ. | A status shown by hue alone. |
| Extending means adding a family or a role, never a one-off value in a rule. | A stray value has no pair, no dark counterpart and no reason. | A hex colour in the middle of a stylesheet. |

## Deciding for a surface

1. Write the concept in a sentence: subject, purpose, how the two meet in colour.
2. Measure the source colours and grow the families.
3. List the roles this surface needs, group by group, and fill them in for light and for dark.
4. Check every pair mechanically. Render both appearances and look for a level that cannot be seen, a family that is absent, and a colour doing two jobs.
5. Record the concept, the sources and the roles in the project's record.

## Sources

The grammar of levels, functions and features follows two shipped products studied on 2026-11-24, a transport app and an energy web app, which the owner of this plugin named as exemplars. They are not public sources; the grammar is offered as a method that worked there, and their values are not reproduced here. Contrast thresholds: WCAG 2.2, [contrast (minimum)](https://www.w3.org/TR/WCAG22/#contrast-minimum), [contrast (enhanced)](https://www.w3.org/TR/WCAG22/#contrast-enhanced) and [non-text contrast](https://www.w3.org/TR/WCAG22/#non-text-contrast). Perceptual steps: [OKLCH in CSS Color 4](https://www.w3.org/TR/css-color-4/#ok-lab). Not yet read for this file: Josef Albers, *Interaction of Color*; the colour chapters of Material and Carbon.
