# dont-do-that

`dont-do-that` is a Claude Code and Codex guardrail plugin for stopping common agent reflexes before they become repository damage. It runs hook-time guards on shell commands, file edits, persisted prose, and final answers, then adds three operator correction skills: `/duh`, `/just-a-question`, and `/not-your-monkey`.

Use it when you want an agent session to keep moving while still blocking the
habits that repeatedly cause harm: unapproved remote setup, deploys from
worktrees, unexplained code comments, stale verification handoffs, option menus
that dodge a decision, PR template filler, and other patterns listed below.

## Installation

```bash
claude plugins install dont-do-that@laicluse-agent-fieldkit
codex plugin add dont-do-that@laicluse-agent-fieldkit
```

## What it installs

- PreToolUse guards that can deny risky shell commands or file edits before
  they run.
- PostToolUse guards that surface rewrite context after persisted text or shell
  commands contain known friction patterns.
- Stop guards that block weak final answers and force the active agent to
  continue, verify, or rephrase.
- `/duh`, a read-time correction skill that executes the assistant's previous
  proposal instead of explaining it again.
- `/just-a-question`, a read-only lock for turns that should answer without
  changing files, git state, processes, or external systems.
- `/not-your-monkey` / `$not-your-monkey`, a visual self-inspection correction skill for turns where the agent must stop making the operator reload and judge UI changes.

## Agent support

Claude Code receives the full hook stack. Codex receives the same event layers
through `hooks/hooks.codex.json`, materialized by `circus plugins build` as
`hooks/hooks.json` in the generated Codex adapter package.

Guard placement and per-agent policy live in `hooks/guards.json`. An agent
absent from a guard's `agents` map defaults to `enabled`; only an explicit
`disabled` removes a guard for that agent. Codex currently disables only two
Stop guards:

- `premature`, because its nudge turn can replace an otherwise-complete
  assistant answer in the Mac app.
- `estimate`, because it is a prose-quality guard that should not block Codex
  close-outs.

Every other registered guard runs for Codex.

## Guard catalog

PreToolUse Bash denies invalid or risky command attempts before they run:

- `no-osascript`: blocks `osascript` and common wrapper forms. Claude, Codex.
- `no-remote`: blocks `git push` with no remote or an unknown named remote.
  Claude, Codex.
- `no-remote-create`: blocks `gh repo create` and `gh repo fork`. Claude, Codex.
- `no-worktree-deploy`: blocks `ansible-playbook` from a git worktree unless
  read-only flags are used. Claude, Codex.
- `no-worktree-marketplace`: blocks any linked git worktree passed as a persistent Claude or Codex marketplace source, regardless of the command's current directory; primary checkouts and remote sources remain valid. Claude, Codex.
- `plugin-mutation`: gates the Claude and Codex plugin commands that change which code the machine loads, being install, uninstall, disable, and marketplace add or remove. Updating or enabling an already installed plugin is ordinary agent work and stays ungated. A gated command reaches the operator through the host's own permission prompt (PreToolUse `permissionDecision: "ask"`, which shows the exact pending command) in the modes that still show one; in every other mode and on hosts without an ask channel it is denied, with `DD_PLUGIN_MUTATION=asked` named as the prefix to re-run with once the operator has asked for that exact change. Claude, Codex.
- `pr-discipline`: blocks weak `gh pr create` / `gh pr edit` titles and
  template or tooling-attribution bodies. Claude, Codex.
- `dash-bash`: denies Bash commands containing a real em-dash or en-dash before any side effect occurs. Claude, Codex.
- `followup`: blocks `gh api` bodies that quietly defer work without
  `Bewust uitgesteld:`. Claude, Codex.

PreToolUse file-edit denies unclear code edits:

- `no-code-comments`: blocks new code comments in programming-language files
  unless explicitly allowed. Claude, Codex.

PostToolUse context guards surface rewrite instructions after persisted text is created:

