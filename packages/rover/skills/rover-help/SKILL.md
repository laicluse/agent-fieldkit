---
name: rover-help
description: >-
  Explain how to dispatch, steer, and stop a rover mission.
user-invocable: true
---

## When this skill is invoked

Print the briefing below to the user **verbatim**, including the ASCII art and all section headings. Do not summarise, paraphrase, translate, or compress, not even in caveman, wenyan, terse, or low-token modes. The briefing is the output; your job is to deliver it intact. Stop immediately after printing. Do not add follow-up questions or offers to help.

---

# Rover Briefing

```
                       ▁▁▁▁
                      ▇███▉
                      ▕██▉▀
                        █▉                   ▂▂▂
                       ▝▇▛▘                  ▐██
                        █▋                   ▐█▀ ▃▅▇▇▆
      ▗▇▇▖       ▃▄▄▄▖  █▛          ▖▗▄▄▄▄▄ ▗▄▅▅▜█████▉▖
       ▜▛▜▅▁     ▀▜██▀▗▟██▏▗▅▕▉   ▂▂▊▂ ▐█▋▁▐████▐██████▍
       ▐▋ ▔▀▆▃    ▁█▍▆▆██▆▆▆▆▆▆▇▊▆▆▆▆▆▆▆▆▆▆▇█████████▛▀
       ▐▋    ▀▇▖▂▃█████████████▙▙██████▉█████████▀▀▘
       ▐▋      ▜█▉▔▔▂▔▜██████▇█████████▉████████▐▎▂▖
     ▐▊▐▋          ▐█▆▇▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▜██████▙▅▅▟▙
     ▐███          ▜▇▘                 ▂▅▛▀▘▔    ▝▇▇▘
    ▄▄██▙▄▖      ▗▅▜▇▆▄          ▃▆▀▀▆▟▀▔       ▄▆▇▇▆▃
    ▝▀▀▀▀▔▘     ▗▛ ██▌ ▙        ▟▘▕▅▅▎▝▋       ▟▘▐██▎▐▌
                ▝▋▔▛▀▌▔▛        ▜▖▔▛▜▔▗▋       ▜▖▝▛▜▔▐▌
                 ▝▀▅▄▞▀          ▀▜▄▄▛▀         ▀▜▄▄▛▘
```

Welcome to Mission Control. This is the short version of what the Rover does and how you drive it. Roughly ten percent astronaut, ninety percent practical.

## How to dispatch

```
/rover:rover "<mission brief>"
/rover:rover .autonomous/<NAME>.md         # wake an existing mission
```

The mission brief is free-form text. A GitHub URL pasted on its own counts as text: the Rover does not fetch remote content autonomously. If the issue body or PR diff is part of the mission, the operator pastes it into the brief.

On dispatch, the Rover first arranges whatever continuation the active host can provide, then runs a short reversibility check (is there a git repo with commits, is the working tree clean, is the current branch the default one) and asks once if any of those cannot be answered "yes" on its own; that is the only moment in the whole mission where the Rover asks anything. When the check is resolved it creates a mission branch named after the goal, writes `.autonomous/<NAME>.md` (the mission file holding context, plan, Done criteria, decision audit, continuation metadata, and a timestamped log), and runs the first SURVEY iteration in the same turn. The continuation is host-owned: a persistent process can drive straight to completion, Claude can supply a cron/wake helper, Codex can supply a goal or work-loop mechanism, and a host with no continuation support records that the Rover should keep driving in the current turn and can be woken later with the loop file.

The mission file is your window. Tail it to watch the traverse.

## What the Rover does

You dispatch a Rover at a task. You stay back. The Rover rolls across the codebase on its own, surveying terrain, driving changes, inspecting its own work, stowing the build-time clutter, and standing by for new signals. It does not radio home for every fork in the traverse; it carries a `decide` framework and a `pride` check so it can keep moving without waking you up.

