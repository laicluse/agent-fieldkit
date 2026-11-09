# Instructions

The instruction-file audit pass behind the drydry pipeline. The premise: agent instructions sit a layer above the code; they can themselves cause DRY violations downstream. Two failure modes:

1. **Two paths prescribed for the same job.** An instruction file says both "use the Pundit policy" and "add a `before_action :authorize!`" without naming one as primary. Agents pick one or the other, projects accumulate both, and the code drifts. The instructions ARE the source of the duplication.
2. **Silence on existing helpers.** A project ships a `current_workspace` helper, a `notify_owner` helper, a `with_tenant` wrapper. The instruction files never name them. Agents in fresh sessions do not know they exist; they generate new code that solves the same problem with different shape. The silence is the duplication-enabler.


## Input contract

Caller supplies through `args`:

- **`instruction_paths`**: comma-separated list of instruction-file paths to audit. Mandatory. Typically `AGENTS.md`, `CLAUDE.md`, plus any sub-directory instruction files the project ships.
- **`project_root`**: the project root, used to grep for helper symbols the instructions might be ignoring.
- **`helper_directories`**: optional hint at where the project's helpers live (`lib/`, `app/helpers/`, `app/services/`, `src/utils/`, `Sources/Helpers/`). When absent, the skill infers common locations.

## Output contract

Return a markdown section the orchestrator folds into the audit artefact. The schema mirrors the rest of the audit pipeline (`pattern_id`-keyed findings) so the orchestrator's fold-in step does not special-case this task:

```markdown
## Instruction-file duplication

### Pattern: two-prescribed-paths

- Finding 1
  - instruction_file: `<path>:<line>-<line>`
  - paths_prescribed: ["<path A description>", "<path B description>"]
  - drift_hypothesis: <one sentence: what bad thing happens when half the codebase uses A and half uses B>
  - convergence_proposal: <one sentence: name one as primary, mark the other as legacy or remove>
  - verifier_command: <runnable grep for both paths in the codebase>

### Pattern: silent-helper

- Finding 2
  - helper_path: `<path>:<line>` `<symbol_name>`
  - helper_purpose: <one sentence>
  - instruction_silence: <list of instruction-file sections where this helper should have been named, with line numbers>
  - drift_hypothesis: <one sentence: agents in fresh sessions will reinvent this helper because nothing points them to it>
  - convergence_proposal: <one sentence: where in the instruction files to add the pointer>
  - verifier_command: <runnable grep for the helper symbol's call-sites>
```

Findings without a verifier_command are dropped.

## Workflow

### 1. READ the instruction files

Read each path in `instruction_paths`. Build an in-memory index of what the file prescribes: behavioral rules, workflow patterns, named tools, named scripts, named helpers.

### 2 and 3. AUDIT both patterns in parallel

The two failure modes are orthogonal: pattern `two-prescribed-paths` reads only the instruction files, pattern `silent-helper` reads the helper directories. Run both independent reviews in parallel when the host supports that; otherwise run them sequentially and record that limitation in the method notes. Neither depends on the other's output.

#### 2a. Pattern `two-prescribed-paths`

Use this brief for the first review:

```
You audit an agent instruction file for duplicated prescriptions.

File: <path>
Content: <full file content>

Tasks:
1. Walk the file section by section. For each behavioral rule, ask:
   does another rule somewhere in this file (or in a different
   instruction file in scope) prescribe a different path for the same job?
2. "Same job" examples: two ways to authorise, two ways to commit,
   two ways to run tests, two ways to format dates, two ways to log
   errors, two ways to authenticate.
3. For each duplication, name both paths, write a drift hypothesis
   (what bad thing happens when the codebase splits between A and B),
   propose a convergence direction (which path wins).
4. Provide a verifier_command: a grep over the codebase that shows
   both paths in use.

Drop duplications where one is explicitly named as primary and the
other as a legacy fallback. Drop duplications where the two paths
serve genuinely different domains. Be specific.
```

#### 2b. Pattern `silent-helper`

Identify project helpers:

- Glob `helper_directories` (or default locations) for files containing public functions, modules, or symbols
- Read each helper's docstring or top-of-file comment to infer purpose
- Build a list `(helper_path:line, symbol_name, purpose)`

Use this brief for the second review:

```
You audit an agent instruction file for missing pointers to existing helpers.

Instruction-file content: <full content>
Project helpers: <list of tuples>

Tasks:
1. For each project helper, ask: does the instruction file anywhere mention it,
   point at it, or describe the convention that would lead an agent
   to discover it?
2. When the instruction file is silent on a helper that an agent would plausibly
   re-implement, flag it. "Plausibly re-implement" means: the helper
   covers a common cross-cutting concern (auth, tenancy, formatting,
   notification, logging, query-shaping).
3. For each silent helper, write a drift hypothesis (agents will
   reinvent this in fresh sessions, producing parallel implementations
   that drift on edge cases) and a convergence_proposal (which
   instruction-file section should mention it).
4. Provide a verifier_command: a grep over the codebase showing the
   helper's call-sites (high call-site count means high re-invention
   risk).

Drop helpers that are clearly private (underscore-prefixed, in
internal/ paths). Drop helpers whose purpose is too narrow to matter
(single-use formatters, one-off migration scripts).
```

### 4. SYNTHESISE

Combine the two review reports into the output markdown under `## Pattern: two-prescribed-paths` and `## Pattern: silent-helper`. Apply caps if either pattern produced more than 10 findings; keep the highest-impact (broadest call-site count for `silent-helper`, broadest behavioural surface for `two-prescribed-paths`).

### 5. RETURN

Hand back the assembled markdown to the caller. Do not write to disk; the orchestrator's audit artefact is the canonical home.

## Rules

- **Verifier-burden is mandatory** here too. A finding without a runnable grep is dropped; the operator must be able to re-confirm the duplication or the silence.
- **Drift hypothesis is mandatory.** A finding without a Chapter 4 sentence is dropped. "The instruction file is incomplete" is not a drift hypothesis; "agents in fresh sessions will reinvent the `with_tenant` wrapper because nothing in the instruction files points at it" is.
- **No auto-fix.** This task returns findings; it does not edit instruction files. The operator decides whether to converge prescriptions or add pointers.
- **Both patterns are real and orthogonal.** An instruction file can hit `two-prescribed-paths` without `silent-helper`, or vice versa, or both. Always run both audits when this task is dispatched in audit mode.
- **User-level instruction files are read but never proposed for edit.** The skill audits user-level files if they appear in `instruction_paths`, but its convergence proposals for those files are listed as "operator considers" rather than "edit here". User-level config is operator-personal; the audit informs, it does not prescribe.
