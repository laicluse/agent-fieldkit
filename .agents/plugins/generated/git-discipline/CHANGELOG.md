# git-discipline changelog

The post-update broadcast (see `bin/check-broadcast`) shows the topmost
section once per machine whenever the installed `version` in
`.claude-plugin/plugin.json` changes. Entry headers record the version at
which the entry was written; a pre-commit hook auto-bumps `plugin.json` on
every commit, so the header may lag the shipped version. Header numbers are
informational, the broadcast is positional.

Categories:

- **Breaking**: user must adapt (renamed commands, removed flags, hook gates)
- **Added**: new commands, new optional behavior
- **Changed**: non-breaking adjustments worth knowing about
- **Fixed**: silent unless the bug was user-visible

Patch-level fixes that change nothing the user can observe are intentionally
omitted; the broadcast budget is for things the user benefits from knowing.
Version numbers may therefore be non-contiguous (an internal refactor bumps
the version without producing an entry here).

## [v2.0.65]

### Changed

- **A finished merge now says the worktree is spent.** `merge-to-default` told you to keep the source worktree "until merge and any required deployment are proven complete", which coupled the worktree to a deployment it never takes part in and left a condition nobody could resolve, so integrated worktrees stayed behind. Removing the worktree and its branch is part of the merge step now, and the merge output names the worktree, its branch, and `bonsai:prune` at the moment it lands. Deployment is not a reason to keep one: it runs from a clean deploy checkout on the merged SHA.

## [v2.0.60]

### Breaking

- **Locking a repository now requires a reason.** `/git-discipline:disable-git` refuses a bare invocation and asks for one: `/git-discipline:disable-git <why this repo is locked>`. The reason is stored with the lock alongside the date it was set, and both are quoted back on every denied git command, so a lock you meet weeks later explains itself. Locks written by earlier versions carry no reason and keep denying on their own terms.

### Changed

- **A lock now explains itself to whoever runs into it.** An agent that met the lock could see that git was refused without knowing what set it or whether it was allowed to do anything about it, and the deny message made that worse by telling the reader to run `/git-discipline:enable-git`, which an agent cannot invoke. The sentinel is now written with a header naming the plugin, what it blocks, and whose call lifting it is, so opening the file answers the question on its own. Denies aimed at an agent say it cannot lift the lock itself and to ask the operator; the denies a plain terminal sees no longer assume a slash command exists there, and name the file to delete as well. Locks set by earlier versions keep working and keep reporting whatever they carry.

- **The four toggle commands now take effect when you type them.** `/git-discipline:enable-git`, `/git-discipline:disable-git`, `/git-discipline:enable-discipline` and `/git-discipline:disable-discipline` previously printed a shell command for you to run yourself, because the `sentinel-protect` guard denies agent-driven writes to these files in both directions. The commands now run off your own keystroke and report the result directly. That guard is unchanged and still denies every agent-driven attempt; what disappeared is the copy-paste step, not the rule behind it. Hosts without the `UserPromptExpansion` hook fall back to the previous behaviour.

### Fixed

- **A commit that already shipped is never judged again at push time.** A force-push after a rebase measured against the pre-rebase remote tip, so every commit the branch had caught up on from the default branch counted as new work and was held to the body schema; the push was denied over commits that were published a month earlier and could only be "fixed" by rewriting public history. Both push gates now skip any commit that is already an ancestor of the default branch. The rule sits in the libraries the git hooks load on every run rather than in their push-range arithmetic, so a `pre-push` hook installed by an earlier version applies it too, without a reinstall.

## [v2.0.57]

### Fixed

- **An unreachable plugin path now says so.** The `pre-push` hook reported "flow command not found" when its check was whether an executable file sits at the configured plugin path, which sent readers looking for a `flow` subcommand that never existed. The message names the path it tested and what to do about it.

## [v2.0.54]

### Fixed

- **Installing git-discipline no longer turns worktrees into a machine-wide default.** Canonical-checkout commits and ordinary default-branch pushes remain available unless that repository explicitly sets local `laicluse.requireWorktree=true`; global values are ignored. The hook installer also refuses to write into an inherited global `core.hooksPath` and creates a repo-local hook path instead.

