#!/bin/bash

guard_repair_gate() {
  local input="$1"
  local text
  text=$(dd_assistant_text "$input" 3000)
  [ -z "$text" ] && return 0
  grep -q '🚦' <<< "$text" || return 0

  local gate
  gate=$(dd_without_quoted_spans "$text" | awk '/🚦/ { found = 1 } found { print; if (++lines == 2) exit }')
  grep -qiE '\b(herstel(len)?|repareer|repareren|fixen|oplossen|corrigeer|corrigeren|repair|fix)\b' <<< "$gate" || return 0
  grep -qiE '\b(go|toestemming|akkoord|permission|approval|mag ik|zal ik|wil je dat ik|may i|shall i|should i)\b' <<< "$gate" || return 0
  dd_external_irreversible_gate "$gate" && return 0
  grep -qiE '\b(push(en)?|merge(n)?|deploy(en)?|publiceer|publiceren|publish|release|toestemming voor (kosten|modelgebruik)|model (use|spend)|betal|kosten|budget|review door|peer review)\b' <<< "$gate" && return 0

  dd_emit_block repair-gate "This 🚦 asks for a go to repair something. A repair inside the assignment needs no go: verify it and carry it out. Keep 🚦 for a choice that belongs to the operator or for a gate the rules name, such as push, merge, spending or an external action."
}
