#!/bin/bash
# Shared library for the git-discipline dispatcher and its guard functions.
# Sourced by dispatch.sh and guards/*.sh; never executed directly.
#
# Public helpers:
#   dd_event               - hook event from input JSON
#   dd_tool_name           - tool name from input JSON
#   dd_stop_active         - 0/1 based on stop_hook_active
#   dd_session_id          - session id from input JSON
#   dd_transcript          - transcript path, resolving session fallback
#   dd_assistant_text      - last-turn assistant text, optional line-tracking
#   dd_is_wip              - 0 if the assistant text contains 🚧
#   dd_emit_block          - Stop-style block JSON with mnemonic prefix
#   dd_emit_deny           - PreToolUse stderr + exit 2, mnemonic prefix
#   dd_emit_context        - PostToolUse additionalContext JSON, mnemonic prefix
#   dd_emit_pre_context    - PreToolUse additionalContext JSON, mnemonic prefix
#   dd_extract_commit_message - extract commit message from a bash command string
#
# Every emit helper prefixes the message with "[git-discipline/<mnemonic>] ".
# That prefix is the stable code the operator and Claude can recognise at a
# glance without reading the whole reason.

dd_event() {
  jq -r '.hook_event_name // empty' <<< "$1" 2>/dev/null
}

dd_tool_name() {
  jq -r '.tool_name // empty' <<< "$1" 2>/dev/null
}

dd_stop_active() {
  local v
  v=$(jq -r '.stop_hook_active // false' <<< "$1" 2>/dev/null)
  [ "$v" = "true" ]
}

dd_session_id() {
  jq -r '.session_id // .sessionId // empty' <<< "$1" 2>/dev/null
}

dd_transcript() {
  local input="$1"
  local t
  t=$(jq -r '.transcript_path // empty' <<< "$input" 2>/dev/null)
  if [ -n "$t" ] && [ -f "$t" ]; then
    echo "$t"
    return 0
  fi
  local sid
  sid=$(dd_session_id "$input")
  [ -z "$sid" ] && return 1
  find ~/.claude/projects/ -name "${sid}.jsonl" -type f 2>/dev/null | head -1
}

dd_is_wip() {
  grep -q '🚧' <<< "$1"
}

