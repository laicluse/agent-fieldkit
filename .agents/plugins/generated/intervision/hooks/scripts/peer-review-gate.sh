#!/bin/bash
# allow-comment: PreToolUse:Bash gate. An agent that ships runtime payload for another lab's agent works from assumptions about tooling it does not run. Before such a commit the peer from that lab reviews it through intervision. The first argument names the host running the hook (claude or codex); the gate watches the other host's payload and lets the commit through once the command ends with `# peer-reviewed: <model-id>` naming a model of the other lab.

HOST="${1:-claude}"
INPUT=$(cat)
CMD=$(jq -r '.tool_input.command // empty' <<< "$INPUT" 2>/dev/null)
[ -z "$CMD" ] && exit 0

GIT='(^|&&|;|\|\||[[:space:]])[[:space:]]*git([[:space:]]+-[^[:space:]]+([[:space:]]+("[^"]*"|'"'"'[^'"'"']*'"'"'|[^-][^[:space:]]*))?)*[[:space:]]+'
grep -Eq "${GIT}commit([[:space:]]|$)" <<< "$CMD" || exit 0

# allow-comment: the marker counts only as a trailing comment outside every quote, with heredoc bodies set aside, naming a model of the other lab.
OUTSIDE=$(awk '
  delim != "" { if ($0 == delim) delim = ""; next }
  { print }
  match($0, /<<-?[[:space:]]*["'"'"']?[A-Za-z_][A-Za-z0-9_]*/) {
    d = substr($0, RSTART, RLENGTH); sub(/^<<-?[[:space:]]*["'"'"']?/, "", d); delim = d
  }' <<< "$CMD")
# allow-comment: a quote-aware scan finds the shell comment on the last line; a `#` inside quotes is text, not a comment.
COMMENT=$(awk '
  { line = $0; comment = ""; prev = " "
    for (i = 1; i <= length(line); i++) {
      c = substr(line, i, 1)
      if (sq) { if (c == "\047") sq = 0 }
      else if (dq) { if (c == "\\") i++; else if (c == "\"") dq = 0 }
      else if (c == "\\") i++
      else if (c == "\047") sq = 1
      else if (c == "\"") dq = 1
      else if (c == "#" && prev ~ /[[:space:];&|]/) { comment = substr(line, i); break }
      prev = c
    }
    last = comment }
  END { print last }' <<< "$OUTSIDE")
if [[ "$COMMENT" =~ \#[[:space:]]*peer-reviewed:[[:space:]]*([^[:space:]#]+) ]]; then
  MODEL="${BASH_REMATCH[1]}"
  if [ "$HOST" = codex ]; then grep -Eiq '^(claude|opus|sonnet|haiku|fable)' <<< "$MODEL" && exit 0
  else grep -Eiq '^(gpt-|codex|o[0-9])' <<< "$MODEL" && exit 0
  fi
fi

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
if grep -Eq "${GIT}add([[:space:]]|$)" <<< "$CMD" || grep -Eq "${GIT}commit([[:space:]]+[^#]*)?[[:space:]](-[a-zA-Z]*a[a-zA-Z]*|--all)([[:space:]]|$)" <<< "$CMD"; then
  FILES+=$'\n'$(git -C "$ROOT" status --porcelain --untracked-files=all 2>/dev/null | sed -E 's/^.. //; s/.* -> //')
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