- `dash`: catches em-dash or en-dash characters and HTML entity forms in persisted Markdown, text, MDX, or patch additions. Claude, Codex.
- `land`: catches vague `land` / `landing` / `landed` / `geland` / `landt`
  wording in persisted text. Claude, Codex.
- `reread`: asks for a reread of the whole section after lines are added to an
  instruction artefact. Claude, Codex.

Stop guards block weak final answers and make the agent continue:

- `pre-existing` (`false-claims`): blocks claims that a failure was
  pre-existing instead of fixing or proving parallel work. Claude, Codex.
- `tool-error`: blocks a final answer immediately after a failed tool call.
  Claude, Codex.
- `cache`: blocks blaming localhost problems on cache instead of finding the
  root cause. Claude, Codex.
- `estimate`: blocks effort or scope framed in hours, days, weeks, or months.
  Claude only.
- `prefer`: blocks option menus handed back without a reasoned recommendation
  unless the options include an external irreversible gate. Claude, Codex.
- `premature`: blocks clipped final answers without a substantive finish or
  waiting marker. Claude only.
- `verify`: blocks asking the operator to verify something the agent can check
  itself. Claude, Codex.
- `duh`: blocks giving runnable recipes instead of running the action. Claude,
  Codex.
- `compliance`: blocks reversible local confirmation questions after a clear
  instruction while letting external irreversible gates stay questions. Claude,
  Codex.
- `jargon`: blocks coined approval-gate `-go` compounds in operator-facing
  text. Claude, Codex.

## Bash guards

### `no-osascript`

Denies Bash tool calls that invoke `osascript`, including `/usr/bin/osascript`
and wrapper forms such as `sudo`, `env`, `command`, `exec`, `nohup`, `arch`, and
command substitutions. Pass condition: use an explicit host-owned UI or browser
capability, or a project-native command path that does not execute AppleScript.

### `no-remote`

Denies `git push` when the current repo has no configured remote, or when the
push names a remote that is not configured. The guard follows a leading
`cd <path> &&` before checking remotes, then falls back to the hook cwd. Pass
condition: add or choose a configured remote through the operator-approved
route, or keep the work local.

### `no-remote-create`

Denies forge-side remote creation through `gh repo create` and `gh repo fork`.
Creating account-bound state cannot be fully undone because names, audit events,
notifications, and visibility mistakes may already have existed. Pass condition:
the latest user turn explicitly approves the same forge action, or the operator
creates it through the active host. Local `git remote add` and `git remote
set-url` configuration is allowed; the separate push policy still governs
whether anything may be published.

### `no-worktree-deploy`

Denies `ansible-playbook` invocations when the cwd is a git worktree rather than
the canonical checkout. The check compares `git rev-parse --git-dir` against
`--git-common-dir`, so it works for any worktree layout. Read-only flags pass:
`--check`, `--syntax-check`, `--version`, `--help`, `--list-tasks`,
`--list-hosts`, `--list-tags`, and `-h`.

Pass condition: merge the branch to the default branch first and run
`ansible-playbook` from the canonical checkout, or restrict the worktree call to
a read-only preview flag.

### `pr-discipline`

Denies `gh pr create` and `gh pr edit` when the PR title starts with a placement
or generic git-action verb from the git-discipline Rule 1 vocabulary, including
`Fix`, `Improve`, `Update`, `Change`, `Refactor`, `Add`, `Move`, `Remove`,
`Land`, `Ship`, `Wire`, and similar verbs. PR titles should describe the
user-visible capability that exists now, not the placement action used to get
there.

The same guard denies PR bodies with fixed-section or AI-attribution signatures:
`## Summary`, `## Test plan`, a generated-with footer, or a `Co-Authored-By`
trailer with an `@anthropic.com` email.

Pass condition: write the title as the capability now present, and use a short
body about why the change matters without template or tooling attribution.

### `followup`

Denies `gh api` commands whose body contains deferral language such as
"follow-up", "wordt opgepakt", "buiten scope", or "in een volgende pr" unless
the body starts with `Bewust uitgesteld:`. Pass condition: prefix the body with
`Bewust uitgesteld:` to claim an explicit deferral, or rewrite the body without
deferral language.

