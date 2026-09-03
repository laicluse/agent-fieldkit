#!/bin/bash
# Smoke test suite for the dont-do-that dispatcher. Every case routes
# through hooks/dispatch.sh with an explicit hook_event_name, so the test
# covers the real runtime path.
# Run from the plugin root: bash test/smoke-test.sh
# Exit code 0 = all pass, 1 = failures.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DISPATCH="${SCRIPT_DIR}/../hooks/dispatch.sh"
VALIDATE="${SCRIPT_DIR}/../bin/validate-registry"
PASS=0
FAIL=0

# allow-comment: the registry drives the dispatcher, so a broken guards.json invalidates every case below; validate it first as a hard precondition of the suite.
if bash "$VALIDATE" >/dev/null 2>&1; then
  PASS=$((PASS + 1))
else
  echo "FAIL [registry invalid]: bin/validate-registry exited non-zero"
  bash "$VALIDATE" 2>&1 | sed 's/^/  /'
  FAIL=$((FAIL + 1))
fi

stop_payload() {
  local text="$1" active="${2:-false}"
  jq -cn --arg t "$text" --argjson a "$active" \
    '{hook_event_name:"Stop", last_assistant_message:$t, stop_hook_active:$a}'
}

pretool_bash() {
  local cmd="$1"
  jq -cn --arg c "$cmd" \
    '{hook_event_name:"PreToolUse", tool_name:"Bash", tool_input:{command:$c}}'
}

pretool_bash_with_users() {
  local cmd="$1" first="$2" second="$3" transcript_file
  transcript_file=$(mktemp)
  {
    jq -cn --arg t "$first" '{type:"user",message:{content:[{type:"text",text:$t}]}}'
    jq -cn '{type:"assistant",message:{content:[{type:"text",text:"tussenstap"}]}}'
    jq -cn --arg t "$second" '{type:"user",message:{content:[{type:"text",text:$t}]}}'
  } > "$transcript_file"
  jq -cn --arg c "$cmd" --arg tr "$transcript_file" \
    '{hook_event_name:"PreToolUse", tool_name:"Bash", transcript_path:$tr, tool_input:{command:$c}}'
}

pretool_bash_with_user() {
  local cmd="$1" user_text="$2" transcript_file
  transcript_file=$(mktemp)
  jq -cn --arg t "$user_text" \
    '{type:"user",message:{content:[{type:"text",text:$t}]}}' \
    > "$transcript_file"
  jq -cn --arg c "$cmd" --arg tr "$transcript_file" \
    '{hook_event_name:"PreToolUse", tool_name:"Bash", transcript_path:$tr, tool_input:{command:$c}}'
}

pretool_bash_with_codex_user() {
  local cmd="$1" user_text="$2" transcript_file
  transcript_file=$(mktemp)
  jq -cn --arg t "$user_text" \
    '{type:"response_item",payload:{type:"message",role:"user",content:[{type:"input_text",text:$t}]}}' \
    > "$transcript_file"
  jq -cn --arg c "$cmd" --arg tr "$transcript_file" \
    '{hook_event_name:"PreToolUse", tool_name:"Bash", transcript_path:$tr, tool_input:{command:$c}}'
}

posttool_edit() {
  local file="$1" content="$2"
  jq -cn --arg f "$file" --arg c "$content" \
    '{hook_event_name:"PostToolUse", tool_name:"Edit", tool_input:{file_path:$f, new_string:$c}}'
}

posttool_apply_patch() {
  local patch="$1"
  jq -cn --arg p "$patch" \
    '{hook_event_name:"PostToolUse", tool_name:"apply_patch", tool_input:{patch:$p}}'
}

posttool_bash() {
  local cmd="$1"
  jq -cn --arg c "$cmd" \
    '{hook_event_name:"PostToolUse", tool_name:"Bash", tool_input:{command:$c}}'
}

pretool_edit() {
  local file="$1" old="$2" new="$3"
  jq -cn --arg f "$file" --arg o "$old" --arg n "$new" \
    '{hook_event_name:"PreToolUse", tool_name:"Edit", tool_input:{file_path:$f, old_string:$o, new_string:$n}}'
}

pretool_write() {
  local file="$1" content="$2"
  jq -cn --arg f "$file" --arg c "$content" \
    '{hook_event_name:"PreToolUse", tool_name:"Write", tool_input:{file_path:$f, content:$c}}'
}

pretool_apply_patch() {
  local patch="$1"
  jq -cn --arg p "$patch" \
    '{hook_event_name:"PreToolUse", tool_name:"apply_patch", tool_input:{patch:$p}}'
}

expect_block() {
  local description="$1" payload="$2"
  local out
  out=$(printf '%s' "$payload" | bash "$DISPATCH" 2>/dev/null)
  if echo "$out" | grep -q '"decision":"block"'; then
    # Verify uniform mnemonic prefix.
    if echo "$out" | grep -q '\[dont-do-that/'; then
      PASS=$((PASS + 1))
    else
      echo "FAIL [missing mnemonic prefix]: ${description}"
      echo "  output: ${out}"
      FAIL=$((FAIL + 1))
    fi
  else
    echo "FAIL [block expected]: ${description}"
    echo "  output: ${out:-<empty>}"
    FAIL=$((FAIL + 1))
  fi
}

expect_block_mnemonic() {
  local description="$1" mnemonic="$2" payload="$3"
  local out
  out=$(printf '%s' "$payload" | bash "$DISPATCH" 2>/dev/null)
  if echo "$out" | grep -q "\[dont-do-that/${mnemonic}\]"; then
    PASS=$((PASS + 1))
  else
    echo "FAIL [block by ${mnemonic} expected]: ${description}"
    echo "  output: ${out:-<empty>}"
    FAIL=$((FAIL + 1))
  fi
}

expect_pass() {
  local description="$1" payload="$2"
  local out
  out=$(printf '%s' "$payload" | bash "$DISPATCH" 2>/dev/null)
  if echo "$out" | grep -q '"decision":"block"'; then
    echo "FAIL [pass expected]: ${description}"
    echo "  output: ${out}"
    FAIL=$((FAIL + 1))
  else
    PASS=$((PASS + 1))
  fi
}

expect_deny() {
  local description="$1" payload="$2" expected_substring="${3:-}"
  local stderr_file exit_code stderr_content
  stderr_file=$(mktemp)
  printf '%s' "$payload" | bash "$DISPATCH" >/dev/null 2>"$stderr_file"
  exit_code=$?
  stderr_content=$(cat "$stderr_file")
  rm -f "$stderr_file"
  if [ "$exit_code" -ne 2 ]; then
    echo "FAIL [deny expected exit 2]: ${description}"
    echo "  exit: ${exit_code}"
    echo "  stderr: ${stderr_content:-<empty>}"
    FAIL=$((FAIL + 1))
    return
  fi
  if ! echo "$stderr_content" | grep -q '\[dont-do-that/'; then
    echo "FAIL [missing mnemonic prefix]: ${description}"
    echo "  stderr: ${stderr_content}"
    FAIL=$((FAIL + 1))
    return
  fi
  if [ -n "$expected_substring" ] && ! echo "$stderr_content" | grep -qF -- "$expected_substring"; then
    echo "FAIL [expected '${expected_substring}']: ${description}"
    echo "  stderr: ${stderr_content}"
    FAIL=$((FAIL + 1))
    return
  fi
  PASS=$((PASS + 1))
}

