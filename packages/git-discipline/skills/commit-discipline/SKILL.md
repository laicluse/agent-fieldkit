---
name: commit-discipline
user-invocable: true
description: >-
  Reference for git-discipline commit bodies, trailers, hook denials, examples, and escape hatches.
argument-hint: ""
---

# /git-discipline:commit-discipline

Canonical reference for the git-discipline commit body schema. The PreToolUse:Bash
guard and the git-native hooks (`commit-msg`, `pre-push`) read the same
validator (`hooks/lib/validate-body.sh`); this document describes what
that validator requires, which escape hatches exist, and how to
troubleshoot.

## What

The commit-discipline extension enforces a structured commit body via
two layers: a PreToolUse:Bash guard that intercepts Claude-driven commits,
and git-native hooks (installed via `/git-discipline:install-hooks`)
that guard commits made outside of Claude.

The schema consists of three parts: a subject line in imperative
English (50/72 characters), a free-form WHY paragraph that explains
why the change is needed, and a series of trailers in `git interpret-trailers`
format (`Key: Value`, at the bottom of the message). The validator runs
in two layers but shares exactly the same logic, so behavior never
diverges.

Claude Code does not offer a native PreCommit lifecycle event
(https://github.com/anthropics/claude-code/issues/4834, closed not planned),
so the two-layer architecture is final, not provisional.

Each layer has a creation-time guard plus a backstop for commits that guard
cannot see. The PreToolUse guard only parses a body out of a direct
`git commit -m`/heredoc command string, so a commit a `git rebase`,
`git cherry-pick`, `git merge --continue`, or `git commit --amend` wrote leaves
no parseable string. A PostToolUse net (`commit-body-posttool`) covers those by
validating the commits the command actually wrote and blocking so the body is
fixed at creation time. On the git-native side, `commit-msg` does not fire on
rebase-picked commits, so a `post-rewrite` hook validates rewritten bodies
(warn + log only, because git ignores its exit status) and `pre-push` runs the
same body validation over the push range as the last gate. The point of the
PostToolUse and git-native backstops is that a repo without a remote never
reaches a push gate, so every commit must be clean at creation time.

## Quick reference for AI: pass the gate in one attempt

Sessions that come in cold burn many turns rediscovering the same shape of
command that survives both the PreToolUse extractor and `git interpret-trailers`.
The schema below is the one that does. Use it verbatim; deviations from this
shape almost always lose attempts.

### Canonical commit form

```bash
git commit -m "$(cat <<'EOF'
Subject line, imperative, under 50 chars

Body paragraph. Two sentences or 60+ chars ending in a period. Wrap
each line at 72 chars so the line-length guard passes.

Slice: <opt-out token or layer description>
Red-then-green: <spec-path>:<line> # <test-name>   (or `n/a (reason)`)
Verified: <operator-confirmed | agent-confirmed | path | red-then-green | n/a (reason)>
Verified-how: Due to <reason>, this was confirmed by <what you ran and saw>   (only with agent-confirmed)
EOF
)" # ack-rule<N>:<password>
```

Why this exact shape works: `dd_extract_commit_message` in `hooks/lib/common.sh`
tries heredoc bodies first and reads the full body verbatim. The `-m` fallback
joins multiple `-m` values with `\n\n` (one paragraph per flag), which leaves
trailers in earlier paragraphs invisible to `git interpret-trailers --parse`
later in `validate-body.sh`. Inside a single heredoc the trailers sit
contiguous at the bottom of one paragraph, so the validator sees them. The
ack token rides as a trailing shell comment after the closing `)"`, where
`dd_strip_commit_message` (same file) keeps it intact for the rule-rotation
regex in `commit-subject.sh`.

### Anti-patterns that cost attempts

- **Multiple `-m` flags for trailers.** Each `-m` becomes its own paragraph
  separated by a blank line; `git interpret-trailers` only treats the LAST
  paragraph as a trailer block. A commit with `-m "Slice: foo" -m
  "Red-then-green: bar" -m "Verified: baz"` fails with `missing-slice` even
  though all three trailers are present, because only `Verified` ends up in
  the trailer paragraph. Put trailers contiguous inside the heredoc.
- **Embedded `\n` or real newlines inside a `-m` argument.** The extractor's
  `grep -oE` reads the bash command string line by line, so a newline inside
  the quotes truncates the captured body before the validator sees it. Either
  the body becomes "empty" (`missing-body`) or the subject is read as
  editor-mode. Use the heredoc form instead.
- **`-F path` or `-F -`.** The `commit-subject` guard denies any commit that
  yields an empty extracted subject (via `dd_extract_commit_message`); `-F`
  falls under that because the extractor sees no `-m` flag and the heredoc
  walk picks up nothing useful. The deny message is "Editor-mode commit hides
  the subject. Pass inline: git commit -m '...'". No `--no-verify`-adjacent
  flag combination makes `-F` pass the PreToolUse layer.
- **Subjects with conjunctions.** ` and `, ` + `, ` & ` (each surrounded by
  spaces) are rejected by `commit-format` as bundled changes. Rewrite into a
  cohesive single verb, split into two commits, or add `# allow-conjunction:
  <reason>` inside the body when the joined form is genuinely atomic.
- **Body lines over 72 chars.** Inside the heredoc, wrap prose manually;
  the validator measures actual line length. Trailer lines (`Key: Value`)
  are exempt from the 72-char ceiling.
- **Free-text Slice under 10 chars.** A token like `Slice: fe` is rejected
  with `slice-too-short`; write at least `frontend layer` or similar.
- **Vague `Verified: n/a` rationale.** The rationale must contain one of the
  closed-enum tokens listed in the "Required trailers" section. A phrase like
  "not applicable" matches none of them and is rejected with
  `verified-rationale-vague`.
- **Manually exporting `GIT_DISCIPLINE_TRIVIAL_OK=1`.** The PreToolUse guard sets
  this automatically when the staged diff has at most 1 file and at most 5
  insertions; the git-native commit-msg hook re-derives it from the staged
  diff every run and ignores any exported value. There is no manual override
  at the PreToolUse layer; at the git-native layer `git commit --no-verify`
  skips the hook (audit-logged emergency bypass).

### Rule-rotation expectations

Every `git commit` invocation fires one thematic reminder from the rotation
table (see "Rotation reminders" below). This is per-commit, not per-session;
even a warm session that just landed a clean commit fires the next slot on
the next commit. Acknowledge by appending `# ack-rule<N>:<password>` to the
same bash command line, where `<password>` is the mnemonic listed against
rule N in the table. The mnemonic is intentionally referential to the rule's
principle so the lookup counts as one exposure per ack cycle; do not memoise
the passwords from a prior commit.

Plan for **two bash invocations per commit**: the first surfaces the rule
number, the second includes the ack. The rotation advances by one slot on
every landed commit, so the password the previous attempt printed is the
password the current attempt needs.

### Opt-out tokens for housekeeping commits

`Slice:` accepts opt-out tokens that relax `Tests:`, `Red-then-green:`, and
`Verified:` requirements:

- `docs-only`: only documentation files (`.md`, `.txt`, `.rst`, README)
- `config-only`: configuration without behaviour change (`.gitignore`,
  YAML/TOML/INI tweaks that do not flip behaviour)
- `migration-only`: pure database migrations
- `spec-only`: only spec/test files (the diff IS the red phase)
- `chore-deps`: dependency bumps, lockfile updates
- `revert`: full revert of an earlier commit
- `merge`: merge commits (typically created automatically)
- `wip`: work-in-progress; accepted at commit time, blocked at push

For the first five, `Red-then-green` and `Tests` drop. `Verified` still
applies in the schema but accepts `n/a (reason)` with a one-phrase rationale
from the closed enum (`no behaviour change`, `no ui touched`, etc.).
`revert`, `merge`, and `wip` carry their own semantics; see "Opt-out enum"
below for the per-token rules.

When the body still triggers `missing-slice` on an opt-out token, the
problem is almost always structural (multi `-m`, not heredoc) and not the
token itself; check the canonical form first.

### Single-attempt checklist

Before invoking `git commit`, verify:

- [ ] Subject under 50 chars, imperative, no conjunction
- [ ] Body wrapped at 72 chars per line, 60+ chars total, ends in `.`
- [ ] Trailers contiguous at the bottom of the heredoc
- [ ] Ack token appended after `)"` with the password for the rule the
      previous attempt surfaced (or skip on a true first attempt and accept
      the reminder fire)
- [ ] No `-F`, no embedded `\n` literals, no quoted multi-line `-m`

If the gate still denies, the deny output lists ALL schema misses for the
commit in one block (batched reporting); fix every listed check and
re-submit in one call, do not iterate one error at a time. Hard violations
(format, body) block at PreToolUse so the commit object is never created;
rerun the same `git commit` call after fixing (no `--amend` needed).
Soft nudges (subject 51-72 chars) are non-blocking and appear as context.

## The schema

### Subject lines

- Imperative English ("Add handler", not "Added handler" or "Adding handler").
- At most 72 characters; 50 characters is the target for readability in `git log`.
- No period at the end.
- No conventional-commits prefix required (`feat:`, `fix:`), but allowed.
- Automatically skipped for: `Merge ...`, `Revert ...`, `fixup!`, `squash!`, `amend!`.
- Cherry-pick commits: skip runs through both layers. The git-native `commit-msg`
  hook detects cherry-picks because `git cherry-pick -x` adds the phrase
  `(cherry picked from commit <sha>)` to the body. The PreToolUse
  guard detects the same phrase when Claude invokes a `git commit -m '...(cherry
  picked from commit ...)...'` wrapper. A raw `git cherry-pick` from
  the terminal does not pass through PreToolUse, so the layer split does not
  apply there. Without the `-x` flag, the subject does not contain a
  `(cherry picked...)` phrase, which means the anti-copy-paste check can fire
  unjustly if the WHY of the source commit is identical.

### WHY paragraph

- Free-form prose, at least two non-empty lines OR at least 60 characters
  ending in `.`, `!`, or `?`.
- Sits after the subject line, separated by a blank line.
- Anti-copy-paste: the SHA1 of the WHY text must not be identical to that of
  any of the five most recent commits on the current branch.
- Not validated for content (too easy to bullshit), only structurally.

### Required trailers

| Trailer | Value | Required when |
|---------|-------|---------------|
| `Slice` | opt-out token or free-form text (see below) | always |
| `Tests` | comma-separated list of spec paths | when `Slice` is not an opt-out token |
| `Red-then-green` | `yes` or `n/a (reason >= 10 chars)` | when `Slice` is not `docs-only`, `config-only`, `migration-only`, `spec-only`, or `chore-deps` |
| `Visual` | file path or `n/a (reason >= 10 chars)` | when the staged diff touches UI files (see heuristic below) |
| `Verified` | `operator-confirmed`, `agent-confirmed`, `<path>`, `red-then-green`, or `n/a (reason)` | when `Slice` is not an opt-out token |
| `Verified-how` | one sentence, `Due to <reason>, this was confirmed by <what the agent ran and saw>` (>= 20 chars) | when `Verified` is `agent-confirmed` |

**`Slice` rules:** the value is either one of the eight opt-out tokens (see
the next section), or free-form text describing which layers the commit
touches (e.g. `handler + service + spec`, `frontend + backend + migration`).
Free-form Slice values must be at least 10 characters; shorter values are
rejected with `slice-too-short`.

**`Tests` rules:** every path in the list must exist in the HEAD tree
(`git ls-tree -r HEAD --name-only`) or in the staged diff
(`git diff --cached --name-only`). Supported extensions:
`.rb`, `.py`, `.js`, `.ts`, `.tsx`, `.jsx`, `.go`, `.sh`, `.bash`, `.bats`,
`.feature`, `.swift`.
Anchor suffixes (`#method_name`) are stripped for the file existence check.

**`Red-then-green` rules:** the trailer accepts three forms; bare `yes`
is no longer accepted because self-attestation without an anchor cannot
be checked and was the primary leakage path.

| Form | Meaning | When |
|------|---------|------|
| `<path>` | Names the spec file that was seen red. The path must end in a recognized spec extension (`.rb`, `.py`, `.js`, `.ts`, `.tsx`, `.jsx`, `.go`, `.sh`, `.bash`, `.bats`, `.feature`, `.swift`) and must appear in `git diff --cached --name-only` so the claim is anchored to the change under review. | The file is at least named. |
| `<path>:<line> # <test-name>` | Identifies WHICH test was seen red, by line and by name. The validator checks that the staged blob has at least `<line>` lines, and matches `<test-name>` against runner-specific patterns: `it "name"`, `describe "name"`, `context "name"`, `specify "name"`, `@test "name"`, `@Test("name")`, `Scenario: name`, `func name(`, `def name(`. First hit wins. The `# ` separator is the RSpec / Cucumber wire format and keeps `path:line` clickable in iTerm2 / VSCode / Ghostty terminal link parsers (the gcc-style `path:line: <name>` form was rejected because two of those three parsers absorb the trailing non-numeric continuation past the second colon, breaking cmd-click). | Strongest form: the commit says exactly which test, on which line, went RED then GREEN. |
| `n/a (reason)` | Opt-out with a rationale of at least 10 characters. Bare `n/a` without rationale is rejected. | When no red-then-green sequence applies (e.g. log-line addition, copy change). |

Structural limitation: the validator checks the presence and format
of `Red-then-green`, not the truth of its content. The combined
`<path>:<line> # <test-name>` form anchors the claim to the staged
diff and the staged file but cannot prove that the test was actually
run red. That is a deliberate choice:
a cache that automatically tracks evidence adds more complexity than
it is worth. Attestation responsibility lies with the author; the validator
closes the easiest leakage paths (bare `yes` self-attestation, random
spec path not in this commit, hallucinated test name not in the staged
file).

**`Visual` rules:** a path value points to a screenshot or
recording file that must exist in the worktree (`[[ -f "$path" ]]`). The
value `n/a (reason)` is allowed with a rationale of at least 10
characters; bare `n/a` without rationale is rejected. The trailer is only
required when the heuristic below detects UI touches in the
staged diff; backend-only commits do not see the rule and need not
include `Visual`.

**`Verified n/a` closed enum:** the `n/a (reason)` form is only accepted when
the rationale contains at least one of these category tokens (case-insensitive):
`extract-only`, `accessibility-only`, `accessibility metadata`, `debug-only`,
`spec-only`, `test-only`, `copy-only`, `copy change`, `metadata-only`,
`no behaviour change`, `no behavior change`, `no visual change`, `no ui change`,
`no visual impact`, `no ui impact`, `byte-identical`, `render unchanged`,
`pixel-identical`, `backend rewrite`, `backend only`, `no ui touched`,
`sound-only`, `audio-only`, `log-only`, `telemetry-only`. Rationale that
matches none of these tokens is rejected with `verified-rationale-vague`.

**`Verified` rules:** the trailer is the self-assessment "how was the new behaviour verified". The closed answer set covers the four legitimate anchors plus the `n/a` opt-out.

| Form | Meaning |
|------|---------|
| `operator-confirmed` | The operator confirmed the change works in this session (saw the UI flow run, ran the Siri Shortcut, hit the endpoint, etc.). The validator cannot anchor this claim, but the trailer makes it explicit so a later `git log` reader sees what backed the commit. |
| `agent-confirmed` | The agent itself exercised the change this session (ran the code, smoke-tested, observed the output) rather than the operator. Requires a companion `Verified-how:` trailer with a concrete sentence (>= 20 chars) of the shape "Due to \<reason\>, this was confirmed by \<what the agent ran and saw\>". Because that sentence lands in git, it leaves a paper trail to catch a dishonest self-attestation later. |
| `<path>` | A screenshot, recording, log dump, or curl-output stored in the repo. Resolved against repo root; the file must exist. Recognised extensions: `.png`, `.jpg`, `.jpeg`, `.gif`, `.webp`, `.heic`, `.svg`, `.tiff`, `.bmp`, `.mov`, `.mp4`, `.webm`, `.pdf`, `.txt`, `.log`, `.md`, `.json`, `.html`. Any value containing `/` is also treated as a path. |
| `red-then-green` | The verification anchor is the `Red-then-green` trailer. Rejected when `Red-then-green` is itself `n/a (...)` (the chain is broken: tests cannot be both the verification and the not-applicable). |
| `n/a (reason)` | Closed-enum rationale, same set as `Visual: n/a` (see `visual-rationale-vague` below). Bare `n/a` without rationale is rejected. |

The trailer drops when `Slice` is one of the eight opt-out tokens (same exemption as `Tests`). It does **not** consult the UI-touch heuristic; it is required on every behaviour-bearing commit, not just UI commits, because the question "was this verified" applies to backend logic, intents, queues, and migrations alike.

Why this trailer exists alongside `Tests`, `Red-then-green`, and `Visual`: the existing three trailers anchor specific anchors but never force a top-level answer to "is the behaviour itself verified". A backend behaviour change can pass the schema with no anchor when the UI-touch heuristic does not fire (e.g. `.swift` AppIntents that only `import AppIntents`). The `Verified` trailer closes that gap by asking the question directly: did the operator see this work, did the agent run it, is there an artefact, was it covered by Red-then-green, or is there genuinely no behaviour to verify.

Error codes:

| Code | When |
|------|------|
| `missing-verified` | Trailer is absent on a non-opt-out commit, or the value is bare `n/a` without rationale, or the value is none of the recognised forms (e.g. `Verified: probably`). |
| `missing-verified-how` | `Verified: agent-confirmed` without a companion `Verified-how:` trailer, or with one under 20 chars. Add a sentence naming why the agent verified instead of the operator and what it ran. |
| `verified-path-not-found` | Path-form value points at a file that does not exist relative to repo root. |
| `verified-red-then-green-mismatch` | `Verified: red-then-green` while `Red-then-green` is `n/a (...)`; pick a different Verified form. |
| `verified-build-only-removed` | `Verified: build-only` is no longer accepted; supply a concrete anchor (`operator-confirmed`, `<path>`, `red-then-green`) or `n/a (reason)`. |
| `verified-rationale-vague` | `n/a (reason)` rationale does not name a recognised category from the closed enum (same set as `Visual: n/a`). |

**UI-touch heuristic:** the validator scans `git diff --cached --name-only`
and triggers the Visual requirement on any path that matches one of these patterns:

- web template: `.tsx`, `.jsx`, `.vue`, `.svelte`, `.html`, `.htm`,
  `.erb`, `.haml`, `.slim`
- styling: `.css`, `.scss`, `.sass`, `.less`
- iOS storyboard/xib: `.storyboard`, `.xib`
- iOS asset catalog: any path under `*.xcassets/`
- Swift source files: `.swift` whose staged content (`git show :<path>`,
  fallback to worktree) contains one of `import SwiftUI`, `import UIKit`,
  `import AppKit`, `: View {`, `UIView`, `UIViewController`, `NSView`,
  or `NSViewController`

Backend `.swift` files without UI symbols are not covered by the rule.
False positives of the heuristic can be absorbed via
`Visual: n/a (backend rewrite, no UI touched)` or a similar rationale,
analogous to the `Red-then-green: n/a` opt-out. The heuristic does not
consult `Slice` tokens; the trailer fires correctly when a commit with
`chore-deps` slice also bumps a CSS dependency.

**Known false positives.** The extension list deliberately chooses broad
over narrow:

- `.html` also matches backend e-mail templates and HTML fixtures without
  rendering. Escape with `Visual: n/a (e-mail template, no rendered UI)`.
- A `chore-deps` commit that also brings along a generated `.scss` or `.css`
  fires the rule. The Slice token does not explicitly suppress the
  heuristic (a real UI change in a chore-deps commit must
  also get a screenshot). Escape with `Visual: n/a (regenerated by
  package manager, no UI authored)`.
- `.swift` without visible UI symbols falls outside; watch out when the
  staged blob is not available (e.g. partial amend), because then the
  heuristic conservatively classifies the file as non-UI and you must
  opt in yourself via `Visual: <path>` or `Visual: n/a (...)`.

Error codes:

| Code | When |
|------|------|
| `missing-visual` | UI-touch detected but trailer is absent, or trailer is bare `n/a`, or `n/a (reason)` with too short a rationale |
| `visual-path-not-found` | Trailer is not an `n/a` form and the given path does not exist in the worktree |
| `visual-rationale-defers` | The `n/a (rationale)` text uses deferral language (`later`, `follow-up`, `next iteration`, `to be captured`, `will capture`, `coming next`, `post-merge`, `saved for later`) that promises a screenshot at a future event. The trailer cannot validate that promise; either supply `Visual: <path>` now or rewrite the rationale to describe why a screenshot has no meaning for this change (extract-only refactor, accessibility metadata, debug-only surface, copy-only). |
| `visual-rationale-vague` | The `n/a (rationale)` text does not name a recognized non-applicable category. The closed enum is: `extract-only`, `accessibility-only`, `accessibility metadata`, `debug-only`, `spec-only`, `test-only`, `copy-only`, `copy change`, `metadata-only`, `no behaviour change`, `no visual change`, `no ui change`, `no visual impact`, `no ui impact`, `byte-identical`, `render unchanged`, `pixel-identical`, `backend rewrite`, `backend only`, `no ui touched`, `sound-only`, `audio-only`, `log-only`, `telemetry-only`. The rationale must contain at least one of these tokens (case-insensitive) so the claim "no screenshot has meaning here" is classified rather than narrated. |
| `red-then-green-path-not-in-staged` | Trailer names a spec path that is not in `git diff --cached --name-only`. Either name a spec file this commit actually touches, or fall back to `n/a (reason)`. |
| `red-then-green-test-not-found` | Trailer is `<path>:<line> # <test-name>` but the staged blob has no matching `it`, `describe`, `context`, `specify`, `@test`, `@Test`, `Scenario:`, `func name(`, or `def name(` declaration. Name the test as it appears in the file. |
| `red-then-green-line-out-of-range` | Trailer is `<path>:<line> # <test-name>` but the staged file has fewer lines than `<line>`. Name a line that exists in the file as it stands in this commit. |
| `red-then-green-bare-yes` | `Red-then-green: yes` is no longer accepted. Use `<path>` or `<path>:<line> # <test-name>`, or `n/a (reason)`. |
| `visual-na-on-ui-touch` | `Visual: n/a (reason)` on UI-touched commits is rejected; capture a screenshot and supply `Visual: <path>`. |
| `review-pass-batch` | The WHY block names a review pass (`pride pass`, `end-user pass`, `technical pass`, `review pass`, `review findings`, `pride contrarian`, `review contrarian`) and lists two or more findings as bullets. Review-pass commits should land one finding per commit so each fate (fix, reject-with-evidence) is its own reviewable unit; rewrite the WHY in prose for one finding and split the others into separate commits, or remove the review-pass keyword if this is not a review-pass commit. |

### Optional trailers

| Trailer | Value |
|---------|-------|
| `Resolves` | URL to issue, Sentry, incident; or `none` |
| `Cucumber` | `applicable` (and used), or `n/a (reason)` |
| `Co-authored-by` | allowed provided it is not an `@anthropic.com` address (see escape hatches) |

Trailers are parsed via `git interpret-trailers --parse`. Order
within the trailer block does not matter.

### Subject conjunction

The subject must not join two changes with a conjunction. The format
guard rejects subjects containing ` and `, ` + ` (space-plus-space),
or ` & ` because they signal that the author bundled multiple
changes behind one subject. Split into separate commits, or rewrite
the subject as one cohesive change. When the joined form is
intentional (e.g. an atomic refactor that genuinely couples two
verbs), set `GIT_DISCIPLINE_ALLOW_CONJUNCTION=1` in the shell for the single
commit, or add `# allow-conjunction: <reason>` to the body.

## Opt-out enum

If `Slice` is one of these eight tokens, relaxed rules apply:

| Token | When to use |
|-------|-------------|
| `docs-only` | Only changes in documentation (`.md`, `.txt`, `.rst`, README) |
| `config-only` | Only changes in configuration files without behavior change |
| `migration-only` | Only database migrations without an associated handler/spec change |
| `spec-only` | Commit contains only spec/test files (the diff is itself the red evidence) |
| `chore-deps` | Dependency bumps, lockfile updates, build system tweaks |
| `revert` | Full revert of an earlier commit |
| `merge` | Merge commits (typically created automatically) |
| `wip` | Work-in-progress commit on a feature branch; **blocked at push** |

For `docs-only`, `config-only`, `migration-only`, `spec-only`, and `chore-deps`
the `Red-then-green` requirement also drops. Rationale: migrations have no
meaningful red-then-green sequence; spec-only commits are themselves the red
phase (the spec existed before the implementation). For all eight, the
`Tests` requirement drops.

`wip` commits are accepted at commit time but blocked by the
pre-push gate. You cannot accidentally send a wip commit to remote.

## Rotation reminders

In addition to the structural subject and body checks, the
PreToolUse:Bash guard `commit-subject.sh` rotates one thematic
reminder from the table below on every commit. Acknowledge with
`# ack-rule<N>:<password>` as a trailing shell comment behind the
git command. The password is a mnemonic that is referentially tied
to the rule, so looking it up forces one exposure per cycle.

| Rule | Password | Rule |
|------|----------|------|
| 1 | `gedrag` | Subject = new behavior/capability, no git action or capability-laundering verb. The literal regex covers Fix/Add/Land/Make/Address/Apply/Tweak/Surface/Plant/Place/Pin/Lay/Anchor/Set/Stand/Mount/Install, but the rule is broader than the list: any verb that describes what YOU did to the artifact ("plant"/"sow"/"ground"/"hook"/"wire"/"bring"/"ship") is a dodge of the same category. If you find yourself reaching for a new placement or attachment verb to slip past the regex, that itself is the signal the subject is still git-action-shaped. Rewrite so the subject describes what the system can do now that it could not before. |
| 2 | `effect` | Subject says WHAT the system does, not the WHY trigger ("Address feedback"). Fires before Rule 1 when the trigger phrase matches. |
| 4 | `essentie` | Body only when needed: 2-4 sentences why. |
| 5 | `dubbelop` | No file listings or class inventory; the diff already shows files. |
| 6 | `proza` | No bullet dumps or meta-narrative ("reviewer asked", "tests failed"). |
| 7 | `atoom` | Logically independent changes = separate commits; test + impl of 1 feature = 1 atomic commit. |
| 8 | `inferno` | Never commit broken code with "fix in next commit". |
| 9 | `solist` | No Co-Authored-By from AI tooling unless asked. |
| 10 | `incognito` | No 'Generated with Claude Code' footer. |
| 11 | `loep` | Review the staged diff before commit; tool output is not evidence. |
| 12 | `bewijsstuk` | Commit check is evidence you observed the real result (the test ran and covers this change; the endpoint was hit; the on-screen output was looked at), not a green build, gut feel, or a screenshot that merely exists. For visual work the evidence is the on-screen render; an offscreen capture can differ from what ships, so confirming a file exists is not the check. |
| 13 | `kralen` | Never squash merge; preserve history. |
| 14 | `voorwaarts` | Amend rewrites public history when the commit is already pushed: forbidden in that case. On unpushed commits amend is fine, including gate-mandated rewrites that `push-body-gate` asks for; the prohibition kicks in once the SHAs are public. |
| 15 | `steiger` | No internal AI-tooling or process vocabulary in subject/body (skill names, phase terms, "after the panel reviewed", "consensus reached"). |

Rule 3 (subject length 50/72) is enforced structurally by
`commit-format.sh` and is not in the rotation. Rules 1 and 2 only
land on you after a real violation in the subject; rules 4-15 rotate in
slot order, one per commit. State lives under `${LAICLUSE_HOME:-~/.laicluse}/git-discipline/`,
namespaced first by the worktree's toplevel hash (so two repos do not
share state) and then by the Claude session id (so two concurrent
Claude sessions in the same repo do not race each other's slot, see
"Concurrent sessions" below). State shifts after every *confirmed*
commit success, not on every ack-match: the guard records the HEAD
sha at the moment the ack matches, and the next dispatcher entry
advances the rotation slot only when HEAD has actually moved
(commit landed). When the commit fails at commit-msg, pre-commit, or
never runs, the slot stays so the operator acks the same rule again
on the next attempt instead of burning a fresh rotation slot. A
`git commit --amend` of the just-acked commit is detected via parent
comparison (the new HEAD and the previously-acked HEAD share the same
parent); on a detected amend the slot does NOT advance, so a
gate-mandated message rewrite does not cost an extra ack cycle. The
canonical mnemonic table that the hook validates against is in
`packages/git-discipline/hooks/lib/rotation-rules.sh`.

