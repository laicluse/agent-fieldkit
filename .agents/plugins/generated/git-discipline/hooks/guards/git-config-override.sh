#!/bin/bash

guard_git_config_override() {
  local input="$1"
  local command
  command=$(jq -r '.tool_input.command // empty' <<< "$input" 2>/dev/null)
  [[ -z "$command" ]] && return 0

  [[ "$command" =~ (^|[[:space:]]|;|\&\&|\|\|)git[[:space:]] ]] || return 0

  if [[ "$command" =~ -c[[:space:]]+user\.(email|name)= ]] || \
     [[ "$command" =~ --config[[:space:]]+user\.(email|name)= ]]; then
    dd_emit_deny "git-config-override" \
"Passing -c user.email=... or -c user.name=... (or the --config equivalents) overrides the operator's canonical git identity with whatever value Claude just typed. The global gitconfig already has the right author and committer; running 'git commit' without overrides uses it. If you saw an email in the Claude environment context (e.g. 'The user's email address is X'), that is the operator's Anthropic account email, NOT their git identity, and using it here corrupts commit attribution on every commit.

Run the command again without the override. If the gitconfig is actually unset and you need an identity, that is a prelaunch question the operator must answer, not a value to invent from env."
  fi
}