## [v2.0.51]

### Breaking

- **Public repositories no longer qualify for automatic trunk pushes just because one author appears in their history.** Collaboration is now the independent `individual` or `shared` fact, while visibility separately determines publication risk. The former `solo-trunk` and `team-trunk` modes are now `auto-trunk` and `gated-trunk`; only private, individual repositories qualify for `auto-trunk`.

## [v2.0.50]

### Fixed

- **Local merges no longer desynchronise a checked-out default worktree.** `merge --local` now keeps a clean default checkout, its index, and its branch ref on the same merge commit through Git's `updateInstead` path, preserves untracked files, and rejects repositories whose policy must resolve through a remote target.

## [v2.0.48]

### Breaking

- **Default-branch authoring now goes through verified worktree candidates.** Installing the native hooks adds a `pre-commit` guard that blocks commits in the primary checkout and on the default branch. Create a linked feature worktree, then use `git-discipline rebase`, `verify`, and `merge`; reinstall hooks with `/git-discipline:install-hooks --force` after updating.

### Added

- **Parallel candidates can merge without a canonical checkout.** The shared `bin/git-discipline` command dynamically resolves the default branch, rebases the worktree owner against the actual local or remote tip, records passing verification against the candidate SHA, creates a two-parent merge commit, and atomically updates the default ref. A concurrent winner causes a clean compare-and-swap failure followed by rebase and re-verification, without a long-lived merge lock.
- **Native pushes enforce the candidate topology.** The installed `pre-push` hook permits a default update only when it is a verified two-parent merge whose first parent is the current remote tip and whose tree equals the candidate tree. Remote branch protection remains the hard boundary for repositories that require PRs.

## [v2.0.47]

### Changed

- **A stale default-branch ref no longer forces a manual fetch and second invocation.** `rebase-latest-default` asks before fetching `origin`, then re-determines the target and continues the same rebase flow after approval. `merge-to-default` inherits that continuation when its rebase precondition encounters a stale ref.

## [v2.0.46]

### Fixed

- **Local-only repositories can merge and rebase to their configured default branch.** `merge-to-default` and `rebase-latest-default` still prefer `origin/HEAD`, then fall back to Git's `init.defaultBranch` when that branch exists locally. This restores repositories without a remote without reviving hard-coded `main` or `master` guesses.

## [v2.0.44]

### Added

- **Generated build-output can opt out of the Visual-trailer gate.** Mark generated files (a built docs site, adapter mirrors) with `git-discipline-generated=true` in `.gitattributes`, and a commit that only regenerates them no longer demands a fresh screenshot. Hand-authored UI (a component, a stylesheet) still requires the Visual trailer, so the gate keeps its teeth where a human designed the pixels. Repos without the attribute are unaffected.

## [v2.0.43]

### Fixed

- **Default-branch helpers no longer guess `main` or `master`.** The
  `rebase-latest-default`, `merge-to-default`, `push-policy`, and WIP gate
  paths now read Git's `origin/HEAD` metadata and stop or fall back to tracked
  upstreams instead of inventing a default branch from local branch names.
  `push-policy` treats missing default-branch metadata as `unknown`, so it
  stays conservative instead of assuming the default branch is pushable.

## [v2.0.42]

### Fixed

- **`merge-to-default` now writes hook-compliant merge commits itself.** The
  workflow uses `git merge --no-commit` followed by an explicit `Slice: merge`
  commit body, so repositories with commit-body or PII trailer hooks no longer
  get stuck after a clean no-ff merge.

## [v2.0.32]

### Changed

