---
name: second-opinion
user-invocable: true
description: >-
  Get a Codex second opinion on recent work or a design from Claude Code.
---

<post-update-broadcast>
BEFORE doing the actual work below, run this one-time check only when
`CLAUDE_PLUGIN_ROOT` is set:

```bash
if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; then
  node "${CLAUDE_PLUGIN_ROOT}/bin/check-broadcast"
fi
```

If the command produces output, the intervision plugin was updated since
the last time you saw the broadcast on this machine. Show the output
verbatim in a markdown block, prefixed with one short sentence
("intervision was updated; here is what changed."). Then continue with
the rest of this skill.

If the command produces no output, say nothing about updates and proceed.

The helper writes the sentinel only when stdout was non-empty, so a silent
run does not mark the version as seen. Codex currently has no equivalent
post-update broadcast path in this plugin; skip this block silently there.
</post-update-broadcast>

# Second opinion

Intervision is peer consultation: equals looking at each other's work, not a supervisor looking down. Etymology says it plainly, `inter-` (between, among, together) against `super-` (from above). This skill brings a second coding agent in as that peer for an independent read. You hand it the work just done or just discussed, it looks with fresh eyes and a different training, and the two of you talk it through.

The peer here is Codex, reached through its `codex exec` command. It runs from
the same repository, on its own login, with its own model behind it. That
independence is the whole point; a peer trained the same way as you would only
echo you.

Both families ship in three tiers, and the peer is chosen by tier, never by
one hard-coded slug. Codex: **Luna** (fast, cheap), **Sol** (the Codex
default), **Astra** (frontier). Claude: **Sonnet**, **Opus**, **Fable** in
the same order. A second opinion runs one tier below the session's own by
default: routine consultations go to Luna (a Claude session on Opus or Fable
asking Codex) or to Sonnet (a Codex session asking Claude); escalation moves
one tier up per round.

Resolve the Codex tier with `${CLAUDE_PLUGIN_ROOT}/bin/codex-fast-coding-model`.
Without arguments it returns the newest visible Luna slug from
`codex debug models` (today `gpt-6-luna`; a `gpt-5.6-luna` in the same
catalog loses on generation), and only when no Luna tier is listed it falls
back to a Codex Spark or mini coding model, or to the legacy Spark slug when
the catalog cannot be read. `--tier sol` and `--tier astra` resolve the
higher tiers the same way and fail closed when that tier is absent, so an
escalation never silently lands on the cheap model or on whatever Codex
happens to default to. Escalate to Sol when the Luna pass says the context
is too large or uncertain, misses a concrete concern you can point to, the
change is high-risk, or the operator asks for a deeper pass. Reach for Astra
only when Sol still leaves a disagreement standing and the decision is hard
to reverse (a data contract, a public interface, a deploy shape). Two
frontier models agreeing on a routine diff is not worth the spend.

## The peer has to be there

Before asking, confirm the peer exists:

```bash
command -v codex >/dev/null 2>&1 || { echo "codex CLI not found; intervision needs a peer to ask. Install and log in to Codex first."; }
```

If `codex` is missing, or `codex login status` shows you are not logged in, say so plainly and stop. There is no peer to ask, and pretending otherwise wastes the operator's time. This is the one hard precondition.

Then resolve the cheap first-pass model before any handoff:

```bash
: "${CLAUDE_PLUGIN_ROOT:?CLAUDE_PLUGIN_ROOT not set; intervision needs its installed plugin helper}"
CODEX_PEER_MODEL="$("${CLAUDE_PLUGIN_ROOT}/bin/codex-fast-coding-model" INTERVISION_CODEX_MODEL)" || {
  echo "no Codex Luna model found; stop instead of guessing a slug or using the expensive Codex default"
  exit 1
}
```

`INTERVISION_CODEX_MODEL` can override the catalog choice for one run. Keep it
to a plain model id; the helper rejects shell metacharacters.

## Three ways to get the second opinion

Pick by what just happened. All three run through `codex exec`, and they combine: review a diff first, then go back and forth on whatever the review leaves open.

**1. Check work just done, when there is a diff.** Codex's review path reads the repository's changes directly, so point it at the change set that matches "what we just did":

