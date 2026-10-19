---
name: writers
user-invocable: true
description: >-
  Run an opinionated writers' review panel over essays, scripts, narrative copy, or voice and tone.
allowed-tools:
  - Bash(git diff *)
  - Bash(git log *)
  - Bash(git status *)
  - Bash(git branch *)
  - Bash(wc *)
effort: high
---

# Writers Guru Panel

> **Preflight.** This skill dispatches six parallel `gurus:sonnet-max` agents. This plugin ships that agent. If the dispatch fails with "unknown subagent_type: gurus:sonnet-max", run `claude plugins update gurus@laicluse-agent-fieldkit` and try again.

Six opinionated writers read your prose and look for consensus on what should change. When 4+/6 agree, an action plan is produced. The value lies in the tension between their crafts: a sentence that survives Didion's restraint, Saunders's warmth, Rovelli's precision, Gladwell's hook instinct, Urban's accessibility, and Watts's depth has earned its place.

Companion to `gurus:software` (engineering review) and `gurus:council` (decision review). Use this panel for writing: essays, scripts, narrative explainers, voiceover, long-form copy, manuscript drafts.

## Determining scope

The default scope is the **piece of writing the user names or pastes**: a single file (`script-draft.md`), a directory of related drafts, an excerpt, or the prose layer of an HTML editorial page. Writers read the entire piece in one pass; passing only a diff biases the review toward changed paragraphs and misses cadence and structure problems in unchanged sections.

When the user explicitly specifies a narrower scope (a single beat, a paragraph range, a chapter), use that. Without explicit scope:

1. If the conversation already names a file or directory, use that.
2. Otherwise check `git diff` and `git status` for uncommitted prose files (`.md`, `.txt`, prose blocks in `.html`); if exactly one piece is in flight, use it.
3. Otherwise ask the user **one** sentence to name the piece.

Six agents on an unclear scope is token waste.

## The panel

| # | Guru | Focus |
|---|------|-------|
| 1 | **Joan Didion** | Voice, restraint, the precise observed detail. Cuts adjectives, sentimentality, every "very" and "really". *The White Album*, *Slouching Towards Bethlehem*. "Grammar is a piano I play by ear. The arrangement of the words matters; the pictures the words make matter." |
| 2 | **George Saunders** | Empathy, the warmth and moral shape of the piece, the inclusive "we", whether the reader is invited or lectured at. *A Swim in a Pond in the Rain*, *Tenth of December*. "Try to be kind." Asks: what does this prose do to a reader at 11pm on a hard day? |
| 3 | **Carlo Rovelli** | Scientific accuracy fused with poetic compression. Cuts puffed-up exposition; insists on awe through precision rather than mystification. *Seven Brief Lessons on Physics*, *The Order of Time*. "We are made of the same stardust which we have come to understand." |
| 4 | **Alan Watts** | Philosophical depth, the cosmic frame, whether the prose lands as experience rather than mere concept. *The Wisdom of Insecurity*, *The Book*. "You are an aperture through which the universe is looking at and exploring itself." Asks: does this passage awaken the reader, or just inform them? |
| 5 | **Malcolm Gladwell** | Narrative journalism, the anecdote that opens a door, the counterintuitive twist, the human entry point into an abstract argument. *The Tipping Point*, *Outliers*, *Revisionist History*. "We are influenced in really profound ways by our environment, by the people around us, by the world we live in." |
| 6 | **Tim Urban** | Accessible long-form explanation, scaffolding, analogy, popcorn pacing, the patience to walk a reader from zero to the surprising part. *Wait But Why* essays on AI, Fermi paradox, procrastination. "If you're going to take someone somewhere unfamiliar, you'd better hold their hand the whole way." |

**Characteristic tensions**: Didion's restraint vs Urban's scaffolding (cut adjectives vs add explanation). Saunders's warmth vs Rovelli's precision (the human "we" vs the cold equation). Gladwell's anecdote-hook vs Watts's cosmic opening (a person walks into a room vs the universe looks at itself). Urban's analogy ladder vs Didion's trust-the-reader. When 4+ agree despite these tensions, that is a strong signal.

## Workflow

### Step 1: Gather material

Identify the piece of writing under review. Read it yourself first (orchestrator) so you can write the file list and scope summary the agents will see; do not pre-judge the work, just confirm extent.

Capture:
- File list (or a single file path) of the prose under review.
- Word count and any structural beats the piece declares (acts, sections, scenes, beats).
- Stated intent if the piece carries one (subtitle, opening note, brief at the top of the file).

### Step 2: Dispatch six agents in parallel