- **After updating git-discipline, re-run `/git-discipline:install-hooks
  --force` to refresh the git-native hooks.** The installed `commit-msg`,
  `prepare-commit-msg`, and `pre-push` hooks bake this plugin's absolute
  install path so they source `validate-body.sh` from the same logic as the
  PreToolUse guard. That path is version- and marketplace-specific (it looks
  like `.../plugins/cache/<marketplace>/git-discipline/<version>/`), so a
  plugin update, reinstall, or marketplace rename leaves the baked path
  pointing at a directory that no longer exists. Every later commit then
  aborts with `validator not found at .../validate-body.sh`. Re-running
  `install-hooks --force` re-bakes the current install path (it backs up the
  old hooks first), and is idempotent when the path already matches. If you
  only commit through Claude Code's PreToolUse layer you are unaffected; this
  matters when you commit from the shell, an IDE, or Codex, where these
  git-native hooks are the enforcement layer. The emergency bypass for a
  single commit is `git commit --no-verify`.

## [v2.0.22]

### Changed

- **Codex now receives only the git-discipline skills it can run.** Workflow
  skills such as `commit-snipe`, `rebase-latest-default`, `push-policy`,
  `install-hooks`, and `run-spec` remain available in the generated Codex
  adapter. Claude PreToolUse control skills (`disable-discipline`,
  `enable-discipline`, `discipline-status`, `disable-git`, `enable-git`) are
  omitted from Codex because that hook layer does not exist there.

### Fixed

- **Shared push-policy lookups no longer hard-code `CLAUDE_PLUGIN_ROOT`.**
  Shared skills resolve the active plugin root from Claude's environment or
  Codex's installed plugin metadata before running `git-repo-policy`.

## [v2.0.21]

### Added

- **`Verified: agent-confirmed` is now a recognised anchor, paired with a
  required `Verified-how:` trailer.** When the agent (not the operator) ran the
  change and saw it work, `operator-confirmed` was a lie and the only honest
  fallback was a vague `n/a`. `agent-confirmed` names that case directly, and
  the companion `Verified-how:` trailer forces a concrete sentence of the shape
  "Due to \<reason\>, this was confirmed by \<what the agent ran and saw\>" (>=
  20 chars). Because that sentence lands in git, it leaves a paper trail to
  catch a dishonest self-attestation later. A bare `agent-confirmed` without
  `Verified-how:` is rejected with `missing-verified-how`.

## [v2.0.15]

### Breaking

- **Flipping the discipline or the per-repo git lock is now operator-actuated.**
  A new `sentinel-protect` guard denies any agent-driven Bash call that
  creates or removes a `git-discipline-disabled-*` or `.git/git-discipline-deny`
  sentinel, in both directions (off AND back on) and with no magic-comment or
  env-var escape. The guard runs before the disabled-sentinel early exit, so a
  session whose discipline is off cannot quietly re-enable it either. The
  toggle skills (`disable-discipline`, `enable-discipline`, `disable-git`,
  `enable-git`) now hand you a ready-to-paste `! `-prefixed command instead of
  running it; your keystroke is the switch. Read-only inspection
  (`discipline-status`) is unaffected.

### Fixed

- **Corrected the advertised `--no-verify` escape.** The commit-body deny
  message, the guard's header comment, the shared vsd-skip message, and the
  commit-discipline / install-hooks docs claimed `git commit --no-verify`
  bypasses the PreToolUse layer. It never did: the PreToolUse guards validate
  every git commit command, flags included. All texts now scope `--no-verify`
  to the git-native layer (where it is real and audit-logged) and name the
  operator-only `/git-discipline:disable-discipline` as the only PreToolUse
  off-switch. Behaviour is unchanged; only the claims moved to match it.

## [v2.0.2]

### Breaking

- **First public l'Aicluse release.** Install this plugin as
  `git-discipline@laicluse-agent-fieldkit` for migrated workflows.

## [v1.0.1]

### Breaking

- **New l'Aicluse identity.** The plugin is now installed as
  `git-discipline@laicluse-agent-fieldkit` and slash commands use the
  `/git-discipline:*` namespace.

### Changed

- **Runtime state moved under l'Aicluse storage.** New first-party state is
  written under `${LAICLUSE_HOME:-~/.laicluse}/git-discipline`.

## [v1.0.164]

### Added

- **Mark a rebase-carried commit `Discipline: skip due to rebase` and the push body-gate treats it as already-shipped instead of re-litigating its body.** `/git-discipline:rebase-latest-default` marks these for you.