The state file is in key=value format: `pv=`, `pr=`, `rp=`, and
`ack_pending_sha=` (the HEAD sha at the last ack-match, empty when
no resolution is pending). The reader also accepts the two legacy
positional formats (three-line and four-line); the next write
converges any legacy file to key=value.

#### Concurrent sessions

When two Claude Code sessions work in the same repo at the same time
(one driving the feature branch, another landing a fix on main, both
firing `git commit` through this guard), each session has its own
rotation state file under the per-toplevel namespace. The PreToolUse
JSON payload carries the Claude session id; the guard derives an
8-character session key from it and appends it to the per-toplevel
path. Two sessions therefore advance independently: a commit landing
under session B does not change the slot session A's hook will ask
A to ack on A's next commit.

The first dispatch under a fresh session id inherits the rotation
position (`rp`) from the per-toplevel file (if one exists from earlier
work in the repo); transient flow-state (`pv`, `pr`, `ack_pending_sha`)
is reset, so the new session continues at the next slot in the cycle
instead of resetting to slot 0 and is not asked to acknowledge an
earlier session's in-flight rule. The per-toplevel file itself is not
archived after this inherit; other sessions in the same repo also
inherit from it. Stale per-session files older than 7 days are
opportunistically pruned the first time a session creates its own
state file in a repo; subsequent commits inside the same session
skip the prune, so the directory scan stays bounded to once per
session per repo.