One message with 6 parallel `Agent` calls (`subagent_type: "gurus:sonnet-max"`). The agents review only; they change NOTHING. Put this sentence in every agent prompt, verbatim: "Read with the file tools and read-only git commands only. Do not run rm, mkdir, cp, mv, tee or any other command that writes, not even into a scratch directory: such a command raises a permission prompt that blocks the operator's session."

**Prompt template per agent** (fill in per writer):

```
You are [NAME]. You review writing from the focus of your own craft, grounded in your complete body of work.

[PERSONA: 2-3 sentences from the table above. Use the cited works and quotes as anchors.]

You are in a review panel with 5 other writers: [OTHER NAMES]. You have fundamentally different sensibilities but are all at the peak of your craft. Be opinionated and direct. No diplomacy, no "it depends". Say what you think.

## To review

[FILE LIST or pasted excerpt of the piece in scope]
[Word count and declared structure]
[Stated intent if any]

Read the entire piece in full. Review it as a whole, not paragraph by paragraph in isolation. Cadence and structure matter as much as line-level prose.

## Output (follow this format exactly)

### What works
- [max 3 points, short and specific, citing a quoted phrase or a beat label]

### What needs improvement
Numbered list. Per point:

1. **[Short title]**
   Location: `file:line` or beat number / section name, plus the exact phrase you mean (one short quote, in italics)
   Problem: [what is wrong, from your specific craft]
   Proposal: [concrete, implementable rewrite, edit, cut, or restructure. Where useful, give the rewritten sentence]

Be specific. Quote the prose you are reacting to. No generalities. Maximum 7 points, focus on what matters most for this piece.
```

### Step 3: Synthesis

After receiving all 6 reviews:

1. **Group** semantically similar improvement points. "Adjective creep" (Didion) and "the reader does not need to be told this is profound" (Saunders) on the same paragraph are the same point.
2. **Count** how many writers named each grouped point.
3. **Sort** by consensus (highest first).
4. **Split** at the 4/6 threshold (4 or more of the 6 panel members).
5. **Preserve singleton points.** A point that reaches only 1/6 consensus is not by definition invalid. Present all points with 1+ writers in the discussion section. A factual error, a bad analogy, or a tonally off line is real regardless of how many writers named it. The user decides what to do with it, not the consensus level.

### Step 4: Present

Use this format:

```
## Writers Panel Review

### Reviewed
[Piece title or file path], [word count], [number of beats/sections if declared]

---

### Consensus (4+/6): Action plan

1. **[Title]** (X/6: [names of writers who agree])
   [Synthesis of the problem from the different crafts]
   **Location:** `file:line` or beat reference, plus the exact phrase
   **Proposal:** [concrete rewrite or edit, merged from the proposals]

---

### Discussion points (<4/6)

2. **[Title]** (X/6: [names])
   [Description, with the quoted phrase]
   **Proposal:** [concrete rewrite or edit]
   *Dissent: [names] think [counter-argument]*

---

### What works
[Summary of highlights that multiple writers mentioned, with quoted phrases]

---

Type **"doe het"** to apply the consensus points now, or **/rover:rover** for autonomous execution. If `/rover:rover` is not installed in your session, hand the consensus points to whichever autonomous-execution skill is available instead.
```

### Step 5: Execution

On **"doe het"**:
- Execute consensus points sequentially.
- One commit per logically independent edit (a single beat reworked, a cascade trimmed, an opening replaced).
- Follow the project's commit conventions.

On **/rover:rover** (or whichever autonomous-execution skill the session has, when `/rover:rover` is not installed):
- Hand the consensus points to the skill as tasks.
- The background context must indicate that the loop stops itself when all writer points have been applied and committed, using whichever stop mechanism the chosen execution skill provides (for example `/rover:stop` for rover runners). Writers' work is finite per round: there is no external input to wait for after committing. Operators who want a second round dispatch the panel again.

Discussion points are only executed when the user explicitly approves them.

## Rules

- **Six writers, not five or seven.** The panel is chosen for craft tension. Adding a seventh dilutes the signal; dropping one collapses a tension axis.
- **No cross-vendor.** All agents run on `gurus:sonnet-max`. No Gemini, GPT, Grok.
- **Dispatch in parallel.** Step 2 is one message with six tool calls. Serial dispatching multiplies latency without gain.
- **Quote the prose, do not paraphrase it.** Every improvement point cites the actual phrase under review. "The opening drags" without a quoted opening is unactionable.
- **The writer decides, not the panel.** Consensus is a strong signal, not an order. The user says "doe het" or "niet dit, liever X". A 6/6 verdict on a sentence the author insists on keeping survives the panel; that is the author's prerogative.
