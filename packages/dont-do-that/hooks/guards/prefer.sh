#!/bin/bash
# allow-comment: guard-doc. Stop guard nudging a reasoned, emoji-marked preference when an option menu is offered without one. Runs before premature/compliance so the menu is judged here, not swallowed by the generic stop guards.

_dd_prefer_option_table() {
  awk '
    /^[[:space:]]*\|[[:space:]]*:?-{2,}/ { if (prev ~ /optie|option|aanpak|approach|mechaniek|mechanism|variant/) found=1 }
    { prev=tolower($0) }
    END { exit(found?0:1) }
  ' <<< "$1"
}

_dd_prefer_rover_tip() {
  local plugin_json

  if command -v codex >/dev/null 2>&1; then
    plugin_json=$(codex plugin list --json 2>/dev/null) || plugin_json=""
    if [ -n "$plugin_json" ] && jq -e '.installed[]? | select(.pluginId == "rover@laicluse-agent-fieldkit")' >/dev/null 2>&1 <<< "$plugin_json"; then
      printf '%s\n' " /rover:decide is one way to settle a genuinely hard call."
      return 0
    fi
  fi

  if command -v claude >/dev/null 2>&1; then
    plugin_json=$(claude plugins list --json 2>/dev/null) || plugin_json=""
    if [ -n "$plugin_json" ] && jq -e '.plugins | keys[]? | select(startswith("rover@"))' >/dev/null 2>&1 <<< "$plugin_json"; then
      printf '%s\n' " /rover:decide is one way to settle a genuinely hard call."
      return 0
    fi
  fi

  return 0
}

_dd_prefer_defines() {
  MARKER="$1" perl -CSD -0777 -ne '
    my $m = $ENV{MARKER}; utf8::decode($m);
    my $found = 0;
    while (/\Q$m\E[ \t]*[*(]*[ \t]*(\p{L}+)/g) {
      $found = 1 unless lc($1) =~ /^(of|or|en|and|voor|for|kies|koos|pick|picked|choose|chose|als|as|is|blijft|stays)$/;
    }
    exit($found ? 0 : 1);
  ' <<< "$2"
}

guard_prefer() {
  local input="$1"
  local text
  text=$(dd_assistant_text "$input" 1500 "prefer")
  [ -z "$text" ] && return 0
  dd_is_wip "$text" && return 0

  local option_a_count option_b_count
  option_a_count=$(grep -oF '🅰️' <<< "$text" | wc -l | tr -d ' ')
  option_b_count=$(grep -oF '🅱️' <<< "$text" | wc -l | tr -d ' ')
  if [ "$option_a_count" -ge 1 ] && [ "$option_b_count" -ge 1 ]; then
    local whole
    whole=$(dd_assistant_text "$input" 100000 "prefer")
    if ! _dd_prefer_defines '🅰️' "$whole" || ! _dd_prefer_defines '🅱️' "$whole"; then
      dd_emit_block prefer "You pointed at a 🅰️/🅱️ decision without spelling it out in this message. An unanswered question means the operator never read it: they were away, or it scrolled out of view. Either present it whole here (what is being decided and why it matters, the evidence, 🅰️ and 🅱️ each described, your pick and why) or leave it out. A bare \"say 🅰️ or 🅱️\" or \"still open: 🅰️\" asks for a decision the reader cannot see."
    fi
    if [ "$option_a_count" -ge 2 ] || [ "$option_b_count" -ge 2 ]; then
      return 0
    fi
  fi
  grep -qE '^🧭' <<< "$text" && return 0

  local is_menu=0
  if [ "$(grep -oiE '\(([a-d])\)' <<< "$text" | sort -u | wc -l | tr -d ' ')" -ge 2 ]; then
    is_menu=1
  elif [ "$(grep -oiE '\b(optie|option) [0-9a-d]\b' <<< "$text" | sort -u | wc -l | tr -d ' ')" -ge 2 ]; then
    is_menu=1
  elif _dd_prefer_option_table "$text"; then
    is_menu=1
  elif [ "$(grep -cE '^[[:space:]]*[0-9]+[.)][[:space:]]' <<< "$text")" -ge 2 ]; then
    is_menu=1
  elif [ "$option_a_count" -ge 1 ] && [ "$option_b_count" -ge 1 ]; then
    is_menu=1
  fi
  [ "$is_menu" -eq 0 ] && return 0

  grep -qiE '\bwelke\b|\bwhich (do|would|one|of|approach|option|version|route|path)\b|wat (heeft|is) je voorkeur|geen voorkeur|wat verkies je|do you prefer|jouw keuze([^[:alpha:]]|$)|aan jou|your (call|choice|pick)|up to you' <<< "$text" || return 0
  dd_external_irreversible_gate "$text" && return 0

  local tip
  tip=$(_dd_prefer_rover_tip)

  dd_emit_block prefer "You laid out options but handed the choice back without committing. If the answer is knowable and your pick is reversible local work, label both alternatives with 🅰️ and 🅱️, then repeat the chosen marker while stating the preference you would back and why. One marker, or one of each without a stated pick, is not a committed comparison. If choosing would create or mutate external/account-bound state, do not decide it yourself: ask as a real gate and make the reversibility boundary explicit.${tip} A bare menu defers a decision you are equipped to make."
}
