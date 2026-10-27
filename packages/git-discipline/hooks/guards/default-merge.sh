#!/bin/bash
# allow-comment: PreToolUse:Bash guard. Refuses `git merge <default>` while a
# allow-comment: feature branch is checked out, also a colleague's published PR
# allow-comment: branch: it catches up by rebasing (rebase-latest-default), not
# allow-comment: through a merge commit. Without origin/HEAD or a local
# allow-comment: init.defaultBranch the guard stays silent rather than guess.
# allow-comment: Escape for a deliberate merge commit: `# allow-default-merge`.

_dm_default_branch() {
  local sym
  sym=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)
  if [[ -n "$sym" ]]; then
    printf '%s' "${sym#origin/}"
    return 0
  fi
  local configured
  configured=$(git config --local --get init.defaultBranch 2>/dev/null || true)
  [[ -n "$configured" ]] || return 1
  printf '%s' "$configured"
}

_dm_merge_arguments() {
  local command="$1"
  local pre='(^|[[:space:];&|(])'
  local opts='((-[^[:space:]]+)([[:space:]]+[^-][^[:space:]]*)?[[:space:]]+)*'
  [[ "$command" =~ ${pre}git[[:space:]]+${opts}merge([[:space:]]+([^;&|]*))?([;&|]|$) ]] || return 1
  printf '%s' "${BASH_REMATCH[6]}"
}

guard_default_merge() {
  local input="$1"
  local command
  command=$(jq -r '.tool_input.command // empty' <<< "$input" 2>/dev/null)
  [[ -z "$command" ]] && return 0
  [[ "$command" == *"# allow-default-merge"* ]] && return 0

  local args
  args=$(_dm_merge_arguments "$command") || return 0

  local default current
  default=$(_dm_default_branch) || return 0
  current=$(git symbolic-ref --quiet --short HEAD 2>/dev/null) || return 0
  [[ "$current" == "$default" ]] && return 0

  local token
  for token in $args; do
    case "$token" in
      --continue|--abort|--quit) return 0 ;;
      "$default"|"origin/$default"|"refs/heads/$default"|"refs/remotes/origin/$default")
        dd_emit_deny "default-merge" "'${current}' catches up with '${default}' by rebasing, not by merging '${token}' into it. Follow the rebase-latest-default skill: git-discipline rebase --remote, resolve conflicts per commit, verify, then git push --force-with-lease=${current}:<old-remote-sha> for a published branch. A deliberately wanted merge commit takes '# allow-default-merge' at the end of the command."
        ;;
    esac
  done
  return 0
}