Non-Claude shells (a `git commit` run manually in a terminal without
the hook payload carrying a session id) fall back to the per-toplevel
state file, which is the prior single-rotation behaviour for that
context.

### Why this lives in a hook and rotates one rule at a time

Two design choices, two reasons. Both are load-bearing; a "streamline"
that removes either of them defeats the discipline even if the trailer
schema still passes.

1. **The discipline lives in a hook, not in this skill, because skill
   content gets ignored at large enough context.** Skills load into
   the context window once and then have to compete with everything
   else loaded after them. At enough scale, the model glances past
   instructions it has already "seen" and reverts to default behaviour.
   A hook fires at the moment of the action, every time, regardless of
   how full the context is. Git discipline is important enough that it
   has to be reactive at action-time, not declarative in a skill.
2. **One rule per commit, not all rules at once, because a wall of
   rules triggers reflex-compliance.** When the hook output contains
   the full list, the model does not actually inspect each rule; it
   reads "git discipline reminder" and types back "ja ja, akkoord"
   without verifying that the commit actually complies. Splitting the
   rules into a rotation forces a single rule into focus, which is
   small enough to actually be read against the commit at hand. The
   rotation is anti-reflex, not anti-forgetting.

Read those two lines before proposing any change to the rotation. A
proposal that moves the reminder out of the hook into a skill briefing
breaks reason 1. A proposal that bundles the rules together in one
hook output breaks reason 2.

