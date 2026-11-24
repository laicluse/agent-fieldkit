# Judge before the user looks

The builder of a surface judges it too kindly. A context that did not build it, given the user's own verdicts, finds what the user would otherwise have to point out.

## When

- A new look, a redesign, or a change whose visible effect reaches many places: one review before showing it.
- An exact correction: a fresh capture and a check of the touched state are enough.
- A second round only after a concrete finding was fixed and a new capture exists. Size the effort by the visible effect, not by the size of the diff.

## The package

Give the judge only this:

1. The task in one paragraph, without your reasoning or the history of attempts.
2. Captures at a scale where text is readable: the main width, the narrowest supported width, and each state that matters. A change over time needs a recording or its key frames.
3. The output of the taste recall for this project ([the user's taste](../eye-of-the-beholder/taste.md)).
4. From the project's record, what was decided for this product, when it bears on the judgement.

## The judge

Use a context that has seen none of the work. From Claude, a subagent started without the conversation, or Codex:

```sh
codex exec --ephemeral --sandbox read-only --image <capture> --image <capture> - < package.txt
```

From Codex, a subagent with no forked turns, or the other host when it can be given the images themselves; a file path in a text prompt shows it no pixels.

Ask for this and nothing else:

- Per aspect that applies: where on the capture, what is visible there, and the correction this user would ask for, given their verdicts.
- "Insufficient evidence" wherever the capture or the verdicts do not support a finding.
- Whether the user would accept this as it stands.

## After

Check each finding against the render yourself, fix what holds, and keep the judge's answer beside the captures. When the user then gives their verdict, record it, and note which of the judge's predictions they confirmed and which corrections it missed. That comparison is the only measure of whether the judge is worth its time.
