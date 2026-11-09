# Sweep

The detection pass behind the drydry audit pipeline. It runs an independent pass over a named scope against a named checklist and returns a structured findings list with a runnable verifier per finding. The operator types `/drydry:drydry` and the orchestrator routes here.

## Input contract

Caller supplies through `args`:

- **`scope`**: a directory, a glob, a package root, or a comma-separated list of files. Mandatory.
- **`checklist`**: either an inline markdown blob (the six-to-ten patterns), or a path to a markdown file containing one. Mandatory. Use `checklist` upstream when the caller does not already have one.
- **`exclude`**: optional comma-separated list of paths to exclude (vendor, generated, `.bundle/`, `node_modules/`, build outputs). Default excludes are inferred from `.gitignore` plus a built-in list.
- **`max_findings_per_pattern`**: optional cap, default 5. Prevents one rampant pattern from drowning out the rest.
- **`max_files`**: optional cap on the file count walked before the skill downsamples by language. Default 2000.

## Output contract

Return a JSON-like markdown structure with one section per checklist pattern:

```markdown
## Pattern: <pattern_id> -- <short pattern title>

- Finding 1
  - file_a: `<path>:<line>`
  - file_b: `<path>:<line>`
  - drift_hypothesis: <one sentence; the Chapter 4 test must pass>
  - verifier_command: `<runnable command>`
  - verifier_expected: <what the command should output to re-confirm>
- Finding 2
  - ...

## Pattern: <pattern_id_2> -- ...
```

Patterns with zero findings appear as `_no findings under this pattern_`. Patterns where the detector flagged "interesting but off-list" hits go under a separate `## Checklist gaps` section at the end (Chapter 3 keeps them out of the findings proper).

## Workflow

1. **Read the inputs.** Parse `scope`, load `checklist`. Compute default excludes from `.gitignore` plus the built-in list (`.git/`, `node_modules/`, `vendor/`, `.bundle/`, `build/`, `dist/`, `target/`, `.next/`, `coverage/`, `tmp/`).

2. **Size the scope.** Run `find <scope> -type f | wc -l` to gauge file count after excludes. When the count exceeds the caller's `max_files` (default 2000; the caller passes a different value when their project warrants it), downsample by language: keep all the language's primary source files, drop tests and fixtures unless the checklist explicitly names them. Log the downsample decision so the caller can verify.

3. **Build the detector prompt.** Use the template in this task's body (see "Detector prompt template" below). Pass:
   - The checklist verbatim.
   - The scope file list (or a glob the detector can expand itself).
   - The verifier-burden rule (every finding carries a runnable verifier).
   - The drift-hypothesis rule (every finding carries a Chapter 4 sentence).
   - The off-list rule (anything outside the checklist goes to `## Checklist gaps`, not into the findings).
   - The `max_findings_per_pattern` cap.

4. **Run the independent detector.** Use the host's native independent-review capability when available. In Claude Code this can be an Agent tool call with `subagent_type: Explore`; in Codex use native subagents when exposed, otherwise run a separate deliberate pass in the current session and record that limitation in the returned method notes. The detector needs read/search/shell access for verifier work. Token budget: enough for a thorough walk; do not skim.

5. **Filter the response.** Walk the detector's output:
   - Drop any finding without a verifier_command.
   - Drop any finding whose drift_hypothesis matches the Chapter 4 anti-patterns ("a bit messy", "would be cleaner to share", "feels redundant" without a concrete bad-thing-if-drifts).
   - Cap each pattern at `max_findings_per_pattern`.
   - Keep `## Checklist gaps` separately.

5b. **Run each verifier in this task's own context.** For every finding that survived step 5, execute its `verifier_command` here in sweep, not relying on the detector's claim that it ran. Drop the finding if the command exits non-zero, produces no matching output, or returns lines that do not contain both `file_a` and `file_b`. This is the only check with teeth; the detector's self-report is not enough.

6. **Return.** Hand back the filtered markdown structure to the caller. Do not write to disk; the caller owns the artefact.

## Detector prompt template

```
You are a duplication-detection reviewer.

Scope: <inline or file list>
Excludes: <comma-separated>

Checklist (the only patterns you may report under):

<inline checklist verbatim>

Rules:

1. For each pattern, find at most <max_findings_per_pattern> distinct
   instances in scope. A "finding" is a pair (or set) of locations that
   match the pattern.

2. Verifier-burden discipline. For every finding, produce a runnable
   command (grep, rg, ast-grep, find ... -exec) that re-confirms the
   pair without you in the loop. If you cannot produce one, drop the
   finding. Do not invent a command you did not actually run.

3. Drift-hypothesis discipline. For every finding, write one sentence
   that answers "what bad thing happens if these two paths keep
   drifting?". Do not write "the code is a bit messy" or "it would be
   cleaner to share"; those are not drift hypotheses. Write the
   concrete consequence (a UI bug, a silent data loss, a localisation
   miss, a security regression, a deploy that breaks the second path).

4. Off-list rule. If you notice a pattern that is not in the checklist
   but seems important, do not silently report it under the closest
   matching pattern. Put it under a separate "## Checklist gaps"
   section at the end so the operator can fold it into the next sweep.

5. Output format: per pattern, the schema below.

   ## Pattern: <pattern_id> -- <short pattern title>

   - Finding 1
     - file_a: `<path>:<line>`
     - file_b: `<path>:<line>`
     - drift_hypothesis: <one sentence>
     - verifier_command: `<runnable command>`
     - verifier_expected: <what the command outputs to re-confirm>

   Empty patterns: "_no findings under this pattern_".

Do your homework: actually run the verifier commands you propose, do
not paste a regex you think looks right. The pipeline drops findings
whose verifier does not run cleanly.
```

## Rules

- **Verifier-burden is mandatory.** Hits without a runnable verifier are dropped at filter-time even if the detector reported them.
- **Drift hypothesis is mandatory.** A hit without a Chapter 4 sentence is dropped.
- **Off-list hits go to `## Checklist gaps`, not into the findings.** Chapter 3 keeps the audit deterministic.
- **The orchestrator owns the artefact.** This task returns markdown to the caller and writes nothing to disk.
- **Token honesty.** When the scope is too large to walk thoroughly, downsample and log the decision instead of pretending the walk was complete.
