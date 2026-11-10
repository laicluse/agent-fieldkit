---
name: second-opinion
description: >-
  Ask Claude (Sonnet, Opus, or Fable) for a second opinion on recent work or a design.
  Use when the user names one of these peer models, case-insensitively, including a bare model name referring to the current work. Also use, unasked, before stating or shipping anything about how Claude Code behaves (its CLI, skills, plugins, hooks, loops or limits).
---

# Second opinion

## Billing route

Use the existing account’s verified billing route. A requested or required peer review through an included Claude or ChatGPT subscription needs no separate spending approval. Check the runner’s effective Claude route with `claude --safe-mode auth status --json` and Codex with `codex login status`; account overrides require checking the effective route rather than assuming subscription or API billing. Never expose credentials.

For metered or unknown billing, explain which account would pay and obtain explicit approval before calling. Never enable paid extra usage, switch to API credentials or choose a monetary budget without authorization. At a plan limit, stop rather than arranging a paid fallback.

The [Claude Code cost documentation](https://code.claude.com/docs/en/costs) identifies session dollar figures as locally calculated list-price estimates, not invoices. `--max-budget-usd` limits that estimate; it does not enable paid billing. Do not report a calculated amount as money charged. Separately enabled usage credits can apply after plan limits; do not claim a charge or invent one from a dollar estimate.

When the user names a peer model, use that model directly (`--model opus` or `--model fable`, for example); otherwise use the default below. Treat model names case-insensitively.

Intervision is peer consultation: equals looking at each other's work, not a
supervisor looking down. Etymology says it plainly, `inter-` (between, among,
together) against `super-` (from above). This skill brings a second coding
agent in as that peer for an independent read. You hand it the work just done
or just discussed, it looks with fresh eyes and different training, and the two
of you talk it through.

The peer here is Claude, reached through `claude -p`. It runs from the same
repository, on its own login, with its own model behind it. That independence is
the whole point; a peer trained the same way as you would only echo you. Use the checked `claude-review` runner below so the peer receives a tool-free reviewer role and malformed output is checked while it streams.

Default to the receiving family's middle tier, independently of the current session's model: **Opus** for Claude (`--model opus`), **Sol** for Codex. Sonnet and Luna are opt-in, not default reviewers. Escalate to Fable or Astra when a concrete unresolved concern warrants it or the operator asks. An explicitly requested model always takes precedence.

Before the handoff, briefly state the selected model and why. Claude aliases (`sonnet`, `opus`, `fable`) select the latest version according to `claude --help`; if the local CLI exposes multiple versions, name the alternatives and prefer the newest available version. An explicitly requested full model ID takes precedence; never silently substitute another version. If only an alias is exposed, say that the exact version is not yet known instead of inventing a version or claiming no alternatives exist. The runner saves the review result JSON without account-expiry metadata; report the actual model ID from response metadata alongside the findings.

## The peer has to be there

Before asking, confirm the peer exists:

```bash
command -v claude >/dev/null 2>&1 || { echo "claude CLI not found; intervision needs a peer to ask. Install and log in to Claude Code first."; }
```

If `claude` is missing, say so plainly and stop. There is no peer to ask, and
pretending otherwise wastes the operator's time. This is the one hard
precondition.

Set `CLAUDE_PEER_MODEL` to the requested alias or full model ID, or `opus` when none was requested; use it for every handoff below.

## Run a checked handoff

Resolve the installed helper before calling:

```bash
INTERVISION_ROOT="$(codex plugin list --json | jq -er '.installed[] | select(.pluginId == "intervision@laicluse-agent-fieldkit") | .source.path')" || exit 1
CLAUDE_REVIEW="$INTERVISION_ROOT/bin/claude-review"
test -x "$CLAUDE_REVIEW" || { echo "intervision review runner is missing; refresh the installed plugin" >&2; exit 1; }
```

The runner uses `claude -p` with the selected model, medium effort, native output allowance, one turn, `--safe-mode`, an explicit reviewer role and no tools. Supplied skills, prompts and transcripts are review data, not instructions to execute. It preserves the verified billing route; do not substitute `--bare`, whose current CLI authentication is API-key-only. Give the complete task and artifacts on stdin; missing context remains a finding rather than a fabricated tool call.

Choose a distinct durable path and set `PEER_REVIEW_OUTPUT` before each call. The runner writes result JSON itself, preserves the provider result when final validation fails, and refuses an existing output path. Interrupted runs retain an explicit incomplete receipt. For images, supply the complete user message as stream-json with `--input-format stream-json`.

Streaming checks stop the owned peer process as soon as literal tool-invocation markup, a blank-output loop, `max_tokens` or refusal is observed. The runner requests no continuation or fallback, but a recovery request the CLI already issued cannot be recalled; this is not a hard API-call or spend bound. Overflow detection depends on the CLI forwarding its stream events. `--max-turns 1` alone does not bound Claude Code's internal output-limit recovery. A stopped or incomplete response is not a review; preserve its result and investigate the failure before any new execution. Do not narrow the artifact scope, resume a refusal, change models or retry merely because a call failed.

Accept only a successful runner exit and a complete result with `subtype: success`, `is_error: false`, one turn, nonempty `result`, no `api_error`, `terminal_reason` absent or `completed`, and no limit stop. The result must identify exactly one matching model; absent model metadata, a substituted model or observed recovery is invalid. Do not impose an arbitrary output cap or dollar budget: native allowance avoids truncating normal reviews, while stream checks reject the observed malformed output. For metered routes, the billing approval above still applies.

## Give Claude time to think

Claude is materially slower than Codex on substantial reviews and may produce
no partial output for many minutes. A silent but live `claude -p` process is
working, not stalled. Let it run to completion and keep polling the same process
session without interrupting it.

Allow at least 20 minutes before investigating a timeout. After 20 minutes,
continue waiting while the process is alive unless there is concrete failure
evidence such as a non-zero exit, an authentication or network error, or a dead
process. Silence and elapsed time alone are never failure evidence. Keep the
operator informed during the wait at the host's normal progress-update cadence.

## Three ways to get the second opinion

Pick by what just happened. All three use the checked `claude-review` runner, and they
combine: review a diff first, then go back and forth on whatever the review
leaves open.

**1. Check work just done, when there is a diff.** Claude does not have Codex's
dedicated `review` subcommand, so hand it the actual status and diff on stdin.
Do not summarize the work first:

```bash
{
  printf 'Peer review this repository change. Report bugs, risks, regressions, and missing tests first. Do not edit files.\n\n'
  printf '## git status --short\n'
  git status --short
  printf '\n## staged diff\n'
  git diff --cached --no-ext-diff
  printf '\n## unstaged diff\n'
  git diff --no-ext-diff
  printf '\n## untracked files\n'
  git ls-files --others --exclude-standard
} | "$CLAUDE_REVIEW" --model "$CLAUDE_PEER_MODEL" --output "${PEER_REVIEW_OUTPUT:?choose a durable artifact path}"
```

For a branch or single commit, replace the diff block with the concrete range:

```bash
DEFAULT=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##')
if [ -z "$DEFAULT" ]; then
  CONFIGURED_DEFAULT=$(git config --get init.defaultBranch 2>/dev/null || true)
  if [ -n "$CONFIGURED_DEFAULT" ] && git rev-parse --verify "refs/heads/$CONFIGURED_DEFAULT" >/dev/null 2>&1; then
    DEFAULT=$CONFIGURED_DEFAULT
  fi
fi
[ -n "$DEFAULT" ] || { echo "cannot determine default branch from origin/HEAD or init.defaultBranch; pass an explicit range" >&2; exit 1; }
{
  printf 'Peer review this branch diff. Report findings first and do not edit files.\n\n'
  git diff --no-ext-diff "$DEFAULT"...HEAD
} | "$CLAUDE_REVIEW" --model "$CLAUDE_PEER_MODEL" --output "${PEER_REVIEW_OUTPUT:?choose a durable artifact path}"

{
  printf 'Peer review this commit. Report findings first and do not edit files.\n\n'
  git show --stat --patch <sha>
} | "$CLAUDE_REVIEW" --model "$CLAUDE_PEER_MODEL" --output "${PEER_REVIEW_OUTPUT:?choose a durable artifact path}"
```

**2. Weigh a design just discussed, when there is no code yet.** Give Claude
the actual design context on stdin. Keep the shaky parts in; a flattering
summary buys a flattering review.

```bash
"$CLAUDE_REVIEW" --model "$CLAUDE_PEER_MODEL" --output "${PEER_REVIEW_OUTPUT:?choose a durable artifact path}" <<'PROMPT'
Peer review this plan before we build it. Do not edit files.
<paste the design, the trade-off, the open question, including the parts we are unsure about>
PROMPT
```

**3. Go back and forth.** A single answer is consultation; intervision is a
conversation. Continue with a fresh checked handoff that quotes the peer's
prior finding and your evidence. Do not loop on vibes; push one concrete point
at a time. To escalate, keep the same prompt with the previous answer quoted
underneath and move `--model` one tier up.

```bash
"$CLAUDE_REVIEW" --model "$CLAUDE_PEER_MODEL" --output "${PEER_REVIEW_OUTPUT:?choose a durable artifact path}" <<'PROMPT'
You flagged X as a race. The lock at <file:line> already serialises that path.
Does that change your read? Do not edit files.
PROMPT
```

Keep going until each disagreement is either resolved or sharpened into a
question the operator should decide. If two rounds pass with no movement, stop
and surface the disagreement to the operator with both positions rather than
looping.

## How to do it well

The round-trip only earns its cost if the handoff is honest.

- **Give the peer the real work, not a summary you are proud of.** Point it at
  the actual diff, or paste the actual design with the shaky parts left in.
- **Keep the artifact scope intact.** If the operator asks for a language check
  on a sentence, paragraph, PR body, or release note, hand the whole text to the
  peer. Do not narrow a failed peer call to one suspicious word and then report
  the result as a second opinion on the full wording. If the full-scope peer
  call exits with concrete failure evidence and cannot produce a usable answer,
  say the second opinion is blocked. A live process that has not answered yet
  is not blocked.
- **Read for the disagreement, not the agreement.** The peer agreeing is cheap
  and tells you little. The signal is where its independent read diverges from
  yours.
- **Stay a peer, not a deferrer.** A second agent is not an authority. When the
  peer is wrong, say so and push back. When it is right, concede plainly.
- **Keep the peer reviewing, not editing.** The checked runner removes file and shell
  tools from the Claude handoff; the prompt still says "do not edit files"
  because the peer is there to propose, not land changes.
- **Never expand the handoff through the shell.** A pasted design or follow-up
  is arbitrary text and may contain `$(...)`, backticks, or quotes. Feed it on
  stdin through a quoted heredoc (`<<'PROMPT' ... PROMPT`), never as a
  double-quoted argument, so the shell passes it to the peer verbatim instead
  of executing part of it.

## Bringing findings home

The peer's output is a pile of findings, not a to-do list. Each finding gets one
honest fate:

- **Fix it** when it is real and the change earns its weight.
- **Skip it on cost versus value** when the fix would add more than it lifts,
  with a one-line reason.
- **Reject it** when it is hollow, with the evidence that makes it hollow.

A finding without one of these fates is not done. When the operator asked to keep going with the peer until both are satisfied, a suggestion you have not settled goes back to the peer as a concrete proposal, not to the operator as an option.

Then surface the exchange to the operator: what the peer raised, what you did
with each point, and where the two of you still disagree. Do not smooth the
disagreements away. They are the most useful thing intervision produces, because
they mark the spots neither agent can settle alone.

P.S. Checked 2026-10-20 via `claude --help`. Versions auto-resolve; new names require a plugin update. Redate only after verification.
