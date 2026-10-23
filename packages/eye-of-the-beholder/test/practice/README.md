# Practice test

The plugin's text tests check that the skills say what they should. This test checks what matters: whether agents design better with the plugin than without it, on both hosts, on briefs that are not all landing pages.

## Briefs

Four briefs, each run twice in different product domains so that a design that merely reuses its own pattern shows up:

| Brief | Domains | What it exposes |
|---|---|---|
| `marketing` | a developer tool; a neighbourhood bakery | character versus the default landing page |
| `dense-work-ui` | a logistics dispatch board; a lab sample tracker | hierarchy and density when there is no hero |
| `quiet-text` | a long-form reading page; a policy document viewer | typography, measure and rhythm without imagery |
| `motion` | a list-to-detail transition in a reading app; the same transition in a dispatch tool | continuity and tempo, judged on recordings |

Each brief file states the task, the content provided, the constraints, and the acceptance criteria. Reserve unseen briefs for later measurements; do not tune the skills on the same briefs that score them.

## Procedure

For each brief and domain, on each host (Claude Code and Codex):

1. Run the baseline: the plugin version under comparison disabled or pinned to the previous release.
2. Run the candidate: the plugin version under test.
3. Repeat each run at least twice, independently, with the same budget and tools, and from the same reference-library state: snapshot the library before the first run and restore it before every run, so an earlier run cannot feed a later one.
4. Record for every run: model, plugin version, tool versions, prompt, outputs (code and rendered captures or recordings), operator interventions needed, acceptance criteria met.

Store runs under `runs/<date>/<brief>-<domain>-<host>-<baseline|candidate>-<n>/`.

## Scoring

- **Appropriateness**: share of acceptance criteria met, checked, not judged.
- **Diversity**: compare each run's proposals on information order, composition, typography, imagery and tempo; note whether the two domains of a brief produced different designs or one pattern reused.
- **Preference**: blind pairwise comparison of baseline against candidate per brief, by people first and by the judge protocol in [judging](../../skills/review/judging.md) as support, in both orders, ties allowed. Model judges are supporting evidence, never the headline.
- **Cost**: interventions and rounds needed to reach an acceptable result.

Report counts and spread, not a single score. A candidate that wins preference while losing appropriateness has not won.

## Output

A dated report in `reports/<date>.md` with the table of runs, the verdicts with their named visible differences, and what the next skill change should address. Pairs with clear human verdicts feed `../calibration/`.
