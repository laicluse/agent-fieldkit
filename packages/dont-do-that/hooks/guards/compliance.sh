#!/bin/bash
# Stop guard, back-stop only. Catches two failure modes that end on '?':
# (a) reflex-terugkaatsing where the active agent asks the user something it could
# just decide and continue, and (b) truncated generation that happened to
# stop mid-sentence on a question mark. Not a whip. Steady pacing is the
# point: when the question is reflex, answer it yourself and carry on at
# normal pace; when it is a genuine user-choice, mark with 🧭 prefix so
# the back-stop stands aside; when the work is actually done, end with
# 🏁 + sentence.

guard_compliance() {
  local input="$1"
  local text
  text=$(dd_assistant_text "$input" 500 "compliance-reflex")
  [ -z "$text" ] && return 0
  dd_is_wip "$text" && return 0

  grep -qE "^🧭" <<< "$text" && return 0
  grep -qE "🏁" <<< "$text" && return 0

  if tail -c 400 <<< "$text" \
       | grep -qiE "als (een )?side[ -]?quest|als (een )?follow[ -]?up|in een (aparte|volgende|latere|nieuwe) pr|aparte pr|separate pr|later oppakken|voor later|pak ik later|de rest (komt|volgt|later)|rest als (een )?(side|follow)"; then
    dd_emit_block compliance "Declarative deferral of in-scope work. Parking the rest as a side quest / follow-up / separate PR is the compliance reflex dressed as a decision: the operator asked for the best solution, not the cheapest slice. Do the whole thing now, or mark it deliberately: 🧭 (genuine two-outcome choice the operator must make) / 🏁 (done). A scope rule is not cover for doing less than was asked."
    return 0
  fi

  grep -qiE "(wil je dat ik|zal ik|moet ik|shall i|should i|want me to|do you want me to|wilt u dat ik|wat heeft? je voorkeur|what do you prefer|nog (updaten|aanpassen|fixen|doen|starten|draaien)).*\?\s*$" <<< "$text" \
    || return 0

  # Genuine-question hatch: words that signal a real disambiguation question.
  tail -c 200 <<< "$text" \
    | grep -qiE "(bedoel je|do you mean|of (wil je|wilt u)|or (do you|would you)|is dit beter|is this better|welke (van|optie)|which (of|option)|[0-9]+ (issues|bestanden|items|punten|commits|stappen))" \
    && return 0

  dd_external_irreversible_gate "$text" && return 0

  dd_emit_block compliance "'?' ending: double-check, not a whip. First ask what the operator actually requested. If they asked about existing state (does X say Y, is this covered, klopt dit, a review or audit), the answer IS the deliverable: give it and mark 🏁. An action you thought of while answering is yours, not theirs, and executing it converts their question into an assignment they never gave. If the action WAS the request and it is knowable, reversible, local work, do it yourself and continue. If it would create or mutate external/account-bound state (remote repo/fork/remote, push, deploy, publish, production, DNS, shared infra), ask as a real gate instead. Mark deliberately: 🧭 (genuine user-choice), 🚦 (waiting on external go), or 🏁 (done)."
}