expect_allow() {
  local description="$1" payload="$2"
  local stderr_file exit_code
  stderr_file=$(mktemp)
  printf '%s' "$payload" | bash "$DISPATCH" >/dev/null 2>"$stderr_file"
  exit_code=$?
  rm -f "$stderr_file"
  if [ "$exit_code" -ne 0 ]; then
    echo "FAIL [allow expected exit 0]: ${description}"
    echo "  exit: ${exit_code}"
    FAIL=$((FAIL + 1))
    return
  fi
  PASS=$((PASS + 1))
}

expect_context() {
  local description="$1" payload="$2" mnemonic="${3:-dash}"
  local out
  out=$(printf '%s' "$payload" | bash "$DISPATCH" 2>/dev/null)
  if echo "$out" | grep -q '"additionalContext"'; then
    if echo "$out" | grep -q "\[dont-do-that/${mnemonic}\]"; then
      PASS=$((PASS + 1))
    else
      echo "FAIL [missing ${mnemonic} mnemonic]: ${description}"
      echo "  output: ${out}"
      FAIL=$((FAIL + 1))
    fi
  else
    echo "FAIL [additionalContext expected]: ${description}"
    echo "  output: ${out:-<empty>}"
    FAIL=$((FAIL + 1))
  fi
}

expect_silent() {
  local description="$1" payload="$2"
  local out exit_code
  out=$(printf '%s' "$payload" | bash "$DISPATCH" 2>/dev/null)
  exit_code=$?
  if [ "$exit_code" -eq 0 ] && [ -z "$out" ]; then
    PASS=$((PASS + 1))
  else
    echo "FAIL [silence expected]: ${description}"
    echo "  exit: ${exit_code}"
    echo "  output: ${out:-<empty>}"
    FAIL=$((FAIL + 1))
  fi
}

# --- premature-interruption ---

expect_block "premature: no escape hatch" \
  "$(stop_payload "Ik heb het aangepast.")"

expect_pass "premature: finish flag with substantive sentence" \
  "$(stop_payload "Beide hooks gefixt en de syntax check slaagt nu. 🏁")"

expect_block "premature: bare finish flag" \
  "$(stop_payload "🏁")"

expect_block "premature: flag without substantive sentence" \
  "$(stop_payload "Klaar 🏁")"

expect_pass "premature: question hands off to compliance" \
  "$(stop_payload "Wat bedoel je precies?")"

expect_block "premature: flag + question is contradiction" \
  "$(stop_payload "Of zal ik hem starten? 🏁")"

expect_block "premature: flag + question separated" \
  "$(stop_payload "Wil je dit nog? Ja hoor. 🏁")"

expect_pass "premature: WIP hatch" \
  "$(stop_payload "Bezig met hooks 🚧")"

expect_pass "premature: mutex skips" \
  "$(stop_payload "Iets." true)"

headless_out=$(printf '%s' "$(stop_payload "Klaar 🏁")" | DD_HEADLESS=1 bash "$DISPATCH" 2>/dev/null)
if [ -z "$headless_out" ]; then
  PASS=$((PASS + 1))
else
  echo "FAIL [headless: DD_HEADLESS suppresses Stop block]"
  echo "  output: ${headless_out}"
  FAIL=$((FAIL + 1))
fi

guarded_out=$(printf '%s' "$(stop_payload "Klaar 🏁")" | bash "$DISPATCH" 2>/dev/null)
if echo "$guarded_out" | grep -q '"decision":"block"'; then
  PASS=$((PASS + 1))
else
  echo "FAIL [headless: unset DD_HEADLESS still blocks]"
  echo "  output: ${guarded_out:-<empty>}"
  FAIL=$((FAIL + 1))
fi

# --- compliance-reflex ---

expect_block "compliance: shall I question" \
  "$(stop_payload "Wil je dat ik dit nog aanpas?")"

expect_block "compliance: preference question" \
  "$(stop_payload "Wat heeft je voorkeur?")"

expect_block "compliance: English shall I" \
  "$(stop_payload "Should I update this?")"

