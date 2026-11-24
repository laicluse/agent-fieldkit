#!/bin/bash

dd_defers_to_third_party_decision() {
  perl -0ne '
    my $found = 0;
    for my $paragraph (split /\n\s*\n/) {
      next unless $paragraph =~ /Bewust uitgesteld:(.*)/s;
      my $reason = $1;
      $found = 1 if $reason =~ /\b(besluit|beslissing|keuze|oordeel)\s+(is|ligt|blijft|hoort)\s+(van|aan|bij)\s+(?!(jou|jullie|u|mij|de operator)\b)/i;
      $found = 1 if $reason =~ /(?<!\bje )(?<!\bjij )(?<!\bu )(?<!\bik )(?<!\boperator )\bmoet\s+(?!(je|jij|u|ik|we|de operator)\b)[^.]{0,60}\b(beslissen|besluiten|kiezen)\b/i;
      $found = 1 if $reason =~ /\bwacht(en)?\s+op\s+(het|een|de)\s+(besluit|beslissing|keuze|oordeel)\s+van\s+(?!(jou|jullie|u|mij|de operator)\b)/i;
      $found = 1 if $reason =~ /\b(decision|call|choice)\s+(is|belongs|lies|rests)\s+(with|to)\s+(?!(you|the operator)\b)/i;
      $found = 1 if $reason =~ /\bis\s+(?!your\b)[a-z]+\x27s\s+(decision|call|choice)\b/i;
    }
    exit($found ? 0 : 1);
  ' <<< "$1"
}

guard_left_behind() {
  local input="$1"
  local text
  text=$(dd_assistant_text "$input" 3000 "left-behind")
  [ -z "$text" ] && return 0
  dd_is_wip "$text" && return 0

  local plain
  plain=$(dd_without_quoted_spans "$text")

  if grep -q "Bewust uitgesteld:" <<< "$plain"; then
    dd_defers_to_third_party_decision "$plain" || return 0
    dd_emit_block left-behind "A decision that belongs to someone else is not a gate. First look up what was already decided (commits, decision records, the running product). Then put what remains to the operator in this answer: what the choice is, your recommendation and what each option changes in practice. The operator is the person to discuss it with and carries it further."
  fi

  grep -qiE "(laat|liet|laten) (ik |we )?(dat |die |het |deze |ze )?liggen|heb ik (laten liggen|niet aangeraakt|niet aangepakt|niet opgelost)|niet in deze pr|buiten deze pr|valt buiten (deze|dit) (pr|werk)|not in this pr|out of scope for this|left (it|them|that) (alone|as is)" <<< "$plain" \
    || return 0

  dd_emit_block left-behind "You named a defect and left it. Fix it in this work, or find out what it is if it is unexplained. Only a gate you cannot pass yourself, such as a host change that needs a go, justifies leaving it; then start that sentence with 'Bewust uitgesteld:' and name the gate. A decision that belongs to someone else is not such a gate: put it to the operator with your recommendation. What happens to parts that coding agents built is your judgement, not the operator's gate."
}
