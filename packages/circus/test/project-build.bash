#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
circus_bin="$repo_root/packages/circus/bin/circus"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }

repo="$tmp/repo"
mkdir -p "$repo/.claude/skills/portable" "$repo/.claude/skills/waits" \
         "$repo/.claude/skills/forced" "$repo/.claude/skills/unwanted" \
         "$repo/.agents/skills/handwritten" "$repo/sub" "$repo/shared"
git -C "$repo" init -q

cat > "$repo/.claude/skills/portable/SKILL.md" <<'MD'
---
name: portable
description: Use when: the colon breaks strict YAML. Second sentence.
user-invocable: true
allowed-tools: Bash(git:*), Read
trigger: Working with files
---

# Portable

Body stays as written.
MD
printf '#!/bin/sh\necho helper\n' > "$repo/.claude/skills/portable/helper.sh"
chmod +x "$repo/.claude/skills/portable/helper.sh"

cat > "$repo/.claude/skills/waits/SKILL.md" <<'MD'
---
name: waits
description: Waits for CI.
allowed-tools: Bash(gh:*), Monitor, TaskStop
---

Arm a watcher, then call ScheduleWakeup.
MD

cat > "$repo/.claude/skills/forced/SKILL.md" <<'MD'
---
name: forced
description: Mentions a wakeup but works without it.
---

Optionally ScheduleWakeup.
MD

cat > "$repo/.claude/skills/unwanted/SKILL.md" <<'MD'
---
name: unwanted
description: Portable but locally unwanted.
---

Plain.
MD

cat > "$repo/.agents/skills/handwritten/SKILL.md" <<'MD'
---
name: handwritten
description: Written for Codex by hand.
---
MD

cat > "$repo/CLAUDE.md" <<'MD'
# Project

Shared rule.

<!-- circus:only claude -->
Claude hook rule.
<!-- circus:end -->

Closing rule.
MD
printf '# Sub\n\nSub rule.\n' > "$repo/sub/CLAUDE.md"
printf '# Shared\n\nSame for all.\n' > "$repo/shared/README.md"
ln -s README.md "$repo/shared/CLAUDE.md"
ln -s README.md "$repo/shared/AGENTS.md"

mkdir -p "$repo/.circus"
printf '+forced\n-unwanted\n' > "$repo/.circus/skills"
printf 'Codex-only rule.\n' > "$repo/.circus/codex.md"
git -C "$repo" add -A
git -C "$repo" -c core.hooksPath=/dev/null -c user.name=t -c user.email=t@example.com commit -qm init

if "$circus_bin" project check "$repo" >/dev/null 2>&1; then
  fail "check passes before the first build"
fi

out="$("$circus_bin" project build "$repo")"

skill="$repo/.agents/skills/portable/SKILL.md"
test -f "$skill" || fail "portable skill not generated"
ruby -ryaml -e 'd = YAML.safe_load(File.read(ARGV[0]).split(/^---\s*$/)[1]); abort "keys: #{d.keys}" unless d.keys == %w[name description]; abort "description: #{d["description"]}" unless d["description"] == "Use when: the colon breaks strict YAML. Second sentence."' "$skill" \
  || fail "generated frontmatter is not strict, minimal YAML"
grep -q 'Body stays as written.' "$skill" || fail "skill body lost"
grep -qF "<!-- GENERATED from .claude/skills/portable/SKILL.md by 'circus project build'" "$skill" || fail "skill banner does not name its original"
test -x "$repo/.agents/skills/portable/helper.sh" || fail "support file not copied with its mode"

test ! -e "$repo/.agents/skills/waits" || fail "host-bound skill was generated"
printf '%s\n' "$out" | grep -Eq 'skip +waits .*Monitor' || fail "skip reason for waits not reported"
test -f "$repo/.agents/skills/forced/SKILL.md" || fail "+forced did not override detection"
test ! -e "$repo/.agents/skills/unwanted" || fail "-unwanted did not skip"
grep -q 'Written for Codex by hand.' "$repo/.agents/skills/handwritten/SKILL.md" || fail "handwritten skill changed"

root="$repo/AGENTS.override.md"
test -f "$root" || fail "root AGENTS.override.md missing"
head -1 "$root" | grep -qF "<!-- GENERATED from CLAUDE.md by 'circus project build'" || fail "root override banner does not name its original"
head -1 "$repo/sub/AGENTS.override.md" | grep -qF "<!-- GENERATED from sub/CLAUDE.md by" || fail "nested override banner does not name its original"
grep -q 'Shared rule.' "$root" || fail "shared rule missing"
grep -q 'Closing rule.' "$root" || fail "text after the block missing"
if grep -q 'Claude hook rule.' "$root"; then fail "claude-only block leaked"; fi
grep -q 'Codex-only rule.' "$root" || fail "codex overlay not appended"
grep -q 'Sub rule.' "$repo/sub/AGENTS.override.md" || fail "nested override missing"
test ! -e "$repo/shared/AGENTS.override.md" || fail "override written where AGENTS.md already matches"

