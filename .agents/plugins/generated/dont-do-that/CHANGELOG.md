# dont-do-that changelog

The post-update broadcast (see `bin/check-broadcast`) shows the topmost
section once per machine whenever the installed `version` in
`.claude-plugin/plugin.json` changes. Entry headers record the version at
which the entry was written; a pre-commit hook auto-bumps `plugin.json` on
every commit, so the header may lag the shipped version. Header numbers are
informational, the broadcast is positional. Use the `--force` flag on the
helper to re-read at any time.

Categories:

- **Breaking**: user must adapt (renamed guards, changed escape tokens, hook
  gates that now block previously-accepted output)
- **Added**: new guard, new user-invocable skill, new escape hatch
- **Changed**: non-breaking adjustments worth knowing about
- **Fixed**: silent unless the bug was user-visible

Patch-level fixes that change nothing the user can observe are intentionally
omitted; the broadcast budget is for things the user benefits from knowing.
Version numbers may therefore be non-contiguous. The helper writes the sentinel
only when stdout is non-empty, so a CHANGELOG without a `## [vX.Y.Z]` section
stays silent on every update.

## [v2.0.61]

### Added

- **A pull request body can no longer hand the reviewer a link where a picture belongs.** `gh pr create` and `gh pr edit` now refuse a markdown link or bare URL whose target is an image or video file, and a `github.com/.../blob/...` image URL without `?raw=true`, because both render as something to click instead of the capture itself. The deny names the working forms: `![alt](url)` on a URL that serves the bytes, the blob URL with `?raw=true` for a committed file, a release-asset download URL otherwise, a captioned table for two or more portrait shots and `<img width>` for one. Takes `# allow-image-link` for a deliberate link.

## [v2.0.59]

### Fixed

- **Codex remote-creation approvals are recognized from the active transcript.** The `no-remote-create` guard now reads Codex user-message records as well as Claude records, so an explicit approval no longer gets rejected as missing.

## [v2.0.57]

### Changed

- **Local Git remote configuration no longer requires repeated approval.** `git remote add` and `git remote set-url` only change the checkout and cannot publish by themselves, so `no-remote-create` now leaves them to the repository's push policy. Forge-side `gh repo create` and `gh repo fork` remain gated.

## [v2.0.56]

### Added

- **A pull request can no longer be opened from a branch that is behind its base.** `gh pr create` and `gh pr ready` now check the head branch against the tip of its base and refuse while it lags, because a reviewer reads the diff as if it were current and GitHub reporting `MERGEABLE` or `CLEAN` answers "does it conflict", never "is it current". Honours `--base` and `--head`, stays silent without a remote or when the fetch fails, exempts `gh pr edit`, and takes `# allow-behind-default` for a deliberate exception.

## [v2.0.41]

### Added

- **Machine-wide plugin changes now require explicit operator approval.** Local Codex marketplace development stays on the safe path: test the worktree, merge it into the primary checkout, and let new sessions read that source without reinstalling the plugin or invalidating live hook paths.

## [v2.0.40]

### Fixed

- **Codex now gives a concrete restart instruction when a running session loses the guard hook runtime.**

## [v2.0.39]

### Fixed

- **Persistent local marketplaces can no longer point at linked worktrees.** The guard now inspects the actual source argument for both Claude's `plugins` command and Codex's `plugin` command, so an explicit worktree path is blocked from any current directory while canonical checkouts and remote sources remain valid.

## [v2.0.36]

### Fixed

- **Shell text is never asked to rewrite after the command already ran.** The `dash-bash` guard now denies a Bash command containing a real em- or en-dash during PreToolUse, while PostToolUse rewrite context remains limited to persisted file edits. HTML entity text remains searchable from Bash. The Unicode matcher compares complete codepoints, so arrows and curly apostrophes no longer trigger as dashes in byte-oriented locales. The soft `land` nudge likewise no longer inspects completed Bash commands.

## [v2.0.35]

### Fixed

- **`dash` now catches HTML entity forms for em/en-dashes.** Persisted text that contains `&mdash;`, `&ndash;`, `&#8212;`, `&#8211;`, `&#x2014;`, or `&#x2013;` now gets the same rewrite context as a literal U+2014 or U+2013 character, while fenced code and patch context lines still pass.

## [v2.0.32]

### Changed

- **`no-remote-create` verstaat nu ook Nederlandse remote-toestemmingen.** De operator-approved escape herkende "remotes aanmaken", "remotes aan maken", "remotes geven" en verwanten niet, waardoor een expliciete go in het Nederlands alsnog blokkeerde. Beide kind-matchers (forge en remote) dekken die frasering nu; ongerelateerde berichten blokkeren onveranderd.

## [v2.0.30]

### Changed

