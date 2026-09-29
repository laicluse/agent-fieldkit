# rover

Dispatch a rover at a task. You stay back, the rover works in the field. The
distance means it decides locally rather than round-tripping every question, so
the plugin carries a `decide` framework, a contrarian `pride` check, a
subtraction-biased `trim` pass, and an evidence-discipline `verify` pass. The
rover only reports done when the mission is solid.

This is the decision framework half of the old `autonomous` plugin. The
keep-it-running half (cron heartbeat, wake/restore, goal loops, self-check
wake-ups, persistent runners) is now a host-owned continuation concern. Rover
records a loop file and tells the active agent to arrange whatever continuation
mechanism that runtime supports; it does not hard-code one implementation.

Use `rover` for long-running or high-stakes work where the agent needs a field
loop instead of a single conversational answer: survey the task, drive the work,
inspect the result, apply pride/trim/verify gates, and return a mission report.

## Installation

Install `gurus` alongside `rover`; rover uses it for the INSPECT panel review.

```bash
claude plugins install rover@laicluse-agent-fieldkit gurus@laicluse-agent-fieldkit
codex plugin add rover@laicluse-agent-fieldkit
codex plugin add gurus@laicluse-agent-fieldkit
```

Claude Code sessions that need a cron heartbeat can additionally install
`autonomous@laicluse-agent-fieldkit`; that plugin is one implementation of the
continuation contract, not a rover dependency. Other hosts may satisfy the same
contract with goal loops, schedulers, or self-check wake-ups that re-enter a
quiet persistent run.

## Dependencies

- **`gurus@laicluse-agent-fieldkit`** (same marketplace): the rover invokes
  `gurus:gurus` once per mission at INSPECT for opinionated panel review; the
  orchestrator routes to `gurus:software`, `gurus:council`, `gurus:writers`,
  or any future panel.

- **`intervision@laicluse-agent-fieldkit`** (optional, same marketplace): with each gurus review, attempt a second opinion from the other frontier lab. Codex asks Claude and Claude asks Codex through the host-specific `intervision:second-opinion` skill. The peer needs its own working CLI/login and available quota. If it is unavailable, record the reason and continue with the existing review workflow; never substitute a reviewer from the executing lab.

No other hard dependencies. Optional integrations (notifier, reviewbot,
commit-splitter) are user-named at invocation and only used when installed.

## User-invocable skills

### `/rover:rover [loop-file-path | free-form text]`

Entry point. Accepts a loop file path to resume or free-form mission text (a
description, a pasted issue body, a GitHub URL). Writes
`.autonomous/<NAME>.md` (the loop file), records the host continuation
mechanism if one is available, and runs the first SURVEY iteration. A host
continuation may be a cron, goal loop, scheduler, or self-check wake-up; rover
only records the opaque handle. The rover does not fetch remote content on its
own; paste an issue body or PR diff into the invocation if it is part of the
mission.

### `/rover:stop [loop-file-path]`

Cleanly stop a running mission. Cancels or marks the host continuation
mechanism when one was recorded, writes a final log entry, and transmits a
mission-report communiqué.

### `/rover:pride [git-range | uncommitted]`

Spawns a contrarian agent that reviews a rover artefact for what the user would
notice but the rover missed. Hard gate inside the rover on every artefact
(code, docs, prose, research briefs, media, communiqués), not just pushes. Also
invocable directly.

### `/rover:trim [git-range | uncommitted]`

The subtraction pass: what got added that does not earn its weight? Hard gate in
INSPECT, the inverse of pride.

### `/rover:verify [--propose <loop-file> | <loop-file> | free text]`

Evidence discipline. With `--propose`, writes Done criteria at the end of
SURVEY. Default mode ticks each criterion with evidence at the end of INSPECT.

### `/rover:decide [free text]`

Choice framework for a fork in the field, or for any moment an operator is stuck
between options.

### `/rover:prepare [target repo + mission brief]`

Lay a rover loop file in another repo's `.autonomous/` now, so the operator can
pick it up later from inside that repo.

### `/rover:rover-help`

The rover briefing.

## Phase machine

```
SURVEY -> DRIVE -> INSPECT -> STOW -> STANDBY
```

The loop is autonomous. It does not ask questions mid-phase. When it hits a
choice it invokes `decide`. Before any artefact leaves the rover (push, PR,
handoff communiqué, research brief, generated doc, media, or any other
deliverable) it invokes `pride`. Pushes themselves are never autonomous: the
user must say "push" or equivalent.

## Loop file

Lives in `.autonomous/<NAME>.md` at the git root. Holds context, plan, Done
criteria, decision audit trail, and a timestamped log. Tail it to watch
progress. The format is unchanged from the old `autonomous` plugin, so existing
loop files still wake.
