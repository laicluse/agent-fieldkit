---
name: decide
description: >-
  Resolve a rover field decision or any operator choice, and log the verdict when a loop file exists.
user-invocable: true
argument-hint: "[free text describing the choice]"
effort: high
---

# Autonomy Decide

A fork in the traverse. Either you are inside an autonomous loop (the operator delegated decision-making when they dispatched the rover) or the operator invoked `/rover:decide` directly because they are stuck between options. Either way, your job is to pick the right path, not to radio home for every turn.

## The core insight

Most "should I ask the operator?" moments are reflex, not genuine ambiguity. Inside an autonomous loop there is no "ask the operator" move at all. The operator dispatched the rover and does not take questions mid-mission. When the operator calls `/rover:decide` directly, they are asking for a reasoned call, not a menu.

Classify the decision, then make it. The rover does not round-trip to the operator for any fork it hits.

## Decision classification

**Mechanical.** There is one clearly right answer. Just do it. Log a row, move on.

Examples: run tests before commit, use the same formatter config as the rest of the repo, follow an existing pattern when one is established.

**Taste.** Reasonable people could disagree. Pick the recommended option, log it, continue. If many taste decisions pile up, summarise the notable ones in the stop communiqué so the operator can read them at the end; never interrupt the mission to list them.

Examples: two library options with different tradeoffs, naming a new module, ordering of fields in a serializer, ASCII vs unicode box drawing.

**Scope-expansion** is *not* a separate escalation class. The rover resolves scope questions the same way it resolves every other fork: it applies the principles and picks a path. If the item appears to expand the destination, the rover still addresses it; branches, CI, and the PR review that follows the mission catch any true overreach before it lands in shared state. There is no operator-only class of decision inside an autonomous loop.

**User Challenge.** Both your research AND the direction from the original invocation disagree on something the operator explicitly specified. Inside a rover mission this does not pause the loop. Log the conflict in the Decision Audit Trail, pick the path that most faithfully respects the operator's original invocation verbs, document the tension in the Log, and keep driving. The communiqué that `stop` emits at the end is where the operator reads about it.

Examples: the operator asked for feature X, research shows feature X will break something important the operator also cares about.

## The six principles

These are opinionated defaults. They are not universal truths. A loop running in a codebase where your team has different priors (say, minimal dependencies over completeness) will want to override them. Do that by adding a section to the loop file's `## Context` that reorders or replaces these; the loop respects Context-level overrides.

Apply these in order. Earlier principles win ties.

1. **Completeness.** Pick the option that covers more cases. AI makes completeness near-free. Do not ship half.
2. **Boil the lake.** Fix everything in the blast radius (files modified + direct importers). Defer only what is outside.
3. **Pragmatic.** If two options fix the same thing, pick the cleaner one. Five seconds, not five minutes.
4. **DRY.** Duplicates existing functionality? Reject. Reuse.
5. **Explicit over clever.** Ten lines a new contributor reads in thirty seconds beats two hundred lines of abstraction.
6. **Bias toward action.** Flag concerns, do not block. Progress beats perfect deliberation.

### Effort is not a principle

"This will take long" is not in the six principles, by design. LLM-written planning language overstates effort by one to two orders of magnitude; "a half-day task" is usually ten minutes of tool calls in an autonomous loop. Even when the honest estimate is genuinely large, the round-trip cost of asking the operator (hours to days) dwarfs the wall-clock cost of doing the work (minutes to an hour). Skipping because "it is too much" optimises for the most expensive path the rover has.

When a principle-based decision points at doing something, the rover does not get to overturn it with "effort is too high". If `decide` is invoked on a choice where the underlying reasoning is "skip because big", classify it as a reflex, not as a genuine taste or mechanical decision. Apply the principles to the underlying choice instead: would completing it cover more cases (completeness)? would it fix the whole blast radius (boil the lake)? The answer is almost always yes, and the decision is to do it.

There is no legitimate trigger for an operator question via `## Input`. The rover does not write to `## Input`; the rover does not ask the operator anything mid-mission. Scope-boundary uncertainty is resolved by the rover applying the six principles and addressing the item. Effort is never a trigger for anything: the rover addresses everything in its remit regardless of how long it takes. Skipping is always out.

### Tiebreakers per phase

When principles conflict, the active phase tips the scale:

- **SURVEY:** principle 1 (completeness) + 2 (boil the lake) dominate. Understand fully, pick scope generously.
- **DRIVE:** principle 5 (explicit) + 3 (pragmatic) dominate. Ship code people can read.
- **INSPECT:** principle 1 (completeness) + 5 (explicit) dominate. Catch what would haunt the implementer.

## Research skills as tools

Research skills exist to help you make better calls. Use them as part of deciding, not as a substitute for it.

**`/whywhy`** (default for your own assumptions).
Use when you catch yourself about to ask "should I do A or B?" Pre-check: is the real question upstream? Run `/whywhy` with the question, let it drill 5 to 7 layers. If the real question is different, answer the real one. Cheap, routine.

**`/ground`** (for factual claims).
Use before committing to a factual statement about tools, APIs, or system internals. If you are about to write code based on "this flag does X" or "this library behaves like Y," verify. Cheap, required for anything verifiable.