expect_pass "compliance: remote creation question is a gate" \
  "$(stop_payload "De lokale naam is duidelijk, maar een forge repo is account-bound state. Zal ik \`gh repo create stekker/backlog-vault --private\` uitvoeren?")"

expect_pass "compliance: push question is a gate" \
  "$(stop_payload "De commit staat lokaal en pushen raakt de gedeelde remote. Should I push this branch?")"

expect_pass "compliance: push changes question is a gate" \
  "$(stop_payload "De commit staat lokaal en raakt een gedeelde branch. Should I push these changes?")"

expect_block "compliance: local push metaphor still blocks" \
  "$(stop_payload "Should I push the validation into a helper?")"

expect_block "compliance: local push changes metaphor still blocks" \
  "$(stop_payload "Should I push these changes into a helper module?")"

expect_pass "compliance: compass escape" \
  "$(stop_payload "🧭 Andere richting nodig?")"

expect_pass "compliance: genuine question" \
  "$(stop_payload "Bedoel je de header of de footer?")"

expect_pass "compliance: WIP hatch" \
  "$(stop_payload "Zal ik dit fixen? 🚧")"

expect_pass "compliance: no question mark" \
  "$(stop_payload "Ik heb de configuratie aangepast en alle testen blijven groen. 🏁")"

expect_block_mnemonic "prefer: lettered menu, no marker" prefer \
  "$(stop_payload "Er zijn twee wegen: (a) de helper inline zetten, (b) een module extraheren. Welke wil je?")"

expect_block_mnemonic "prefer: numbered menu with choice word" prefer \
  "$(stop_payload "Two approaches:"$'\n'"1. Inline the helper"$'\n'"2. Extract a module"$'\n'"Which do you prefer?")"

expect_block_mnemonic "prefer: Optie N menu" prefer \
  "$(stop_payload "Optie 1 hergebruikt de bestaande helper, optie 2 bouwt een nieuwe. Wat heeft je voorkeur?")"

expect_block_mnemonic "prefer: comparison table header" prefer \
  "$(stop_payload "| Aspect | Approach A | Approach B |"$'\n'"|---|---|---|"$'\n'"| speed | fast | slow |"$'\n'"Welke wil je?")"

expect_block_mnemonic "prefer: non-question menu beats premature catch-all" prefer \
  "$(stop_payload "Er zijn twee opties: (a) de helper inline zetten, (b) een module extraheren. Geen voorkeur van mij, jouw keuze.")"

expect_pass "prefer: remote creation menu is an operator gate" \
  "$(stop_payload "Two paths:"$'\n'"1. Keep the vault in a local-only git repo"$'\n'"2. Create a GitHub repo with \`gh repo create stekker/backlog-vault\`"$'\n'"Which path do you want?")"

expect_pass "prefer: remote attach menu is an operator gate" \
  "$(stop_payload "Optie 1 houdt de repo local-only. Optie 2 gebruikt \`git remote add origin https://github.com/stekker/backlog-vault.git\`. Welke optie wil je?")"

expect_block_mnemonic "prefer: reproduction wording is not an external gate" prefer \
  "$(stop_payload "Two local options:"$'\n'"1. Keep the reproduction in the unit test"$'\n'"2. Move the reproduction into a fixture"$'\n'"Which do you prefer?")"

expect_block_mnemonic "prefer: production build wording is not an external gate" prefer \
  "$(stop_payload "Two local options:"$'\n'"1. Run the production build script locally"$'\n'"2. Run the dev build script locally"$'\n'"Which one do you prefer?")"

expect_block_mnemonic "prefer: push changes into helper wording is not an external gate" prefer \
  "$(stop_payload "Two local options:"$'\n'"1. Push these changes into a helper module"$'\n'"2. Keep these changes inline"$'\n'"Which one do you prefer?")"

expect_pass "prefer: squared-letter marker silences" \
  "$(stop_payload "Twee wegen: 🅰️ inline, 🅱️ extract. Ik leun naar 🅰️ want simpeler en sneller te testen. 🏁")"

expect_block_mnemonic "prefer: lone squared-letter marker does not silence" prefer \
  "$(stop_payload "Er zijn twee wegen: (a) inline, (b) extract. Jouw keuze. Ik kies 🅰️. 🏁")"

expect_block_mnemonic "prefer: paired labels without a pick do not silence" prefer \
  "$(stop_payload "Twee wegen: 🅰️ inline, 🅱️ extract. Welke wil je? 🏁")"

expect_pass "prefer: compass escape" \
  "$(stop_payload "🧭 (a) inline of (b) extract, dit is jouw keuze. Welke wil je?")"

expect_pass "prefer: WIP hatch" \
  "$(stop_payload "(a) inline"$'\n'"(b) extract"$'\n'"Welke wil je? 🚧")"

expect_pass "prefer: numbered steps are not a menu" \
  "$(stop_payload "Ik ga verder: 1. de helper inline zetten, 2. de tests draaien, 3. committen. 🏁")"

expect_pass "prefer: status table is not a menu" \
  "$(stop_payload "| File | Status |"$'\n'"|---|---|"$'\n'"| variant.go | done |"$'\n'"| b.go | pending |"$'\n'"Alles groen. 🏁")"

expect_pass "prefer: lettered prose without choice signal" \
  "$(stop_payload "De functie neemt (a) een input en (b) een output, en geeft het resultaat terug. Helpt dat?")"

expect_pass "prefer: numbered report with relative 'which'" \
  "$(stop_payload "Ik checkte twee bestanden:"$'\n'"1. foo.sh which has the bug"$'\n'"2. bar.sh which is fine"$'\n'"Beide gefixt. 🏁")"

expect_pass "prefer: numbered list with 'liever' is not a menu" \
  "$(stop_payload "Twee dingen gedaan:"$'\n'"1. de helper hernoemd"$'\n'"2. de test toegevoegd, liever vroeg dan laat"$'\n'"Klaar. 🏁")"

expect_pass "prefer: plural choices in a numbered report are not a menu handoff" \
  "$(stop_payload "De flow werkt nu:"$'\n'"1. Cleanup beoordeelt ieder bericht tweemaal."$'\n'"2. Daarna kies jij Bewaren, Twijfel of Verwijderkandidaat."$'\n'"3. Pas na jouw controle trekt Cleanup conclusies op grotere schaal."$'\n'"Jouw keuzes blijven disabled tot beide beoordelingen klaar zijn. 🏁")"

expect_block_mnemonic "jargon: push-go coinage" jargon \
  "$(stop_payload "De twee commits staan lokaal en wachten op je push-go. 🏁")"

expect_block_mnemonic "jargon: ship-go coinage" jargon \
  "$(stop_payload "Alles is groen en de feature staat klaar voor je ship-go. 🏁")"

expect_block_mnemonic "jargon: raw user-go in chat" jargon \
  "$(stop_payload "De merge wacht op je user-go voordat ik verderga. 🏁")"

expect_pass "jargon: backticked mention is fine" \
  "$(stop_payload "De term \`push-go\` is verboden; zeg gewoon dat je op mijn go wacht. 🏁")"

expect_pass "jargon: plain phrasing passes" \
  "$(stop_payload "De commits staan lokaal en wachten op jouw go om te pushen. 🏁")"

expect_pass "jargon: get-go idiom is not a coinage" \
  "$(stop_payload "Dit gedrag zat er vanaf de get-go al in en is geen regressie van deze wijziging. 🏁")"

expect_pass "jargon: WIP hatch" \
  "$(stop_payload "Klaar voor je push-go. 🚧")"

# --- cache-excuse ---

expect_block "cache: browser cache blame" \
  "$(stop_payload "Dit komt door de browser cache.")"

expect_block "cache: hard refresh suggestion" \
  "$(stop_payload "Probeer Cmd+Shift+R.")"

expect_pass "cache: no cache mention" \
  "$(stop_payload "Het probleem zit in de router config en niet elders. 🏁")"

expect_pass "cache: WIP hatch" \
  "$(stop_payload "Browser cache issue 🚧")"

expect_pass "cache: mutex skips" \
  "$(stop_payload "Browser cache." true)"

# --- false-claims ---

expect_block "false-claims: pre-existing" \
  "$(stop_payload "Dit is een pre-existing failure.")"

expect_block "false-claims: already broken" \
  "$(stop_payload "Dit was al stuk.")"

expect_block "false-claims: known issue" \
  "$(stop_payload "Dit is een known issue.")"

expect_pass "false-claims: clean text" \
  "$(stop_payload "De test faalt door een typo in de config van middleware. 🏁")"

expect_pass "false-claims: WIP hatch" \
  "$(stop_payload "Pre-existing issue 🚧")"

expect_block "false-claims: ignores mutex (always runs)" \
  "$(stop_payload "Dit is een pre-existing failure." true)"

# --- tool-error ---

TOOL_ERROR_HOME=$(mktemp -d)
TOOL_ERROR_TRANSCRIPT=$(mktemp)
cat > "$TOOL_ERROR_TRANSCRIPT" <<'JSONL'
{"type":"user","message":{"content":"Run the failing command."}}
{"type":"function_call","name":"exec_command","arguments":"{\"cmd\":\"false\"}"}
{"type":"function_call_output","output":"Chunk ID: abc\nProcess exited with code 1\nOutput:\n"}
JSONL
tool_error_payload=$(jq -cn --arg tr "$TOOL_ERROR_TRANSCRIPT" \
  '{hook_event_name:"Stop", session_id:"codex-tool-error", transcript_path:$tr, stop_hook_active:false}')
tool_error_out=$(printf '%s' "$tool_error_payload" | LAICLUSE_HOME="$TOOL_ERROR_HOME" bash "$DISPATCH" 2>/dev/null)
if echo "$tool_error_out" | grep -q '\[dont-do-that/tool-error\]'; then
  PASS=$((PASS + 1))
else
  echo "FAIL [tool-error: Codex function_call failure expected]"
  echo "  output: ${tool_error_out:-<empty>}"
  FAIL=$((FAIL + 1))
fi
rm -f "$TOOL_ERROR_TRANSCRIPT"
rm -rf "$TOOL_ERROR_HOME"

# --- verification-delegation ---
# Every case includes a substantive sentence + 🏁 so the premature-interruption
# guard in the chain hands off to verify instead of blocking first.

expect_block "verification: unproven claim" \
  "$(stop_payload "Ik heb de endpoint niet geraakt maar dit zou nu moeten werken. 🏁")"

expect_block "verification: asks user to check" \
  "$(stop_payload "De wijziging staat in het bestand. Check of het werkt. 🏁")"

expect_block "verification: asks user to refresh" \
  "$(stop_payload "Ik heb de styling aangepast. Refresh de pagina. 🏁")"

expect_block "verification: English claim" \
  "$(stop_payload "I changed the config. This should now work. 🏁")"

expect_pass "verification: Geverifieerd escape" \
  "$(stop_payload "Geverifieerd: screenshot bevestigt de nieuwe styling werkt. 🏁")"

expect_pass "verification: clean text" \
  "$(stop_payload "De wijziging staat in het bestand en de testen blijven groen. 🏁")"

expect_pass "verification: WIP hatch" \
  "$(stop_payload "Zou moeten werken 🚧")"

expect_pass "verification: mutex skips" \
  "$(stop_payload "Zou moeten werken. 🏁" true)"

# --- duh (instruction-instead-of-execution) ---
# Each text is long enough to bypass the premature guard (>=40 non-emoji
# chars + sentence terminator + 🏁), so the block we observe is duh
# itself, not premature catching short text.

expect_block_mnemonic "duh: NL offer with command" "duh" \
  "$(stop_payload "De wijzigingen staan klaar in het bestand. Je kunt dit checken door \`bin/foo\` te draaien op je machine. 🏁")"

expect_block_mnemonic "duh: EN offer with command" "duh" \
  "$(stop_payload "The change is staged in the right module. You can verify this by running \`npm test\` against the suite. 🏁")"

expect_block_mnemonic "duh: imperative Run cmd" "duh" \
  "$(stop_payload "De migratie is voorbereid en klaar voor uitvoering. Run \`bin/migrate\` to apply the changes now. 🏁")"

expect_block_mnemonic "duh: imperative Voer uit" "duh" \
  "$(stop_payload "De spec is bijgewerkt en klaar voor groen. Voer \`bundle exec rspec spec/foo_spec.rb\` uit om te checken. 🏁")"

expect_block_mnemonic "duh: open in browser" "duh" \
  "$(stop_payload "De pagina draait op de dev-server en is bereikbaar. Open http://localhost:3000 in je browser om te kijken. 🏁")"

expect_pass "duh: Instructie escape" \
  "$(stop_payload "De stap is gedocumenteerd voor handmatige uitvoering. Instructie: voer \`bin/foo\` handmatig uit op de prod-host. 🏁")"

expect_pass "duh: WIP hatch" \
  "$(stop_payload "Je kunt dit checken door \`bin/foo\` te draaien op je machine. 🚧")"

expect_pass "duh: clean text" \
  "$(stop_payload "Geverifieerd: alle tests groen na de wijziging, geen verdere actie nodig op deze branch. 🏁")"

# --- time-estimate --- allow-comment: section divider matches existing smoke-test.sh pattern

expect_block_mnemonic "estimate: paar uur werk" "estimate" \
  "$(stop_payload "Een werkende minimale Ansible-setup is een paar uur eerlijk werk voor twee hosts.")"

expect_block_mnemonic "estimate: halve dag" "estimate" \
  "$(stop_payload "5-minuten belletje versus halve dag uitzoekwerk maakt de afweging duidelijker.")"

expect_block_mnemonic "estimate: dagje" "estimate" \
  "$(stop_payload "Dat is een dagje sleutelen op de queue-config, niet meer dan dat.")"

expect_block_mnemonic "estimate: kost een week" "estimate" \
  "$(stop_payload "De refactor van de auth-laag kost een week om netjes door alle clients heen te krijgen.")"

expect_block_mnemonic "estimate: takes a day" "estimate" \
  "$(stop_payload "Wiring this up properly would take a day of careful refactoring through the stack.")"

expect_block_mnemonic "estimate: few days of work" "estimate" \
  "$(stop_payload "Adding the new ingest pipeline would be a few days of work across services.")"

expect_block_mnemonic "estimate: binnen een uur" "estimate" \
  "$(stop_payload "Dat is binnen een uur te bouwen en testbaar op een lokale Postgres.")"

expect_block_mnemonic "estimate: comparison frame vandaag-deze week" "estimate" \
  "$(stop_payload "Optie A is vandaag te leveren, optie B is deze week want raakt meerdere services.")"

expect_pass "estimate: clean substantive text" \
  "$(stop_payload "Zes files aangeraakt, drie edits per file, tests groen na de tweede iteratie. 🏁")"

expect_pass "estimate: 🧭 escape" \
  "$(stop_payload "🧭 Welke route wil je verder uitwerken voor de auth-rewrite, route A of B?")"

expect_pass "estimate: WIP hatch" \
  "$(stop_payload "Een paar uur werk nog op de queue 🚧")"

expect_pass "estimate: mutex skips" \
  "$(stop_payload "Een paar uur werk." true)"

expect_pass "estimate: cron context not estimate" \
  "$(stop_payload "De cron loopt elke dag om 03:00 en draait de backup-rotation netjes door. 🏁")"

expect_pass "estimate: retention window not estimate" \
  "$(stop_payload "De retention window staat op 7 dagen, oudere rijen vallen automatisch uit de view. 🏁")"

expect_pass "estimate: past tense not estimate" \
  "$(stop_payload "Twee weken geleden landde de migratie en sindsdien draait alles stabiel op productie. 🏁")"

expect_pass "estimate: actual measured duration" \
  "$(stop_payload "Mission duration: 13:51 to 14:27 is 36 minutes voor deze diagnose-iteratie. 🏁")"

expect_pass "estimate: SLA fact not estimate" \
  "$(stop_payload "Info Support draaide drie weken live onder SLA zonder regressies in de error budget. 🏁")"

# --- block-followup-without-issue ---

expect_deny "followup: follow-up taal in gh api body" \
  "$(pretool_bash 'gh api repos/foo/bar/issues --field body="Komt in een follow-up PR"')" \
  "followup"

expect_deny "followup: buiten-scope phrasing" \
  "$(pretool_bash 'gh api repos/foo/bar/issues --field body="Buiten scope van deze mission"')" \
  "followup"

expect_allow "followup: Bewust uitgesteld escape" \
  "$(pretool_bash 'gh api repos/foo/bar/issues --field body="Bewust uitgesteld: volgt in een follow-up PR"')"

expect_allow "followup: non-gh command passes" \
  "$(pretool_bash 'echo follow-up')"

expect_allow "followup: echoing a string that mentions gh api and body passes" \
  "$(pretool_bash 'echo "see the gh api docs section about body fields"')"

expect_allow "followup: grep for gh api in a code file with body keyword passes" \
  "$(pretool_bash 'grep -n "gh api" /tmp/notes.md | grep body')"

expect_allow "followup: cat of a path that contains gh api substring and body word passes" \
  "$(pretool_bash 'cat "/tmp/Per-session gh api reference for body shaping.md"')"

expect_allow "followup: echoing a sentence about gh api body fields and follow-up plans passes" \
  "$(pretool_bash 'echo "the gh api docs body section mentions follow-up workflow"')"

expect_allow "followup: grep for follow-up in a notes file that also names gh api and body passes" \
  "$(pretool_bash 'grep -n "follow-up" /tmp/Notes-on-gh-api-body.md')"

expect_deny "no-osascript: direct command blocked" \
  "$(pretool_bash "osascript -e 'return 1'")" \
  "no-osascript"

expect_deny "no-osascript: absolute path after chain blocked" \
  "$(pretool_bash "echo ready && /usr/bin/osascript -e 'return 1'")" \
  "no-osascript"

expect_deny "no-osascript: wrapper command blocked" \
  "$(pretool_bash "sudo osascript -e 'return 1'")" \
  "no-osascript"

expect_deny "no-osascript: command substitution blocked" \
  "$(pretool_bash 'echo $(osascript -e "return 1")')" \
  "no-osascript"

expect_allow "no-osascript: searching for the word passes" \
  "$(pretool_bash 'rg osascript packages/dont-do-that')"

# --- no-remote-create --- allow-comment: section divider matches existing smoke-test.sh pattern

expect_deny "no-remote-create: gh repo create blocked" \
  "$(pretool_bash 'gh repo create stekker/backlog-vault --private')" \
  "not true reversibility"

expect_deny "no-remote-create: gh repo fork blocked" \
  "$(pretool_bash 'gh repo fork epologee/iii --clone=false')" \
  "account-bound forge state"

expect_allow "no-remote-create: git remote add is local configuration" \
  "$(pretool_bash 'git remote add origin https://github.com/stekker/backlog-vault.git')"

expect_allow "no-remote-create: git remote set-url is local configuration" \
  "$(pretool_bash 'git remote set-url origin https://github.com/stekker/backlog.git')"

expect_allow "no-remote-create: operator-approved gh repo fork passes" \
  "$(pretool_bash_with_user 'gh repo fork wbso-ai/slop-off --remote=false' 'Maak de epologee fork van deze repo.')"

expect_allow "no-remote-create: Dutch remotes-aanmaken approval passes for repo create" \
  "$(pretool_bash_with_user 'gh repo create example/infra-tools --private --source . --remote origin --push' 'Ik wil met expliciete toestemming dat jij remotes kan aan maken.')"

expect_allow "no-remote-create: Dutch remotes-geven approval passes for repo create" \
  "$(pretool_bash_with_user 'gh repo create example/gateway --private' 'Kun je deze twee repositories ook private remotes geven onder github?')"

expect_deny "no-remote-create: unrelated chatter still blocks repo create" \
  "$(pretool_bash_with_user 'gh repo create example/sneaky --private' 'Mooi werk, de tests zijn groen.')" \
  "no-remote-create"

expect_allow "no-remote-create: bare go after a remotes question passes" \
  "$(pretool_bash_with_users 'gh repo create example/infra-tools --private --source . --remote origin --push' 'Kun je deze repositories private remotes geven onder github?' 'go')"

expect_deny "no-remote-create: bare go after unrelated chatter still blocks" \
  "$(pretool_bash_with_users 'gh repo create example/sneaky --private' 'De testsuite is groen, mooi werk.' 'go')" \
  "no-remote-create"

expect_allow "no-remote-create: imperative Dutch order passes for repo create" \
  "$(pretool_bash_with_user 'gh repo create example/infra-tools --private --source . --remote origin --push' 'Maak de remotes. En push. Private.')"

expect_allow "no-remote-create: Codex transcript approval passes for repo create" \
  "$(pretool_bash_with_codex_user 'gh repo create example/infra-tools --private' 'Maak de private GitHub-repository example/infra-tools aan en push ernaartoe.')"

expect_deny "no-remote-create: status question without assent still blocks" \
  "$(pretool_bash_with_user 'gh repo create example/sneaky --private' 'Welke remotes heeft dit project eigenlijk?')" \
  "no-remote-create"

# --- no-remote ---
# Each case sets up a temp git repo and cd's in before invoking the hook,
# because the guard reads `git remote` against the current working directory.

ORIG_PWD="$PWD"

NO_REMOTE=$(mktemp -d)
git -C "$NO_REMOTE" init -q
cd "$NO_REMOTE"
expect_deny "no-remote: push without any remote" \
  "$(pretool_bash 'git push')" \
  "no-remote"
expect_deny "no-remote: push origin without any remote" \
  "$(pretool_bash 'git push origin main')" \
  "no-remote"
cd "$ORIG_PWD"
rm -rf "$NO_REMOTE"

WITH_REMOTE=$(mktemp -d)
git -C "$WITH_REMOTE" init -q
git -C "$WITH_REMOTE" remote add origin https://example.com/foo.git
cd "$WITH_REMOTE"
expect_allow "no-remote: push allowed when origin configured" \
  "$(pretool_bash 'git push')"
expect_allow "no-remote: push origin matches existing remote" \
  "$(pretool_bash 'git push origin main')"
expect_deny "no-remote: push to unknown named remote" \
  "$(pretool_bash 'git push upstream main')" \
  "no-remote"
cd "$ORIG_PWD"
rm -rf "$WITH_REMOTE"

NO_REMOTE2=$(mktemp -d)
git -C "$NO_REMOTE2" init -q
cd "$NO_REMOTE2"
expect_allow "no-remote: non-push git commands pass" \
  "$(pretool_bash 'git status')"
expect_allow "no-remote: non-git commands pass" \
  "$(pretool_bash 'echo no push here')"
cd "$ORIG_PWD"
rm -rf "$NO_REMOTE2"

# --- no-worktree-deploy --- allow-comment: section divider matches existing smoke-test.sh pattern

pretool_bash_cwd() {
  local cmd="$1" cwd="$2"
  jq -cn --arg c "$cmd" --arg w "$cwd" \
    '{hook_event_name:"PreToolUse", tool_name:"Bash", tool_input:{command:$c}, cwd:$w}'
}

WT_MAIN=$(mktemp -d)
git -C "$WT_MAIN" init -q
git -C "$WT_MAIN" commit --allow-empty -q -m "init"
WT_BRANCH=$(mktemp -u)
git -C "$WT_MAIN" worktree add -q -b feature "$WT_BRANCH"

expect_deny "no-worktree-deploy: ansible-playbook from worktree blocked" \
  "$(pretool_bash_cwd 'ansible-playbook site.yml' "$WT_BRANCH")" \
  "no-worktree-deploy"
cd "$WT_BRANCH"
expect_deny "no-worktree-deploy: missing cwd falls back to hook working directory" \
  "$(pretool_bash 'ansible-playbook site.yml')" \
  "no-worktree-deploy"
cd "$ORIG_PWD"
expect_allow "no-worktree-deploy: ansible-playbook --check from worktree passes" \
  "$(pretool_bash_cwd 'ansible-playbook --check site.yml' "$WT_BRANCH")"
expect_allow "no-worktree-deploy: ansible-playbook --syntax-check from worktree passes" \
  "$(pretool_bash_cwd 'ansible-playbook --syntax-check site.yml' "$WT_BRANCH")"
expect_allow "no-worktree-deploy: ansible-playbook from canonical checkout passes" \
  "$(pretool_bash_cwd 'ansible-playbook site.yml' "$WT_MAIN")"
expect_allow "no-worktree-deploy: git worktree commands from worktree pass" \
  "$(pretool_bash_cwd 'git status' "$WT_BRANCH")"
expect_allow "no-worktree-deploy: non-ansible command from worktree passes" \
  "$(pretool_bash_cwd 'echo hello' "$WT_BRANCH")"

git -C "$WT_MAIN" worktree remove -f "$WT_BRANCH" 2>/dev/null || rm -rf "$WT_BRANCH"
rm -rf "$WT_MAIN"

NON_GIT=$(mktemp -d)
expect_allow "no-worktree-deploy: ansible-playbook outside git repo passes" \
  "$(pretool_bash_cwd 'ansible-playbook site.yml' "$NON_GIT")"
rm -rf "$NON_GIT"

# --- block-inline-dashes ---
# The awk dash-detect needs an em-dash in a non-code line. We use printf
# to inject the raw byte so the literal stays out of the file.
EMDASH="$(printf '\xe2\x80\x94')"
ENDASH="$(printf '\xe2\x80\x93')"
RIGHT_ARROW="$(printf '\xe2\x86\x92')"
CURLY_APOSTROPHE="$(printf '\xe2\x80\x99')"
expect_deny "dash: em-dash in Bash is denied before execution" \
  "$(pretool_bash "eywa checkpoint 'red${EMDASH}green'")" \
  "dont-do-that/dash-bash"

expect_deny "dash: en-dash in Bash is denied before execution" \
  "$(pretool_bash "eywa checkpoint 'red${ENDASH}green'")" \
  "dont-do-that/dash-bash"

expect_allow "dash: HTML entity text in Bash remains searchable" \
  "$(pretool_bash "rg '&mdash;' src")"

expect_deny "dash: a shell heredoc cannot hide a literal dash after a code fence marker" \
  "$(pretool_bash $'printf \'```\nred'"${EMDASH}"$'green\n\'')" \
  "dont-do-that/dash-bash"

