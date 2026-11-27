#!/bin/bash
# PreToolUse:Bash guard that blocks forge-side remote creation (gh repo create, gh repo fork). allow-comment: hook-header documenting the matchers and the operator escape, same pattern as sibling no-remote.sh and no-worktree-deploy.sh in this directory. Creating account-bound forge state carries permission, billing, visibility and team implications; changing a checkout's local remote configuration does not and is intentionally outside this guard.

DD_NRC_NEGATION="\\b(niet|geen|never|not|don['’]t|do not)\\b"

dd_nrc_last_user_text() {
  local input="$1" direct tr messages
  direct=$(jq -r '.last_user_message // .user_message // empty' <<< "$input" 2>/dev/null)
  if [ -n "$direct" ]; then
    messages=$(jq -cn --arg text "$direct" '[$text]')
  else
    tr=$(dd_transcript "$input") || return 1
    [ -f "$tr" ] || return 1
    messages=$(jq -n '
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
reduce inputs as $event ([]; (. + [
$event
| select(.isMeta != true)
| select(.type == "user" or .role == "user" or .message.role == "user" or (.payload.type == "message" and .payload.role == "user"))
| select(((.payload.content? // .message.content? // .content?) | type) != "array"
    or (((.payload.content? // .message.content? // .content?) | map(.type? // "")) | index("tool_result") | not))
| (.payload.content? // .message.content? // .content? // .text? // empty | textify)
| select(length > 0)
| select((test("^(# AGENTS\\.md instructions for |<environment_context>|<INSTRUCTIONS>)")) | not)
| select((test("^[[:space:]]*<(hc from=|codex_internal_context|goal_context|hook_prompt|skill>|subagent_notification|user_action|user_shell_command)")) | not)
]) | .[-3:])
' "$tr" 2>/dev/null) || return 1
  fi
  jq -r --arg negative "$DD_NRC_NEGATION" '
def approval_text:
  if test("Herdr (Tijdlijn|Timeline)|herdr-timeline receive"; "i") then
    try (
      ([capture("^[[:space:]:\u0027]*Herdr Tijdlijn · (?<card>\\{.*\\}) · Lees de actuele kaart met herdr-timeline receive ")] | first // error("Invalid timeline reply")).card
      | fromjson
      | if (.antwoord | type) != "string" or (.vraag | type) != "string" then
          "geen repo toestemming"
        elif (.antwoord | test($negative; "i")) or (.antwoord | test("\\b(nee|no|nope|stop|nooit|niks|niets|wacht|later|annuleer|cancel)\\b"; "i")) then
          "geen repo toestemming"
        elif ([.vraag, (.opties // [] | .[])] | join(" ") | test("\\b(repo(s)?|repository|repositories|fork(s|en)?|remote(s)?|github|gitlab|forge)\\b"; "i")) then
          if ((.antwoord | test("^[[:space:]]*(yes|yep|ja|akkoord|goedgekeurd|approved|go ahead|do it|doe maar|go)[[:space:].!]*$"; "i"))
            and ((.vraag | test($negative; "i")) | not)
            and (.vraag | test("\\b(aanmaken|maken|create|creation|fork|forken)\\b[^,;.]{0,60}\\b(repo(s)?|repository|repositories|github|gitlab)\\b|\\b(repo(s)?|repository|repositories|github|gitlab)\\b[^,;.]{0,60}\\b(aanmaken|maken|create|creation|fork|forken)\\b"; "i")))
            or (.antwoord | test("^[[:space:]]*(maak|create|fork|make)\\b[^,;.]{0,40}\\b(repo(s)?|repository|repositories|fork(s|en)?|remote(s)?|github|gitlab)\\b"; "i")) then
            "create repository approved"
          else "geen repo toestemming" end
        else "" end
    ) catch "geen repo toestemming"
  else . end;
reduce .[] as $message ([]; ($message | approval_text) as $text |
  if $text == "create repository approved" or $text == "geen repo toestemming" then [$text]
  elif $text == "" then . else . + [$text] end) | join("\n")
' <<< "$messages" \
    | tail -c 1000
}

dd_nrc_operator_approved() {
  local input="$1" kind="$2" user
  user=$(dd_nrc_last_user_text "$input") || return 1
  [ -n "$user" ] || return 1

  if grep -qiE "${DD_NRC_NEGATION}.{0,80}\\b(gh[[:space:]]+repo|repo|fork|remote)\\b" <<< "$user"; then
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