## Examples

### Example 1: feature commit with handler + service + spec + Red-then-green

```
Drop invalid meter reading on transaction events

When StartTransaction or StopTransaction messages arrive with a
meter reading that fails domain validation, we previously rejected
the entire event, which masked session starts and stops in analytics.
This change keeps the transaction event but discards just the bad
reading, restoring the visibility we lost.

Tests: spec/services/session_spec.rb#start_event_with_bad_reading,
       spec/services/session_spec.rb#stop_event_with_bad_reading
Slice: handler + service + spec
Red-then-green: spec/services/session_spec.rb:42 # start_event drops invalid meter reading
Verified: red-then-green
Resolves: https://example.org/backlog/issues/1234
```

### Example 2: docs-only opt-out with minimal trailers

```
Update install instructions for Windows consumers

The symlink-free layout means Windows users need cp -f instead of
ln -s. The previous instructions silently created a text file.

Slice: docs-only
```

(No `Tests` or `Red-then-green` required for `docs-only`.)

### Example 3: chore-deps version bump

```
Bump bundler to 2.5.18

Security patch for CVE-2026-XXXX. No behavior change expected;
suite still loads without modification.

Tests: spec/spec_helper.rb
Slice: chore-deps
Red-then-green: n/a (no behavior change)
```

### Example 4: migration-only opt-out