expect_allow "dash: right arrow in Bash is not an em-dash" \
  "$(pretool_bash "eywa checkpoint 'red${RIGHT_ARROW}green'")"

expect_allow "dash: curly apostrophe in Bash is not an em-dash" \
  "$(pretool_bash "eywa checkpoint 'commando${CURLY_APOSTROPHE}s'")"

expect_silent "dash: Bash is never asked to rewrite after execution" \
  "$(posttool_bash "eywa checkpoint 'red${EMDASH}green'")"

expect_silent "land: Bash is never asked to rewrite after execution" \
  "$(posttool_bash "eywa checkpoint 'the change lands now'")"

expect_context "dash: em-dash in Edit new_string" \
  "$(posttool_edit "/tmp/x.md" "Some prose with ${EMDASH} dash here")"

expect_context "dash: mdash entity in Edit new_string" \
  "$(posttool_edit "/tmp/x.md" "Some prose with &mdash; dash here")"

expect_context "dash: ndash entity in Edit new_string" \
  "$(posttool_edit "/tmp/x.md" "Some prose with &ndash; dash here")"

expect_context "dash: numeric em-dash entity in Edit new_string" \
  "$(posttool_edit "/tmp/x.md" "Some prose with &#8212; dash here")"

expect_context "dash: numeric en-dash entity in Edit new_string" \
  "$(posttool_edit "/tmp/x.md" "Some prose with &#8211; dash here")"

