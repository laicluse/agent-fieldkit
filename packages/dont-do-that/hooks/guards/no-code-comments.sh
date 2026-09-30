#!/bin/bash
# PreToolUse file-edit guard. Blocks tool calls that introduce a code comment
# in a programming-language source file. The reflex to add
# a comment is usually a missed refactor (intent-revealing name, extracted
# method, sharper signature); this guard pushes back on the easy path so
# the structural option gets considered first.
#
# Allow rules. A comment passes the guard when its body:
#   1. contains an http(s):// URL (the language can't express it);
#   2. contains `allow-comment:` followed by a reason (operator escape,
#      one per comment, inline; the colon makes the escape intentional
#      rather than a passing mention of the word);
#   3. starts (after leading whitespace) with a pragma/directive marker
#      from the allowlist (linter directives, compiler magic comments,
#      generated-file headers, copyright notices, Go build constraints);
#   4. is a shebang on line 1 (starts with `!` since the awk strips the
#      leading `#`).
#
# Non-programming-language files (markdown, JSON, YAML, HTML, CSS, ERB,
# env, dotfiles) pass without inspection. CSS is excluded deliberately:
# /* ... */ is its only comment form and not a programming-language reflex.

guard_no_code_comments() {
  local input="$1"
  local tool file_path mode awk_lib
  tool=$(jq -r '.tool_name // empty' <<< "$input" 2>/dev/null)
  case "$tool" in
    Edit|Write|MultiEdit|apply_patch) ;;
    *) return 0 ;;
  esac

  if [ -n "${DIR:-}" ] && [ -f "$DIR/lib/comment-detect.awk" ]; then
    awk_lib="$DIR/lib/comment-detect.awk"
  else
    local guard_dir
    guard_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    awk_lib="$guard_dir/../lib/comment-detect.awk"
  fi
  if [ ! -f "$awk_lib" ]; then
    printf '[dont-do-that/no-code-comments] internal error: comment-detect.awk not found at %s\n' "$awk_lib" >&2
    exit 2
  fi

  case "$tool" in
    apply_patch)
      local patch
      patch=$(dd_tool_patch "$input")
      [ -z "$patch" ] && return 0
      dd_ncc_check_patch "$patch" "$awk_lib"
      ;;
    Edit)
      file_path=$(jq -r '.tool_input.file_path // empty' <<< "$input" 2>/dev/null)
      [ -z "$file_path" ] && return 0
      mode=$(dd_ncc_mode_for "$file_path")
      [ -z "$mode" ] && return 0
      local old_string new_string
      old_string=$(jq -r '.tool_input.old_string // ""' <<< "$input" 2>/dev/null)
      new_string=$(jq -r '.tool_input.new_string // ""' <<< "$input" 2>/dev/null)
      dd_ncc_check_pair "$file_path" "$mode" "$old_string" "$new_string" "$awk_lib"
      ;;
    Write)
      file_path=$(jq -r '.tool_input.file_path // empty' <<< "$input" 2>/dev/null)
      [ -z "$file_path" ] && return 0
      mode=$(dd_ncc_mode_for "$file_path")
      [ -z "$mode" ] && return 0
      local content existing
      content=$(jq -r '.tool_input.content // ""' <<< "$input" 2>/dev/null)
      if [ -f "$file_path" ]; then
        existing=$(cat -- "$file_path")
      else
        existing=""
      fi
      dd_ncc_check_pair "$file_path" "$mode" "$existing" "$content" "$awk_lib"
      ;;
    MultiEdit)
      file_path=$(jq -r '.tool_input.file_path // empty' <<< "$input" 2>/dev/null)
      [ -z "$file_path" ] && return 0
      mode=$(dd_ncc_mode_for "$file_path")
      [ -z "$mode" ] && return 0
      local count idx old new
      count=$(jq -r '.tool_input.edits | length // 0' <<< "$input" 2>/dev/null)
      [ -z "$count" ] && return 0
      idx=0
      while [ "$idx" -lt "$count" ]; do
        old=$(jq -r ".tool_input.edits[$idx].old_string // \"\"" <<< "$input" 2>/dev/null)
        new=$(jq -r ".tool_input.edits[$idx].new_string // \"\"" <<< "$input" 2>/dev/null)
        dd_ncc_check_pair "$file_path" "$mode" "$old" "$new" "$awk_lib"
        idx=$((idx + 1))
      done
      ;;
  esac
}

dd_ncc_mode_for() {
  local path="$1"
  local base
  base=$(basename -- "$path")
  case "$path" in
    *.js|*.ts|*.mjs|*.cjs)                    echo slash ;;
    *.swift)                                  echo slash ;;
    *.kt|*.kts)                               echo slash ;;
    *.java|*.scala|*.groovy)                  echo slash ;;
    *.go)                                     echo slash ;;
    *.rs)                                     echo slash ;;
    *.c|*.h|*.cc|*.cpp|*.cxx|*.hpp|*.hh)      echo slash ;;
    *.cs)                                     echo slash ;;
    *.dart)                                   echo slash ;;
    *.m|*.mm)                                 echo slash ;;
    *.py|*.pyi)                               echo hash ;;
    *.rb|*.rake|*.gemspec)                    echo ruby ;;
    *.sh|*.bash|*.zsh)                        echo hash ;;
    *.pl|*.pm)                                echo hash ;;
    *.ex|*.exs)                               echo hash ;;
    *.cr)                                     echo ruby ;;
    *)
      case "$base" in
        Rakefile|Gemfile|Brewfile|Capfile|Guardfile|Vagrantfile) echo ruby ;;
        *)                                                       echo "" ;;
      esac
      ;;
  esac
}

