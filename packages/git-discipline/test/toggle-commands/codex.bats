#!/usr/bin/env bats

load helpers

submit() {
  local payload
  payload=$(jq -cn --arg p "$1" --arg cwd "$PWD" '{hook_event_name:"UserPromptSubmit",prompt:$p,cwd:$cwd,session_id:"test-session"}')
  run bash "$DISPATCH" <<< "$payload"
}

@test "Codex explicit repo toggles use the prompt working directory" {
  submit '$git-discipline:disable-git maintenance window'
  [ "$status" -eq 2 ]
  [ -f "$(repo_sentinel)" ]
  grep -qx 'reason: maintenance window' "$(repo_sentinel)"
  submit '$git-discipline:enable-git'
  [ "$status" -eq 2 ]
  [ ! -f "$(repo_sentinel)" ]
}

@test "Codex explicit discipline toggles affect only the submitted session" {
  submit '$git-discipline:disable-discipline'
  [ "$status" -eq 2 ]
  [ -f "$(session_sentinel)" ]
  submit '$git-discipline:enable-discipline'
  [ "$status" -eq 2 ]
  [ ! -f "$(session_sentinel)" ]
}

@test "Codex toggle mentions and extra instructions never change state" {
  for prompt in 'Doe $git-discipline:disable-git maintenance' '`$git-discipline:disable-git maintenance`' '$git-discipline:enable-git extra' '$git-discipline:disable-discipline extra' '$git-discipline:disable-git maintenance
then do something else'; do
    submit "$prompt"
    [ "$status" -eq 0 ]
    [ ! -f "$(repo_sentinel)" ]
    [ ! -f "$(session_sentinel)" ]
  done
}

@test "Codex disable-git requires a reason" {
  submit '$git-discipline:disable-git'
  [ "$status" -eq 2 ]
  [ ! -f "$(repo_sentinel)" ]
}

@test "Codex slash form also reaches the operator toggle" {
  submit '/git-discipline:disable-git maintenance'
  [ "$status" -eq 2 ]
  [ -f "$(repo_sentinel)" ]
}

@test "Codex resolves a submitted repo independently of the hook process cwd" {
  local payload
  payload=$(jq -cn --arg cwd "$PWD" '{hook_event_name:"UserPromptSubmit",prompt:"$git-discipline:disable-git maintenance",cwd:$cwd,session_id:"test-session"}')
  mkdir other
  cd other
  run bash "$DISPATCH" <<< "$payload"
  [ "$status" -eq 2 ]
  [ -f "$(repo_sentinel)" ]
}

@test "invalid enable prompts leave existing repo and session locks intact" {
  run_expansion "git-discipline:disable-git" "maintenance"
  run_expansion "git-discipline:disable-discipline"
  for prompt in '$git-discipline:enable-git extra' 'Please $git-discipline:enable-git' '$git-discipline:enable-git
' '$git-discipline:enable-discipline extra'; do
    submit "$prompt"
    [ "$status" -eq 0 ]
    [ -f "$(repo_sentinel)" ]
    [ -f "$(session_sentinel)" ]
  done
}

@test "Codex ignores toggle payloads without a valid working directory or session" {
  local payload
  for payload in \
    '{"hook_event_name":"UserPromptSubmit","prompt":"$git-discipline:disable-git maintenance","session_id":"test-session"}' \
    '{"hook_event_name":"UserPromptSubmit","prompt":"$git-discipline:disable-discipline","cwd":"/","session_id":"../../other"}'; do
    run bash "$DISPATCH" <<< "$payload"
    [ "$status" -eq 0 ]
    [ ! -f "$(repo_sentinel)" ]
    [ ! -f "$(session_sentinel)" ]
  done
}

@test "Codex session enable leaves another session disabled" {
  run_expansion "git-discipline:disable-discipline" "" "other-session"
  submit '$git-discipline:disable-discipline'
  submit '$git-discipline:enable-discipline'
  [ "$status" -eq 2 ]
  [ ! -f "$(session_sentinel)" ]
  [ -f "$(session_sentinel other-session)" ]
}

@test "Codex whitespace-only lock reasons never create a lock" {
  submit '$git-discipline:disable-git   '
  [ "$status" -eq 2 ]
  [ ! -f "$(repo_sentinel)" ]
}
