#!/bin/bash
# allow-comment: The enable/disable sentinel files are operator territory; an
# allow-comment: agent must not flip the discipline in either direction. This
# allow-comment: guard runs with the safety locks, before the early sentinel
# allow-comment: exit in dispatch.sh, so it also fires while discipline is off.

guard_sentinel_protect() {
  local input="$1"
  local command
  command=$(jq -r '.tool_input.command // empty' <<< "$input" 2>/dev/null)
  [[ -z "$command" ]] && return 0

  if [[ "$command" != *git-discipline-disabled* ]] && [[ "$command" != *git-discipline-deny* ]]; then
    return 0
  fi

  local mutating=0
  if [[ "$command" =~ (^|[^[:alnum:]_./-])(rm|touch|mv|cp|tee|ln|unlink|truncate|shred|install)([^[:alnum:]_./-]|$) ]]; then
    mutating=1
  fi
  if [[ "$command" =~ \>[[:space:]]*[^[:space:]]*git-discipline-(disabled|deny) ]]; then
    mutating=1
  fi
  [[ "$mutating" -eq 1 ]] || return 0

  dd_emit_deny "sentinel-protect" \
"Creating or removing a git-discipline sentinel (git-discipline-disabled-* or .git/git-discipline-deny) toggles the git discipline or the per-repo git lock, and that switch is operator territory in BOTH directions. Turning the guards off to get past a deny is bypassing review; turning them back on undoes a state the operator chose deliberately. There is no magic-comment or env-var escape for this guard.

If the operator asked for the toggle, hand them the exact command to run themselves (via the '! ' prefix in the prompt, or their own terminal). If nobody asked, leave the sentinel alone and work within the current state. Inspecting the sentinel (ls, [ -f ... ]) is fine and not blocked."
}