expect_context "dash: lowercase hex em-dash entity in Edit new_string" \
  "$(posttool_edit "/tmp/x.md" "Some prose with &#x2014; dash here")"

expect_context "dash: uppercase hex en-dash entity in Edit new_string" \
  "$(posttool_edit "/tmp/x.md" "Some prose with &#X2013; dash here")"

expect_allow "dash: clean Edit new_string passes silent" \
  "$(posttool_edit "/tmp/x.md" "No dash here.")"

expect_allow "dash: mdash entity in fenced code passes silent" \
  "$(posttool_edit "/tmp/x.md" $'```html\n<span>&mdash;</span>\n```')"

expect_context "dash: em-dash in apply_patch added line" \
  "$(posttool_apply_patch $'*** Begin Patch\n*** Update File: /tmp/x.ts\n@@\n const oldMessage = "No dash here.";\n+const newMessage = "Some prose with '"${EMDASH}"$' dash here.";\n*** End Patch\n')"

expect_allow "dash: em-dash in apply_patch context line passes silent" \
  "$(posttool_apply_patch $'*** Begin Patch\n*** Update File: /tmp/x.ts\n@@\n const oldMessage = "Some prose with '"${EMDASH}"$' dash here.";\n+const newMessage = "No dash here.";\n*** End Patch\n')"