dd_ncc_check_pair() {
  local file="$1" mode="$2" old="$3" new="$4" awk_lib="$5"

  local new_comments
  new_comments=$(awk -v MODE="$mode" -f "$awk_lib" <<< "$new")
  [ -z "$new_comments" ] && return 0

  local old_comments
  old_comments=$(awk -v MODE="$mode" -f "$awk_lib" <<< "$old")

  local old_bodies=""
  if [ -n "$old_comments" ]; then
    old_bodies=$(printf '%s\n' "$old_comments" | sed 's/^[^:]*://')
  fi

  local line
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    local lineno body
    lineno="${line%%:*}"
    body="${line#*:}"

    if [ -n "$old_bodies" ]; then
      if printf '%s\n' "$old_bodies" | grep -Fxq -- "$body" 2>/dev/null; then
        continue
      fi
    fi

    if dd_ncc_is_allowed "$lineno" "$body"; then
      continue
    fi

    local short="$body"
    if [ "${#short}" -gt 100 ]; then
      short="${short:0:100}..."
    fi
    dd_emit_deny no-code-comments \
"Code comment introduced in ${file}:${lineno}:${short}. If the comment is load-bearing (citation, legal, pragma, workaround, debugging note), include 'allow-comment: <reason>' anywhere in the comment body or an http(s) URL. Otherwise rewrite the code so the intent shows in names, types, and structure instead of in prose."
  done <<< "$new_comments"
}

dd_ncc_check_patch() {
  local patch="$1" awk_lib="$2"
  local current_file="" current_mode="" additions="" line

  dd_ncc_flush_patch_file() {
    [ -n "$current_file" ] || return 0
    [ -n "$current_mode" ] || return 0
    [ -n "$additions" ] || return 0
    dd_ncc_check_pair "$current_file" "$current_mode" "" "$additions" "$awk_lib"
    additions=""
  }

  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      "*** Add File: "*)
        dd_ncc_flush_patch_file
        current_file="${line#*** Add File: }"
        current_mode=$(dd_ncc_mode_for "$current_file")
        additions=""
        continue
        ;;
      "*** Update File: "*)
        dd_ncc_flush_patch_file
        current_file="${line#*** Update File: }"
        current_mode=$(dd_ncc_mode_for "$current_file")
        additions=""
        continue
        ;;
      "*** Delete File: "*)
        dd_ncc_flush_patch_file
        current_file=""
        current_mode=""
        additions=""
        continue
        ;;
      "*** Move to: "*)
        dd_ncc_flush_patch_file
        current_file="${line#*** Move to: }"
        current_mode=$(dd_ncc_mode_for "$current_file")
        additions=""
        continue
        ;;
      "+++ b/"*)
        dd_ncc_flush_patch_file
        current_file="${line#+++ b/}"
        current_mode=$(dd_ncc_mode_for "$current_file")
        additions=""
        continue
        ;;
      "+++ "*)
        dd_ncc_flush_patch_file
        current_file="${line#+++ }"
        [ "$current_file" = "/dev/null" ] && current_file=""
        current_mode=$(dd_ncc_mode_for "$current_file")
        additions=""
        continue
        ;;
    esac

    [ -n "$current_mode" ] || continue
    case "$line" in
      "+"*) additions+="${line#+}"$'\n' ;;
    esac
  done <<< "$patch"

  dd_ncc_flush_patch_file
}

dd_ncc_is_allowed() {
  local lineno="$1" body="$2"

  if [ "$lineno" = "1" ]; then
    case "$body" in
      "!"*) return 0 ;;
    esac
  fi

  if [[ "$body" =~ https?:// ]]; then
    return 0
  fi

  local body_lower
  body_lower=$(printf '%s' "$body" | tr '[:upper:]' '[:lower:]')
  case "$body_lower" in
    *"allow-comment:"*) return 0 ;;
  esac

  local trimmed="$body"
  while true; do
    case "$trimmed" in
      "") break ;;
      [[:space:]/!\*]*) trimmed="${trimmed:1}" ;;
      *) break ;;
    esac
  done
  case "$trimmed" in
    frozen_string_literal*)                                                              return 0 ;;
    "@ts-ignore"*|"@ts-expect-error"*|"@ts-nocheck"*|"@ts-check"*)                       return 0 ;;
    "@flow"*|"@noflow"*)                                                                  return 0 ;;
    noqa*)                                                                                return 0 ;;
    "pylint:"*|"mypy:"*|"pyright:"*)                                                      return 0 ;;
    "type:"*)                                                                             return 0 ;;
    eslint-disable*|eslint-enable*)                                                       return 0 ;;
    prettier-ignore*)                                                                     return 0 ;;
    biome-ignore*)                                                                        return 0 ;;
    "tslint:"*)                                                                           return 0 ;;
    "rubocop:"*|"sorbet:"*)                                                                return 0 ;;
    stylelint-disable*|stylelint-enable*)                                                 return 0 ;;
    "Generated by"*|"DO NOT EDIT"*|"Code generated"*|"AUTO-GENERATED"*)                   return 0 ;;
    "@generated"*|"Auto-generated"*|"auto-generated"*)                                    return 0 ;;
    "Copyright "*|"SPDX-License-Identifier"*|"License:"*|"Licensed under"*)               return 0 ;;
    "All rights reserved"*|"See LICENSE"*|"see LICENSE"*)                                 return 0 ;;
    encoding:*|coding:*|"-*- coding:"*)                                                   return 0 ;;
    "go:build"*|"go:generate"*|"go:embed"*|"go:linkname"*|"go:noinline"*)                  return 0 ;;
    "go:nosplit"*|"go:noescape"*|"go:nointerface"*|"go:wasmimport"*)                       return 0 ;;
  esac

  return 1
}