if grep -rq 'circus' "$repo/.git/info/exclude" 2>/dev/null; then fail "build touched the repository's ignore rules"; fi
grep -q 'Claude hook rule.' "$repo/CLAUDE.md" || fail "source was modified"

"$circus_bin" project check "$repo" >/dev/null || fail "check reports drift right after build"

printf '\nNew rule.\n' >> "$repo/sub/CLAUDE.md"
if "$circus_bin" project check "$repo" >/dev/null 2>&1; then
  fail "check misses a changed source"
fi
"$circus_bin" project diff "$repo" | grep -q '^+New rule.' || fail "diff does not show the change"

rm -r "$repo/.claude/skills/portable"
printf 'edited by hand\n' >> "$repo/.agents/skills/handwritten/SKILL.md"
"$circus_bin" project build "$repo" >/dev/null
test ! -e "$repo/.agents/skills/portable" || fail "stale generated skill not removed"
grep -q 'edited by hand' "$repo/.agents/skills/handwritten/SKILL.md" || fail "handwritten skill removed or reset"
grep -q 'New rule.' "$repo/sub/AGENTS.override.md" || fail "rebuild did not pick up the change"
"$circus_bin" project check "$repo" >/dev/null || fail "check reports drift after rebuild"

printf 'handwritten now\n' > "$repo/sub/AGENTS.override.md"
"$circus_bin" project build "$repo" >/dev/null
grep -q 'handwritten now' "$repo/sub/AGENTS.override.md" || fail "override taken over by hand was removed or reset"

rm "$repo/AGENTS.override.md"
ln -s CLAUDE.md "$repo/AGENTS.override.md"
"$circus_bin" project build "$repo" >/dev/null
grep -q 'Claude hook rule.' "$repo/CLAUDE.md" || fail "build wrote through a symlink into the source"
test -L "$repo/AGENTS.override.md" || fail "symlinked override was replaced"
rm "$repo/AGENTS.override.md"

printf 'precious\n' > "$repo/.agents/skills/forced/extra.txt"
"$circus_bin" project build "$repo" >/dev/null
test ! -e "$repo/.agents/skills/forced/extra.txt" || fail "stray file in a generated skill survived"
rm "$repo/sub/CLAUDE.md" "$repo/sub/AGENTS.override.md"
printf '%s\n\nold\n' "<!-- GENERATED from sub/CLAUDE.md by 'circus project build'. Edit that original, never this file. -->" > "$repo/sub/AGENTS.override.md"
"$circus_bin" project build "$repo" >/dev/null
test ! -e "$repo/sub/AGENTS.override.md" || fail "generated override without an original survived"

mkdir -p "$repo/.claude/skills/quoted" "$repo/.claude/skills/blank"
cat > "$repo/.claude/skills/quoted/SKILL.md" <<'MD'
---
name: quoted
description: >- # folded
  It's a "quoted" one
  across lines.
metadata:
  short-description: Short one
---

Body.
MD
printf -- '---\nname: blank\ndescription:\n---\n\nBody.\n' > "$repo/.claude/skills/blank/SKILL.md"
out="$("$circus_bin" project build "$repo")"
ruby -ryaml -e 'd = YAML.safe_load(File.read(ARGV[0]).split(/^---\s*$/)[1]); abort "description: #{d["description"]}" unless d["description"] == %q(It'"'"'s a "quoted" one across lines.); abort "metadata: #{d["metadata"]}" unless d["metadata"] == {"short-description" => "Short one"}' "$repo/.agents/skills/quoted/SKILL.md" \
  || fail "block scalar with comment or metadata not carried over"
test ! -e "$repo/.agents/skills/blank" || fail "skill without a description was generated"
printf '%s\n' "$out" | grep -Eq 'skip +blank .*description' || fail "missing description not reported"

mkdir -p "$repo/.claude/skills/quoted/scripts" "$tmp/elsewhere"
printf 'helper\n' > "$repo/.claude/skills/quoted/scripts/run.sh"
printf 'precious\n' > "$tmp/elsewhere/run.sh"
ln -s "$tmp/elsewhere" "$repo/.agents/skills/quoted/scripts"
"$circus_bin" project build "$repo" >/dev/null
grep -q 'precious' "$tmp/elsewhere/run.sh" || fail "build wrote through a symlinked directory"
grep -q 'helper' "$repo/.agents/skills/quoted/scripts/run.sh" || fail "support file behind a symlinked directory not rebuilt"

printf '%s\n\nother tool\n' "<!-- GENERATED by another tool -->" > "$repo/sub/AGENTS.override.md"
printf '# Sub\n' > "$repo/sub/CLAUDE.md"
"$circus_bin" project build "$repo" >/dev/null
grep -q 'other tool' "$repo/sub/AGENTS.override.md" || fail "another generator's override was taken over"

printf 'ok: project build derives a local Codex stack from the Claude project source\n'
