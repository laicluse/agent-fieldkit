# The user's taste

The user's verdicts on visual work are kept outside every project, so the next surface starts from them. The helper is `bin/taste` in this plugin, two directories above this file. It is not on the path: call it by that location, shown below as `<taste>`.

## Before a design decision

In every route, before you choose or change anything visible, run `<taste> recall --project <project name>` and read the result. Do this for a new surface, a redesign, an unslop and a review alike, not only before the first styles.

What comes back has three kinds of line. "Holds here" was stated as general or said about this product: follow it, or say why this surface is an exception. "Said about one other surface" shows what this user notices; weigh it, do not copy it. A line marked reading is an agent's interpretation of their words and may be wrong.

These are opinions about how to decide. The palette, typeface and imagery of a product come from that product's own material; a colour or face the user named for one product stays with that product.

## When the user gives a verdict

A verdict is any reaction to something visual: accepting it, rejecting it, or steering it. Record it before acting on it:

```sh
<taste> record --aspect <aspect> --choice yes|no|steer --words "<their words, verbatim>" \
  --subject "<the part they judged>" --surface "<kind of surface>" --project <project name> \
  --capture <the capture they saw> --reading "<what you think it means>" --host claude|codex
```

- Their words go in unchanged. Your interpretation goes in `--reading` and nowhere else.
- Record what they accepted as carefully as what they rejected; an accepted part must survive the next change.
- `--scope everywhere` only when they said it as holding beyond this surface. A value such as "12 px here" belongs to the place they pointed at.
- `--link inferred` when you are not certain which version or part they meant.
- One verdict per aspect; a reaction that covers three aspects is three records.

Never write the user's words, their taste records or material from another project into a project file. The project's visual-language record holds the choice made for that product and its reason.