expect_context "land: metaphor in Edit new_string" \
  "$(posttool_edit "/tmp/x.ts" "We land the change on main.")" \
  "land"

expect_allow "land: clean Edit new_string passes silent" \
  "$(posttool_edit "/tmp/x.ts" "We merge the change to main.")"

expect_context "land: metaphor in apply_patch added line" \
  "$(posttool_apply_patch $'*** Begin Patch\n*** Update File: /tmp/x.ts\n@@\n const a = 1;\n+const note = "this lands on the summary record";\n*** End Patch\n')" \
  "land"

# --- no-code-comments ---

expect_deny "no-code-comments: Edit adds // comment in .ts" \
  "$(pretool_edit "/tmp/x.ts" "let x = 1;" $'let x = 1;\n// dumb explanation\nlet y = 2;')" \
  "no-code-comments"

expect_deny "no-code-comments: Edit adds # comment in .py" \
  "$(pretool_edit "/tmp/x.py" "x = 1" $'x = 1\n# dumb explanation\ny = 2')" \
  "no-code-comments"

expect_deny "no-code-comments: Edit adds multi-line block in .ts" \
  "$(pretool_edit "/tmp/x.ts" "let x = 1;" $'let x = 1;\n/* multi\n line\n block */\nlet y = 2;')" \
  "no-code-comments"

expect_deny "no-code-comments: Edit adds // comment in .swift" \
  "$(pretool_edit "/tmp/x.swift" "let x = 1" $'let x = 1\n// dumb explanation\nlet y = 2')" \
  "no-code-comments"

expect_deny "no-code-comments: Edit adds # comment in .rb" \
  "$(pretool_edit "/tmp/x.rb" "x = 1" $'x = 1\n# dumb\ny = 2')" \
  "no-code-comments"

expect_deny "no-code-comments: Edit adds // comment in .go" \
  "$(pretool_edit "/tmp/x.go" "var x = 1" $'var x = 1\n// dumb explanation\nvar y = 2')" \
  "no-code-comments"

expect_deny "no-code-comments: Edit adds /// doc comment in .rs" \
  "$(pretool_edit "/tmp/x.rs" "let x = 1;" $'let x = 1;\n/// dumb explanation\nfn foo() {}')" \
  "no-code-comments"

expect_deny "no-code-comments: Edit adds JSDoc /** */ in .ts" \
  "$(pretool_edit "/tmp/x.ts" "function foo() {}" $'/**\n * does something\n */\nfunction foo() {}')" \
  "no-code-comments"

expect_deny "no-code-comments: Edit changes existing comment body in .py" \
  "$(pretool_edit "/tmp/x.py" $'# old text\nx = 1' $'# new text\nx = 1')" \
  "no-code-comments"

expect_deny "no-code-comments: Write new .swift with bare comment" \
  "$(pretool_write "/tmp/new-x.swift" $'import Foundation\nlet x = 1\n// bad comment')" \
  "no-code-comments"

expect_allow "no-code-comments: Edit adds string containing // in .ts" \
  "$(pretool_edit "/tmp/x.ts" "let x = 1;" $'let x = 1;\nlet u = "// not a comment";')"

expect_allow "no-code-comments: Edit adds string containing # in .py" \
  "$(pretool_edit "/tmp/x.py" "x = 1" $'x = 1\nu = "# not a comment"')"

