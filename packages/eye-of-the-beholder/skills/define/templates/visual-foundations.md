# Optional visual foundations worksheet

Examples below illustrate possible choices, not defaults. Use the project's color representation, documentation style and governance. Accepted images are the primary visual references; book citations and the example decision-log format are optional.

## Visual foundations

Per axis: what has this product chosen, why, and against which accepted image? Use the sections below where relevant.

## Type-as-voice

**Principle**: *A short rule about what type does here. E.g. "Neutral humanist sans for UI, lightly geometric display for headings, mono for code."*

**Chosen**:
- Display: [family, weight, source]
- Body: [family, weight, source]
- Mono: [family, weight, source]

**Rationale**: *Why this pairing? Connect each to a brand attribute from `brand.md`. Not "elegant = serif". Instead "we chose Inter because it is a neutral humanist sans that scales without character loss between UI and display, and because the brand is 'clear but not clever' we want a type that does not impose its own voice too strongly."*

**Reference**: [Work + chapter, e.g. Lupton *Thinking with Type*, ch. 2 "Letter".]

---

## Color-as-mood

**Principle**: *A short rule about what color does here. E.g. "60-30-10 with warm neutrals + a deep accent hue for brand moments."*

**Chosen** (in OKLCH, perceptually uniform):
- Brand hue: `oklch(L C H)` [physical reference, e.g. "old library spine, rough texture"]
- Secondary accent: `oklch(L C H)` [reference]
- Neutral scale: [values for surface-1 to surface-5, optionally via `light-dark()`]
- Status green: `oklch(L C H)`
- Status yellow: `oklch(L C H)`
- Status red: `oklch(L C H)`

**Rationale**: *Why this palette? Physical references, not emotional labels. How does it steer the brand attributes?*

**Reference**: [e.g. Albers *Interaction of Color* for how colors shift in context; Adams *Designer's Dictionary of Color* for the specific hue.]

---

## Form-as-attitude

**Principle**: *A short rule. E.g. "Soft but disciplined: 8 px radius, 1 px borders, no shadows."*

**Chosen**:
- Corner radius: [value + optional scale `--radius-sm`, `--radius-md`, `--radius-lg`]
- Border weight: [value + "default" / "emphatic"]
- Surface depth: [number of levels + their luminance delta]
- Shadow language: [flat / soft / hard + specs per level]

**Rationale**: *How does this geometry express the brand attributes?*

**Reference**: [e.g. Wathan & Schoger *Refactoring UI* ch. "Depth" for shadow decisions.]

---

## Motion-as-tempo

**Principle**: *A short rule. E.g. "Unhurried and careful: 280 ms with expo-out for most state changes, 120 ms for direct feedback like button press."*

**Chosen**:
- `--duration-instant`: [value]
- `--duration-fast`: [value]
- `--duration-base`: [value]
- `--duration-slow`: [value]
- `--ease-entrance`: [cubic-bezier or named]
- `--ease-exit`: [cubic-bezier or named]
- `--ease-standard`: [cubic-bezier or named]

**Rationale**: *Which tempo speaks the brand personality? Fast ease-out = efficient, longer expo = deliberate, micro-bounce = playful.*

**Reference**: [e.g. the build-time motion-design reference your session uses, Walter *Designing for Emotion* for personality coupling.]

---

## Photography and illustration tone

**Principle**: *A short rule. E.g. "Editorial product photography on neutral background, no stock, illustrations only as wayfinding."*

**Chosen**:
- Photography register: [editorial / product / documentary / stock] + [with / without people]
- Color treatment: [full color / monochrome / duotone]
- Illustration register: [geometric / organic / hand / flat] + [mono / color]
- Mix-and-match rule: [where photography, where illustration, never together / how together]

**Rationale**: *Why this register? How does it fit the brand attributes and how does it differentiate from competitors in the competitive scan?*

**Reference**: [e.g. Wheeler *Designing Brand Identity* phase 3 designing identity for touchpoint consistency.]

---

## Decision log entries (future changes)

*On every change to this document: add an entry at the bottom with date, author, what changed, why.*

| Date | Author | Axis | Change | Why |
|------|--------|------|--------|-----|
| [YYYY-MM-DD] | [name/role] | [Type/Color/Form/Motion/Photo] | [short] | [brand rationale] |