```
Add NOT NULL constraint to sessions.user_id

The column was introduced in a prior migration without the constraint.
A backfill confirmed no null rows exist in production before this runs.

Slice: migration-only
```

(No `Tests` or `Red-then-green` required for `migration-only`.)

### Example 5: spec-only opt-out

```
Add failing specs for enrollment race-condition fix

Tests written first to drive the implementation. The handler does not
exist yet; these specs are the red phase.

Slice: spec-only
```

(No `Tests` or `Red-then-green` required for `spec-only`.)

### Example 6: UI touch with `Visual:` trailer

```
Render onboarding banner above tab strip

The banner replaces the static placeholder we shipped last week
and now hosts the IAP teaser for unconfigured users.

Tests: spec/views/onboarding_view_spec.rb
Slice: frontend layer
Red-then-green: spec/views/onboarding_view_spec.rb:18 # renders the banner above the tab strip
Verified: doc/screenshots/onboarding-banner.png
Visual: doc/screenshots/onboarding-banner.png
```

`Visual:` may also be `n/a (reason)` for false positives of the
heuristic or for commits where UI files are changed but
without a pixel effect (e.g. a reorganized component without render
change):

```
Extract OnboardingBanner into its own file

Pure organizational split; render output is byte-identical to the
previous version. No screenshot needed.

Tests: spec/views/onboarding_view_spec.rb
Slice: frontend layer
Red-then-green: n/a (extract-only refactor, no logic change)
Verified: n/a (extract-only refactor, no behaviour change)
Visual: n/a (extract-only refactor, render output unchanged)
```

