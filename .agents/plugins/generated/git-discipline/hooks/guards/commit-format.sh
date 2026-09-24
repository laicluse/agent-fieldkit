#!/bin/bash
# allow-comment: PreToolUse:Bash guard. Walks the commit message line-by-line, collects format misses (72-char ceiling, missing blank line, conjunction in subject) and the soft 51-72 char nudge, then emits one dd_emit_pre_context. Hard misses ask for an amend afterwards; the soft nudge stays informational.

guard_commit_format() {
  local input="$1"
  local command message subject

  command=$(jq -r '.tool_input.command // empty' <<< "$input" 2>/dev/null)
  dd_is_git_commit_command "$command" || return 0

  message=$(dd_extract_commit_message "$command")
  [[ -z "$message" ]] && return 0

  subject=$(printf '%s' "$message" | head -1)

  local hard=() soft=()
  local line_num=0 subject_len=0 line
  while IFS= read -r line || [[ -n "$line" ]]; do
    line_num=$((line_num + 1))

    # allow-comment: trailer lines (Key: Value, machine-readable, often carry
    # allow-comment: a long path) are not narrative and bypass the 72-char
    # allow-comment: ceiling. The allowlist matches the git-discipline schema trailers
    # allow-comment: plus the standard git trailers. Mid-body prose lines
    # allow-comment: starting with a capitalised keyword and colon (Note:,
    # allow-comment: TODO:, BUG:, Warning:) stay subject to the ceiling because
    # allow-comment: they are narrative and should wrap for readability.
    local trailer_re='^(Slice|Tests|Red-then-green|Verified|Verified-how|Visual|PII-Doublecheck|Cucumber|Signed-off-by|Co-Authored-By|Co-authored-by|Acked-by|Reviewed-by|Cc|Fixes|Closes|Resolves):[[:space:]]'
    if [[ ${#line} -gt 72 ]]; then
      if [[ $line_num -eq 1 ]]; then
        hard+=("Subject is ${#line} chars, max 72. Tighten: \"${line}\"")
      elif [[ ! "$line" =~ $trailer_re ]]; then
        hard+=("Body line ${line_num} is ${#line} chars, max 72: \"${line}\"")
      fi
    fi

    if [[ $line_num -eq 2 && -n "$line" ]]; then
      hard+=("Multi-line commit needs a blank line between subject and body.")
    fi

    if [[ $line_num -eq 1 ]]; then
      local conjunction_re=' (and|\+|&) '
      if [[ "$line" =~ $conjunction_re ]]; then
        local matched="${BASH_REMATCH[1]}"
        if [[ "${GIT_DISCIPLINE_ALLOW_CONJUNCTION:-0}" != "1" ]] \
            && ! grep -qE '^# allow-conjunction:[[:space:]]+\S' <<< "$message"; then
          hard+=("Subject contains conjunction \" ${matched} \". Suggests two changes bundled behind one subject. Split into separate commits, rewrite as one cohesive change, or set GIT_DISCIPLINE_ALLOW_CONJUNCTION=1 (or add '# allow-conjunction: <reason>' to the body) when the joined form is intentional.")
        fi
      fi
    fi

    [[ $line_num -eq 1 ]] && subject_len=${#line}
  done <<< "$message"

  if [[ $subject_len -gt 50 && $subject_len -le 72 ]]; then
    soft+=("Subject is ${subject_len} chars. Target is <=50; 51-72 is allowed but aim shorter on the next commit.")
  fi

  [[ ${#hard[@]} -eq 0 && ${#soft[@]} -eq 0 ]] && return 0

  # allow-comment: hard violations BLOCK at PreToolUse via dd_emit_deny so the
  # allow-comment: commit object is never created; the operator rewrites the
  # allow-comment: message and reruns the same call. Soft nudges (subject
  # allow-comment: 51-72 chars) stay non-blocking via dd_emit_pre_context so
  # allow-comment: the operator gets the readability hint without being
  # allow-comment: forced to amend.
  if [[ ${#hard[@]} -gt 0 ]]; then
    local hard_lines=("Format issues; rewrite the commit message and rerun the same git commit call (the commit object has not been created yet):")
    local v
    for v in "${hard[@]}"; do
      hard_lines+=("- ${v}")
    done
    if [[ ${#soft[@]} -gt 0 ]]; then
      hard_lines+=("")
      local s
      for s in "${soft[@]}"; do
        hard_lines+=("Note: ${s}")
      done
    fi
    local hard_body
    hard_body=$(printf '%s\n' "${hard_lines[@]}")
    dd_emit_deny "commit-format" "$hard_body"
  elif [[ ${#soft[@]} -gt 0 ]]; then
    local soft_lines=()
    local s
    for s in "${soft[@]}"; do
      soft_lines+=("Note: ${s}")
    done
    local soft_body
    soft_body=$(printf '%s\n' "${soft_lines[@]}")
    dd_emit_pre_context "commit-format" "$soft_body"
  fi
}