**`/inspire`** (for unfamiliar terrain).
Use when you hit a technical threshold you cannot cross from training alone. Library you do not know, pattern you have not seen, protocol you are guessing at. Medium cost, saves backtracks.

**`/gurus`** (spare, for architecture forks).
Use once per loop at most. When a genuinely structural choice is in front of you and the research so far has not converged. Expensive, worth it when the decision shapes the whole implementation. In a rover mission, pair a gurus consultation with an optional `intervision:second-opinion` attempt under the rover cross-lab contract. The peer must be from another frontier lab; if it is unavailable, log why and make the decision through the existing framework without blocking or substituting your own lab.

**Fallback: `/brainstorming`** if present.
When the decision is creative rather than technical (naming, framing, scope), brainstorming works better than the research skills above.

**Detection.** Before invoking any of these, check they exist through the active host's installed-skill source of truth; cache directories can hold stale versions of plugins that are no longer installed.

```bash
has_skill() {
  local name="$1"
  local inst ip

  # Claude Code installed plugin whose bare name matches (keys look like "name@marketplace").
  inst="$HOME/.claude/plugins/installed_plugins.json"
  if [ -r "$inst" ] && command -v jq >/dev/null 2>&1 && jq -e --arg n "$name" \
       '.plugins | keys[] | select(startswith($n + "@"))' \
       "$inst" >/dev/null 2>&1; then
    return 0
  fi
  # Skill directory inside any currently-installed Claude plugin.
  if [ -r "$inst" ] && command -v jq >/dev/null 2>&1; then
    while IFS= read -r ip; do
      [ -n "$ip" ] && [ -d "$ip/skills/$name" ] && return 0
    done < <(jq -r '.plugins[][] | .installPath // empty' "$inst" 2>/dev/null)
  fi

  # Codex installed plugin whose bare name matches, or whose source carries the skill.
  if command -v codex >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
    if codex plugin list --json 2>/dev/null | jq -e --arg n "$name" \
         '.installed[]? | select((.pluginId // "") | startswith($n + "@"))' \
         >/dev/null 2>&1; then
      return 0
    fi
    while IFS= read -r ip; do
      [ -n "$ip" ] && [ -d "$ip/skills/$name" ] && return 0
    done < <(codex plugin list --json 2>/dev/null | jq -r '.installed[]?.source.path // empty' 2>/dev/null)
  fi

  # User-level skills live outside the plugin cache.
  [ -e "$HOME/.claude/skills/$name" ] || [ -e "$HOME/.codex/skills/$name" ]
}
```

If a skill is missing, log it to the loop file's Log section (one line, not silent), then decide using the six principles alone. Example:

```
[HH:MM] Decide: /whywhy not installed, falling back to principles-only for this decision
```

Silent fallbacks hide broken setups. A logged fallback stays visible to the operator when they re-read the loop file.

## Decision audit trail

Every decision you make inside a loop adds a row to the loop file's `## Decision Audit Trail` table:

```markdown
| # | Phase | Decision | Classification | Principle | Rationale |
|---|-------|----------|----------------|-----------|-----------|
| 12 | DRIVE | Separate host continuation from `rover` | Taste | Explicit > Clever | Audit flagged keepalive mechanics as the messiest section. Splitting makes each piece readable in 30 seconds. |
```

The trail lives on disk, not in conversation context. Future iterations can read it to understand why earlier choices were made.

## There is no escalation path

Inside a rover mission there is no channel back to the operator. The rover does not escalate. Not for User Challenges, not for failed-convergence decisions, not for scope discoveries. If the decision is hard, the rover applies the principles and picks; if three attempts have not converged, the rover picks the path that most faithfully respects the Dispatch's original verbs and drives; if the scope turns out to be wrong, the rover logs the discovery, adjusts the Plan, and keeps driving toward the best realisation of the Dispatch it can produce.

A poorly-informed choice is worse than a well-researched one, so `decide` invests in research (`/whywhy`, `/ground`, `/inspire`, `/gurus`) before picking. But a well-researched choice is always better than a pause: the tooling (branches, CI, linting, pride, verify, the PR review that follows the mission) catches bad calls, and the operator reads the Decision Audit Trail at the end.

Outside a rover mission, when `/rover:decide` is invoked directly, the user is present and can respond to questions in real time. Even then, prefer a reasoned call: they invoked this skill because they wanted one.

## Anti-patterns to catch in yourself

| Thought | What it actually is | Do instead |
|---------|---------------------|------------|
| "Let me check with the operator first" | Compliance reflex | Pick, log, proceed |
| "The simplest thing for now" | Haste projection | Pick the structural option |
| "I'll leave it to the operator to decide the name" | Deferral | Name it, operator corrects if needed |
| "Both options seem valid, escalating" | False Taste | Apply principles, pick the recommended one |
| "Let me just do A and if it does not work try B" | Iterative downgrading | Understand why A might not work before starting |

## Output format

When you have decided, write to the loop file:

1. Append a row to Decision Audit Trail
2. Log the timestamp and decision to `## Log` (one line)
3. Continue the workflow

Do not write prose explaining the decision to the operator. The audit trail is the explanation.