dd_cd_to_bash_target() {
  local input="$1"
  local cwd workdir
  cwd=$(jq -r '.cwd // empty' <<< "$input" 2>/dev/null)
  workdir=$(jq -r '.tool_input.workdir // .tool_input.cwd // empty' <<< "$input" 2>/dev/null)
  if [ -n "$cwd" ] && [ -d "$cwd" ]; then
    CDPATH= cd -- "$cwd" >/dev/null 2>&1 || return 0
  fi
  if [ -n "$workdir" ] && [ -d "$workdir" ]; then
    CDPATH= cd -- "$workdir" >/dev/null 2>&1 || return 0
  fi
  local command
  command=$(jq -r '.tool_input.command // empty' <<< "$input" 2>/dev/null)
  [ -z "$command" ] && return 0

  local target=""
  # allow-comment: a leading `cd <dir>` repositions the gate whatever separator follows (&&, ;, newline, end), so match the first token after cd, not a literal &&.
  if [[ "$command" =~ ^[[:space:]]*cd[[:space:]]+(\"[^\"]+\"|\'[^\']+\'|[^[:space:]\&\;|]+) ]]; then
    target="${BASH_REMATCH[1]}"
    target="${target#\"}"; target="${target%\"}"
    target="${target#\'}"; target="${target%\'}"
    target="${target/#\~/$HOME}"
  elif [[ "$command" =~ git[[:space:]]+-C[[:space:]]+(\"[^\"]+\"|\'[^\']+\'|[^[:space:]\&]+) ]]; then
    target="${BASH_REMATCH[1]}"
    target="${target#\"}"; target="${target%\"}"
    target="${target#\'}"; target="${target%\'}"
    target="${target/#\~/$HOME}"
  fi

  if [ -n "$target" ] && [ -d "$target" ]; then
    CDPATH= cd -- "$target" >/dev/null 2>&1 || return 0
  fi
}

# dd_assistant_text <input-json> <char-budget> [guard-name]
# Returns the tail of the current turn's assistant text.
# When guard-name is set, tracks last-seen transcript line count in
# /tmp/.claude-<guard>-<session>, scanning only new lines. This matches
# the pre-refactor behavior of the individual scripts.
dd_assistant_text() {
  local input="$1"
  local chars="${2:-1000}"
  local guard="${3:-}"

  local msg
  msg=$(jq -r '.last_assistant_message // empty' <<< "$input" 2>/dev/null)
  if [ -n "$msg" ]; then
    echo "$msg" | tail -c "$chars"
    return 0
  fi

  local sid
  sid=$(dd_session_id "$input")
  [ -z "$sid" ] && return 1

  local tr
  tr=$(dd_transcript "$input")
  [ -z "$tr" ] || [ ! -f "$tr" ] && return 1

  local tail_lines=50
  if [ -n "$guard" ]; then
    local line_file="/tmp/.claude-${guard}-${sid}"
    local total last
    total=$(wc -l < "$tr" | tr -d ' ')
    if [ -f "$line_file" ]; then
      last=$(cat "$line_file")
    else
      last=$((total > 30 ? total - 30 : 0))
    fi
    echo "$total" > "$line_file"
    tail_lines=$((total - last))
    [ "$tail_lines" -le 0 ] && return 1
  fi

  tail -"$tail_lines" "$tr" \
    | jq -s -r '
        . as $all
        | ([$all | to_entries[] | select(.value.type == "user") | .key] | last // -1) as $lu
        | $all[$lu + 1:]
        | map(select(.type == "assistant") | .message.content[]? | select(.type == "text") | .text)
        | join("\n")
      ' 2>/dev/null \
    | tail -c "$chars"
}

# dd_emit_block <mnemonic> <message>
# Stop hook: print one-line JSON and exit 0. The reason carries the mnemonic
# prefix so the transcript shows e.g. [git-discipline/cache] Cache is ...
dd_emit_block() {
  local mnemonic="$1"
  local msg="$2"
  jq -cn --arg r "[git-discipline/${mnemonic}] ${msg}" '{decision:"block", reason:$r}'
  exit 0
}

# dd_emit_deny <mnemonic> <message>
# PreToolUse hook: print one-line stderr and exit 2 (blocks the tool).
dd_emit_deny() {
  local mnemonic="$1"
  local msg="$2"
  printf '[git-discipline/%s] %s\n' "$mnemonic" "$msg" >&2
  exit 2
}

# dd_emit_context <mnemonic> <message>
# PostToolUse hook: print additionalContext JSON (does not block, surfaces text).
dd_emit_context() {
  local mnemonic="$1"
  local msg="$2"
  jq -cn --arg c "[git-discipline/${mnemonic}] ${msg}" \
    '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $c}}'
}

# dd_emit_pre_context <mnemonic> <message>
# PreToolUse hook: print additionalContext JSON (does not block, surfaces text
# to Claude in the next turn so it can adjust subsequent calls).
dd_emit_pre_context() {
  local mnemonic="$1"
  local msg="$2"
  jq -cn --arg c "[git-discipline/${mnemonic}] ${msg}" \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", additionalContext: $c}}'
}

# _dd_run_collect <guard-func> <input-json>
# Run a guard in a subshell so its exit 2 does not short-circuit the parent,
# capture stdout and stderr separately, and accumulate deny output into the
# parent's DD_DENY_MESSAGES array. The caller initialises the array and
# flushes it after all collected guards have run.
#
# Behaviour by exit code:
#   rc=0  -> forward stdout (additionalContext JSON from dd_emit_pre_context).
#   rc=2  -> append captured stderr to DD_DENY_MESSAGES; forward stdout too.
#   other -> guard crashed; print stdout+stderr and exit with that rc so
#            failures stay visible.
_dd_run_collect() {
  local guard_func="$1" input="$2"
  local tmp_out tmp_err rc out err
  tmp_out=$(mktemp "/tmp/git-discipline-collect-out.XXXXXX") \
    || { printf 'git-discipline dispatch: mktemp failed for stdout buffer\n' >&2; exit 1; }
  tmp_err=$(mktemp "/tmp/git-discipline-collect-err.XXXXXX") \
    || { rm -f "$tmp_out"; printf 'git-discipline dispatch: mktemp failed for stderr buffer\n' >&2; exit 1; }
  ( "$guard_func" "$input" ) >"$tmp_out" 2>"$tmp_err"
  rc=$?
  out=$(cat "$tmp_out")
  err=$(cat "$tmp_err")
  rm -f "$tmp_out" "$tmp_err"

  [ -n "$out" ] && printf '%s\n' "$out"

  if [ "$rc" -eq 2 ]; then
    [ -n "$err" ] && DD_DENY_MESSAGES+=("$err")
  elif [ "$rc" -ne 0 ]; then
    [ -n "$err" ] && printf '%s\n' "$err" >&2
    printf 'git-discipline dispatch: %s exited %d (not a deny); aborting.\n' "$guard_func" "$rc" >&2
    exit "$rc"
  else
    [ -n "$err" ] && printf '%s\n' "$err" >&2
  fi
}

# dd_extract_commit_message <bash-command>
# Extract the commit message from a bash command string.
# Tries heredoc body first (the pattern Claude Code defaults to for multi-line
# commits); falls back to all -m / -am / --message literals, joined with blank
# lines (matching git's paragraph-per-flag behavior).
# Prints the message on stdout, or nothing if no message is detected.
# Both commit-format.sh and commit-body.sh rely on this shared parser.
dd_extract_commit_message() {
  local command="$1"
  local message=""

  # Heredoc body extraction. Walks the command line-by-line, opens on
  # <<MARKER or <<-MARKER (quoted or unquoted), captures until a line whose
  # trimmed content matches the marker. Only the first heredoc is used.
  if [[ "$command" == *"<<"* ]]; then
    message=$(awk '
      in_hd {
        trimmed = $0
        sub(/^[[:space:]]+/, "", trimmed)
        if (trimmed == marker) { in_hd = 0; exit }
        print
        next
      }
      {
        if (match($0, /<<-?[[:space:]]*['"'"'"]?[A-Za-z_][A-Za-z0-9_]*['"'"'"]?/)) {
          tok = substr($0, RSTART, RLENGTH)
          sub(/<<-?[[:space:]]*['"'"'"]?/, "", tok)
          sub(/['"'"'"]?$/, "", tok)
          marker = tok
          in_hd = 1
        }
      }
    ' <<< "$command")
  fi

  # Fallback: all -m / -am / --message literals, joined with blank lines.
  # Multiple -m flags concatenate into subject + body paragraphs in git,
  # each separated by a blank line. Collect every match, strip the flag and
  # surrounding quotes from each, then join them with \n\n.
  if [[ -z "$message" ]]; then
    local all_dashm stripped para
    all_dashm=$(printf '%s' "$command" \
      | grep -oE -- $'(-[a-zA-Z]*m|--message)[[:space:]=]+("[^"]*"|\x27[^\x27]*\x27)' \
      || true)
    if [[ -n "$all_dashm" ]]; then
      stripped=""
      while IFS= read -r para; do
        local val
        val=$(printf '%s' "$para" \
          | sed -E $'s/^(-[a-zA-Z]*m|--message)[[:space:]=]+["\x27]//;s/["\x27]$//')
        if [[ -z "$stripped" ]]; then
          stripped="$val"
        else
          stripped="${stripped}"$'\n\n'"${val}"
        fi
      done <<< "$all_dashm"
      message="$stripped"
    fi
  fi

  printf '%s' "$message"
}

# dd_strip_commit_message <bash-command>
# Returns the bash command with heredoc bodies and quoted-string contents
# removed, so callers searching the command for shell-level tokens (such
# as the ack-rule comment behind a `git commit`) do not get fooled by a
# token buried inside the message itself. The heredoc walk uses the same
# grammar as dd_extract_commit_message; together the two functions form
# inverses over the heredoc body. Used by commit-subject.sh to detect
# ack tokens outside the message.
dd_is_git_commit_command() {
  local command="$1"
  local stripped
  stripped=$(dd_strip_commit_message "$command")
  [[ "$stripped" =~ (^|[^A-Za-z0-9_/.-])git[[:space:]]+commit($|[[:space:]]) ]]
}

# allow-comment: dd_is_commit_graph_writer <bash-command> is true for any git
# allow-comment: command that can create or rewrite commit objects (commit,
# allow-comment: rebase, cherry-pick, revert, merge, am). The PreToolUse path
# allow-comment: snapshots HEAD before such a command and the PostToolUse path
# allow-comment: validates the commits it wrote; a read-only subcommand never
# allow-comment: matches and an --abort that writes nothing matches harmlessly
# allow-comment: because the post-tool range then resolves empty.
dd_is_commit_graph_writer() {
  local command="$1"
  dd_is_git_commit_command "$command" && return 0
  local stripped
  stripped=$(dd_strip_commit_message "$command")
  local pre='(^|[[:space:];&|(])'
  local opts='((-[^[:space:]]+)([[:space:]]+[^-][^[:space:]]*)?[[:space:]]+)*'
  [[ "$stripped" =~ ${pre}git[[:space:]]+${opts}(rebase|cherry-pick|revert|merge|am)([[:space:]]|$) ]]
}

dd_is_git_push_command() {
  local command="$1"
  local stripped
  stripped=$(dd_strip_commit_message "$command")
  # allow-comment: tokens between `git` and `push` must be options (a leading -), each with an optional non-option argument, so `git -C /p push` matches but a subcommand like `git stash push` does not.
  [[ "$stripped" =~ (^|[[:space:];\&|])git[[:space:]]+((-[^[:space:]]+)([[:space:]]+[^-][^[:space:]]*)?[[:space:]]+)*push([[:space:]]|$) ]]
}

# allow-comment: dd_stages_before_commit is true when a git add/stage runs in the same compound command as the commit. The PreToolUse gate fires before the command, so that staging has not run yet and its files are absent from the index the validator reads; the caller uses this to explain a path-not-found deny instead of leaving it bare. The message body is stripped first so an "add" inside the commit text does not count.
dd_stages_before_commit() {
  local command="$1"
  local stripped
  stripped=$(dd_strip_commit_message "$command")
  [[ "$stripped" =~ (^|[^A-Za-z0-9_/.-])git[[:space:]]+(-C[[:space:]]+[^[:space:]]+[[:space:]]+)?(add|stage)([[:space:]]|$) ]]
}

dd_strip_commit_message() {
  local command="$1"
  local stripped
  stripped=$(printf '%s' "$command" | awk '
    BEGIN { in_hd = 0; marker = "" }
    in_hd {
      trimmed = $0
      sub(/^[[:space:]]+/, "", trimmed)
      if (trimmed == marker) { in_hd = 0; marker = "" }
      next
    }
    {
      if (match($0, /<<-?[[:space:]]*['"'"'"]?[A-Za-z_][A-Za-z0-9_]*['"'"'"]?/)) {
        tok = substr($0, RSTART, RLENGTH)
        sub(/<<-?[[:space:]]*['"'"'"]?/, "", tok)
        sub(/['"'"'"]?$/, "", tok)
        marker = tok
        in_hd = 1
      }
      print
    }
  ' || true)
  # Drop quoted-string contents so a token inside a quoted argument
  # does not count as a shell-level token either.
  printf '%s' "$stripped" | sed -E $'s/"[^"]*"//g; s/\x27[^\x27]*\x27//g' || true
}
