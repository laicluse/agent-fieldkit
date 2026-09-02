#!/bin/bash
# PreToolUse:Bash guard that blocks forge-side remote creation (gh repo create, gh repo fork). allow-comment: hook-header documenting the matchers and the operator escape, same pattern as sibling no-remote.sh and no-worktree-deploy.sh in this directory. Creating account-bound forge state carries permission, billing, visibility and team implications; changing a checkout's local remote configuration does not and is intentionally outside this guard.

dd_nrc_last_user_text() {
  local input="$1" direct tr
  direct=$(jq -r '.last_user_message // .user_message // empty' <<< "$input" 2>/dev/null)
  if [ -n "$direct" ]; then
    printf '%s\n' "$direct" | tail -c 1000
    return 0
  fi

  tr=$(dd_transcript "$input") || return 1
  [ -f "$tr" ] || return 1
  tail -200 "$tr" \
    | jq -s -r '
def textify:
if . == null then ""
elif type == "string" then .
elif type == "array" then
map(
if type == "string" then .
elif type == "object" then (.text? // (.content? | textify) // "")
else "" end
) | join("\n")
elif type == "object" then (.text? // (.content? | textify) // "")
else "" end;
[
.[]
| select(.type == "user" or .role == "user" or .message.role == "user" or (.payload.type == "message" and .payload.role == "user"))
| select(((.payload.content? // .message.content? // .content?) | type) != "array"
    or (((.payload.content? // .message.content? // .content?) | map(.type? // "")) | index("tool_result") | not))
| (.payload.content? // .message.content? // .content? // .text? // empty | textify)
| select(length > 0)
] | .[-3:] | join("\n")
' 2>/dev/null \
    | tail -c 1000
}

dd_nrc_operator_approved() {
  local input="$1" kind="$2" user
  user=$(dd_nrc_last_user_text "$input") || return 1
  [ -n "$user" ] || return 1

  if grep -qiE '\b(niet|geen|never|not|don'\''t|do not)\b.{0,80}\b(gh[[:space:]]+repo|repo|fork|remote)\b' <<< "$user"; then
    return 1
  fi

  grep -qiE '\b(yes|yep|go ahead|do it|run it|execute|approved|approve|allow|please|can you|could you|make|create|fork|add|set|ja|doe maar|voer.{0,30}uit|uitvoeren|maak|aanmaken|voeg.{0,30}toe|zet|mag|toestemming|akkoord|goedgekeurd|graag|kan je|kun je|wil.{0,30}graag|overrul)\b' <<< "$user" || return 1

  [ "$kind" = forge ] || return 1
  grep -qiE '\b(remotes?|repos?|repository|repositories|fork(s|en)?|github)\b' <<< "$user"
}

guard_no_remote_create() {
  local input="$1"
  local cmd
  cmd=$(jq -r '.tool_input.command // empty' <<< "$input" 2>/dev/null)
  [ -z "$cmd" ] && return 0

  if grep -Eq '(^|&&|;|\|\||[[:space:]])[[:space:]]*gh[[:space:]]+repo[[:space:]]+(create|fork)([[:space:]]|$)' <<< "$cmd"; then
    dd_nrc_operator_approved "$input" forge && return 0
    dd_emit_deny no-remote-create "remote creation blocked: 'gh repo create' / 'gh repo fork' creates account-bound forge state. Deleting it later is not true reversibility once the name, visibility, audit events, or notifications may have existed on the internet. Ask the operator for explicit approval in the current turn, or have them create the repo in the browser and tell you the URL."
  fi
}
