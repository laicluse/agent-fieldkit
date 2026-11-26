#!/bin/bash
# allow-comment: single source for "which long-lived process holds this session's locks". Sourced by hooks/occupancy.sh (claim + SessionEnd release) and by the undibs skill (manual sweep), so claim time and release time agree on the same pid. DIBS_HOLDER_PID overrides; else walk to the NEAREST claude/codex ancestor (not topmost: a codex nested in a claude session must resolve to the codex). Fall back to the start pid.
dibs_holder_pid() {
  local start="${1:-$PPID}"
  if [ -n "${DIBS_HOLDER_PID:-}" ] && [ "${DIBS_HOLDER_PID}" -gt 0 ] 2>/dev/null; then
    printf '%s\n' "$DIBS_HOLDER_PID"
    return 0
  fi
  local pid="$start" hops=0 comm parent match=""
  while [ -n "$pid" ] && [ "$pid" -gt 1 ] 2>/dev/null && [ "$hops" -lt 30 ]; do
    comm=$(ps -o comm= -p "$pid" 2>/dev/null)
    case "$comm" in
      *[Cc]laude*|*[Cc]odex*) match="$pid"; break ;;
    esac
    local executable
    if [ -r "/proc/$pid/cmdline" ] && IFS= read -r -d '' executable < "/proc/$pid/cmdline"; then
      case "${executable##*/}" in
        *[Cc]laude*|*[Cc]odex*) match="$pid"; break ;;
      esac
    fi
    parent=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
    [ -z "$parent" ] && break
    pid="$parent"
    hops=$((hops + 1))
  done
  if [ -n "$match" ]; then
    printf '%s\n' "$match"
  elif [ "$start" -gt 0 ] 2>/dev/null; then
    printf '%s\n' "$start"
  else
    printf '%s\n' "$PPID"
  fi
}
