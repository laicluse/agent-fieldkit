#!/bin/bash
# allow-comment: First-contact briefing guard. Mirrors commit-subject.sh wiring.

_DD_HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

guard_git_first_contact() {
  local input="$1"
  local command
  command=$(jq -r '.tool_input.command // empty' <<< "$input" 2>/dev/null)
  [ -z "$command" ] && return 0

  local git_write_re='(^|[^A-Za-z0-9_/.-])git[[:space:]]+(commit|add|push|rebase|branch|switch|tag|cherry-pick|reset|restore)([[:space:]]|$)'
  [[ "$command" =~ $git_write_re ]] || return 0

  local sid
  sid=$(dd_session_id "$input")
  [ -z "$sid" ] && return 0

  local sentinel="/tmp/.claude-git-discipline-briefed-${sid}"
  [ -f "$sentinel" ] && return 0
  touch "$sentinel" 2>/dev/null || return 0

  local skill_dir skill_path
  skill_dir=$(cd "$_DD_HERE/../../skills/commit-discipline" 2>/dev/null && pwd)
  skill_path="${skill_dir}/SKILL.md"
  if [ -f "$skill_path" ]; then
    [[ -n "$HOME" && "$skill_path" == "$HOME"/* ]] && skill_path="~${skill_path#$HOME}"
  else
    skill_path="(skill path unresolved; reinstall git-discipline@laicluse-agent-fieldkit)"
  fi

  local msg="First git write in this session. Required commit form: heredoc inside a double-quoted -m, trailers (Slice/Tests/Red-then-green/Verified, plus Visual when UI is touched) contiguous at the bottom of the heredoc, ack-rule comment trailing the closing )\". Hard schema misses BLOCK at PreToolUse so the commit object is never created; rewrite the body and rerun the same git commit call. Soft nudges (subject 51-72 chars) stay non-blocking. Every commit also fires one rotation-reminder deny; the deny carries the rule essence and the row to look up the password in. An amend that rewrites a just-acked commit (gate-mandated message fix) does NOT burn a fresh rotation slot. Closed enums to know up-front: Slice free-text must be at least 10 chars (or pick an opt-out token: docs-only, config-only, migration-only, spec-only, chore-deps, revert, merge, wip); Tests paths must end in .rb/.py/.js/.mjs/.cjs/.ts/.tsx/.jsx/.go/.sh/.bash/.bats/.feature/.swift; Verified n/a rationales must name a recognised category (no behaviour change, copy-only, byte-identical, render unchanged, extract-only, backend only, accessibility-only, debug-only, log-only, telemetry-only, full list in SKILL.md); Verified: red-then-green requires the Red-then-green trailer to be a positive attestation, not n/a. Full canonical shape, anti-patterns, opt-out tokens: ${skill_path} (section 'Quick reference for AI'). Cost: each -m \"...\" paragraph counts separately (don't put trailers in their own -m), -F path is denied, embedded newlines inside -m truncate the body, conjunctions in the subject are rejected."

  dd_emit_pre_context git-first-contact "$msg"
}