- **`/not-your-monkey` now routes on looser "niet je aapje" phrasing.** The trigger metadata now includes short and reordered forms such as "niet je aapje" and "je aapje niet", so the correction does not depend on the operator typing a grammatical full sentence.

## [v2.0.29]

### Added

- **New `/not-your-monkey` visual self-inspection skill.** Invoke it as `/not-your-monkey` in Claude Code, `$not-your-monkey` in Codex, or with natural-language variants like "ik ben niet je aapje" when an agent has handed visual reload or QA work back to the operator; it requires the agent to inspect, adjust, reload, and iterate with visual evidence.

## [v2.0.28]

### Changed

- **`no-remote-create` now honors explicit operator approval in the latest user turn.** Remote creation and remote attach commands still block by default, but a current user message that names the same action and approves running it now lets the tool call proceed.

## [v2.0.27]

### Changed

- **`prefer` and `compliance` now distinguish reversible local work from external gates.** The guards still push agents to choose and continue for local edits, tests, scripts, commits, and local-only repo setup, but they no longer turn GitHub/remote/push/deploy/publish-style choices into "decide it yourself" nudges.
- **`no-remote-create` explains why deletion is not true reversibility.** The denial now names account-bound forge state, internet-visible names, audit events, notifications, visibility mistakes, and later accidental pushes as the risk boundary.

## [v2.0.18]

### Added

- **New PreToolUse:Bash guard `no-osascript`.** Blocks `osascript` and common
  wrapper forms before they can drive local apps or user-facing system state via
  AppleScript. Use an explicit host-owned UI/browser capability or a
  project-native command path instead.

## [v2.0.17]

### Changed

- **Guard placement and per-agent policy now live in a registry.**
  `hooks/guards.json` is the source of truth for which guard runs on which hook
  event for which agent; the dispatcher reads guard membership and order from it
  instead of hard-coding them. Manifests signal the agent with `DD_AGENT`
  (`claude` / `codex`), replacing the ad hoc `DD_SKIP_STOP_GUARDS=premature`
  variable. To silence a guard durably, set its `agents.<agent>` to `disabled`
  in the registry; the per-event `DD_SKIP_*` env vars remain as a one-off
  override.

### Added

- **`bin/validate-registry`** rejects an impossible placement (a guard on a hook
  event whose payload it cannot inspect), a duplicate guard order or function
  name, and a registry entry with no backing script.
- **Fail-closed on a broken registry.** If `guards.json` is missing or invalid,
  PreToolUse now denies the tool call with a `[dont-do-that/registry]` message
  instead of silently running no guards, so a corrupt registry cannot disarm the
  safety gates unnoticed.

## [v2.0.7]

### Changed

- **Codex skips only the `premature` Stop guard.** The other Stop guards still
  run in Codex; the dispatcher now supports per-event guard filters such as
  `DD_SKIP_STOP_GUARDS` so hook manifests can make one guard agent-specific
  without dropping the whole event.

## [v2.0.6]

### Added

- **New `land` guard nudges on the vague "land" metaphor.** A soft PostToolUse
  reminder (never blocks) surfaces when `land`/`landing`/`landed`/`geland`/`landt`
  appears in persisted file content or a Bash command, asking for a concrete word
  that names what actually happens. Like `dash` it only surfaces
  context; false positives on ordinary words are accepted as the price of a gentle
  reminder rather than a hard gate.

## [v2.0.2]

### Added

- **Codex now receives the dont-do-that hook stack.** The generated Codex adapter
  materializes `hooks/hooks.codex.json` as `hooks/hooks.json`, ships the
  dispatcher, guard scripts, and shared hook libraries, and registers PreToolUse,
  PostToolUse, and Stop hooks.
- **Codex `apply_patch` edits are covered by the file-edit guards.**
  `no-code-comments` inspects added patch lines per target file, and `dash`
  surfaces em/en-dashes in added patch lines without tripping on context lines.

### Changed

- **Runtime state is stored under `${LAICLUSE_HOME:-~/.laicluse}`.** The Stop
  guards no longer write their per-session line trackers under `/tmp/.claude-*`.
- **The operator correction skills are host-owned-suggestion friendly.** They now
  refer to available shell, file-edit, browser, and research tooling instead of
  assuming Claude tool names.

## [v2.0.1]

### Breaking

- **dont-do-that now ships from the public laicluse-agent-fieldkit marketplace.**
  Install the Fieldkit copy for the current guardrail hooks and correction
  skills.

### Changed

- **The plugin is multi-agent packaged.** Claude Code receives the existing
  guardrail hooks plus `/duh` and `/just-a-question`; Codex receives the two
  skills through the generated adapter package. Claude-specific hooks do not
  run in Codex.
- **Broadcast state moved under `${LAICLUSE_HOME:-~/.laicluse}`.**

