#!/bin/bash
# packages/git-discipline/hooks/guards/git-dash-c.sh
# PreToolUse:Bash guard. Blocks `git -C <dir> ...` invocations because Claude
# Code's prefix-based permission matching trips on them. Absorbed 1-to-1 from
# ~/.claude/hooks/block-git-dash-c.sh; behaviour unchanged.
#
# The guard fires only when the command starts with `git -C `. Lowercase `-c`
# (config override) is unaffected, and a `-C` later in the command line (for
# example as a value to another flag) is also left alone, matching the
# original script's regex anchor.

guard_git_dash_c() {
  local input="$1"
  local command
  command=$(jq -r '.tool_input.command // empty' <<< "$input" 2>/dev/null)
  [[ -z "$command" ]] && return 0

  if [[ "$command" =~ ^git[[:space:]]+-C[[:space:]] ]]; then
    local target_dir
    target_dir=$(echo "$command" | sed -E 's/^git[[:space:]]+-C[[:space:]]+("[^"]+"|[^ ]+).*/\1/' | tr -d '"')
    target_dir="${target_dir/#$HOME/\~}"
    dd_emit_deny "git-dash-c" "git -C is annoying due to Claude Code's prefix-based permission matching. Use 'cd ${target_dir}' first, then run the git command directly."
  fi
}
