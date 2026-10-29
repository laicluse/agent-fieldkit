#!/bin/bash
# allow-comment: PreToolUse:Bash guard. Denies an rm whose arguments expand a variable without the ${VAR:?} guard or a command substitution, such as rm -f $D/*.png. Claude Code asks the operator for permission on such a command because an empty variable would widen the path, so an unattended session stalls and auto-denies. Single-quoted and escaped text, comments and heredoc bodies are data and are skipped.

# allow-comment: dd_rm_unguarded_args <text> prints the arguments of the first rm that expands an unguarded variable or a command substitution. A character scanner follows quoting, escapes, comments, line continuations and heredocs, and splits simple commands on ; & | ( ) ` and newlines; a redirection target is not an argument. A command counts as rm when rm is its first word after env assignments, a keyword such as then or do, and sudo, command, exec, nohup, time or xargs with its options; find -exec rm counts too.
dd_rm_unguarded_args() {
  awk '
    function flag_var(pos,   rest) {
      rest = substr(text, pos)
      if (rest ~ /^\$\{[A-Za-z_][A-Za-z0-9_]*:\?/) return
      if (rest ~ /^\$(\{?[A-Za-z_]|[0-9@*])/ || (rest ~ /^\$\(/ && rest !~ /^\$\(\(/)) wordvar = 1
    }
    function end_word() {
      if (word != "" && redir) redir = 0
      else if (word != "") { wc++; W[wc] = word; V[wc] = wordvar }
      word = ""; wordvar = 0
    }
    function report(from, to,   j, out) {
      out = ""
      for (j = from; j <= to; j++) out = out " " W[j]
      print out; found = 1
    }
    function check_rm(k,   j, last) {
      for (j = k + 1; j <= wc; j++) if (V[j]) { report(k + 1, wc); return }
    }
    function end_cmd(   k, j) {
      end_word()
      k = 1
      while (k <= wc && (W[k] ~ /^[A-Za-z_][A-Za-z0-9_]*=/ || W[k] ~ /^(then|do|else|elif|if|while|until|!|\{|sudo|command|exec|nohup|time)$/)) k++
      if (W[k] == "xargs") {
        k++
        while (k <= wc && W[k] ~ /^-/) { if (W[k] ~ /^-[IinPLsdEJ]$/) k++; k++ }
      }
      if (W[k] == "rm") check_rm(k)
      else if (W[k] == "find") {
        for (j = k + 1; j < wc; j++) if (W[j] ~ /^-exec(dir)?$/ && W[j + 1] == "rm") {
          last = j + 2
          while (last <= wc && W[last] != "\\;" && W[last] != ";" && W[last] != "+") last++
          for (k = j + 2; k < last; k++) if (V[k]) { report(j + 2, last - 1); break }
        }
      }
      wc = 0; redir = 0
    }
    { lines[NR] = $0 }
    END {
      text = ""
      for (l = 1; l <= NR; l++) text = text lines[l] (l < NR ? "\n" : "")
      gsub(/\\\n/, " ", text)
      n = length(text); sq = 0; dq = 0; wc = 0; word = ""; wordvar = 0; ntags = 0; found = 0
      for (i = 1; i <= n && !found; i++) {
        c = substr(text, i, 1)
        if (sq) { word = word c; if (c == "\047") sq = 0; continue }
        if (c == "\\") { word = word c substr(text, i + 1, 1); i++; continue }
        if (dq) {
          if (c == "\"") dq = 0
          else if (c == "$") flag_var(i)
          word = word c; continue
        }
        if (c == "\047") { sq = 1; word = word c; continue }
        if (c == "\"") { dq = 1; word = word c; continue }
        if (c == "$" && substr(text, i + 1, 2) == "((") {
          close_at = index(substr(text, i), "))")
          if (close_at) { word = word substr(text, i, close_at + 1); i += close_at; continue }
        }
        if (c == "$") { flag_var(i); word = word c; continue }
        if (c == ">" || (c == "<" && substr(text, i + 1, 1) != "<")) {
          end_word()
          while (substr(text, i + 1, 1) ~ /[>&|]/) i++
          redir = 1; continue
        }
        if (c == " " || c == "\t") { end_word(); continue }
        if (c == "#" && word == "") { while (i < n && substr(text, i + 1, 1) != "\n") i++; continue }
        if (c == "<" && substr(text, i + 1, 1) == "<" && substr(text, i + 2, 1) != "<") {
          rest = substr(text, i + 2)
          if (match(rest, /^-?[ \t]*["\047]?[A-Za-z_][A-Za-z0-9_]*["\047]?/)) {
            tag = substr(rest, 1, RLENGTH)
            sub(/^-?[ \t]*["\047]?/, "", tag); sub(/["\047]$/, "", tag)
            tags[++ntags] = tag
            i += 1 + RLENGTH; continue
          }
        }
        if (c == "\n") {
          end_cmd()
          for (t = 1; t <= ntags; t++) {
            while (i < n) {
              rest = substr(text, i + 1); eol = index(rest, "\n")
              line = eol ? substr(rest, 1, eol - 1) : rest
              i += eol ? eol : length(rest)
              sub(/^\t+/, "", line)
              if (line == tags[t]) break
            }
          }
          ntags = 0; continue
        }
        if (c ~ /[;&|()`]/) { end_cmd(); continue }
        word = word c
      }
      if (!found) end_cmd()
    }
  ' <<< "$1"
}

guard_rm_unguarded_var() {
  local input="$1" cmd args
  cmd=$(jq -r '.tool_input.command // empty' <<< "$input" 2>/dev/null)
  [ -z "$cmd" ] && return 0
  case "$cmd" in *rm*'$'*) ;; *) return 0 ;; esac
  grep -q -- '# allow-rm-var' <<< "$cmd" && return 0
  args=$(dd_rm_unguarded_args "$cmd")
  [ -z "$args" ] && return 0

  dd_emit_deny rm-unguarded-var "rm on an unguarded variable path blocked:${args}. An empty variable or substitution would widen the path, so Claude Code asks the operator for permission and an unattended session stalls. Write each variable as \"\${D:?}\" (for example rm -f \"\${D:?}\"/*.png), assign a substitution to a variable first, or use a literal path."
}