expect_allow "no-code-comments: Edit adds template literal with // in .ts" \
  "$(pretool_edit "/tmp/x.ts" "let x = 1;" $'let x = 1;\nlet t = `// inside template`;')"

expect_allow "no-code-comments: Edit adds triple-quoted text with # in .py" \
  "$(pretool_edit "/tmp/x.py" "x = 1" $'x = 1\ny = """\n# not a comment\n"""')"

expect_allow "no-code-comments: Edit adds URL comment in .swift" \
  "$(pretool_edit "/tmp/x.swift" "let x = 1" $'let x = 1\n// see https://example.com/foo\nlet y = 2')"

expect_allow "no-code-comments: Edit adds URL comment in .py" \
  "$(pretool_edit "/tmp/x.py" "x = 1" $'x = 1\n# see https://example.com\ny = 2')"

expect_allow "no-code-comments: Edit adds allow-comment escape in .py" \
  "$(pretool_edit "/tmp/x.py" "x = 1" $'x = 1\n# allow-comment: legacy quirk\ny = 2')"

expect_allow "no-code-comments: Edit adds frozen_string_literal pragma in .rb" \
  "$(pretool_edit "/tmp/x.rb" "x = 1" $'# frozen_string_literal: true\nx = 1\ny = 2')"

expect_allow "no-code-comments: Edit adds markdown heading inside <<~HTML heredoc in .rb" \
  "$(pretool_edit "/tmp/x.rb" "render html: 1" $'render html: <<~HTML\n  # Account update\n  **bold** intro\nHTML')"

expect_allow "no-code-comments: Edit adds shell comment inside <<-EOS heredoc in .rb" \
  "$(pretool_edit "/tmp/x.rb" "x = 1" $'x = <<-EOS\n  # not a comment\n  EOS')"

expect_deny "no-code-comments: Edit adds real # comment after heredoc closes in .rb" \
  "$(pretool_edit "/tmp/x.rb" "x = 1" $'a = <<~SQL\n  select 1\nSQL\n# real comment')" \
  "no-code-comments"

expect_deny "no-code-comments: Edit adds # comment after left-shift (not a heredoc) in .rb" \
  "$(pretool_edit "/tmp/x.rb" "x = 1" $'arr << thing\n# real comment')" \
  "no-code-comments"

expect_allow "no-code-comments: Edit adds @ts-ignore pragma in .ts" \
  "$(pretool_edit "/tmp/x.ts" "let x = any;" $'// @ts-ignore\nlet x = any;')"

expect_allow "no-code-comments: Edit adds noqa pragma in .py" \
  "$(pretool_edit "/tmp/x.py" "import os" $'import os  # noqa: F401\nimport sys')"

expect_allow "no-code-comments: Edit adds go:build directive in .go" \
  "$(pretool_edit "/tmp/x.go" "package main" $'//go:build linux\npackage main')"

expect_allow "no-code-comments: Edit adds eslint-disable pragma in .ts" \
  "$(pretool_edit "/tmp/x.ts" "let x = 1;" $'// eslint-disable-next-line\nlet x = 1;')"

expect_allow "no-code-comments: Write new .sh with shebang on line 1" \
  "$(pretool_write "/tmp/new-x.sh" $'#!/usr/bin/env bash\necho hi')"

expect_allow "no-code-comments: Edit adds // comment in .md (non-code file)" \
  "$(pretool_edit "/tmp/x.md" "# Heading" $'# Heading\n// looks like a comment but markdown ignores it')"

expect_allow "no-code-comments: Edit adds # in .yml (non-code file)" \
  "$(pretool_edit "/tmp/x.yml" "key: value" $'key: value\n# yaml comment is fine')"

expect_allow "no-code-comments: Edit adds // in .json (non-code file)" \
  "$(pretool_edit "/tmp/x.json" '{}' $'{}\n// not actually json')"

expect_allow "no-code-comments: Edit preserves existing comment unchanged" \
  "$(pretool_edit "/tmp/x.py" $'# existing\nx = 1' $'# existing\nx = 1\ny = 2')"

expect_allow "no-code-comments: Edit removes a comment (no new comment)" \
  "$(pretool_edit "/tmp/x.py" $'# leaving\nx = 1' "x = 1")"

expect_allow "no-code-comments: Edit on file with no extension passes" \
  "$(pretool_edit "/tmp/x" "old" $'old\n// looks like comment')"

expect_allow "no-code-comments: Edit on .css passes (style-only language)" \
  "$(pretool_edit "/tmp/x.css" "body {}" $'body {}\n/* css comments are fine */')"

expect_deny "no-code-comments: MultiEdit first edit adds comment" \
  "$(jq -cn '{hook_event_name:"PreToolUse", tool_name:"MultiEdit", tool_input:{file_path:"/tmp/x.ts", edits:[{old_string:"a", new_string:"a;\n// added"}, {old_string:"b", new_string:"b;"}]}}')" \
  "no-code-comments"

expect_deny "no-code-comments: apply_patch adds // comment in .ts" \
  "$(pretool_apply_patch $'*** Begin Patch\n*** Update File: /tmp/x.ts\n@@\n let x = 1;\n+// dumb explanation\n+let y = 2;\n*** End Patch\n')" \
  "no-code-comments"

expect_allow "no-code-comments: apply_patch adds code without comment" \
  "$(pretool_apply_patch $'*** Begin Patch\n*** Update File: /tmp/x.ts\n@@\n let x = 1;\n+let y = 2;\n*** End Patch\n')"

expect_allow "no-code-comments: Edit adds JS regex literal with escaped slashes" \
  "$(pretool_edit "/tmp/x.ts" "let x = 1;" $'let x = 1;\nconst re = /https?:\\/\\//g;')"

expect_allow "no-code-comments: Edit adds split on URL regex in .js" \
  "$(pretool_edit "/tmp/x.js" "let x = 1;" $'let x = 1;\nconst parts = url.split(/\\/\\//)[1];')"

expect_deny "no-code-comments: bare allow-comment without colon is blocked" \
  "$(pretool_edit "/tmp/x.py" "x = 1" $'x = 1\n# Use allow-comment to bypass')" \
  "no-code-comments"

expect_deny "no-code-comments: pylint mid-prose is blocked" \
  "$(pretool_edit "/tmp/x.py" "x = 1" $'x = 1\n# I hate pylint: it is annoying')" \
  "no-code-comments"

expect_deny "no-code-comments: noqa mid-prose is blocked" \
  "$(pretool_edit "/tmp/x.py" "x = 1" $'x = 1\n# the noqa rule is dumb')" \
  "no-code-comments"

expect_allow "no-code-comments: noqa at body start passes" \
  "$(pretool_edit "/tmp/x.py" "import os" $'import os  # noqa: F401')"

expect_allow "no-code-comments: rubocop pragma at body start passes" \
  "$(pretool_edit "/tmp/x.rb" "def foo; end" $'def foo  # rubocop:disable Style/EmptyMethod\nend')"

expect_allow "no-code-comments: SPDX license header passes" \
  "$(pretool_edit "/tmp/x.rs" "fn main() {}" $'// SPDX-License-Identifier: MIT\nfn main() {}')"

