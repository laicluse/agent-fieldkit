---
name: self-improvement
user-invocable: true
description: >-
  Route agent-behavior feedback into durable fixes in hooks, skills, code, or instruction sources.
---

<post-update-broadcast>
BEFORE doing the actual work below, run this one-time check only when
`CLAUDE_PLUGIN_ROOT` is set:

```bash
if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; then
  node "${CLAUDE_PLUGIN_ROOT}/bin/check-broadcast"
fi
```

If the command produces output, the self-improvement plugin was updated since
the last time you saw the broadcast on this machine. Show the output
verbatim in a markdown block, prefixed with one short sentence
("self-improvement was updated; here is what changed."). Then continue with
the rest of this skill.

If the command produces no output, say nothing about updates and proceed.

The helper writes the sentinel only when stdout was non-empty, so a silent
run does not mark the version as seen. In agents that do not set
`CLAUDE_PLUGIN_ROOT` the broadcast is intentionally skipped; that is the
guard's purpose, not an oversight.
</post-update-broadcast>

# Self-Improvement

Turn user feedback into a durable improvement. Do not default to adding a line
to the nearest instruction file. First choose the strongest enforcement level,
then the broadest correct scope, then edit the source that owns that behavior.

When the feedback is clear, apply the change. Do not stop at advice unless the
change would cross an explicit approval gate or the target cannot be found.

## Core Rule

Walk both ladders before editing anything:

1. Enforcement ladder: what kind of target can make the mistake less likely?
2. Scope ladder: where does this rule actually apply?

The common failure is pinning feedback to the current repo's `AGENTS.md` or
`CLAUDE.md` because that file is nearby. Nearby is not the same as correct.

## Enforcement Ladder

Pick the first level that can structurally address the feedback.

1. **Hook or structural enforcement.** If a hook, permission rule, linter,
   test, schema, commit hook, pre-push gate, or deterministic script can catch
   the behavior, prefer that. Hook reason text is visible exactly when the
   mistake happens.
2. **Skill or plugin.** If no structural gate fits, sharpen an existing skill
   or create a new one. Skills carry workflow nuance better than global prose.
3. **Project code.** If the same mistake recurs because the codebase invites it,
   fix the code: consolidate duplicate paths, rename confusing APIs, add a type
   guard, delete dead lookalikes, or add a test for the invariant.
4. **Instruction file.** Last resort. `AGENTS.md`, `CLAUDE.md`, user-level
   instructions, and project instructions are broad reminders; they are weaker
   than hooks, skills, and code.

Other targets can sit between these levels: helper scripts in `bin/`, fixtures,
tool config, generated adapters, or project-local docs. Use the same principle:
prefer the target that changes future behavior closest to the failure point.

## Scope Ladder

After choosing the enforcement level, choose the broadest scope where the rule
still holds.

1. **Cross-agent / cross-project.** Applies across languages, repos, or agent
   clients. Target a shared marketplace plugin, shared skill, shared hook, or
   user-level instruction source.
2. **Cross-project but stack-specific.** Applies to all Rails apps, all iOS
   projects, all React frontends, and so on. Target a framework-scoped skill or
   shared framework guidance.
3. **One repo.** Applies across the current repository. Target repo-level code,
   repo-level skills/docs, or root instruction sources.
4. **One subproject.** Applies only below one package/app/service. Target that
   subproject's code or local instruction source.

Where the feedback arose is evidence, not the scope. Ask whether the same rule
would hold in a sibling repo or another stack before choosing a narrow target.

## Marketplace Repos

If the current project is a plugin marketplace, user-level instruction edits are
not a valid fix for plugin-related feedback. Marketplace users need the fix in
the plugin source.

Marketplace indicators include:

- `.claude-plugin/marketplace.json`
- `.agents/plugins/marketplace.json`
- `packages/*/.claude-plugin/plugin.json`

In a marketplace, route feedback like this:

- Hook behavior: edit the hook script, helper library, or hook manifest.
- Skill behavior: edit `packages/<plugin>/skills/<skill>/SKILL.md`.
- Plugin metadata: edit `.claude-plugin/plugin.json` or marketplace source.
- Adapter drift: run the repo's adapter build/check commands.
- General package docs: edit `packages/<plugin>/README.md`.

Do not edit runtime caches as source. Caches live under agent-managed install
directories and are overwritten by plugin updates. Find the source repo under
`~/github.com/<owner>/<repo>/` or use the current marketplace checkout.

## Instruction Files

Instruction files are valid only after the stronger targets do not fit.

Common targets:

- Project-level: `AGENTS.md`, `CLAUDE.md`, or equivalent files in
  the repo.
- User-level: the active agent's personal instruction source.
- Generated targets: files that say they are generated must be fixed at their
  source, then rebuilt. Do not hand-edit generated instructions.

Keep personal context out of project-level files. If a rule is personal, keep it
in user-level instructions. If it is useful to other users of a plugin or repo,
move it into that shared source instead.

## Existing Skills

When feedback names a skill, hook, or plugin, inspect that source before any
instruction file. If the principle is already present but was missed, sharpen
the source: add a clearer trigger, an explicit anti-pattern, a checkpoint, or a
short example. "It already says that" is not a resolution when the miss just
happened.

When no existing skill fits but the workflow is repeatable, create a skill in
the appropriate marketplace or user-level skill directory. Use the active
agent's skill-authoring guidance and this repo's existing package conventions.

## Pruning

Self-improvement is allowed to delete, shorten, merge, or simplify. Do not only
append.

Prune when you find:

- the same rule in two places
- stale agent names, old plugin names, or obsolete paths
- procedural detail in a global instruction file that belongs in a skill
- a narrow project rule that is actually cross-project
- a broad rule that only applies to one package or workflow

One clear source of truth beats mirrored reminders.

## Workflow

1. Identify the feedback and the behavior it should change.
2. Walk the enforcement ladder and choose the strongest fitting target.
3. Walk the scope ladder and choose the broadest correct source.
4. Locate existing sources with `rg`/file search before creating anything.
5. Make the smallest durable, actionable edit. Use a concrete failure example, not broad restrictions; preserve judgment elsewhere.
6. Rebuild generated adapters or instruction targets when the repo provides a
   build/check command.
7. Run focused tests or validation for the changed surface.
8. Report what changed and where.

If you cannot find the source, say exactly what you checked and what blocked the
edit. Do not patch a cache or a generated file as a substitute.

## Red Flags

Stop and re-walk both ladders if you catch yourself thinking:

- "I will first edit `AGENTS.md`/`CLAUDE.md`" while the feedback names a skill,
  hook, plugin, command, or generated target.
- "This is general agent behavior, so it belongs in global instructions" before
  checking whether a hook or skill can carry it.
- "The feedback happened in this repo, so the rule belongs in this repo" without
  checking whether it applies across repos.
- "The skill already says this, so there is nothing to change" after the user
  just corrected that behavior.
- "I will edit both the skill and the instruction file for double coverage."
  Duplicate enforcement drifts; put the rule in the owner source.

## Examples

- Commit discipline feedback that applies everywhere belongs in
  `git-discipline` hook/skill sources, not one project's instruction file.
- Feedback about a plugin hook's wording belongs in that hook reason text.
- "Always use `travel_to` in time-sensitive Rails specs" is stack-specific; use
  a Rails-scoped source, not a single app's local note unless no shared Rails
  source exists.
- A recurring mistake caused by two duplicate code paths should be fixed by
  converging the code, not by adding a reminder to be careful.
