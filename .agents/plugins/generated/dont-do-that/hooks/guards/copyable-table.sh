#!/bin/bash
# allow-comment: Stop guard. A terminal wraps long table cells, so a URL or long inline-code value inside a markdown table copies as fragments with cell borders. See test/copyable_table_guard.bats.

guard_copyable_table() {
  local input="$1"
  local text
  text=$(dd_assistant_text "$input" 200000 "copyable-table")
  [ -z "$text" ] && return 0
  dd_is_wip "$text" && return 0

  local row
  row=$(awk '
    function copyable(line,   rest) {
      if (line ~ /[A-Za-z][A-Za-z0-9+.-]*:\/\/[^ |]/) return 1
      rest = line
      while (match(rest, /`[^` ]+`/)) {
        if (RLENGTH - 2 >= 40) return 1
        rest = substr(rest, RSTART + RLENGTH)
      }
      return 0
    }
    {
      line = $0
      if (match(line, /^[ \t]*(```+|~~~+)/)) {
        marker = substr(line, RSTART, RLENGTH)
        sub(/^[ \t]*/, "", marker)
        if (!in_fence) {
          in_fence = 1; fence_char = substr(marker, 1, 1); fence_len = length(marker)
          in_table = 0; prev = ""
          next
        }
        if (substr(marker, 1, 1) == fence_char && length(marker) >= fence_len && line ~ /^[ \t]*[`~]+[ \t]*$/) {
          in_fence = 0
          next
        }
      }
      if (in_fence) next
      if (in_table) {
        if (line !~ /^[ \t]*$/ && line !~ /^[ \t]*(#+[ \t]|>|[-*+][ \t]|[0-9]+[.)][ \t])/ && line !~ /^[ \t]*([-*_][ \t]*)([-*_][ \t]*)([-*_][ \t]*)+$/) {
          if (copyable(line)) { print line; exit }
          next
        }
        in_table = 0
      }
      if (line ~ /^(    |\t)/ || prev ~ /^(    |\t)/) { prev = line; next }
      if (index(prev, "|") && index(line, "|") && line ~ /^[ \t]*\|?[ \t]*:?---*:?[ \t]*(\|[ \t]*:?---*:?[ \t]*)*\|?[ \t]*$/) {
        in_table = 1
        if (copyable(prev)) { print prev; exit }
        next
      }
      prev = line
    }
  ' <<< "$text")
  [ -z "$row" ] && return 0

  dd_emit_block copyable-table "A URL or long copyable value sits inside a markdown table. The terminal wraps the cell, so copying it yields fragments joined by table borders. Give each copyable value its own fenced code block on its own line, outside the table; the table may name the item and refer to the block below it."
  return 0
}
