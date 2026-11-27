#!/bin/bash
# allow-comment: PreToolUse:Bash gate. An agent that ships runtime payload for another lab's agent works from assumptions about tooling it does not run. Before such a commit the peer from that lab reviews it through intervision. The first argument names the host running the hook (claude or codex); the gate watches the other host's payload and lets the commit through once the command ends with `# peer-reviewed: <model-id>` naming a model of the other lab.

HOST="${1:-claude}"
INPUT=$(cat)
CMD=$(jq -r '.tool_input.command // empty' <<< "$INPUT" 2>/dev/null)
[ -z "$CMD" ] && exit 0

GIT='(^|&&|;|\|\||[[:space:]])[[:space:]]*git([[:space:]]+-[^[:space:]]+([[:space:]]+("[^"]*"|'"'"'[^'"'"']*'"'"'|[^-][^[:space:]]*))?)*[[:space:]]+'
grep -Eq "${GIT}commit([[:space:]]|$)" <<< "$CMD" || exit 0

# allow-comment: the marker counts only as a comment that ends the git commit command itself, outside every quote and with heredoc bodies set aside, naming a model of the other lab. Commands before or after the commit cannot carry it.
OUTSIDE=$(awk '
  delim != "" { l = $0; if (tabs) sub(/^\t+/, "", l); if (l == delim) delim = ""; next }
  { print
    for (i = 1; i <= length($0); i++) {
      c = substr($0, i, 1)
      if (sq) { if (c == "\047") sq = 0 }
      else if (dq) { if (c == "\\") i++; else if (c == "\"") dq = 0 }
      else if (c == "\\") i++
      else if (c == "\047") sq = 1
      else if (c == "\"") dq = 1
      else if (c == "#" && (i == 1 || substr($0, i - 1, 1) ~ /[[:space:];&|]/)) break
      else if (substr($0, i, 3) == "<<<") i += 2
      else if (substr($0, i, 2) == "<<") {
        rest = substr($0, i + 2)
        if (match(rest, /^-?[[:space:]]*\\?["'"'"']?[A-Za-z_][A-Za-z0-9_]*/)) {
          d = substr(rest, RSTART, RLENGTH); tabs = (d ~ /^-/); sub(/^-?[[:space:]]*\\?["'"'"']?/, "", d); delim = d
        }
        i++
      }
    }
  }' <<< "$CMD")
# allow-comment: quote state carries across lines, so a multi-line message or `$(cat <<EOF ...)` ends on the line where its command ends. Each `;`, `&&`, `||` or `|` starts a new command, and every git commit command must itself end in a marker naming a model of the other lab; a comment after a later command proves nothing about the commit.
if [ "$HOST" = codex ]; then PEER_MODELS='^(claude|opus|sonnet|haiku|fable)'; else PEER_MODELS='^(gpt-|codex|o[0-9])'; fi
REVIEWED=$(awk -v models="$PEER_MODELS" '
  function close_command(comment,   model) {
    if (seen) {
      commits++
      if (match(comment, /#[[:space:]]*peer-reviewed:[[:space:]]*[^[:space:]#]+/)) {
        model = substr(comment, RSTART, RLENGTH); sub(/^#[[:space:]]*peer-reviewed:[[:space:]]*/, "", model)
        if (tolower(model) ~ models) marked++
      }
    }
    cmd = ""; seen = 0
  }
  { line = $0; comment = ""; prev = " "; cont = 0
    for (i = 1; i <= length(line); i++) {
      c = substr(line, i, 1); nx = substr(line, i + 1, 1)
      if (sq) { if (c == "\047") { sq = 0; cmd = cmd "Q" } }
      else if (dq) { if (c == "\\") i++; else if (c == "\"") { dq = 0; cmd = cmd "Q" } }
      else if (c == "\\") { if (i == length(line)) cont = 1; i++ }
      else if (c == "\047") sq = 1
      else if (c == "\"") dq = 1
      else if (c == "#" && prev ~ /[[:space:];&|]/) { comment = substr(line, i); break }
      else if (c == ";" || c == "|" || (c == "&" && prev !~ /[<>]/ && nx != ">")) {
        if (cmd ~ /(^|[[:space:]])git([[:space:]]+-[^[:space:]]+([[:space:]]+[^-[:space:]][^[:space:]]*)?)*[[:space:]]+commit([[:space:]]|$)/) seen = 1
        close_command("")
        if ((c == "&" || c == "|") && nx == c) i++
      }
      else cmd = cmd c
      prev = c
    }
    cmd = cmd " "
    if (cmd ~ /(^|[[:space:]])git([[:space:]]+-[^[:space:]]+([[:space:]]+[^-[:space:]][^[:space:]]*)?)*[[:space:]]+commit([[:space:]]|$)/) seen = 1
    if (!sq && !dq && !cont) close_command(comment)
  }
  END { if (commits > 0 && marked == commits) print "yes" }' <<< "$OUTSIDE")
[ "$REVIEWED" = yes ] && exit 0

DIR=$(jq -r '.tool_input.workdir // .cwd // empty' <<< "$INPUT" 2>/dev/null)
[ -n "$DIR" ] || DIR=$PWD
PATH_ARG='("[^"]*"|'"'"'[^'"'"']*'"'"'|[^[:space:]&;|"'"'"']+)'
CD=$(grep -Eo "^[[:space:]]*cd[[:space:]]+$PATH_ARG" <<< "$CMD" | sed -E 's/^[[:space:]]*cd[[:space:]]+//')
GIT_C=$(grep -Eo "(^|[[:space:]])git[[:space:]]+-C[[:space:]]+$PATH_ARG" <<< "$CMD" | head -1 | sed -E 's/.*-C[[:space:]]+//')
for step in "$CD" "$GIT_C"; do
  [ -n "$step" ] || continue
  step="${step#[\"\']}"; step="${step%[\"\']}"
  step="${step/#\~/$HOME}"
  case "$step" in /*) DIR=$step ;; *) DIR="$DIR/$step" ;; esac
done

if ! ROOT=$(git -C "$DIR" rev-parse --show-toplevel 2>/dev/null); then
  [ -n "$CD$GIT_C" ] || exit 0
  printf '[intervision/peer-review] Could not resolve the repository this commit runs in (%s), so it cannot be checked for payload another agent runs. Run the commit from inside the repository.\n' "$DIR" >&2
  exit 2
fi
[ -f "$ROOT/.claude-plugin/marketplace.json" ] && [ -f "$ROOT/.agents/plugins/marketplace.json" ] || exit 0

FILES=$(git -C "$ROOT" diff --cached --name-only 2>/dev/null)
# allow-comment: `git add … && git commit` and `git commit -a` commit files that are not staged yet when this hook runs, so count every pending change.
# allow-comment: `git add` with plain named paths stages only those paths, so only their pending changes count. Anything the shell could reinterpret (quotes, escapes, expansion, comments) or `-A`, `-u`, `.` or no path counts every pending change.
ADD_ALL=0; ADD_SPECS=()
if grep -Eq "${GIT}add([[:space:]]|$)" <<< "$CMD"; then
  while IFS= read -r piece; do
    grep -Eq "${GIT}add([[:space:]]|$)" <<< "$piece" || continue
    if ! [[ "$piece" =~ ^[A-Za-z0-9._/@+=:,\ -]*$ ]]; then ADD_ALL=1; continue; fi
    after_add=0
    for word in $piece; do
      if [ "$after_add" = 0 ]; then
        [ "$word" = add ] && after_add=1
        case "$word" in -*) ADD_ALL=1 ;; esac
        continue
      fi
      case "$word" in
        -f|-v|--force|--verbose|--) ;;
        -*|.|:/) ADD_ALL=1 ;;
        *) ADD_SPECS+=("$word") ;;
      esac
    done
  done < <(awk '{ gsub(/&&|\|\||;|\|/, "\n"); print }' <<< "$CMD")
  [ "${#ADD_SPECS[@]}" -gt 0 ] || ADD_ALL=1
  # allow-comment: named paths resolve against $DIR, which follows only a leading cd; any other directory change makes their base uncertain.
  DIR_CHANGES=$(grep -Eo '(^|[;&|[:space:]])(cd|pushd|popd)([[:space:]]|$)' <<< "$CMD" | wc -l | tr -d ' ')
  LEADING_CD=$(head -1 <<< "$CMD" | grep -Ec '^[[:space:]]*cd[[:space:]]')
  [ "$DIR_CHANGES" -le "$LEADING_CD" ] || ADD_ALL=1
fi
if [ "$ADD_ALL" = 1 ] || grep -Eq "${GIT}commit([[:space:]]+[^#]*)?[[:space:]](-[a-zA-Z]*a[a-zA-Z]*|--all)([[:space:]]|$)" <<< "$CMD"; then
  FILES+=$'\n'$(git -C "$ROOT" status --porcelain --untracked-files=all 2>/dev/null | sed -E 's/^.. //; s/.* -> //')
elif [ "${#ADD_SPECS[@]}" -gt 0 ]; then
  if NAMED=$(git -C "$DIR" status --porcelain --untracked-files=all -- "${ADD_SPECS[@]}" 2>/dev/null); then
    FILES+=$'\n'$(sed -E 's/^.. //; s/.* -> //' <<< "$NAMED")
  else
    FILES+=$'\n'$(git -C "$ROOT" status --porcelain --untracked-files=all 2>/dev/null | sed -E 's/^.. //; s/.* -> //')
  fi
fi
FILES=$(grep -Ev '^$|^packages/[^/]+/(test|tests)/|/README\.md$|/CHANGELOG\.md$' <<< "$FILES" | sort -u)

if [ "$HOST" = codex ]; then
  PEER=Claude
  TOUCHED=$(grep -E '^packages/|(^|/)\.claude-plugin/' <<< "$FILES" | grep -Ev '/SKILL\.codex\.md$|/hooks/hooks\.codex\.json$|^packages/[^/]+/agents\.codex/')
else
  PEER=Codex
  TOUCHED=$(grep -E '^packages/|^\.agents/plugins/' <<< "$FILES" | grep -Ev '/SKILL\.claude\.md$|^packages/[^/]+/hooks/hooks\.json$|^packages/[^/]+/\.claude-plugin/|^packages/[^/]+/agents/')
fi
TOUCHED=$(head -5 <<< "$TOUCHED" | tr '\n' ' ')
[ -n "${TOUCHED// /}" ] || exit 0

printf '[intervision/peer-review] This commit ships payload that %s runs: %s. What %s does with it (skill names, invocation, hooks, loops, limits) is not something this session can observe. Ask the %s peer through the intervision second-opinion skill to review this change, settle its findings, then rerun the commit ending with `# peer-reviewed: <%s model-id>`.\n' "$PEER" "${TOUCHED% }" "$PEER" "$PEER" "$PEER" >&2
exit 2