Commit-message discipline lives in the `git-discipline` plugin and the
`/git-discipline:commit-discipline` skill. `dont-do-that` still owns
`pr-discipline` because it protects PR creation and editing, not `git commit`.

## File-edit guard

### `no-code-comments`

Denies file-edit tool calls that introduce a code comment in a programming
language source file. Claude `Edit`, `Write`, and `MultiEdit` inputs compare
old-side and new-side content; Codex `apply_patch` inputs inspect only added
patch lines per target file.

The guard uses per-language awk tokenizers in two modes:

- `slash` for C-family languages: JS, TS, Swift, Kotlin, Java, Scala, Groovy,
  Go, Rust, C, C++, C#, Dart, and Objective-C.
- `hash` for script-family languages: Python, Ruby, Bash, Zsh, Perl, Elixir,
  Crystal, Rakefile, and Gemfile.

The tokenizer walks diffs character by character, tracks string state including
template literals and triple-quoted strings, and emits real comments rather
than strings that merely contain comment-looking text. In slash mode a
backslash-then-anything pair is consumed as an escape so regex-literal interiors
like `/a\/b/` do not trip the `//` detector.

A touched comment counts as added, so changing `# foo` to `# bar` is blocked.
Doc comments (`///`, `//!`, `/** */`) are blocked like plain comments. Use
`allow-comment:` when a project relies on generated API documentation from
source comments.

Allowed comments:

- a comment containing `https?://`, for URLs the language cannot express
  without a comment;
- a comment containing `allow-comment:` followed by a reason;
- a pragma allowlist anchored at the start of the trimmed body, including
  `frozen_string_literal`, `@ts-ignore`, `@ts-expect-error`, `@ts-nocheck`,
  `@ts-check`, `@flow`, `noqa`, `pylint:`, `mypy:`, `pyright:`, `type:`,
  `eslint-disable`, `eslint-enable`, `prettier-ignore`, `biome-ignore`,
  `tslint:`, `rubocop:`, `sorbet:`, `stylelint-disable`,
  `stylelint-enable`, `go:` directives, generated-code notices, copyright and
  license notices, `encoding:`, and `coding:`;
- a shebang (`#!`) on line 1.

Non-programming-language files pass without inspection, including Markdown,
JSON, YAML, HTML, CSS, ERB, env files, and dotfiles. CSS is excluded because
`/* ... */` is its only comment form and not the programming-language reflex
this guard targets. PHP is excluded because mixed HTML and PHP files would
false-positive on the HTML parts. JSX and TSX are excluded because text content
between JSX tags can contain `//` literally.

Known limitations:

- Ruby and Bash heredoc bodies are not fully shielded; a `#`-prefixed line
  inside a heredoc can register as a comment when edited.
- Nested JS template literals such as `` `${`inner //`}` `` may close the outer
  template state early.
- Triple-quoted Python or Swift strings do not handle a literal `\"` before the
  close, so an embedded escaped triple-quote can mis-end the string.

Pass condition: rewrite the code for clarity by naming, extracting, or shaping
the code better, or use one of the explicit allow rules.

## PostToolUse context guards

### `dash-bash`

Denies Bash commands containing em-dash (U+2014) or en-dash (U+2013) before execution. HTML entity text remains allowed so search and migration commands can inspect it.

### `dash`

Surfaces additional context when em-dash (U+2014), en-dash (U+2013), or an HTML entity form (`&mdash;`, `&ndash;`, `&#8212;`, `&#8211;`, `&#x2014;`, `&#x2013;`) appears in `.md`, `.txt`, or `.mdx` files outside fenced code blocks, in persisted file content, or in added `apply_patch` lines. Chat and completed shell commands are not checked.

### `land`

Surfaces additional context when the vague `land` metaphor (`land`, `landing`, `landed`, `geland`, `landt`) appears in persisted file content or added `apply_patch` lines outside fenced code blocks. Completed shell commands are not inspected because a post-execution rewrite could repeat their side effects. The match is a plain case-insensitive substring, so ordinary words such as `Nederland`, `landscape`, and `landing page` can trip it. That is deliberate: this is a gentle reminder to choose a concrete verb, never a hard gate.

