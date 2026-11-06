#!/bin/bash
# PreToolUse:Bash guard. A symlinked dependency directory makes a checkout run another checkout's installed packages, and an install through the link rewrites that other checkout.

guard_no_shared_dependency_link() {
  local input="$1"
  local cmd segment dir_pattern
  cmd=$(jq -r '.tool_input.command // empty' <<< "$input" 2>/dev/null)
  [ -z "$cmd" ] && return 0

  dir_pattern="(^|[[:space:]/\"'])(node_modules|\.venv|vendor/bundle)/?([[:space:]\"']|$)"
  while IFS= read -r segment; do
    segment="${segment#"${segment%%[![:space:]]*}"}"
    [[ "$segment" =~ ^([^[:space:]]*/)?ln[[:space:]] ]] || continue
    [[ " $segment " =~ [[:space:]](-[a-zA-Z]*s[a-zA-Z]*|--symbolic)[[:space:]] ]] || continue
    [[ "$segment" =~ $dir_pattern ]] || continue
    dd_emit_deny no-shared-dependency-link "symlinking a dependency directory (${BASH_REMATCH[2]}) blocked: the checkout would run the other checkout's installed packages instead of its own lockfile, and an install through the link rewrites the other checkout. Install dependencies in this checkout instead (bonsai does this for worktrees)."
    return 0
  done < <(printf '%s' "$cmd" | awk -v sq="'" 'BEGIN { RS = "\001" } {
    out = ""; q = ""
    for (i = 1; i <= length($0); i++) {
      c = substr($0, i, 1)
      if (c == "\\" && q != sq) {
        n = substr($0, i + 1, 1)
        out = out (n == "\n" ? " " : c n)
        i++
        continue
      }
      if (q == "" && (c == "\"" || c == sq)) q = c
      else if (c == q) q = ""
      if (index(";&|()\n", c)) c = (q == "" ? "\n" : " ")
      out = out c
    }
    print out
  }')
}