## [v1.0.83]

### Added

- **New `prefer` Stop guard.** Hand back a bare option menu and it asks you to commit to a reasoned pick; mark your lean with 🅰️/🅱️ or 1️⃣/2️⃣ to pass, or escape with 🧭 (operator's call) / 🚧 (WIP).

## [v1.0.81]

### Fixed

- **`no-code-comments` no longer flags `#` lines inside Ruby/shell heredocs.** A Markdown heading or embedded shell comment in a `<<~HTML` / `<<-EOS` / `<<'TAG'` body is content, not a code comment, and now passes; real comments after the heredoc closes are still caught.

## [v1.0.71]

### Changed

- **`/duh` reference resolution updated.** The research-fallback step names `/inspire:inspire` as default with a fallback for sessions without it; the inviolable-gate check names `~/.claude/CLAUDE.md` as default and acknowledges harness equivalents.

## [v1.0.68]

### Fixed

- **`followup` no longer fires on `gh api` as substring.** Filenames or echoed strings with `gh api` pass; the body deferral check now requires `--field`/`-f`/`--raw-field`/`-F` or `--input`, not the bare word `body` anywhere.

## [v1.0.66]

### Fixed

- **`no-code-comments` only flags `#` or `//` at line start or after whitespace.** Ruby `Recipes#create`, bash `$foo#bar`, bare URLs like `let u = http://blabla;`, and Edit snippets that begin mid-string with a `#method` reference now pass.

## [v1.0.64]

### Added

- **New Stop guard `estimate`.** Blocks assistant text that frames effort in hours, days, weeks, or months ("een paar uur werk", "a few days of work", "binnen een uur"). Drop the duration claim or use a concrete count; calendar and SLA phrasing passes. Escape: `🧭` or `🚧`.

## [v1.0.59]

### Added

- **New PreToolUse:Bash guard `no-worktree-deploy`.** Blocks `ansible-playbook` when cwd is a git worktree, so branch state cannot land on shared infrastructure pre-merge. Read-only flags still pass (`--check`, `--syntax-check`, `--list-*`, `--version`, `--help`).

## [v1.0.52]

### Added

- **New PreToolUse guard `no-code-comments`.** Blocks Edit, Write, MultiEdit that add a code comment to a programming-language file. Pass: `https?://` URL, `allow-comment: <reason>` (colon required), pragma at body start (`@ts-ignore`, `noqa`, ...), or shebang on line 1.

### Note

- **Doc comments (`///`, `//!`, `/** */`) count as comments** and are blocked. Use `allow-comment: generates API docs` if your Swift/Rust/JSDoc project relies on source-derived documentation.
- **JSX (`.jsx`) and TSX (`.tsx`) are excluded** because text content between JSX tags can legitimately contain `//`. Plain `.js`/`.ts` files are still checked.

## [v1.0.48]

### Breaking

- **`/do-that` is renamed to `/duh`.** Slash command, SKILL directory, and the sister Stop guard with its `[dont-do-that/duh]` error code flip together. Retrain muscle memory.

## [v1.0.46]

### Changed

- **`/do-that` now covers declarations of inability.** After "I can't see this" or "I don't have access", `/do-that` signals: find a path via a different tool, wider scope, or `/inspire:inspire`. The skill names the lesson so it persists.

## [v1.0.45]

### Added

- **New `/just-a-question` skill.** Marks a message as a question, not a request for change. Claude answers with read-only tools only; `Edit`, `Write`, and mutating Bash are off the table for the turn. Imperatives get named, not applied. `/do-that` is the exit.

### Changed

- **`/do-that` menu has no upper bound.** The "two or three options" cap is gone: every distinct candidate from the previous turn is listed, even ten, and the operator picks. Truncation counts as picking in disguise.
- **`/do-that` no longer collapses options across actors.** Two candidates with different actors (operator vs assistant) used to rationalize as "already disambiguated, run mine". Both are now listed regardless of actor.

## [v1.0.41]

### Added

- **New Stop guard `do-that`.** Blocks Stop when the assistant offers a
  recipe (`Run \`cmd\``, `open the URL`) for an action it could have run
  itself. Pass: run it, or prefix with `Instructie:` for an explicit
  manual recipe. 🚧 skips this guard.
- **New user-invocable skill `/do-that`.** Type `/do-that` when the
  previous turn offered a recipe instead of executing; the skill resolves
  the proposal and runs it. Multiple candidates trigger a numbered "A or
  B?" prompt. Inviolable gates are not lifted.

### Fixed

- **`do-that` guard now matches real Dutch prose.** Pattern A's `[^.\n]`
  hit the letter `n` between `je kunt` and `door` and never reached the
  keyword; replaced with `[^.]`. The imperative pattern also now matches
  after sentence terminators, not only after newlines.