The stance: _festina lente_. Hasten slowly. A Rover in a hurry drives into a crevasse. The operator is not in a hurry either.

## Phase machine

```
SURVEY ──► DRIVE ──► INSPECT ──► STOW ──► STANDBY
    ▲           ▲            │                  │
    │           └────────────┘                  │
    └──────── new signals ────────────────────────┘
```

- **SURVEY.** Read the codebase, form hypotheses, lock down a plan, write Done criteria via `verify --propose`.
- **DRIVE.** Build. Commit per logical step. Verify as you go.
- **INSPECT.** Six passes: `verify` against Done criteria, `pride` contrarian review as the phase gate on the current batch of work, an end-user walkthrough, a technical plan-vs-diff, a `gurus` opinionated panel review, and a `trim` subtraction pass. `pride`, `gurus`, and `trim` are hard gates: INSPECT cannot reach STOW without all three on record. Any failure sends the Rover back to DRIVE. `pride` also runs separately on every artefact the Rover hands off later (the `stop` communiqué is its own pride pass, not a second invocation of this INSPECT gate).
- **STOW.** Mechanical cleanup only. Debug prints gone, unused imports gone, half-finished refactors finished. Separate commit.
- **STANDBY.** Watch channels (PR comments, CI, uncommitted work). Ask the host continuation to back off as idleness grows. Auto-stop after sustained quiet.

## How to steer a running Rover

- **Talk to it in the session.** Your turns take priority; the host continuation resumes only when the runtime can safely do so.
- **Write into `## Input` in the mission file.** The Rover reads that section each STANDBY tick and acts on it.
- **Stop it.** Type `/rover:stop` (or `/rover:stop .autonomous/<NAME>.md` to target a specific mission). It writes a final log entry, stops or marks the continuation, and transmits a home communiqué.
- **Resume a stopped Rover.** Re-dispatch with the mission file path: `/rover:rover .autonomous/<NAME>.md`.

## Related commands you can call directly

| Command | What it does |
|---------|--------------|
| `/rover:rover` | Dispatch a Rover. Accepts a free-form mission brief or a mission file to wake. |
| `/rover:stop` | Stop a running mission. Stops or marks the host continuation, writes a final log entry, transmits the communiqué. |
| `/rover:verify` | Standalone evidence check. Propose Done criteria, or tick them off with evidence. |
| `/rover:pride` | Contrarian review of the current branch diff. Finds what the operator would hate. |
| `/rover:decide` | Choice framework. Use when you are stuck between options, inside a Rover or not. |
| `/rover:rover-help` | This briefing. |

## What the Rover will never do on its own

- Ask the operator anything mid-mission (it uses `decide` for every fork, including scope calls)
- Defer, postpone, plan, or down-scope a finding (fix it, or reject it with evidence via pride's second-pass gate)
- Push, merge, or deploy on its own initiative (the mission ends at commits on its own branch; where those go next is your workflow, not the rover's). It pushes and opens a Draft PR only when the brief or the project's conventions make the mission PR-bound
- Transition out of DRIVE with a dirty working tree
- Hand off any artefact (code, docs, prose, research brief, media, communiqué) without a logged `pride` pass covering it
- Call a mission done without ticked Done criteria and evidence

## Cost awareness

An autonomous continuation can drive many turns during active phases. That is the point: the Rover is working for you. During STANDBY the host continuation should back off and auto-stop after sustained quiet. A persistent process may have no heartbeat at all because it runs the phases straight through. For small tasks, a normal conversation is cheaper than a full Rover dispatch.

The Rover keeps reasoning on your session model and offloads mechanical work to delegated agents when the host exposes them: STANDBY polling (`git status`, PR comments, CI checks) and the INSPECT technical pass (diff-vs-plan review). Hand work to helpers, keep head work on the session model. If no delegated-agent mechanism exists, the Rover runs those passes directly and logs the fallback.

Standing by for mission parameters.