## [v1.0.163]

### Fixed

- **`rebase-latest-default` now reruns CI on the rebased tip of a published branch.** When a branch has an open PR but no local tracking, the gate keys on the remote and force-pushes with a lease, instead of leaving CI on the pre-rebase commits.

## [v1.0.161]

### Fixed

- **The push gate no longer fails on commits whose `Visual:`/`Verified:` path was deleted or whose `Tests:`/`Red-then-green:` spec moved after the commit.** Those path checks now run at commit time; trailer presence and format are still enforced at push.

## [v1.0.157]

### Added

- **`/git-discipline:push-policy` decides whether and when a push fits the current repo.** A resolver derives one of five push modes from per-repo facts (collaboration, visibility, protection, access), overridable via git-local `codingAgent.git.*`.

### Changed

- **`/git-discipline:rebase-latest-default` now finishes by force-pushing a rebased upstream branch when you have write access.** The `--force-with-lease` is the completion of the rebase, gated by the push-policy; it never touches a protected default.

## [v1.0.154]

### Fixed

- **Rebased branches stop false-failing the push gates on a team repo.** A bare push scopes to `origin/<default>..HEAD` and judges only commits you authored or rebase-co-authored, so already-merged teammate commits a rebase swept in are never demanded a body or blocked.

## [v1.0.133]

### Fixed

- **push-{wip,body}-gate always pick the range from git itself, not from the bash command shape.** Anything other than an explicit `<remote> <local>:<dest>` validates `@{u}..HEAD`; shell pipes and `2>&1` no longer confuse the parser into the old 50-commit fallback.

## [v1.0.132]

### Changed

- **Rotation reminders shift to PostToolUse: only the first commit per fresh state denies; the next slot arrives as a silent `additionalContext` hint.** Commits outside Claude Code fall back to the v1.0.131 per-commit deny.

## [v1.0.131]

### Fixed

- **push-{wip,body}-gate no longer fire on `git rebase` or `git commit --amend` when the message body contains "git ... push" text.** The push-detection regex now runs against a heredoc/quoted-string-stripped copy of the command.

## [v1.0.130]

### Added

- **Version-skew warning when this session's loaded git-discipline differs from the installed version.** Surfaces parallel-session drift after `claude plugins update`; fires once per session via a `/tmp` sentinel.

## [v1.0.128]

### Breaking

- **commit-format, commit-body, commit-trailers no longer deny at commit-time.** They emit `additionalContext`; the commit lands and Claude amends. The visible deny moves to push-time via `push-body-gate`. `/git-discipline:install-hooks`' `commit-msg` is unchanged.

### Added

- **push-body-gate blocks `git push` when any commit in the range has a non-conformant body.** Same range-detection as `push-wip-gate`. Skips `Merge`/`Revert`/`fixup!`/`squash!`/`amend!`/cherry-pick. Bypass with `/git-discipline:disable-discipline`.

- **GIT_DISCIPLINE_VALIDATE_CONTEXT picks the `validate_body` source.** Values: `staged` (default), `HEAD` (just-landed delta), `<sha>` (used by push-body-gate). `commit --amend` switches to `HEAD` automatically.

## [v1.0.123]

### Fixed

- **Concurrent Claude sessions in the same repo no longer race the rotation slot.** Each session now has its own rotation state file, so a commit landing in another session does not change which rule the hook asks you to ack.

## [v1.0.120]

### Changed

- **Visual-trailer errors point at capture-route categories.** A failing `missing-visual` or `visual-na-on-ui-touch` guard now hints at where capture routes live (browser drivers, OS utilities, simulator tools, project-launch flows).

## [v1.0.117]

### Fixed

- **Commit guards no longer fire on `git commit` as substring.** Filenames in a `for`-loop (`git-discipline commit discipline.md`), `grep -n "git commit"`, or `echo` with `git commit` in a string pass cleanly.

## [v1.0.112]

### Changed

- **Rule 1 banlist widened.** `Land`, `Make`, `Work`, `Do`, `Get`, `Tweak`, `Surface`, `Address`, and `Apply` now deny at subject start. Rewrite the subject to name the actual capability change.

