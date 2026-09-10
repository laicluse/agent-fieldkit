# Design tokens: [Product name]

Three-layer taxonomy after Nathan Curtis (medium.com/eightshapes-llc). Application code talks ONLY to the semantic layer. Primitives are the physical palette, components are per-component derivations.

## Layer 1: Primitive tokens

*The physical palette. Meaningless for the product: `--blue-500` says nothing about where it is used. Exists so that the semantic layer has something to point to.*

### Colors (OKLCH)

```css
--blue-50:  oklch(0.97 0.02 260);
--blue-100: oklch(0.93 0.04 260);
--blue-500: oklch(0.62 0.18 260);
--blue-700: oklch(0.48 0.16 260);
--blue-900: oklch(0.28 0.12 260);

--neutral-50:  oklch(0.99 0 0);
--neutral-100: oklch(0.96 0 0);
--neutral-500: oklch(0.62 0 0);
--neutral-700: oklch(0.42 0 0);
--neutral-900: oklch(0.15 0 0);

/* + remaining colors from visual-language.md */
```

### Spacing

```css
--space-0:   0;
--space-1:   0.25rem;  /* 4 px */
--space-2:   0.5rem;   /* 8 px */
--space-3:   0.75rem;  /* 12 px */
--space-4:   1rem;     /* 16 px */
--space-6:   1.5rem;   /* 24 px */
--space-8:   2rem;     /* 32 px */
--space-12:  3rem;     /* 48 px */
--space-16:  4rem;     /* 64 px */
```

### Type scale

```css
--font-size-xs:  0.75rem;   /* 12 px */
--font-size-sm:  0.875rem;  /* 14 px */
--font-size-md:  1rem;      /* 16 px */
--font-size-lg:  1.125rem;  /* 18 px */
--font-size-xl:  1.5rem;    /* 24 px */
--font-size-2xl: 2rem;      /* 32 px */
--font-size-3xl: 3rem;      /* 48 px */

--font-weight-regular: 400;
--font-weight-medium:  500;
--font-weight-semi:    600;
--font-weight-bold:    700;

--line-height-tight: 1.15;
--line-height-base:  1.5;
--line-height-loose: 1.75;
```

### Radius + Motion

```css
--radius-0: 0;
--radius-1: 2px;
--radius-2: 4px;
--radius-3: 8px;
--radius-4: 16px;
--radius-full: 9999px;

--duration-instant: 80ms;
--duration-fast:    140ms;
--duration-base:    240ms;
--duration-slow:    360ms;

--ease-entrance: cubic-bezier(0.0, 0.0, 0.2, 1);
--ease-exit:     cubic-bezier(0.4, 0.0, 1, 1);
--ease-standard: cubic-bezier(0.4, 0.0, 0.2, 1);
```

## Layer 2: Semantic tokens

*Role, not color. Application code talks only to these. Brand change = update one semantic alias, not thirty components.*

```css
/* Color: role */
--color-accent:         var(--blue-500);
--color-accent-hover:   var(--blue-700);
--color-danger:         oklch(0.58 0.22 25);
--color-success:        oklch(0.62 0.16 150);
--color-warning:        oklch(0.78 0.15 80);

/* Color: surface */
--color-surface-0:      light-dark(var(--neutral-50),  var(--neutral-900));
--color-surface-1:      light-dark(var(--neutral-100), oklch(0.19 0 0));
--color-surface-2:      light-dark(oklch(0.93 0 0),    oklch(0.23 0 0));

/* Color: text */
--color-text-primary:   light-dark(var(--neutral-900), var(--neutral-50));
--color-text-secondary: light-dark(var(--neutral-500), oklch(0.72 0 0));
--color-text-inverse:   light-dark(var(--neutral-50),  var(--neutral-900));

/* Spacing: role */
--space-inline-tight:  var(--space-2);
--space-inline-base:   var(--space-3);
--space-inline-loose:  var(--space-4);
--space-stack-tight:   var(--space-2);
--space-stack-base:    var(--space-4);
--space-stack-loose:   var(--space-6);
--space-section:       var(--space-12);

/* Type: role */
--type-body:     var(--font-size-md) / var(--line-height-base);
--type-caption:  var(--font-size-sm) / var(--line-height-base);
--type-heading:  var(--font-size-2xl) / var(--line-height-tight);
--type-display:  var(--font-size-3xl) / var(--line-height-tight);

/* Radius: role */
--radius-control:  var(--radius-2);
--radius-container: var(--radius-3);
--radius-pill:     var(--radius-full);

/* Motion: role */
--duration-enter: var(--duration-base);
--duration-exit:  var(--duration-fast);
```

Two anti-patterns to avoid:

- **Application code referring to primitives**: `background: var(--blue-500)` in a `.button` selector bypasses the semantic layer. Always use `--color-accent`.
- **Semantic names that are disguised primitives**: `--color-blue-primary` is not a semantic name. `--color-accent` is. If you want to shift the hue, you should not also need to change the name.

## Layer 3: Component tokens (optional)

*Only when a component needs its own variation that does not belong in the semantic layer. If you frequently add new tokens here, your semantic layer is incomplete.*

```css
/* Button */
--button-bg-primary:       var(--color-accent);
--button-bg-primary-hover: var(--color-accent-hover);
--button-fg-primary:       var(--color-text-inverse);
--button-radius:           var(--radius-control);
--button-padding-x:        var(--space-inline-base);
--button-padding-y:        var(--space-2);

/* Card */
--card-bg:        var(--color-surface-1);
--card-radius:    var(--radius-container);
--card-padding:   var(--space-stack-loose);
--card-border:    1px solid var(--color-surface-2);
```

---

## References used

- Curtis, Eightshapes Medium: 3-layer model from Module 3.1 of SKILL.md.
- WCAG 2.1 SC 1.4.3 for AA/AAA contrast thresholds (4.5:1 for body text and 3:1 for large text / UI boundaries; AAA tightens to 7:1 and 4.5:1). Verify your palette against those after filling in. The OKLCH spec and CSS Color 4 module are the canonical references for perceptually uniform color.
- eye-of-the-beholder's surface-delta 1.07x rule: for surface-0 to surface-2 ratio check in dark mode.
