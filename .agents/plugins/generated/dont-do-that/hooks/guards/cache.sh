#!/bin/bash
# Stop guard. Blocks cache-as-cause rationalisations on localhost.

guard_cache() {
  local input="$1"
  local text
  text=$(dd_assistant_text "$input" 2000 "cache-guard")
  [ -z "$text" ] && return 0
  dd_is_wip "$text" && return 0

  echo "$text" \
    | grep -qiE "(het probleem is|komt door|ligt aan|veroorzaakt door|schuld van).*(cache|gecachet)|(cache|gecachet).*(stale|verouderd|invalide|probleem|oorzaak)|wacht.*(cache|10 minuten).*invalideer|browser.*(cache|gecachet|oude.*versie)|hard.refresh|Cmd.*Shift.*R|esbuild.*watcher.*(niet|cache)|oude.*\b(JS|javascript|bundle|assets)\b" \
    || return 0

  # A clean profile that behaves differently is evidence, not a rationalisation.
  echo "$text" | grep -qiE "incognito|privévenster|private window|schoon profiel|clean profile" && return 0

  dd_emit_block cache "Cache is not the cause on localhost. Find the actual root cause; only a clean profile (incognito) that behaves differently shows otherwise."
}
