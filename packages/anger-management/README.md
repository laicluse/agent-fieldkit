# anger-management

Cuss at your coding agent now, fix the actual problem later.

When the agent does something that sets you off, you do not want a lecture and you do
not want to drop everything to fix it. So you cuss: `/fuck`, `/fucking`, `/fucked`,
`/shit`, `/crap`, `/wtf`, `/bullshit`. These swear/cuss words each capture a single
cheap line about what happened and get out of your way. Later, cooled off,
`/anger-management:repair` looks at the pile, decides whether there is one concrete
recurring thing worth fixing, scores its own confidence, chooses the mitigation layer
and scope, and only applies or routes a fix when confidence is high. If there is
nothing clear, it leaves the trail open. That restraint is the point.

If you still have enough mental capacity to steer in the moment, use the lighter
safeword lane instead: `/safeword`, `/pineapple`, `/pineapplejuice`, `/pinapplejuice`,
`/flugelhorn`, or `/banana`. Those do **not** go into the delayed pile. They mean:
"pause the current work; I see a concrete thing going wrong, fix it now." The whole
plugin is intentionally not solemn: sometimes the irritation is real, sometimes it is
played up because swearing at a robot is funny. The command split is what matters.

The ladder is deliberately simple: the **safeword lane** interrupts work now, the
**cuss lane** logs the escalated friction for delayed analysis, and the **repair lane**
reviews high-confidence proposals on a cooled-down pass.

## Installation

```bash
claude plugins install anger-management@laicluse-agent-fieldkit
codex plugin add anger-management@laicluse-agent-fieldkit
```

In a Claude Code session, version 2.1.275 or later, one line installs it straight from the marketplace repository:

```
/plugin install anger-management --marketplace laicluse/agent-fieldkit
```

## When to use which lane

- Use a **cuss command** when the agent behavior was frustrating but the current
  work should continue. It logs one line for later analysis.
- Use a **safeword command** when the current work must pause because one
  concrete problem is visible and fixable now.
- Use **`/anger-management:repair`** when you want the cooled-down review to
  decide whether the open captures justify a durable fix.

## The idea, in one breath

Two things at once, 80% serious and 20% dry: it makes working with the agent better,
and it gives you somewhere to put the heat without pretending the heat fixes anything.

The split between a cheap in-the-moment capture and a later, separate fix pass is how
teams already do it (Stripe wired "bad day" buttons into their tooling, then a separate
team mined the pile). It is also what the research says: letting it out
does not discharge anger, it rehearses it (Bushman 2002), so the cuss stays a
two-second capture you walk away from, never a rant you marinate in.

## Commands

| Command | What it does |
|---------|--------------|
| `/fuck` `/fucking` `/fucked` `/shit` `/crap` `/wtf` `/bullshit` | Capture one cheap friction line and move on. No apology, no fix, no scope change. |
| `/safeword` `/pineapple` `/pineapplejuice` `/pinapplejuice` `/flugelhorn` `/banana` | Interrupt the current work and fix one visible friction point now. No delayed capture. |
| `/anger-management` | Quick read-back of the pile and its recurring clusters. |
| `/anger-management:repair` | The cooled-down fix pass: judge go/no-go, then apply or route a real recurring problem at its owner source. |

The vocabulary avoids slurs and identity-targeted abuse.

## How it works

1. **Cuss (instant, global).** A cuss appends one line to a single pile shared
   across every session and repo: `${LAICLUSE_HOME:-~/.laicluse}/anger-management/friction.jsonl`
   (`ts, word, cwd, git, note`). The note is fed on stdin via a quoted heredoc, so it is
   never interpreted by the shell even if it echoes something hostile.
2. **Safeword (instant, local to the current problem).** A safeword command is not a
   log entry. It interrupts the current task, asks the agent to identify the concrete
   failure with evidence, and fixes that now. It may be a one-off.
3. **Cool down (you do not have to remember).** A capture schedules a single background
   investigation: 22 minutes 22 seconds later (a wink, and long enough for the heat to
   pass) a separate headless agent (`claude -p --model sonnet`, or
   `codex exec --model <fast-coding-model> -s read-only` when only Codex is
   installed) reads the open captures, the repair history,
   and the recent transcripts, and writes a diagnosis. If you are still in that session, a
   check-in cron may surface it between turns; otherwise it shows up at your next
   `/anger-management:repair`. Either way, ignoring it just leaves the captures open.
4. **Repair (on your terms).** `/anger-management:repair` opens with a blunt verdict:
   *nothing* (change nothing, and that is fine), *not-enough-signal* (leave it open to
   accumulate), or *fix* (one concrete recurring thing plus the specific change). Every
   verdict carries a confidence score, mitigation level, and target scope. The threshold
   for a fix is `0.80`, so weak guesses stay as breadcrumbs for a future pass instead
   of becoming config churn. A high-confidence fix then follows the owner source:
   hooks in hooks, skills in skill source, plugin metadata in plugin metadata, generated
   adapters through the generator, and instruction files only as the last resort.

Because the pile is global and every repair reads the whole open set, deferring makes
the diagnosis better: cuss in one session, again two hours later in another, and they
land in the same pile and get weighed together.

## Why "repair" never just edits CLAUDE.md on a hunch

You mostly cuss when a behaviour comes back *despite* earlier self-improvements. So a
cuss is also a signal that a previous fix added noise or swung too far. If the verdict
is not clearly actionable and we change config anyway, that is noise-reflex busywork
that fools everyone. So the default is to change nothing unless the pattern is concrete,
recurring, and above the confidence threshold. Below that line, the right action is to
keep the captures open so the next pass has more evidence.

## The thinking behind it (research spine)

- **The delayed pass separates fixable workflow friction from the extra noise of the
  moment.** The background for that split, stated as a fact about brains and never as a
  verdict about you: emotions are built, not piped in raw (Anil Seth's "controlled
  hallucination"; Lisa Feldman Barrett's constructed emotion).
- **Signal anger vs pattern anger.** Some anger is real, present, and points at a fixable
  thing (act on it). Some is an old pattern re-igniting, out of proportion to the trigger
  (sit with it). Repair's whole job is to separate the two: honour the signal by fixing
  the recurring problem, and leave the pattern to you. (Roughly the Emotion-Focused
  Therapy distinction between adaptive and maladaptive anger; it rhymes with, but is not
  the same as, the Japanese okoru/ikari split of immediate vs deep anger.)
- **Catharsis is a myth** (Bushman 2002): blowing off steam amplifies anger, so capture
  stays cheap and repair de-escalates instead of inviting more heat.
- **It "gets you" by mirroring, not profiling.** It only ever reflects your own logged
  lines back ("you hit this three times"); it builds no profile of you. State is stored
  locally; the optional background investigation uses the configured runner, so that
  step does send your captures and the relevant transcripts to that model.

## Files

- `bin/anger-log` captures a line. `bin/anger-schedule` single-flight launches the background
  investigation. `bin/anger-resolve` records a routed fix so its captures close.
- `ANGER_SCHEDULE_CODEX_MODEL` overrides the Codex fallback model; by default
  `bin/codex-fast-coding-model` reads `codex debug models`, prefers Codex
  Spark or an ultra-fast coding model, then falls back to mini so background
  diagnosis does not pick the expensive Codex session default.
- The cuss skills are generated from `capture-skill.template.md` by
  `bin/sync-capture-skills` (repo root); edit the template, not the generated files.
- The safeword skills are generated from `safeword-skill.template.md` by
  `bin/sync-safeword-skills` (repo root); they intentionally do not call
  `anger-log`.
