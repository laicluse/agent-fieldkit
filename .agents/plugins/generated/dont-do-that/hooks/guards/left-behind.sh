#!/bin/bash

guard_left_behind() {
  local input="$1"
  local text
  text=$(dd_assistant_text "$input" 3000 "left-behind")
  [ -z "$text" ] && return 0
  dd_is_wip "$text" && return 0
  grep -q "Bewust uitgesteld:" <<< "$text" && return 0

  local plain
  plain=$(dd_without_quoted_spans "$text")
  grep -qiE "(laat|liet|laten) (ik |we )?(dat |die |het |deze |ze )?liggen|heb ik (laten liggen|niet aangeraakt|niet aangepakt|niet opgelost)|niet in deze pr|buiten deze pr|valt buiten (deze|dit) (pr|werk)|not in this pr|out of scope for this|left (it|them|that) (alone|as is)" <<< "$plain" \
    || return 0

  dd_emit_block left-behind "You named a defect and left it. Fix it in this work, or find out what it is if it is unexplained. Only a gate you cannot pass yourself, such as a host change that needs a go, justifies leaving it; then start that sentence with 'Bewust uitgesteld:' and name the gate. What happens to parts that coding agents built is your judgement, not the operator's gate."
}
