# dibs changelog

The post-update broadcast shows the topmost section once per machine whenever
the installed `version` in `.claude-plugin/plugin.json` changes. Keep entries
short; categories are Breaking, Added, Changed, Fixed.

## [v2.0.59]

### Fixed

- **Codex patch calls now lock the checkout named by the patch.** Codex can expose native `apply_patch` input as `tool_input.command`; Dibs ignored that payload form, lost even absolute file targets, and fell back to the conversation checkout. The patch extractor now treats `command` like the existing raw, `patch`, `input`, and `content` forms, so a patch aimed at another worktree checks that worktree instead.

## [v2.0.50]

### Changed

- **The refusal that asks for a work description now says what makes one useful.** It asked for "what you are doing here", which every coding agent answers the same way in every directory, so locks ended up labelled `session work` and told you nothing at the moment you needed them: finding an old lock and deciding whether its work finished. Both the hook refusal and the CLI error now ask for the change, name the reader, and show a description that passes beside one that fails. `DIBS_DESCRIPTION` is documented as the channel for a scheduled run that knows its task up front, set per run; pinned once for every session it silently satisfies the requirement and suppresses the question.

### Breaking

- **A lock is no longer released at the end of a turn.** Since v2.0.43 the occupancy hook swept every lock a session held whenever its closing message did not end in `?`, `？` or `🚧`. A session that opens its closing line with a marker instead of ending on one never matched, so every turn handed the directory back and the next agent found it free, mid-work. The `Stop` hook is gone from both manifests. A lock now lasts until the agent releases it with `undibs`, until `SessionEnd`, or until pid-liveness sees the holding process is gone. Deciding when a directory is finished with is the agent's own call again: holding one turn too long costs an `undibs`, releasing one turn too early costs a collision nobody sees coming.

## [v2.0.49]

### Fixed

- **Claimed Codex repositories no longer require shell rewrites when hook payloads omit `workdir`.** An existing claim lets Dibs use the conversation directory as the fallback basis for normal target analysis; unclaimed ambiguous mutations remain blocked, and additional write targets still need their own claims.

## [v2.0.48]

### Fixed

- **Codex no longer exposes ambiguous-target diagnostics in the conversation.** The denial contains only `Dibs lock required for changes.` because Codex renders hook context visibly; the Dibs skill owns the agent recovery procedure.

## [v2.0.47]

### Changed

- **Codex keeps ambiguous-target denials compact.** The visible block says `Dibs lock required for changes.` while the recovery instructions remain available in the collapsed agent details.

## [v2.0.46]

### Fixed

- **Codex no longer turns a missing execution workdir into conversation-CWD occupancy.** When Codex omits `workdir` from a mutating Bash hook payload, Dibs refuses any relative or implicit target without claiming a lock. Commands with explicit absolute targets, such as `git -C <repo> ...`, remain available.

## [v2.0.44]

### Fixed

- **Occupancy follows each tool call's workdir.** Relative command and file targets now resolve from the mutation's own execution directory instead of the conversation cwd, so a session started in one checkout no longer claims or collides with that checkout while writing elsewhere.

## [v2.0.43]

### Changed

- **Completed handoffs release Dibs before the session ends.** Claude and Codex now sweep every lock they hold on `Stop` when the final answer hands control back for new work. A final question or the `🚧` marker retains the locks for continuation; `SessionEnd` remains a fallback.

## [v2.0.42]

### Fixed

- **Codex now gives a concrete restart instruction when a running session loses the Dibs hook runtime.**

## [v2.0.41]

### Changed

- **Worktree-only refusals now include the narrow escape hatch.** An explicit operator request or path-dependent checkout can disable `laicluse.requireWorktree` without disabling Dibs occupancy.

## [v2.0.40]

### Changed

- **Cross-session occupancy refusals now tell the blocked agent to surface the holder, pid, and work to the operator before choosing a recovery path.**

### Fixed

- **Bash occupancy now gates command-specific write targets instead of path-like text.** The shell lexer excludes heredoc bodies, separates flag values and read-only operands from write destinations, resolves Git `-C`/`--git-dir` context and output redirects, expands `~`, `$HOME`, and exported path variables, and uses cwd only when the parsed command actually writes there.

## [v2.0.39]

### Breaking

- **A work description is now mandatory to create a lock.** `dibs claim` refuses
  a new lock without `--description` (or `DIBS_DESCRIPTION`), so no lock is ever
  anonymous and a blocked agent can always tell the operator whose work a lock
  is. Re-claiming a lock you already hold (`held-by-self`) still needs nothing.

### Changed

- **The occupancy description is the agent's own label, never the git branch.**
  The hook reads it only from `DIBS_DESCRIPTION`; the branch-name derivation is
  gone (it was wrong on the default branch and absent outside a repo). A write
  with no administered dibs is denied with instructions to run
  `dibs claim <dir> --description ...`.

## [v2.0.34]

### Fixed

- **Read-only commands no longer take occupancy locks.** A `2>/dev/null` (or any
  `>/dev/...`) stderr redirect no longer counts as a mutation, and `/dev` is now
  a default exclude. Previously every agent serialised on a single global `/dev`
  lock, and a suppressed-stderr `grep`/`find` claimed occupancy on the paths it
  merely read, blocking other agents (and itself) on unrelated directories.

## [v2.0.31]

### Added

- **Locks now carry a short work description.** `dibs claim --description <text>`
  and `DIBS_DESCRIPTION` store a compact human `description` in the lock record;
  `check`, refused claims, and occupancy denials show it as `work: <text>`.
  `bonsai` records the branch name as words for the worktrees it hands out.

