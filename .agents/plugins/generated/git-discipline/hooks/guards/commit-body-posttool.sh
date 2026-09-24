#!/bin/bash
# allow-comment: Two halves of the commit-graph-writer body net. PreToolUse calls
# allow-comment: commit_body_snapshot_head to record HEAD before any command that
# allow-comment: can write commits (commit/rebase/cherry-pick/revert/merge/am).
# allow-comment: PostToolUse calls guard_commit_body_posttool, which validates the
# allow-comment: bodies of the commits that command actually wrote (snapshot..HEAD)
# allow-comment: and blocks via exit 2 when one falls short. This closes the gap
# allow-comment: that the PreToolUse commit-body guard cannot reach: it only parses
# allow-comment: a direct `git commit -m`/heredoc string, so a body written by a
# allow-comment: rebase, cherry-pick, merge --continue, or a message-reusing
# allow-comment: --amend was never validated until push, and a remote-less repo
# allow-comment: never pushes.

# allow-comment: per-session, per-toplevel snapshot path so two repos and two
# allow-comment: concurrent sessions never share or race a before-ref.
_cbp_snapshot_file() {
  local input="$1"
  local sid toplevel toplevel_hash sid_key
  sid=$(dd_session_id "$input")
  toplevel=$(git rev-parse --show-toplevel 2>/dev/null || printf 'no-toplevel')
  toplevel_hash=$(printf '%s' "$toplevel" | cksum | tr -d ' ' | cut -c1-8)
  sid_key=$(printf '%s' "${sid:-no-session}" | cksum | tr -d ' ' | cut -c1-8)
  printf '%s/git-discipline/git-discipline-commit-snapshot-%s-%s' \
    "${LAICLUSE_HOME:-$HOME/.laicluse}" "$toplevel_hash" "$sid_key"
}

commit_body_snapshot_head() {
  local input="$1"
  local command
  command=$(jq -r '.tool_input.command // empty' <<< "$input" 2>/dev/null)
  [[ -z "$command" ]] && return 0
  dd_is_commit_graph_writer "$command" || return 0

  local snap_file head
  snap_file=$(_cbp_snapshot_file "$input")
  mkdir -p "$(dirname "$snap_file")" 2>/dev/null || true
  head=$(git rev-parse --verify --quiet HEAD 2>/dev/null || printf 'NONE')
  printf '%s' "$head" > "$snap_file" 2>/dev/null || true
  return 0
}

# allow-comment: resolve the from-ref for the snapshot..HEAD range. Snapshot is
# allow-comment: the primary source; HEAD@{1} is the fallback when the snapshot
# allow-comment: is missing (older install, state miss); empty means validate the
# allow-comment: tip alone (first commit in a fresh repo). The snapshot file is
# allow-comment: consumed (removed) on read so a stale before-ref never bleeds
# allow-comment: into a later unrelated command.
_cbp_resolve_from() {
  local input="$1"
  local snap_file snap
  snap_file=$(_cbp_snapshot_file "$input")
  if [[ -f "$snap_file" ]]; then
    snap=$(cat "$snap_file" 2>/dev/null || true)
    rm -f "$snap_file" 2>/dev/null || true
    if [[ -n "$snap" && "$snap" != "NONE" ]] \
       && git cat-file -e "${snap}^{commit}" 2>/dev/null; then
      printf '%s' "$snap"
      return 0
    fi
    if [[ "$snap" = "NONE" ]]; then
      return 0
    fi
  fi
  if git rev-parse --verify --quiet 'HEAD@{1}' >/dev/null 2>&1; then
    printf 'HEAD@{1}'
    return 0
  fi
  return 0
}

guard_commit_body_posttool() {
  local input="$1"
  local command
  command=$(jq -r '.tool_input.command // empty' <<< "$input" 2>/dev/null)
  [[ -z "$command" ]] && return 0
  dd_is_commit_graph_writer "$command" || return 0

  local head
  head=$(git rev-parse --verify --quiet HEAD 2>/dev/null || true)
  [[ -z "$head" ]] && return 0

  local from commits
  from=$(_cbp_resolve_from "$input")
  if [[ -n "$from" ]]; then
    local from_sha
    from_sha=$(git rev-parse --verify --quiet "$from" 2>/dev/null || true)
    [[ "$from_sha" = "$head" ]] && return 0
    commits=$(git rev-list "${from}..HEAD" 2>/dev/null || true)
  else
    commits="$head"
  fi
  [[ -z "$commits" ]] && return 0

  local me
  me=$(git config user.email 2>/dev/null || true)

  local violations=() sha subject line short_sha
  while IFS= read -r sha; do
    [[ -z "$sha" ]] && continue
    # allow-comment: a rebase onto an advanced default branch sweeps teammate
    # allow-comment: commits into snapshot..HEAD; the ours filter keeps the net on
    # allow-comment: the commits this session actually wrote, matching push-body-
    # allow-comment: gate. In a remote-less personal repo every commit is ours.
    wip_gate_commit_is_ours "$sha" "$me" || continue
    if line=$(vb_validate_commit "$sha"); then
      continue
    fi
    subject=$(git log -1 --pretty=format:%s "$sha" 2>/dev/null || true)
    short_sha=$(git rev-parse --short "$sha" 2>/dev/null || printf '%s' "${sha:0:7}")
    violations+=("${short_sha} \"${subject}\": ${line}")
  done <<< "$commits"

  [[ ${#violations[@]} -eq 0 ]] && return 0

  local msg
  msg=$(printf 'Body schema misses in commits this command just wrote:\n')
  local v
  for v in "${violations[@]}"; do
    msg+=$(printf -- '\n  %s' "$v")
  done
  msg+=$(printf '\n\nThe commit object already exists, so fix it in place: `git commit --amend` for the tip, or a message-only rebase for an earlier commit (git rebase <base> --exec to amend each), then continue. Opt-out tokens for Slice: docs-only, config-only, migration-only, spec-only, chore-deps, revert, merge, wip. Use /git-discipline:disable-discipline to lift the discipline for this session.')

  dd_emit_deny "commit-body" "$msg"
}
