# Design system governance: [Product name]

Who may change what, when, via which process. Without governance a design system becomes a graveyard of half-adopted tokens and duplicate components within a year.

## Contribution model

### Proposing a new component

Via a PR to this repo with:

- **Design rationale**: why does this component exist? What does it solve that an existing component cannot?
- **Alternatives considered**: which existing components did you consider and why did they fall short?
- **Component contract** (see `components/_example.md`): API, states, variants, slots, a11y, do/don't.
- **Visual**: mockup or screenshot in three states (rest / hover or focus / disabled).
- **A11y checklist**: role, keyboard support, screen-reader names, contrast ratios checked against `reference/color-and-contrast.md` (WCAG AA).

### Changing an existing component

- **Impact assessment**: which other components and pages use this?
- **Breaking vs additive**: is this change breaking (prop removed, default changed, visual behavior changed) or additive (new prop, new variant)?
- **Migration path for breaking changes**: how long does the old API remain available? What is the communication path?

### Adding a new token

- **Primitive**: any team member may do this via a PR.
- **Semantic**: review by design owner. Why is the existing semantic layer not sufficient?
- **Component**: only when the semantic layer has no suitable vocabulary. If you frequently add component tokens, the semantic layer is incomplete; discuss with the design owner first.

## Review

- **Design owner**: [role or person].
- **Technical owner**: [role or person].
- Every design-system PR gets both reviewers. Approval from one is not sufficient; both must approve.
- **SLA for review**: [e.g. within 2 working days of request].
- **Blocking vs non-blocking feedback**: explicit in every comment. Blocking = merge only after fix. Non-blocking = follow-up PR is allowed.

## Semver

Design system follows semantic versioning for both tokens and components:

- **Major**: breaking change. Token renamed, component API changed, visual behavior fundamentally different.
- **Minor**: additive. New token, new variant, new component. Existing behavior unchanged.
- **Patch**: bugfix, visual refinement without behavior change, documentation. A brand hue that shifts 5 degrees in OKLCH is a patch if it does not feel like a perceptual break; major if the brand reads visually differently.

## Deprecation

A token or component is never silently removed. Process:

1. **Mark as deprecated**: JSDoc or CSS comment `/* @deprecated: use --color-accent instead, removed in v3.0.0 */`.
2. **Console warning or linter rule** on usage in the codebase.
3. **Communication**: changelog entry, message in shared channels, entry in design-system roadmap.
4. **Minimum window**: [e.g. 2 minor releases or 6 calendar months], depending on product release cadence.
5. **Removal**: only after the window. On removal: changelog entry as breaking change + major bump.

## Review cadence

- **Token audit**: [e.g. every three months]. Are there still primitives in application code? Are there semantic tokens that are not used?
- **Component audit**: [e.g. every six months]. Have duplicate components emerged (two similar buttons, three similar cards)?
- **Governance audit**: [e.g. annually]. Does this process still work for the team?

---

## References used

- Kholmatova, *Design Systems* (Smashing): semver for tokens, contribution model.
- DesignBetter, *Design Systems Handbook*: team organization and governance cadence.
- Curtis, Eightshapes: DS team structures + roles.