### Example 7: wip commit (and the pre-push gate that holds it back)

```
Sketch enrollment race-condition fix

Half-baked: the locking strategy is not settled yet. Saving state
before context switch.

Slice: wip
```

This commit goes through locally. A `git push` with this commit in the
range is blocked by the pre-push gate with:

```
wip-gate: commit <sha> has Slice: wip in push range
Set GIT_DISCIPLINE_ALLOW_WIP_PUSH=1 or add '# allow-wip-push' to bypass.
```

## Escape hatches

The discipline is strict by default for every commit. There is no
magic-comment opt-out (`# vsd-skip` is rejected) and no env-var ramp
(the former `GIT_DISCIPLINE_AUTONOMOUS=1` is gone; its strict rules apply to
every commit). Escape hatches are per layer: at the git-native layer the
audit-logged emergency bypass is `git commit --no-verify`; at the PreToolUse
layer no bypass flag exists and the off-switch is the operator-only
`/git-discipline:disable-discipline` sentinel. The only purpose-scoped
opt-out is the `Discipline: skip due to rebase` trailer for commits a rebase
carried along (see below).

### `--no-verify`

`git commit --no-verify` skips all git-native hooks, per git semantics. It
does NOT bypass the PreToolUse:Bash guards: those validate every git commit
command, flags included, so inside a Claude session a `--no-verify` commit
with a schema violation is still denied. The only PreToolUse off-switch is
the operator-only `/git-discipline:disable-discipline` sentinel: it writes a
session-scoped sentinel file that tells the dispatcher to skip all guards,
and `/git-discipline:enable-discipline` removes it. This section is the
canonical statement of the layer split. For commits outside Claude (CLI,
IDE), the installed post-commit hook logs `--no-verify` usage to
`${LAICLUSE_HOME:-~/.laicluse}/git-discipline/git-discipline-no-verify.log` for after-the-fact auditing.