## [v2.0.30]

### Added

- **Bash mutations now participate in occupancy.** The hook recognises
  conservative shell write patterns (`cp`, `mv`, `rm`, `touch`, mutating `git`
  subcommands, package installs, and redirection), gates explicit path operands
  when present, and leaves read-only shell commands unclaimed.
- **Opt-in worktree-only mutation guard.** Repos can set local git config
  `laicluse.requireWorktree=true`; the occupancy hook then denies mutating the
  primary checkout while allowing linked worktrees. Default behavior is
  unchanged for repos that do not opt in.

### Changed

- **Occupancy refusals now reject loose repository copies.** The CLI, hook
  suggestion, and skill text explicitly say to recover with `bonsai:bonsai` or
  a real `git worktree`, not a copied non-git directory that cannot be delivered.

## [v2.0.28]

### Changed

- **Exclude management is now the imperative pair `exclude` / `include`.**
  `dibs exclude <dir>` and `dibs include <dir>` mirror `claim` / `release`;
  `dibs excludes` lists the entries. Replaces the `exclude add|remove|list`
  subcommands from v2.0.27.

## [v2.0.27]

### Added

- **Exclude list: directories dibs never locks.** `claim` and `check` on an
  excluded directory (or any path inside it) return state `excluded` and write no
  lock, so the occupancy hook passes the edit through. The list is built-in
  defaults (`/tmp` and the agent-config homes `~/.claude`, `~/.codex`,
  `~/.config/opencode`) plus a config file at
  `${LAICLUSE_HOME:-$HOME/.laicluse}/dibs/excludes`.
  Manage it with `dibs exclude [list | add <dir> | remove <dir>]`.

## [v2.0.25]

### Changed

- **Subdirectories in one git worktree now contend for the same dibs lock.**
  `claim`, `check`, and `release` resolve paths inside git to the nearest
  worktree root before choosing the lock file, while standalone non-git
  directories keep their existing realpath-keyed behavior.

## [v2.0.20]

### Changed

- **Occupancy starts at the first write, not session start.** Claude and Codex
  no longer claim or steer aside on `SessionStart`; the occupancy hook claims at
  the mutating file-edit gate and only suggests a separate worktree when that
  write would collide with another live agent.
- **Agent-held locks stay held after task completion.** The dibs skill and
  README now spell out that `release` is recovery/operator teardown, not normal
  end-of-task cleanup. Claude releases on `SessionEnd`; Codex relies on
  pid-liveness or owner reclaim.

## [v2.0.15]

### Changed

- **Blocked directories now point at a worktree recovery path.** `dibs claim`,
  JSON refusals, and the occupancy hook suggest creating a separate git worktree
  on a new branch and claiming that worktree path when another live agent holds
  the requested directory.

## [v2.0.14]

### Fixed

- **Codex resumes no longer self-lock on their old dibs claim.** Locks now carry
  a stable `owner` in addition to pid and hook session id. The occupancy hook
  fills it from `DIBS_OWNER`, then Codex surface ids (`CMUX_TAB_ID`,
  `CMUX_WORKSPACE_ID`, `CODEX_THREAD_ID`) before falling back to the hook
  session id. A resumed Codex with the same owner rewrites the lock to its new
  pid/host; a one-time legacy handoff lets resume clear older ownerless Codex
  locks.

## [v2.0.11]

### Fixed

- **Occupancy now refuses a codex nested under a Claude session.** A codex
  started inside a Claude session (intervision, `codex exec`) runs below the
  Claude process, and the holder-pid walk climbed to the topmost agent
  ancestor, landing on the Claude pid that already held the directory, so dibs
  read held-by-self and allowed the edit. The walk now stops at the nearest
  agent ancestor, and the agent label keys on `PLUGIN_ROOT` (which codex sets
  alongside `CLAUDE_PLUGIN_ROOT`) so a nested codex no longer mislabels itself
  as claude.

## [v2.0.9]

### Added

- **Universal occupancy enforcement hooks.** dibs now ships
  `hooks/occupancy.sh` (with `hooks/hooks.json` for Claude and
  `hooks/hooks.codex.json` for Codex), so single-occupancy is enforced for every
  agent session, not only the worktrees `bonsai` hands out. SessionStart claims
  the working directory and steers a latecomer aside, a PreToolUse file-edit gate
  hard-denies a write when a different live agent session holds the directory,
  and Claude SessionEnd releases while Codex relies on pid-liveness self-heal.
  Self-recognition keys on the lock's session id so a drifted worker pid never
  blocks the agent against its own lock, and the gate fails open on anything that
  is not a positive cross-session refusal. The hooks shell out to this plugin's
  own CLI; no lock logic is duplicated. Opt out per session with
  `DIBS_OCCUPANCY=off`.

## [v1.0.0]

### Added

- **Single-occupancy lock**: `dibs claim`, `dibs release`, and `dibs check`
  arbitrate exclusive occupancy of a working directory across vendors and
  platforms, with `--json` facts output.
- **Atomic, dependency-free**: locks are atomic exclusive-create files keyed by
  the directory's realpath under `${LAICLUSE_HOME:-$HOME/.laicluse}/locks/`. No
  `flock`, no native binding.
- **Self-healing**: a lock left by a dead holder pid is taken over by the next
  claimer; a live holder is respected and reported with who holds it and since
  when. An optional `--max-age-hours` cap bounds foreign-host locks.
- **Consumed, not duplicated**: `bonsai` claims the lock for the directory it
  hands out by importing the one dibs implementation. No second lock path.