## [v1.0.111]

### Added

- **Rotation Rule 15 (`steiger`): no internal AI-tooling vocabulary in commit subject/body.** Targets skill names, phase terms, and politer rewrites like "consensus reached"; surfaces on rotation, not a hard block.

## [v1.0.107]

### Breaking

- **Strict commit-discipline is the default.** `GIT_DISCIPLINE_AUTONOMOUS=1` is gone (rules apply universally); bare `Red-then-green: yes`, `Visual: n/a` on UI-touch, `Verified: build-only`, and `# vsd-skip` are always rejected. `--no-verify` is the only audit-logged emergency bypass.

## [v1.0.106]

### Breaking

- **New required `Verified:` trailer.** Anchors how the change was verified: `operator-confirmed`, `<artefact path>`, `red-then-green`, `build-only`, or `n/a (reason)`. Drops on Slice opt-outs; `build-only` is rejected under `GIT_DISCIPLINE_AUTONOMOUS=1`. See `/git-discipline:commit-discipline`.

## [v1.0.102]

### Added

- **`/git-discipline:disable-git` and `/git-discipline:enable-git` lock the repo for Claude.** While the lock is on, git mutations are denied; read-only inspection (status, log, diff, show, blame) keeps working. With `/git-discipline:install-hooks` active, CLI `git commit` and `git push` are blocked too.

## [v1.0.94]

### Fixed

- **Migration of the legacy global state file no longer poisons
  new repos.** The first repo after v1.0.92 used to leave the
  global file in place, re-migrating stale rotation state into
  every later new repo. The source is now renamed to `*.migrated`
  after a successful copy.
- **Toplevel-hash portability on systems without `shasum`.** The
  fallback chain dropped to `cksum` (decimal CRC), drifting per-
  toplevel paths into a different alphabet. It now tries `md5sum`
  and `md5 -q` first, with a final degradation to the global path
  when no hex hasher exists.

### Changed

- **Empty `git rev-parse HEAD` is denied with guidance.** A
  `git commit` in a zero-commit repo used to silently lose the
  ack; the deny is now explicit: "cannot read HEAD, is this a new
  repository?" (Landed as v1.0.90; documented retroactively.)

## [v1.0.93]

### Changed

- **Deny strings are now English.** The rotation guard mixed
  Dutch and English; it is now uniformly English (`violates`,
  `password missing or wrong`, `Paste`). The ack placeholder is
  `<password>`. Tooling that grepped old fragments needs to update.

## [v1.0.92]

### Changed

- **Rotation state file is now per-repo, not per-user.** The
  global path collided across unrelated repos. It is now
  namespaced by an 8-char hash of `git rev-parse --show-toplevel`.
  The legacy file migrates atomically on first read; worktrees of
  the same repo share state.

## [v1.0.91]

### Changed

- **State file format is now key=value.** Was positional
  (line 1 = pv, ...); now `pv=-1`, `pr=-1`, `rp=0`,
  `ack_pending_sha=`. The reader still accepts legacy 3- and
  4-line forms. Tooling using `sed -n '<N>p'` should switch to
  `grep -E '^<key>='`.
- **Migration of the legacy `dont-do-that` state file is now
  atomic.** The one-shot `cp` could be raced by two Claude sessions
  starting at once; the migration now writes to a per-pid temp file
  and renames atomically.

## [v1.0.89]

### Changed

- **Broken-install deny replaces the slash-command fallback.** When
  `commit-subject.sh` cannot resolve `SKILL.md`, it now emits a loud
  `install appears broken: ... Reinstall git-discipline@laicluse-agent-fieldkit.` deny
  instead of degrading to `/git-discipline:commit-discipline`. Reinstall if
  you see this.

## [v1.0.85]

### Changed

- **Rotation slot only advances after a commit actually lands.** A commit that passed PreToolUse but failed downstream (missing `[doublecheck]`, version-bump hook error) used to burn a slot anyway; now you ack the same rule again on retry.

## [v1.0.83]

### Changed