**Audit-log race window (outside Claude, detection only, not
enforcement):** the detector uses a trace window of 30
seconds. Concurrent commits in another shell can refresh the trace
and mask a bypass in this shell. Long test runs (>30s between starting
commit-msg and post-commit firing) can produce false positives.
The audit log is best-effort, not authoritative.

### `Discipline: skip due to rebase`

A rebase replays and rewrites every commit it touches, including commits whose
subject-only bodies were authored before this discipline existed. On the
force-push afterwards the body-gate would re-litigate them even though they
already shipped under their pre-rebase SHA. Amending the trailer
`Discipline: skip due to rebase` (any `Discipline:` value beginning with `skip`)
onto such a commit marks it as carried-along; the shared validator then exempts
it from the schema, so every enforcement path (PreToolUse commit/push guards and
the git-native `commit-msg`) honours it from one source. The skip is logged to
`${LAICLUSE_HOME:-~/.laicluse}/git-discipline/git-discipline-skips.log`.

This is a deliberate "discipline bankruptcy" admission, not a blanket bypass:
stamp it only on commits a rebase carried along, not on fresh work you are
authoring under the discipline. `/git-discipline:rebase-latest-default` marks these for
you; for a manual rebase, the push gate names the stragglers and you amend the
trailer onto exactly those.

### `GIT_DISCIPLINE_ALLOW_AI_COAUTHOR=1`

The `commit-trailers.sh` guard blocks `Co-Authored-By:` trailers with an
`@anthropic.com` e-mail address. Set `GIT_DISCIPLINE_ALLOW_AI_COAUTHOR=1` to
bypass that specific block (e.g. for explicit attribution requirements).

### `GIT_DISCIPLINE_ALLOW_WIP_PUSH=1` or `# allow-wip-push`

Bypasses the pre-push wip-gate for the current push. Both forms are logged
to `${LAICLUSE_HOME:-~/.laicluse}/git-discipline/git-discipline-wip-pushes.log`. Use the magic-comment form
when you want to document the bypass in the command itself without
exporting an environment variable.

**Asymmetry:** the `# allow-wip-push` magic comment only works when
Claude executes the push (the PreToolUse:Bash guard reads the bash command string).
For pushes you run yourself in a terminal, only
`GIT_DISCIPLINE_ALLOW_WIP_PUSH=1` works; the git-native pre-push hook does not
read the command string.

### `GIT_DISCIPLINE_ALLOW_CONFLICT_MARKERS=1` or `# allow-conflict-markers`

The `merge-conflict-markers` guard blocks a merge-finalizing command (`git
commit`, `git merge --continue`, `git rebase --continue`) while one or more
tracked files still hold a leftover conflict marker, so a half-resolved merge
cannot land in a live checkout. Detection is `git diff --check` against both the
working tree and the index, shared by the PreToolUse:Bash guard and the
git-native commit-msg hook. Set `GIT_DISCIPLINE_ALLOW_CONFLICT_MARKERS=1`, or add
`# allow-conflict-markers` to the command, to commit anyway. Use this for the
rare case where a conflict region is intentionally part of a fixture being
committed.

**Asymmetry:** same as the wip-push gate, with one extra nuance for the env var.
The `# allow-conflict-markers` magic comment only works when Claude executes the
commit (the PreToolUse:Bash guard reads the bash command string); the git-native
commit-msg hook never sees the command string. The env var works at both layers,
but only when it is actually in the environment: a one-line *prefix*
(`GIT_DISCIPLINE_ALLOW_CONFLICT_MARKERS=1 git commit ...`) propagates to the
git process and so reaches the git-native hook, but the PreToolUse guard runs
before the command executes and reads its own process environment, so the prefix
does not reach it. For the PreToolUse layer, `export` the variable first (or use
the magic comment).

**Scope note:** git flags only lines a commit *adds* that are exactly seven
conflict characters, so a differently-lengthed markdown underline or a
pre-existing marker-like line never fires the guard; a newly-added
exactly-seven-character divider does, and the escape covers it.

### `GIT_DISCIPLINE_TRIVIAL_OK=1`

Set automatically by the PreToolUse:Bash guard when the staged diff has
at most 1 file and at most 5 insertions. Can also be exported manually
inside a Claude session to skip body validation for a specific trivial
commit. Not persistent; applies only to the next commit.

**Limitation:** manual export of `GIT_DISCIPLINE_TRIVIAL_OK=1` only applies to the
PreToolUse:Bash layer. The git-native commit-msg hook re-derives the
trivial flag from the staged diff on every run; an externally exported
value does not bypass that hook. For trivial-but-larger commits at the
git-native layer there is no shortcut: write the schema body or use
`git commit --no-verify` (audit-logged; see the `--no-verify` section
above for layer scope).

## Troubleshooting

**"The hook blocks my commit with missing-tests; how do I fix it?"**

The `Tests:` trailer is missing or contains no valid path. Add a
`Tests:` line with the paths of the specs you ran, e.g.:

```
Tests: spec/services/enrollment_spec.rb, spec/models/device_spec.rb
```

The paths are checked against the HEAD tree and the staged diff. Make
sure the files actually exist in the project. If there are no tests (e.g.
pure config change), use a fitting opt-out token:
`Slice: config-only`.

**"My body is clear enough but the hook says why-too-short"**

The WHY paragraph is too compact. The validator requires at least two
non-empty lines OR at least 60 characters ending in `.`, `!`, or `?`. A
single-line summary of 30 characters does not qualify. Break the
sentence into two lines or write a more complete explanation.

**"I get duplicate-why; I wrote my body myself"**

The SHA1 of your WHY text (after whitespace normalization) matches exactly
that of one of the five most recent commits on the current branch. This
points to copy-paste from an earlier commit message. Rewrite the WHY for
this specific commit; even small textual deviations are enough.

**"What is the rotation ack format and where do I paste it?"**

Each commit fires one rotation reminder. The deny output names the
rule number and the path to the SKILL.md table; look up the
mnemonic password for that rule there, then append it as a trailing
shell comment on the `git commit` command:

```
git commit -m "Subject" -m "Body" # ack-rule11:loep
```

Bare `# ack-rule<N>` without the password is recognised as "user
tried to ack" but does not clear the rotation; the suffixed form
does. The password is intentionally referential: looking it up is
the per-cycle exposure to the rule's principle.

**"install appears broken: cannot resolve SKILL.md path"**

The guard could not locate its own SKILL.md alongside the hooks
directory. The plugin install is incomplete or the cache version
got out of sync with the marketplace. Run
`claude plugins update git-discipline@laicluse-agent-fieldkit` to refresh.

**"cannot read HEAD, is this a new repository?"**

The repository has zero commits yet. The rotation guard records
HEAD at ack-match so the next dispatcher entry can confirm the
commit landed; an empty HEAD breaks that signal. Make at least one
commit (any subject is fine) before invoking the rotation, or
disable the discipline for that initial commit via
`/git-discipline:disable-discipline`.

**"push blocked by wip-gate but the wip commit was already amended"**

If you have amended a `Slice: wip` commit into a normal schema-compliant
commit, the wip-gate sometimes runs over a stale reflog entry. Check with
`git log --oneline` whether there is still a `Slice: wip` commit in the push range.
If there is none left but the gate still blocks, set `GIT_DISCIPLINE_ALLOW_WIP_PUSH=1`
for the push and report the edge case.

## Session-level kill-switch

When you want to temporarily turn off the git-discipline guards without disabling
the plugin globally, use `/git-discipline:disable-discipline`. That uses a sentinel file in
`${LAICLUSE_HOME:-~/.laicluse}/git-discipline/` with your session id; the dispatcher exits early on every
`git commit` or `git push`. Re-enable with `/git-discipline:enable-discipline`. Status check with
`/git-discipline:discipline-status`.

The flip itself is operator-actuated. The `sentinel-protect` guard runs with
the safety locks, before the disabled-sentinel early exit (so it also fires
while discipline is off), and denies any agent-driven Bash call that creates
or removes a `git-discipline-disabled-*` or `.git/git-discipline-deny`
sentinel, in both directions and with no magic-comment or env-var escape.
Read-only inspection of the sentinel paths stays open.

The four toggle commands still honour that rule while running as a single
keystroke. A `UserPromptExpansion` hook
(`hooks/handlers/toggle-commands.sh`) fires on the operator's own typed
command, writes or removes the sentinel itself, reports the result, and
blocks the expansion, so the skill body never reaches the model. Nothing the
model authored can reach the sentinel: `sentinel-protect` is untouched and
keeps denying agent-driven Bash mutations.

## Architecture

The enforcement consists of two parallel layers that call the same
`hooks/lib/validate-body.sh`:

```
git commit (via Claude Code)
    |
    v
PreToolUse:Bash dispatcher (hooks/dispatch.sh)
    |-- git-dash-c.sh       (blocks git -C <dir>)
    |-- commit-format.sh    (editor-mode detection)
    |-- commit-subject.sh   (50/72 subject rules)
    |-- commit-body.sh      (body schema, trivial check)
    |-- commit-trailers.sh  (Co-Authored-By @anthropic.com)
    |-- push-wip-gate.sh    (wip commits on git push)
    |
    +-> validate-body.sh (shared library)
           |-- layer-classify.sh
           |-- example-synth.sh
           +-- wip-gate.sh

git commit (outside Claude, via CLI or IDE)
    |
    v
git-native hooks (installed via /git-discipline:install-hooks)
    |-- commit-msg          -> validate-body.sh (same lib)
    |-- prepare-commit-msg  -> layer-classify.sh (template-fill)
    |-- post-commit         (logs --no-verify usage)
    +-- pre-push            -> wip-gate.sh
```

The git-native hooks live in
`packages/git-discipline/skills/commit-discipline/git-hooks/` and are copied
(not symlinked) by `install-hooks`.

## Migration leftovers

The commit-subject and commit-format guards have moved from `dont-do-that`
to `git-discipline/hooks/guards/` (slice 2). The user-level git hooks
(`block-coauthored-trailer.sh`, `warn-untested-commits.sh`,
`block-git-dash-c.sh`) have been absorbed into `git-discipline/hooks/guards/` (slice 5).
`~/.claude/hooks/` no longer contains any git-touching hooks after the migration.

The audit script lives in the plugin under `bin/audit-no-body-commits`. Use it
as follows to always run it against the active plugin version:

```bash
GIT_DISCIPLINE=$(jq -r '.plugins["git-discipline@laicluse-agent-fieldkit"][0].installPath' \
  ~/.claude/plugins/installed_plugins.json)
python3 "$GIT_DISCIPLINE/bin/audit-no-body-commits"
python3 "$GIT_DISCIPLINE/bin/audit-no-body-commits" --branch main --since 2026-04-01
python3 "$GIT_DISCIPLINE/bin/audit-no-body-commits" --exclude-trivial
```
