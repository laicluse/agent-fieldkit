#!/bin/bash
# allow-comment: PreToolUse:Bash safety net that validates every commit body in the push range against validate_body (via the shared vb_validate_commit) and denies the push when one or more commits fall short. Layered with two earlier nets that share the same validator: PreToolUse commit-body blocks a malformed direct `git commit` before it lands, and PostToolUse commit-body catches a malformed body that any commit-graph writer (rebase, cherry-pick, -F, editor, amend) wrote without a direct `git commit` string. push-body-gate stays as the last gate before commits leave the machine, for the case where an earlier net was bypassed or never saw the commit.

guard_push_body_gate() {
  local input="$1"

  [[ "${GIT_DISCIPLINE_PUSH_BODY_GATE_DISABLED:-0}" = "1" ]] && return 0

  local command
  command=$(jq -r '.tool_input.command // empty' <<< "$input" 2>/dev/null)
  [[ -z "$command" ]] && return 0

  dd_is_git_push_command "$command" || return 0

  local DIR
  DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  source "$DIR/lib/wip-gate.sh"

  local range
  range=$(wip_gate_resolve_push_range "$command")

  [[ -z "$range" ]] && return 0

  local commits
  commits=$(git rev-list "$range" 2>/dev/null || true)
  [[ -z "$commits" ]] && return 0

  local me
  me=$(git config user.email 2>/dev/null || true)

  local violations=()
  local sha subject line short_sha
  while IFS= read -r sha; do
    [[ -z "$sha" ]] && continue

    # allow-comment: personal discipline only judges commits that are ours
    # allow-comment: (authored or rebase-co-authored); purely-carried teammate
    # allow-comment: commits swept in by a rebase are never demanded a body.
    wip_gate_commit_is_ours "$sha" "$me" || continue

    # allow-comment: vb_validate_commit is the shared per-commit body check
    # allow-comment: (validate-body.sh); push-body-gate, the PostToolUse net, and
    # allow-comment: the git-native pre-push hook all route through it so the
    # allow-comment: verdict can never drift between layers.
    if line=$(vb_validate_commit "$sha"); then
      continue
    fi
    subject=$(git log -1 --pretty=format:%s "$sha" 2>/dev/null || true)
    short_sha=$(git rev-parse --short "$sha" 2>/dev/null || printf '%s' "${sha:0:7}")
    violations+=("${short_sha} \"${subject}\": ${line}")
  done <<< "$commits"

  [[ ${#violations[@]} -eq 0 ]] && return 0

  local msg
  msg=$(printf 'Body schema misses in push range:\n')
  local v
  for v in "${violations[@]}"; do
    msg+=$(printf -- '\n  %s' "$v")
  done
  msg+=$(printf '\n\nAmend or interactive-rebase each commit to fix, then retry push. For commits whose bodies predate the discipline and were rewritten by a rebase, amend the trailer "Discipline: skip due to rebase" onto them instead of reworking the body; the gate treats those as already-shipped. Use /git-discipline:disable-discipline if you need to lift the discipline for this session.')

  dd_emit_deny "push-body-gate" "$msg"
}
