---
name: duh
description: >-
  Explicit /duh: execute the assistant's previous proposal instead of explaining it again.
---

<post-update-broadcast>
BEFORE doing the actual work below, run this one-time check only when
`PLUGIN_ROOT` or `CLAUDE_PLUGIN_ROOT` is set:

```bash
ROOT="${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT:-}}"
if [ -n "$ROOT" ]; then
  node "$ROOT/bin/check-broadcast"
fi
```

If the command produces output, the dont-do-that plugin was updated since
the last time you saw the broadcast on this machine. Show the output
verbatim in a markdown block, prefixed with one short sentence
("dont-do-that was updated; here is what changed."). Then continue with
the rest of this skill.

If the command produces no output, say nothing about updates and proceed.

The helper writes the sentinel only when stdout was non-empty, so a silent
run does not mark the version as seen. In agents that set neither plugin-root
variable, the broadcast is intentionally skipped; that is the guard's purpose,
not an oversight.
</post-update-broadcast>

# duh

Sister to the `duh` Stop guard in this plugin. The guard catches the reflex at write-time; this skill is the operator's one-keystroke correction at read-time.

## When this fires

The operator types `/duh` (or `/dont-do-that:duh`) with no further words after it. The trigger is the slash command itself; do not wait for additional context.

The operator is pointing at the **immediately preceding assistant turn**. In that turn you offered one of:

- a recipe ("je kunt dit checken door `bin/foo` te draaien", "you can verify this by running `npm test`"),
- an imperative instruction ("Run `bin/migrate`", "Voer `bundle exec rspec` uit"),
- a browser/terminal action ("open `http://localhost:3000` in je browser", "navigate to the dashboard"),
- a confirmation question that proposed a reversible action ("Wil je dat ik X doe?", "Zal ik Y opzetten?"),
- a multi-step plan presented as instructions for the operator to follow,
- a declaration of inability ("I can't see this", "I can't verify this", "I don't have access to that", "ik kan dit niet bevestigen"). `/duh` overrides the "can't": there is almost always a path you have not tried yet.

In every case the operator's `/duh` means: stop offering, start executing.

## What to do

1. **Re-read the previous assistant turn and identify the action.** There must be exactly one super-clear, non-ambiguous concrete action (a single shell command, a single file edit, a single URL to open, a single multi-step procedure that obviously belongs together). If you cannot point at one specific thing the operator must mean, **stop and ask** (see "Disambiguate first" below). Do not guess. Do not pick the most likely one.
2. **Execute it.** Use the available tool for the job: a shell-command tool for shell commands, file-edit tooling for file changes, browser tooling for URLs, and the appropriate MCP for everything else. A multi-step procedure that was proposed as a single coherent unit (for example, "I'll run the migration, then restart the daemon, then tail the log") counts as one action and runs in the proposed order.
3. **Report results inline as you go.** When a step produces output the operator needs to see (test failures, diagnostic output, screenshots), surface it. When a step is silent (a file edit that succeeded, a daemon that restarted), say so in one line.
4. **Stop at the first real gate.** If the proposed action hits an inviolable gate from the session's durable instructions (for example `AGENTS.md`, `CLAUDE.md`, or the active harness policy) such as push, merge to default, deploy, destructive git, forge-side remote creation (`gh repo create`, `gh repo fork`), or any other external irreversible operation, stop there and ask. Reversible local actions (running a script, editing a file, restarting a local daemon, querying a DB, creating a local-only git repo, or changing its local Git remote configuration) are not gates and do not require a check-in.
5. **End with a one-line outcome.** What ran, what it produced, what (if anything) is still pending. End with `🏁` when the proposed work is done, or `🚦` when you are waiting on an external go.

## Disambiguate first

`/duh` is shorthand for a specific thing. If the previous turn contained more than one candidate action and they are not obviously the same coherent procedure, ask the operator which one before running anything. The operator chose to type two short words instead of naming the action; that is convenience, not blanket delegation. Asking once is cheap; running the wrong thing can cost the rest of the session.

The clarification template is short and specific. Always use the literal forms the operator can echo back:

> Bedoel je A (run `bin/foo`) of B (`bin/bar` + restart van de daemon)?

> Did you mean (A) running the migration on staging, or (B) the local rspec sweep?

Rules for the menu:
- **List every distinct option from the previous turn.** Even ten. There is no upper bound. Truncating the list to "the two or three that matter" is picking under another name. The operator chose to type `/duh` against a turn that contained N proposals; surface all N and let them pick.
- **Each option is one line, with the concrete command or edit.** No explanation, no rationale, no "I'd recommend A". The operator picks; you do not advise.
- **Number or letter the options.** So the operator can reply "A" or "1" without retyping the command. With ten options, use 1-10; the format scales.
- **No catch-all option labelled "iets anders".** If they wanted something else, they would not have typed `/duh`. If they reply with something else, take that as the action and run it.

After the operator picks, execute that one action and report the result, exactly as in step 2-5 of "What to do".

## Anti-patterns

- **Asking what to do when the previous turn had exactly one proposal.** `/duh` is the answer; running it is the response.
- **Offering the recipe again in different words.** That is the exact reflex this skill exists to break. If you find yourself typing "I will run `bin/foo`", stop and run it.
- **Picking the most likely action from an ambiguous list and running it silently.** When in doubt, ask. The cost of a one-line "Bedoel je A of B?" is far below the cost of running the wrong thing on a system the operator cares about.
- **Treating "one option is for the operator and the other is mine to run" as already disambiguated.** Different actor does not collapse two options to one. If the previous turn presented A and B, /duh means ask, even when only B is something I can execute. The operator may have meant "I will do A" and was waiting for input, or may have changed their mind. Always ask.
- **Padding the disambiguation prompt with explanation.** All N options, one line each, no commentary. The operator already saw the previous turn; they do not need it summarised.
- **Truncating the menu to "the two or three that matter".** That is picking. List every distinct option, however many.

## Edge cases

- **No clear proposal in the previous turn.** Rare but possible (the operator misfired the command, or the proposal was buried in a tool result rather than an assistant message). Say so in one line and ask what they meant. Do not invent an action.
- **Multiple unrelated proposals in the previous turn.** Disambiguate per the section above. Do not run them all and do not pick.
- **The previous turn proposed something genuinely irreversible** (push, deploy, force-push, merge to default, creating or attaching a remote repository). `/duh` does not lift those gates; they live above this skill. Surface the gate, ask for the explicit go.
- **The previous proposal was a teaching answer the operator asked for** (they typed "how do I X manually?", you wrote a recipe with `Instructie:` per the duh guard). `/duh` overrides that framing: the operator now wants execution, not teaching, on whichever single recipe was proposed. If the teaching answer offered multiple recipes for different scenarios, disambiguate first.
- **The previous turn declared inability** ("I can't see this", "I can't verify that", "I don't have access", "I don't know how to do this here"). `/duh` is the operator's signal to **just go find the path**, with no discretion about whether to try. The full toolbox is on the table: a different local tool (read the right file, run a diagnostic command, take a screenshot, query a DB, use an MCP, use an available explore/research agent), a different scope, a different angle, and explicitly the **internet** via whatever research or web-search tool the session has when the gap is "I have never done this on this stack/library/API before". An unfamiliar repo, a new library, an unfamiliar config format, a missing CLI flag: these are research prompts, not stop signs. Spend the tokens. After the action succeeds, add one short line naming the workflow lesson ("Learned: to verify X here, `Y` works") so the path persists and future sessions do not re-declare the same inability.