### `reread`

Surfaces additional context when an `Edit`, `MultiEdit`, or `Write` adds lines to an instruction artefact: a `SKILL.md` (including the `.claude.md` and `.codex.md` variants), a `CLAUDE.md` or `AGENTS.md`, or a file under a `circus/shared` or `circus/specific` directory. Prose has no test that catches a rule clashing with the rule two paragraphs below it, and a diff shows only what was written, never what surrounds it. The nudge asks two questions: does anything already in that section now contradict the addition, and did the operator ask for it. Moved text counts as added text, since arriving somewhere new is not the same as fitting there.

An edit that removes more lines than it adds stays silent, and so does a rewrite of the same size; only growth trips it. Code files never trip it, whatever they contain.

## Stop guards

### `pre-existing` (`false-claims`)

Blocks Stop when recent assistant text relativizes a test or error as already
existing before the current change. Also runs when `stop_hook_active` is true
and keeps its own per-session line tracker. Pass condition: fix the failure, or
formulate it as parallel work in the same directory when there is concrete
evidence of a parallel session.

### `tool-error`

Blocks Stop when the last significant transcript event was a failed tool call.
Also runs when `stop_hook_active` is true. The guard has a hard cap of two
nudges per session and uses line tracking so it only fires on new errors. Pass
condition: analyse the error and retry instead of giving up.

### `cache`

Blocks Stop when recent assistant text blames cache for a localhost problem. On
a dev server, cache is rarely the root cause. Pass condition: investigate and
name the actual root cause.

### `estimate`

Blocks Stop when assistant text frames effort or scope in hours, days, weeks, or
months: "een paar uur eerlijk werk", "halve dag uitzoekwerk", "dagje
sleutelen", "kost een week", "takes a day", "a few days of work", "binnen een
uur", or comparison frames such as "option A is vandaag, option B is deze week".

The guard skips common false positives on the same line as past-tense markers,
calendar and scheduling language, retention windows, measured duration,
uptime/history language, legal or SLA facts, and absolute-time references such
as "tomorrow" or "morgen".

Pass condition: drop the duration phrasing, replace it with concrete counts
such as files touched and verifications run, prefix the turn with `🧭` for a
deferred-judgment user choice, or close with `🚧` for work in progress.

### `prefer`

Blocks Stop when the assistant lays out an option menu and hands the choice back
without committing to one. Detection covers two or more `(a)` / `(b)` markers,
two or more `Optie` / `Option N` items, a markdown table whose header names an
option/approach/variant column, or two or more ordered-list items, then requires
a choose-between signal such as "which one", "je voorkeur", "jouw keuze", "do
you prefer", or "your call".

Pass condition: state the preference the agent would back and why, then mark the
pick with a squared-letter or number-keycap emoji. `🧭` for a genuine operator
call and `🚧` for work in progress also stand the guard aside. When the `rover`
plugin is installed, the reminder can include a `/rover:decide` pointer for
hard calls.

The guard stands aside when the menu includes external irreversible state such
as remote creation, remote attachment, push, deploy, publish, production, DNS,
or shared infrastructure; those are operator gates, not preference-reflex cases.

### `premature`

Blocks Stop when the last assistant message does not end with a question and
does not end with `🏁` (finished) or `🚦` (waiting on external go) plus a
substantive sentence of at least 40 non-space, non-emoji characters with a
sentence terminator. Pass condition: finish with a real completed-work sentence,
finish with a real waiting-on-external-go sentence, or keep writing.

### `verify`

Blocks Stop when the assistant delegates verification to the operator with
phrases like "zou moeten werken", "check of het werkt", or "refresh de pagina"
instead of verifying directly. Meta-references in backticks, quotes, and table
cells are stripped before matching. Pass condition: actually verify with a test,
curl, grep, screenshot, browser check, or other available tool, then prefix the
conclusion with `Geverifieerd:`.

