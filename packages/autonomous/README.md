# autonomous

The layer that keeps an autonomous mission running across turns. It owns the
persistence workarounds an interactive session needs to stay alive (a cron
heartbeat with exponential backoff, auto-stop after sustained idleness, and
wake/restore after a session restart) and decides by itself whether any of that
machinery is needed.

The decision is a capability probe, not a caller flag. The `rover` plugin's
decision framework calls this layer once at dispatch and asks a single
question: am I in a persistent process, or an interactive session that pauses
between turns? The probe answers from the runtime.

## Installation

`autonomous` is Claude Code-only. Install it with `rover` and `gurus` when a
Claude Code session needs a cron heartbeat for rover missions:

```bash
claude plugins install autonomous@laicluse-agent-fieldkit rover@laicluse-agent-fieldkit gurus@laicluse-agent-fieldkit
```

In a Claude Code session, version 2.1.275 or later, one line installs it straight from the marketplace repository:

```
/plugin install autonomous --marketplace laicluse/agent-fieldkit
```

## Agent support

Codex does not currently receive this plugin because it has no compatible cron
heartbeat API or wake path for these skills. The decision framework lives in
`rover` (invoked as `/rover:...`); `autonomous` is one host-specific
continuation implementation that `rover` can call when available.

## Why this is its own plugin

A cron heartbeat is a workaround for one fact: an interactive TUI session is
not a persistent process. It runs a turn, then waits for the operator, and an
autonomous loop in that session stops between turns unless something re-enters
the conversation. A detached process (an Agent SDK run, a conveyor line) has the
opposite shape: it keeps executing until the mission completes, so a heartbeat
there is dead weight.

Splitting the keep-alive machinery out of the decision framework means the
caller no longer has to know any of this. It invokes `rover`, the rover invokes
`autonomous:keepalive`, and the autonomy layer probes its own runtime and acts.

## Skills

All skills here are internal: the `rover` plugin loads them, and the operator
does not invoke them directly.

- **`keepalive`**: the startup probe and front door. Checks whether `CronCreate`
  is available in this process. Available means an interactive session, so it
  schedules a cron heartbeat through `cron` and returns the job id. Absent means a
  persistent process, so it schedules nothing and reports back that the mission
  should just drive to completion.
- **`cron`**: the cadence machine. CronCreate, CronDelete, exponential backoff
  when the field goes quiet, auto-stop after sustained idleness, and cron
  restoration after a session restart.
- **`wake`**: bring a stalled mission back online. Reads the loop file, relights
  the cron, summarises where the traverse left off, and fires the next
  iteration. Reached via `rover:rover` with a loop-file path.

## The probe and its one assumption

The probe is correct only when need and availability coincide: a host that runs
a mission as a persistent process must withhold `CronCreate` (for example by
adding the cron tools to its disallowed-tools list), and a host whose sessions
go idle must expose it. When a persistent host still exposes the cron tools the
probe over-detects interactive and schedules a heartbeat. On the normal path that is
dead weight: a process that runs to completion never goes idle, so the cron
never fires and is torn down with the session. Only an abnormal exit can leave
it as an orphan, which the `wake` restore path reaps on the next relight. See
`skills/keepalive/SKILL.md` for the full contract.