expect_allow "no-code-comments: Licensed under MIT passes" \
  "$(pretool_edit "/tmp/x.rb" "x = 1" $'# Licensed under the MIT License, see LICENSE for details\nx = 1')"

expect_allow "no-code-comments: @generated marker passes" \
  "$(pretool_edit "/tmp/x.ts" "let x = 1;" $'// @generated by tsoa\nlet x = 1;')"

expect_allow "no-code-comments: Auto-generated marker passes" \
  "$(pretool_edit "/tmp/x.py" "x = 1" $'# Auto-generated by protoc-gen-py. Do not edit.\nx = 1')"

expect_allow "no-code-comments: .jsx files are excluded from inspection" \
  "$(pretool_edit "/tmp/x.jsx" "let x = 1;" $'let x = 1;\n// this passes because jsx is excluded')"

expect_allow "no-code-comments: .tsx files are excluded from inspection" \
  "$(pretool_edit "/tmp/x.tsx" "let x = 1;" $'let x = 1;\n// this passes because tsx is excluded')"

expect_deny "no-code-comments: .js still checked (not jsx)" \
  "$(pretool_edit "/tmp/x.js" "let x = 1;" $'let x = 1;\n// this is still blocked in plain js')" \
  "no-code-comments"

expect_deny "no-code-comments: Swift /// doc comment blocked by design" \
  "$(pretool_edit "/tmp/x.swift" "func foo() {}" $'/// Documentation\nfunc foo() {}')" \
  "no-code-comments"

expect_allow "no-code-comments: Swift /// doc with allow-comment escape" \
  "$(pretool_edit "/tmp/x.swift" "func foo() {}" $'/// Documentation. allow-comment: generates API docs\nfunc foo() {}')"

expect_allow "no-code-comments: /// doc with @generated pragma passes (marker chars stripped)" \
  "$(pretool_edit "/tmp/x.rs" "fn foo() {}" $'/// @generated by build.rs\nfn foo() {}')"

expect_allow "no-code-comments: /** */ block with @generated pragma passes (marker chars stripped)" \
  "$(pretool_edit "/tmp/x.ts" "let x = 1;" $'/** @generated by openapi */\nlet x = 1;')"

expect_allow "no-code-comments: //! Rust inner-doc with @generated passes" \
  "$(pretool_edit "/tmp/x.rs" "fn foo() {}" $'//! @generated by build.rs\nfn foo() {}')"

expect_deny "no-code-comments: prose body starting with 'go:' is blocked (not a Go directive)" \
  "$(pretool_edit "/tmp/x.go" "package main" $'// go: fix this later\npackage main')" \
  "no-code-comments"

expect_allow "no-code-comments: //go:generate directive passes" \
  "$(pretool_edit "/tmp/x.go" "package main" $'//go:generate stringer -type=Pill\npackage main')"

expect_allow "no-code-comments: //go:embed directive passes" \
  "$(pretool_edit "/tmp/x.go" "package main" $'//go:embed static/*\npackage main')"

expect_deny "no-code-comments: Write new .sh with comment after shebang is blocked" \
  "$(pretool_write "/tmp/new-x-after-shebang.sh" $'#!/usr/bin/env bash\n# sets up environment\nexport PATH=$PATH:/foo')" \
  "no-code-comments"

expect_allow "no-code-comments: Ruby method notation Recipes#create in .rb passes" \
  "$(pretool_edit "/tmp/x.rb" "x = 1" $'x = 1\ndescribe Recipes, "#create" do\nend')"

expect_allow "no-code-comments: Edit snippet starting mid-string with #method does not fire" \
  "$(pretool_edit "/tmp/x.rb" 'from API"' 'from Recipes#create"')"

expect_allow "no-code-comments: bash parameter expansion \$foo#bar passes in .sh" \
  "$(pretool_edit "/tmp/x.sh" "x=1" $'x=1\necho $foo#bar')"

expect_allow "no-code-comments: bare http URL as expression in .ts passes" \
  "$(pretool_edit "/tmp/x.ts" "let x = 1;" $'let x = 1;\nlet u = http://blabla;')"

expect_allow "no-code-comments: s3:// scheme as expression in .ts passes" \
  "$(pretool_edit "/tmp/x.ts" "let x = 1;" $'let x = 1;\nlet u = s3://bucket/key;')"

# --- pr-discipline --- allow-comment: section divider matches existing smoke-test.sh pattern

expect_deny "pr-discipline: gh pr create with Plant title" \
  "$(pretool_bash 'gh pr create --title "Plant planner-analysis section" --body "honest body text"')" \
  "pr-discipline"

expect_deny "pr-discipline: gh pr create with Land title" \
  "$(pretool_bash 'gh pr create --title "Land the new dispatch path" --body "honest body text"')" \
  "pr-discipline"

expect_deny "pr-discipline: gh pr create with Ship title" \
  "$(pretool_bash 'gh pr create --title "Ship the redesigned card" --body "honest body text"')" \
  "pr-discipline"

expect_allow "pr-discipline: capability-shape title passes" \
  "$(pretool_bash 'gh pr create --title "Read planning rows beyond one site" --body "honest body text"')"

expect_allow "pr-discipline: title beginning with The passes" \
  "$(pretool_bash 'gh pr create --title "The cache survives a daemon restart" --body "honest body text"')"

expect_deny "pr-discipline: body with ## Summary header" \
  "$(pretool_bash $'gh pr create --title "Honest title here" --body "## Summary\n- foo\n- bar"')" \
  "pr-discipline"

expect_deny "pr-discipline: body with ## Test plan header" \
  "$(pretool_bash $'gh pr create --title "Honest title here" --body "## Test plan\n- [ ] foo"')" \
  "pr-discipline"

expect_deny "pr-discipline: body with Generated with Claude Code footer" \
  "$(pretool_bash $'gh pr create --title "Honest title here" --body "Body text.\n\n🤖 Generated with Claude Code"')" \
  "pr-discipline"

expect_deny "pr-discipline: body with Co-Authored-By anthropic trailer" \
  "$(pretool_bash $'gh pr create --title "Honest title" --body "Body.\n\nCo-Authored-By: Claude <noreply@anthropic.com>"')" \
  "pr-discipline"

expect_allow "pr-discipline: non-gh command passes silently" \
  "$(pretool_bash 'echo hello')"

expect_allow "pr-discipline: gh pr view (read-only subcommand) passes" \
  "$(pretool_bash 'gh pr view 1234')"

expect_deny "pr-discipline: gh pr edit --title with Drop verb" \
  "$(pretool_bash 'gh pr edit 1234 --title "Drop the legacy adapter"')" \
  "pr-discipline"

expect_allow "pr-discipline: git commit body mentioning gh pr create as text passes" \
  "$(pretool_bash $'git commit -m "Subject\n\nThe commit-body talks about gh pr create as a literal phrase, not invokes it. Generated with Claude Code is also mentioned as a banned pattern, not a real footer."')"

expect_deny "pr-discipline: gh pr create after cd is still caught" \
  "$(pretool_bash 'cd /tmp && gh pr create --title "Plant the section" --body "honest body text"')" \
  "pr-discipline"

# --- Summary ---

TOTAL=$((PASS + FAIL))
if [ "$FAIL" -eq 0 ]; then
  echo "${TOTAL}/${TOTAL} passed"
  exit 0
else
  echo "${PASS}/${TOTAL} passed, ${FAIL} failed"
  exit 1
fi