### `duh`

Blocks Stop when the assistant offers a runnable recipe for an action it could
execute itself, such as "je kunt dit doen door `cmd` te draaien", "you can
verify this by running `cmd`", "Run `cmd` to see the result", or "open the URL
in your browser". Fenced code blocks are stripped first so documentation
examples do not trigger.

Pass condition: run the action and report the result, or prefix the line with
`Instructie:` when the operator explicitly asked for a manual recipe.

### `compliance`

Blocks Stop when the last assistant message ends with a confirmation question
after the operator already gave a clear instruction, for example "Wil je dat ik
...?", "Shall I ...?", or "Moet ik ...?". The blocker applies to reversible
local work: edits, tests, local scripts, local daemons, local commits, and
local-only repo setup. It stands aside when the question is about external or
account-bound state such as remote creation, remote attachment, push, deploy,
publish, production, DNS, or shared infrastructure. Pass condition: continue the
local work and stop asking, or make the external gate explicit.

### `jargon`

Blocks Stop when operator-facing text uses coined approval-gate `-go` compounds
such as `push-go`, `ship-go`, `merge-go`, `deploy-go`, `commit-go`,
`release-go`, `publish-go`, `send-go`, `post-go`, `launch-go`, `user-go`,
`yolo-go`, or `approval-go`. Fenced code and inline-code mentions are ignored,
and `🚧` skips the guard while work is in progress.

Pass condition: phrase it plainly, for example "waiting for your go to push" or
"ik push zodra je het zegt", or wrap the term in backticks when naming the
jargon itself.

## Operator skills

### `/duh`

The operator types `/duh` when the previous assistant turn offered a recipe,
instruction, browser action, confirmation question, multi-step operator-facing
plan, or declaration of inability instead of executing. The skill re-reads the
immediately preceding assistant turn, resolves the proposed action, and runs it
with the available shell, file-edit, browser, research, or host-native tooling.

The proposal must be exactly one clear action. If the previous turn contained
multiple distinct candidate actions, `/duh` asks the operator to pick from a
numbered menu that includes every option. Inviolable gates still apply: `/duh`
does not authorize push, merge to default, deploy, destructive git, remote
creation, remote attachment, or other external irreversible operations.

When `PLUGIN_ROOT` or `CLAUDE_PLUGIN_ROOT` is set, `/duh` first runs
`bin/check-broadcast`; if the installed plugin version has new topmost
changelog notes, it prints that one-time update before executing the correction.

### `/just-a-question`

The operator types `/just-a-question`, "just a question", "read-only", "do not
change anything", or equivalent when the turn should be informational only. For
the rest of that turn, mutation tools are forbidden: file-edit tools and
mutating shell commands such as `git commit`, `push`, `rm`, `mv`, and
`launchctl`. Read-only tools stay available.

When the answer reveals an obvious fix, the skill names it but does not apply
it. This is an explicit lock for the current turn, not a blanket rule for every
question mark. QA and status checks on work the agent is currently driving still
belong to the deliverable; if such a check fails, the broken or stale artifact
is a blocker to fix.

### `/not-your-monkey`

The operator invokes `/not-your-monkey` in Claude Code, `$not-your-monkey` in Codex, or natural-language variants such as "niet je aapje", "je aapje niet", "ik ben niet je reload-aapje", or "not your monkey" when visual review work has been handed back to them. The skill makes the active agent reconstruct the target, open or render it with the available host-owned visual capability, capture evidence, patch the visible cause, reload, and iterate until its own screenshot or renderer evidence shows the issue is resolved.

This is for visual or interactive work: web apps, app screens, PDFs, images, generated screenshots, canvas output, responsive layouts, and similar artifacts where code review alone cannot prove the result. It does not lift normal gates; credentials, human-only account approvals, external irreversible operations, or inaccessible hardware still require the operator.

## Configuration

