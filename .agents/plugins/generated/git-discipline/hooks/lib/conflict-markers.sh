#!/bin/bash
# packages/git-discipline/hooks/lib/conflict-markers.sh
#
# Shared detection for leftover conflict markers in tracked files. Sourced by both
# the PreToolUse:Bash guard (hooks/guards/merge-conflict-markers.sh) and the
# git-native commit-msg hook, so the two enforcement paths cannot drift.
#
# Detection unions `git diff --check` (working tree vs index) and `--cached`
# (index vs HEAD): the first catches unstaged markers, the second catches a
# marker-bearing file that was `git add`-ed before committing (the case that broke
# a live checkout and prompted this guard).
#
# Functions never exit; callers decide how to surface the verdict.
#   conflict_markers_find_files                          -> unique dirty files, one per line; empty = clean
#   conflict_markers_escape_active <bash-command-or-empty> -> 0 when an escape is active (see below)
#   conflict_markers_format_message <files-newline-list> -> human message naming the files + escapes

_conflict_markers_setext_underline() {
  local file="$1" heading="$2" underline="$3"
  [[ "$file" =~ \.(md|markdown|mdx)$ ]] \
    && [[ "$underline" =~ ^=+[[:space:]]*$ ]] \
    && [[ "$heading" =~ [^[:space:]] ]] \
    && ! [[ "$heading" =~ ^(<{7}|={7}|>{7}|\|{7})( |$) ]] \
    && ! [[ "$heading" =~ ^\ {0,3}(#{1,6}([[:space:]]|$)|\`\`\`|~~~) ]]
}

_conflict_markers_unambiguous() {
  local version="$1" top entry file line lines fences
  top=$(git rev-parse --show-toplevel 2>/dev/null)
  grep -F ': leftover conflict marker' \
    | while IFS= read -r entry; do
        [[ "$entry" =~ ^(.*):([0-9]+):\ leftover\ conflict\ marker$ ]] || continue
        file="${BASH_REMATCH[1]}"
        line="${BASH_REMATCH[2]}"
        if [[ "$version" == index ]]; then
          lines=$(git show ":$file" 2>/dev/null | sed -n "1,${line}p")
        else
          lines=$(sed -n "1,${line}p" "$top/$file" 2>/dev/null)
        fi
        fences=$(head -n "$((line - 1))" <<< "$lines" | grep -cE '^ {0,3}(```|~~~)')
        (( fences % 2 == 0 )) \
          && _conflict_markers_setext_underline "$file" "$(sed -n "$((line - 1))p" <<< "$lines" 2>/dev/null)" "$(tail -n 1 <<< "$lines")" \
          || printf '%s\n' "$file"
      done
}

conflict_markers_find_files() {
  # `|| true`: grep exits 1 on the (common) no-marker case; without it the
  # pipeline's non-zero status would surface under a caller's set -o pipefail.
  {
    git -c diff.relative=false diff --check 2>/dev/null | _conflict_markers_unambiguous worktree
    git -c diff.relative=false diff --cached --check 2>/dev/null | _conflict_markers_unambiguous index
  } | LC_ALL=C sort -u || true
}

conflict_markers_escape_active() {
  local command="${1:-}"
  if [[ "${GIT_DISCIPLINE_ALLOW_CONFLICT_MARKERS:-0}" = "1" ]]; then
    return 0
  fi
  if [[ -n "$command" ]] && grep -qF '# allow-conflict-markers' <<< "$command"; then
    return 0
  fi
  return 1
}

conflict_markers_format_message() {
  local files="$1"
  local out=""
  out+=$'conflict resolution incomplete: conflict markers remain in tracked files:\n'
  local f
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    out+="  ${f}"$'\n'
  done <<< "$files"
  out+=$'\nResolve every conflict region (the <<<<<<< / ======= / >>>>>>> lines) before\n'
  out+=$'finalizing the merge so a half-resolved merge cannot land in a live checkout.\n'
  out+=$'Escapes (rare, e.g. a deliberate fixture):\n'
  out+=$'  export GIT_DISCIPLINE_ALLOW_CONFLICT_MARKERS=1   (any commit: terminal or Claude)\n'
  out+=$'  append  # allow-conflict-markers  to the command (only when Claude runs it)\n'
  printf '%s' "$out"
}