- **Rotation deny names the SKILL.md path.** The reminder ends with `(lookup: <abs-path>, section 'Rotation reminders')` instead of `(zie /git-discipline:commit-discipline)`, so the password lookup is a direct Read; tooling that greps for the old phrase needs an update.

## [v1.0.80]

### Breaking

- **`Red-then-green` line+name forms are unified.** The bare
  `<path>:<line>` and bare `<path>:<test-name>` forms are removed.
  Use the combined form `<path>:<line> # <test-name>` instead. A
  full example trailer:

  ```
  Red-then-green: spec/foo_spec.rb:42 # SomeClass#method does the thing
  ```

  The `# ` separator is the RSpec / Cucumber wire format and is the
  only candidate that keeps `path:line` clickable in iTerm2 Semantic
  History, VSCode terminalLinkParsing, and Ghostty. The gcc-style
  `path:line: <name>` form was rejected because two of those three
  parsers greedily absorb the trailing non-numeric continuation past
  the second colon, breaking cmd-click; see
  https://github.com/microsoft/vscode/issues/127762 and
  https://github.com/ghostty-org/ghostty/discussions/11378 for the
  upstream confirmations. The file-only `<path>` form, the `yes`
  self-attestation, and `n/a (reason >= 10 chars)` are unchanged.

  New error code `red-then-green-line-out-of-range` fires when the
  named line exceeds the staged blob's line count or names line 0
  (the trailer uses 1-based numbering, matching every test runner's
  output). `red-then-green-test-not-found` continues to fire when
  the named test does not match any `it / describe / context /
  specify / @test / @Test / Scenario / func / def` declaration in
  the staged blob.

## [v1.0.73]

### Breaking

- **`Red-then-green: yes` is rejected under `GIT_DISCIPLINE_AUTONOMOUS=1`.**
  New code `red-then-green-autonomous`. The trailer must anchor the
  claim with `<path>` (staged), `<path>:<test-name>`, or `n/a
  (reason >= 10 chars)`. Outside autonomous mode `yes` still works.

### Added

- **`Red-then-green` accepts spec-path forms.** Three new shapes on top
  of the legacy `yes` and `n/a (reason)`:

  - `Red-then-green: spec/foo_spec.rb` anchors the claim to a spec file
    that this commit actually touches. New error code
    `red-then-green-path-not-in-staged` rejects random spec names.
  - `Red-then-green: spec/foo_spec.rb:starts on StartTransaction`
    identifies WHICH test was seen red, by name. New error code
    `red-then-green-test-not-found` fires when the staged blob has no
    matching `it / describe / context / specify / @test / @Test /
    Scenario / func / def` declaration.
  - `Red-then-green: spec/foo_spec.rb:42` is the line-number form; the
    staged blob must have at least that many lines.

  The validator cannot prove that the test was actually run red, but it
  can refuse claims that are not anchored anywhere. See
  `/git-discipline:commit-discipline` for the full table.

## [v1.0.61]

### Breaking

- **`# vsd-skip` no longer bypasses UI-touched commits.** New code
  `vsd-skip-ui-touch`. UI commits must use `Visual: <path>` or
  `Visual: n/a (rationale)`. Backend / spec / migration commits are
  unaffected.

### Added

- **`GIT_DISCIPLINE_AUTONOMOUS=1` strict mode for unattended commits.**
  When set, `# vsd-skip` is rejected outright
  (`vsd-skip-autonomous`) and `Visual: n/a` is rejected on UI-
  touched commits (`visual-na-autonomous`; only `Visual: <path>`).
  Ship from rover skills to tighten policy.

## [v1.0.57]

### Added

- **Post-update broadcasts.** After an update, the next git-discipline slash
  command shows a one-line summary of what changed. Runs once per
  machine per version; sentinel at
  `${LAICLUSE_HOME:-~/.laicluse}/git-discipline/broadcasts/git-discipline-broadcast-seen`.
- **Shared marketplace whats-new reader.** Re-prints this file's section for
  the current version on demand, regardless of whether the broadcast already
  fired. Fieldkit now provides this through `/whats-new`.
