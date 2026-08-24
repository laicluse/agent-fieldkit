---
name: prepare
description: >-
  Prepare a rover loop file in another repo so it can be woken later.
---

# Autonomy Prepare

Lay a rover loop file in another repo's `.autonomous/` now, so the operator can wake it later from inside that repo. Useful when the conversation context for the mission lives here, but the work has to happen there. Also useful when you want to queue up multiple missions in different repos and pick them up one by one.

Prepare is to rover what writing-a-letter-and-leaving-it-on-the-desk is to picking up the phone. The rover is dispatched and runs immediately. Prepare hands the operator a sealed envelope they open from inside the target repo when they are ready.

## Arguments

Free-form text describing:
- The mission (what the rover should do, in action verbs)
- The target repo (a path on disk: absolute, tilde-expanded, or relative to the current working directory)
- Optional: integrations (`notify_on_done`, `reviewbot`, `commit_splitter`) the same way rover parses them

Examples:

- `/rover:prepare ~/code/foo fix the OAuth flow`
- `/rover:prepare /Users/me/projects/foo fix the OAuth flow`
- `/rover:prepare ../bar refactor the Settings page`

The conversation up to this point is the source of mission context. The operator is invoking prepare because what they want the rover to do has just been discussed; pull from that.

## What it does

1. **Resolve target repo path.** Accept an absolute path, a tilde-expanded path, or a relative path (`./`, `../`, or anything containing a `/`). Anything else (a bare name, an `owner/repo` slug, a phrase) is not a path; ask the operator for an explicit one (this is the only case prepare halts for input, it has nothing else to fall back on). Operators who want slug-style invocation can document a personal mapping in their active agent instructions or a shell function; the skill itself stays neutral about clone layout. Verify the resolved path has `.git/`. If not, surface the error and stop.

2. **Distil mission `<NAME>`.** ALL-CAPS, hyphens, no spaces. Goal not mechanism. Same conventions as rover. `ADD-RAW-SOURCES-SUPPORT.md` not `RAW-SOURCES-CLI-WORK.md`. Distil from the dispatch's action verbs.

3. **Suggest a kebab-case mission branch.** Same conventions as rover step 2 (no slashes, no prefixes, no rover or space-mission words: `add-raw-sources-support`, `fix-oauth-flow`, `refactor-settings-page`). The branch is recorded in the loop file but not created on disk; the operator runs `git checkout -b <name>` themselves at wake time.

4. **Write `<repo>/.autonomous/.gitignore` with content `*`** if it does not yet exist. Use the Write tool so parent directories are created automatically.

5. **Write `<repo>/.autonomous/<NAME>.md`** using the rover template, with these specifics:
   - `branch:` filled with the suggested kebab-case mission branch name
   - `continuation: none (prepared; wake with /rover:rover)`
   - `continuation_handle:` empty
   - `legacy_cron_job_id:` empty
   - `watch_checks: 0`
   - Phase: SURVEY
   - Dispatch: verbatim brief from the operator's invocation argument, plus any directly relevant operator quotes from the conversation that frame the intent. Mark the source of each quote.
   - Context: 2 to 5 paragraphs distilled from the current conversation. Pull in:
     - Why this mission exists (what surfaced the need)
     - What is known about the target codebase or domain from the conversation so far
     - What is in scope and out
     - Constraints, source URLs, design references the operator and you have already gathered
     - Optional integrations the operator named
   - Plan: leave as the placeholder line.
   - Done criteria: leave as the placeholder line.
   - Decision Audit Trail: empty header row only.
   - Input: empty placeholder.
   - Log: one entry timestamped from `date +%H:%M`, recording that the file was prepared in advance via prepare from another session, continuation is not running yet, mission branch is not created yet, and how the operator picks it up. Example:
     ```
     [HH:MM prepare] Prepared in advance by /rover:prepare. Continuation NOT running, mission branch NOT created. Operator picks up by: cd <repo> && git checkout -b <branch>, then /rover:rover .autonomous/<NAME>.md.
     ```
   - Instructions: same canonical block as rover (Phases, Decisions, Interjections, Commits and what happens after, Timestamps, Source of truth).

6. **Report to the operator.** Print the exact path written, the branch name proposed, and the two commands they run to start the mission:
   ```
   cd <repo>
   git checkout -b <branch>
   ```
   Followed in an agent session in that repo by:
   ```
   /rover:rover .autonomous/<NAME>.md
   ```

## What it does not do

- Does not arrange host continuation. The mission lies dormant until wake.
- Does not create the mission branch in the target repo. The operator does that when they pick the mission up.
- Does not commit anything in either repo.
- Does not push, merge, or deploy.
- Does not run a SURVEY iteration. The first iteration happens at wake.
- Does not modify the originating repo (where prepare was invoked from). The target repo's `.autonomous/` is the only filesystem write.

## Why split out from rover

Rover's setup contract assumes: I am dispatched here, I run here. Setup steps 1 through 6 (continuation, branch, leftovers, gitignore, loop file, first SURVEY) all happen now in the cwd. That contract is wrong for the case where the conversation context belongs to one repo (or no repo at all), but the mission target is somewhere else.

Prepare strips setup down to the minimum needed for the operator to pick the mission up later from inside the target repo: the loop file with full context, plus `.gitignore`. Everything else (host continuation, mission branch, leftovers, first SURVEY) is rover's job at pickup time. The pickup command is `/rover:rover .autonomous/<NAME>.md`; rover detects the path argument, reads the file, arranges host continuation if available, and continues the phase machine from the file's current state.

## Optional integrations

Same parsing as rover's free-form text path. If the operator names a notifier, reviewbot, or commit_splitter in the brief, parse it, verify the skill or binary exists with the `has_skill` helper from `decide`, and write the value into the Integrations block. If a named integration is not installed, write a loud line to the Log instead of silently skipping, same as rover:

```
[HH:MM prepare] Operator mentioned <skill> but it is not installed. Integration disabled.
```

## Source of truth

The Dispatch block in the prepared loop file is verbatim and never paraphrased once written, same rule as rover. Context is interpretation. Wake reads both; the rover phase machine that wake hands off to compares against Dispatch, never only against Context.

Operator-quoted text included in the Dispatch should be marked as such (with a brief attribution like `[Operator context at invocation, YYYY-MM-DD:]`) so the rover, reading the file later in a fresh session, can tell what was the literal invocation argument and what was framing.

## Naming the loop file

Same rules as rover. ALL-CAPS, hyphens, no spaces. Goal not mechanism.

- `ADD-RAW-SOURCES-SUPPORT.md` (good: names the goal)
- `FIX-OAUTH-FLOW.md` (good)
- `REFACTOR-SETTINGS-PAGE.md` (good)
- `RAW-SOURCES-CLI-WORK.md` (bad: names the mechanism)
- `WORK-ON-BRAINS.md` (bad: vague)

If a loop file with the same name already exists in the target's `.autonomous/`, do not overwrite. Append a numeric suffix (`ADD-RAW-SOURCES-SUPPORT-2.md`) and tell the operator. The original is somebody's in-flight or queued mission; respect it.