The dispatcher always runs when the host calls the hook, but individual guards
fire only when their pattern matches. To silence a guard durably for one agent,
set that guard's `agents.<agent>` value to `disabled` in `hooks/guards.json` and
run:

```bash
packages/circus/bin/circus plugins build .
```

For a one-off local silence, set `DD_SKIP_GUARDS=<id>` or an event-specific
variant such as `DD_SKIP_STOP_GUARDS=<id>` on the dispatcher command in the hook
manifest. `DD_ONLY_GUARDS` and event-specific `DD_ONLY_*_GUARDS` variants are
available for focused local testing.

To silence the plugin entirely, uninstall it:

```bash
claude plugins uninstall dont-do-that@laicluse-agent-fieldkit
codex plugin remove dont-do-that@laicluse-agent-fieldkit
```

## Architecture

`hooks/dispatch.sh` is the single dispatcher for PreToolUse, PostToolUse, and
Stop events. It reads stdin once, extracts `hook_event_name` and `tool_name`,
picks the matching lane, and reads the ordered, agent-filtered guard list from
`hooks/guards.json`.

Claude file edits arrive as `Edit`, `Write`, or `MultiEdit`. Codex patches
arrive as `apply_patch`. Both agents use Bash for shell commands. The manifests
identify the host with `DD_AGENT=claude` or `DD_AGENT=codex`; the registry
resolves which guards apply.

Guards live under `hooks/guards/` as sourced shell functions. Shared helpers
live under `hooks/lib/common.sh`. No external process runs per guard except the
small helper commands each guard explicitly invokes.

The registry has four parts:

- `contracts`: payload types guards can inspect. `tool-call` is the pending tool
  invocation, `persisted-edit` is file content or shell text after it has been
  applied, and `final-answer` is the assistant's final-turn text.
- `events`: hook events and the contracts they provide.
- `lanes`: execution groups owned by the dispatcher. `pre-bash` and `pre-edit`
  deny tool calls, `post` and `stop-tracked` capture context while still running
  every guard for line tracking, and `stop-mutex` blocks Stop unless a previous
  Stop fire already blocked.
- `guards`: every guard, keyed by the guard id, with its lane, order, function,
  inspected contract, and optional per-agent policy.

If `guards.json` is missing or malformed, PreToolUse fails closed with a
`[dont-do-that/registry]` denial so a broken registry cannot silently disarm
the safety gates. PostToolUse and Stop stay quiet in that state because they
only surface context or nudges.

## Adding a guard

- Add `hooks/guards/<id>.sh` with a shell function named in the registry.
- Register the guard in `hooks/guards.json` with a lane, unique order within
  the lane, function name, contract, and optional agent policy.
- Run the registry validator with
  `bash packages/dont-do-that/bin/validate-registry`.
- Sync generated Codex adapter files with `packages/circus/bin/circus plugins build .`.
- Update this README so the guard appears in the catalog and the detailed
  section for its hook moment.

Every user-visible hook message starts with `[dont-do-that/<code>] `. The code
is a stable identifier for the guard or, in the `false-claims` case, for the
message mnemonic (`[dont-do-that/pre-existing]`).

## Known quirk

These hooks scan assistant transcripts for trigger phrases. Documenting or
discussing the hooks themselves can trigger them. If you are editing the scripts
or writing docs about them, expect occasional Stop blocks. The work-in-progress
escape hatch `🚧` skips Stop guards while you work on the hook system.

## Language

Trigger patterns match Dutch and English phrasing. Messages are in English. Some
escape tokens remain Dutch (`Bewust uitgesteld:`, `Geverifieerd:`) because they
are deliberate trigger words that the agent must type verbatim to pass a guard.

## Tests

```bash
bash packages/dont-do-that/test/smoke-test.sh
bats packages/dont-do-that/test/guard-registry.bats
bats test/build-pages
```

The smoke test drives every trigger case through `hooks/dispatch.sh` with an
explicit `hook_event_name`, matching the real runtime path. The registry tests
prove guard placement, per-agent policy, and README coverage. The build-pages
tests prove the website page is regenerated from this README.
