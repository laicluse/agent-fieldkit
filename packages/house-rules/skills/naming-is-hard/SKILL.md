---
name: naming-is-hard
user-invocable: true
description: >-
  Apply naming and wording doctrine to code symbols, files, branches, docs, UI copy, and mixed Dutch/English terms.
---

<post-update-broadcast>
BEFORE doing the actual work below, run this one-time check only when
`CLAUDE_PLUGIN_ROOT` is set:

```bash
if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; then
  node "${CLAUDE_PLUGIN_ROOT}/bin/check-broadcast"
fi
```

If the command produces output, the house-rules plugin was updated since
the last time you saw the broadcast on this machine. Show the output
verbatim in a markdown block, prefixed with one short sentence
("house-rules was updated; here is what changed."). Then continue with
the rest of this skill.

If the command produces no output, say nothing about updates and proceed.

The helper writes the sentinel only when stdout was non-empty, so a silent
run does not mark the version as seen. `/whats-new house-rules`
re-shows the section on demand without touching the sentinel.
</post-update-broadcast>

# Naming Is Hard

Use this skill as the canonical naming and wording source before inventing or
normalizing names. The title points at the Phil Karlton line usually rendered
as: "There are only two hard things in Computer Science: cache invalidation and
naming things." Martin Fowler records the quote and its early web trail; David
Karlton records it as something Phil used at Netscape.

Public attribution references:

- Martin Fowler: https://martinfowler.com/bliki/TwoHardThings.html
- David Karlton: https://www.karlton.org/2017/12/naming-things-hard/

## Quick Workflow

1. Read the nearest project instructions first: `AGENTS.md`, `CLAUDE.md`,
   `README.md`, and any local domain docs that clearly own the
   vocabulary.
2. Search before inventing. Use `rg`, `git log`, and neighboring code/docs to
   find the existing term for the concept. A slightly imperfect established
   name beats a fresh synonym that creates drift.
3. Apply this precedence: explicit user wording, project/domain vocabulary,
   framework or language convention, this skill, then general corpus defaults.
4. Prefer domain nouns and user-visible capabilities over implementation
   mechanics. Name the thing by what it means in the system, not by which file,
   class, agent, framework, or refactor produced it.
5. If a comment or explanation is needed only because a name is vague, improve
   the name, signature, boundary, or domain model first.
6. Keep internal AI scaffolding out of shareable names and prose. Commits, PRs,
   READMEs, comments, branch names, and UI copy describe the product or change,
   not the agent or toolchain.

## Core Rules

- Code names are English: variables, methods, classes, modules, packages,
  files, config keys, commands, feature identifiers, branch names, worktree
  names, and commit subjects.
- Notes, folders and attachments in a Markdown vault are titles, not code
  names. Name them like a person titles them, in the vault's language, with
  sentence-case capitals, spaces and diacritics: `Gap-analyse visuele taal.md`,
  never `gap-analyse-2026-09-30.md`. A distinguishing date or sequence goes in
  front with ` · `, as Tilt does: `2026-09-30 · Gap-analyse visuele taal`.
- Human conversation may be Dutch when the channel or project uses Dutch, but
  technical terms, library names, framework names, product names, and domain
  jargon stay in their established language.
- Do not literally translate English metaphor verbs into Dutch when the Dutch
  word only has the physical meaning. Pick a natural Dutch verb or keep the
  established English/code-switched term.
- Commit subjects are imperative English, aimed at about 50 characters and no
  more than 72. Describe the capability or behavior change, not the file
  operation.
- Pull requests are proposals to humans. Lead with context and intent. Do not
  use default agent templates, agent footers, or rendered diffs as prose.
- Branch and worktree names describe the domain or feature. They do not contain
  agent, vendor, or tool names.
- In chat-like human communication, keep the greeting generic and the message
  short. Do not use private names or internal setup details.
- For issue and PR references in intentional prose, use full URLs rather than
  bare `#123`.

## Detailed Doctrine

Read `references/naming-doctrine.md` when the task involves a nontrivial naming
choice, a rename, a cross-language wording decision, a branch/worktree/project
name, a commit or PR title/body, a user-facing message, or a category not
covered by the quick rules.