```bash
DEFAULT=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##')
if [ -z "$DEFAULT" ]; then
  CONFIGURED_DEFAULT=$(git config --get init.defaultBranch 2>/dev/null || true)
  if [ -n "$CONFIGURED_DEFAULT" ] && git rev-parse --verify "refs/heads/$CONFIGURED_DEFAULT" >/dev/null 2>&1; then
    DEFAULT=$CONFIGURED_DEFAULT
  fi
fi
[ -n "$DEFAULT" ] || { echo "cannot determine default branch from origin/HEAD or init.defaultBranch; pass an explicit --base" >&2; exit 1; }
codex exec --model "$CODEX_PEER_MODEL" review --uncommitted     # staged, unstaged, and untracked work
codex exec --model "$CODEX_PEER_MODEL" review --base "$DEFAULT" # everything on this branch against default
codex exec --model "$CODEX_PEER_MODEL" review --commit <sha>    # the changes in one commit
```

**2. Weigh a design just discussed, when there is no code yet.** Give Codex the context on stdin and keep it read-only so it reflects rather than edits. The `-s` flag rides on `codex exec` itself, not on a subcommand: neither `review` nor `resume` accepts it (`resume` inherits the session's sandbox, and passing `-s` there fails with `error: unexpected argument '-s' found`). Use a quoted heredoc so nothing in the pasted text is expanded by the shell:

```bash
codex exec --model "$CODEX_PEER_MODEL" -s read-only - <<'PROMPT'
Peer review this plan before we build it.
<paste the design, the trade-off, the open question, including the parts we are unsure about>
PROMPT
```

**3. Go back and forth.** A single answer is consultation; intervision is a conversation. Resume the same session to push on a point, defend your reasoning, or ask the peer to reconsider, again through a quoted heredoc. Do not add `-s` here; `resume` inherits the read-only sandbox from the session and rejects the flag:

```bash
codex exec resume --last - <<'PROMPT'
You flagged X as a race. The lock at <file:line> already serialises that path. Does that change your read?
PROMPT
```

To escalate, resolve the next tier and start a fresh handoff with the same
original prompt and the cheaper peer's answer quoted underneath:

```bash
CODEX_PEER_MODEL="$("${CLAUDE_PLUGIN_ROOT}/bin/codex-fast-coding-model" --tier sol)" || exit 1
codex exec --model "$CODEX_PEER_MODEL" -s read-only - <<'PROMPT'
<the original prompt, then the Luna answer under a heading "Earlier pass (Luna)">
PROMPT
```

Do not resume the cheaper session for the escalation; resuming keeps that
consultation on the same model. `--tier astra` is the last rung.

Keep resuming until each disagreement is either resolved or sharpened into a question the operator should decide. If two rounds pass with no movement, stop and surface the disagreement to the operator with both positions rather than looping.

## How to do it well

The round-trip only earns its cost if the handoff is honest.

- **Give the peer the real work, not a summary you are proud of.** Point it at the actual diff, or paste the actual design with the shaky parts left in. A flattering summary buys a flattering review.
- **Read for the disagreement, not the agreement.** The peer agreeing is cheap and tells you little. The signal is where its independent read diverges from yours.
- **Stay a peer, not a deferrer.** A second agent is not an authority. When the peer is wrong, say so and push back. When it is right, concede plainly. Equals, in both directions.
- **Keep the peer reviewing, not editing.** `codex exec review` is used here to read a change set and report on it, and `-s read-only` keeps the design path from touching the tree. Let the peer propose; you and the operator decide what lands. Only widen the sandbox when the operator asks for it on purpose.
- **Never expand the handoff through the shell.** A pasted design or follow-up is arbitrary text and may contain `$(...)`, backticks, or quotes. Feed it on stdin through a quoted heredoc (`<<'PROMPT' ... PROMPT`) into `codex exec ... -`, never as a double-quoted argument, so the shell passes it to the peer verbatim instead of executing part of it.

## Bringing findings home

The peer's output is a pile of findings, not a to-do list. Each finding gets one honest fate:

- **Fix it** when it is real and the change earns its weight.
- **Skip it on cost versus value** when the fix would add more than it lifts, with a one-line reason.
- **Reject it** when it is hollow, with the evidence that makes it hollow.

Then surface the exchange to the operator: what the peer raised, what you did with each point, and where the two of you still disagree. Do not smooth the disagreements away. They are the most useful thing intervision produces, because they mark the spots neither agent can settle alone.
