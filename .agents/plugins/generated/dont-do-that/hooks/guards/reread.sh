#!/bin/bash
# allow-comment: PostToolUse guard. Soft nudge (never blocks) after lines are added to an instruction artefact, where no test guards the surrounding prose.

_dd_reread_is_instruction_file() {
  case "$1" in
    */SKILL.md|*/SKILL.claude.md|*/SKILL.codex.md) return 0 ;;
    */CLAUDE.md|*/AGENTS.md|*/CLAUDE.local.md) return 0 ;;
    */circus/shared/*.md|*/circus/specific/*.md) return 0 ;;
    *) return 1 ;;
  esac
}

guard_reread() {
  local input="$1"
  local tool source added removed
  tool=$(jq -r '.tool_name // empty' <<< "$input" 2>/dev/null)
  case "$tool" in
    Edit)
      source=$(jq -r '.tool_input.file_path // empty' <<< "$input" 2>/dev/null)
      added=$(jq -r '.tool_input.new_string // empty' <<< "$input" 2>/dev/null | grep -c '')
      removed=$(jq -r '.tool_input.old_string // empty' <<< "$input" 2>/dev/null | grep -c '')
      ;;
    MultiEdit)
      source=$(jq -r '.tool_input.file_path // empty' <<< "$input" 2>/dev/null)
      added=$(jq -r '.tool_input.edits[]?.new_string // empty' <<< "$input" 2>/dev/null | grep -c '')
      removed=$(jq -r '.tool_input.edits[]?.old_string // empty' <<< "$input" 2>/dev/null | grep -c '')
      ;;
    Write)
      source=$(jq -r '.tool_input.file_path // empty' <<< "$input" 2>/dev/null)
      added=1
      removed=0
      ;;
    *) return 0 ;;
  esac

  [ -z "$source" ] && return 0
  _dd_reread_is_instruction_file "$source" || return 0
  [ "${added:-0}" -gt "${removed:-0}" ] || return 0

  dd_emit_context reread "Lines added to the instruction artefact ${source}. A diff shows what you wrote, never its neighbours, and prose has no test that catches a clash. Read the whole surrounding section back and answer two questions before moving on: does anything already there now contradict what you added, and did the operator actually ask for this addition? Moved text counts as added text; arriving somewhere new is not the same as fitting there."
}
