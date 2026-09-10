# Component: [Name]

Copy this file per new component to `components/<name>.md`. Fill in every section completely. If a section does not apply, write "N/A" with a brief justification; do not omit the section. Completeness is half the reason this document exists.

## Purpose

*One to two sentences. What does this component solve, and for which user? Which alternative is not good enough and why?*

## API

### Props

| Prop | Type | Default | Required | Description |
|------|------|---------|:--------:|-------------|
| `variant` | `"primary" \| "secondary" \| "danger"` | `"primary"` |  | Which variant; see Variants section. |
| `size` | `"sm" \| "md" \| "lg"` | `"md"` |  | Visual size. |
| `disabled` | `boolean` | `false` |  | Interaction off. |
| `loading` | `boolean` | `false` |  | Loading state; pairs with aria-busy. |
| `leadingIcon` | `ReactNode` | | | Icon before the label. |
| `trailingIcon` | `ReactNode` | | | Icon after the label. |
| `onClick` | `(e: MouseEvent) => void` | | | Handler. |

### Slots

*Can this component accept children? If so, which? With what constraints? Example:*

- `children`: the label (text or ReactNode). Maximum length 40 characters; longer labels fail in mobile layout.

## States

Document every state explicitly. Per state: visual description, a11y annotations.

- **Rest**: default, no interaction.
- **Hover**: cursor above, no click. Visual: [e.g. background shift via `--button-bg-primary-hover`].
- **Focus-visible**: keyboard focus. Visual: [e.g. 2 px outline in `--color-accent`]. Screen reader: aria-label from `aria-describedby` coupled where needed.
- **Active**: pressed. Visual: [e.g. 1 px translate-y for depth feedback].
- **Disabled**: disabled. Visual: [e.g. 40% opacity on label, cursor not-allowed]. A11y: `aria-disabled="true"`, NOT `disabled` attribute (otherwise focus is skipped and the user loses context).
- **Loading**: in progress. Visual: [e.g. spinner replaces leading-icon, label stays]. A11y: `aria-busy="true"`.
- **Error** (if applicable): validation failed. Visual and a11y specs.

## Variants

Each variant: when do you use it, with which brand rationale?

- **Primary**: the main action on the view. One per view. Brand rationale: [e.g. "this is where we want to take the user, so visually dominant"].
- **Secondary**: alternative action. Multiple allowed. Brand rationale: [e.g. "subsidiary, neutral surface without brand accent"].
- **Danger**: destructive action. Use sparingly. Brand rationale: [e.g. "uses status-danger color to signal irreversibility"].

## A11y

- **Role**: [e.g. button (native) or role="button" if non-button element].
- **Keyboard support**: Space and Enter activate, Tab adds to tab order, Shift+Tab goes back. Disabled does not skip Tab if `aria-disabled`.
- **Screen reader name**: via children text, or `aria-label` when icon only.
- **Contrast ratios** (per variant, per state, against typical background): minimum WCAG AA (4.5:1 for body text, 3:1 for UI boundaries). Checked against WCAG 2.1 SC 1.4.3.
- **Reduced motion**: respects `prefers-reduced-motion: reduce`; animations removed or instant.
- **Minimum touch target**: 44x44 px on mobile.

## Do

- Use Primary for exactly one main action per view.
- Combine leading-icon with a clear label; icon-only buttons require `aria-label`.
- Use Loading state for actions with latency > 300 ms.

## Don't

- Use Danger for non-destructive actions, even "to stand out".
- Place more than 3 buttons side by side; that is a menu, not a button row.
- Use Primary + Secondary + Danger simultaneously in the same frame; choose at most two.

## Visual examples

*Link or screenshot to the showcase route + a state matrix (all states as a row).*

State matrix: replace this sentence with an embedded, durable capture of the actual implemented states. Do not link a temporary file.

---

## References used

- Frost, *Atomic Design*: button as atom + combination rules.
- Kholmatova, *Design Systems*: states as part of component contract.
- WCAG 2.1 SC 1.4.3: AA/AAA contrast thresholds.
- W3C WAI-ARIA Authoring Practices and the WHATWG HTML spec: keyboard + focus patterns.
