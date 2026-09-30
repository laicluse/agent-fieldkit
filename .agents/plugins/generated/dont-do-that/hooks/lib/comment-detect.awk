# State machine that walks source code character-by-character, tracking
# string and block-comment state, and emits one line per detected comment
# of the form LINE_NUMBER:COMMENT_BODY.
#
# Invocation:
#   awk -v MODE=slash -f comment-detect.awk < source.{ts,js,go,rs,swift,java,kt,c,cpp,cs}
#   awk -v MODE=hash  -f comment-detect.awk < source.{py,rb,sh,zsh,bash,pl,ex,exs,cr}
#
# MODE=slash recognises:
#   line block:   // ...
#   block block:  /* ... */ (spans newlines)
#   string types: "..." '...' `...` (template literal, spans newlines)
#   In NORMAL state, a backslash-then-anything sequence is consumed as a
#   pair so regex-literal escapes (/foo\/bar/) and stray backslashes do not
#   mis-trigger // comment detection on the trailing slash.
#   `//` only opens a comment when at the start of a line or preceded by
#   whitespace, so `http://foo` written as a bare expression does not get
#   mis-read as a comment whose body has lost the URL prefix.
#
# MODE=hash recognises:
#   line block:   # ...
#   string types: "..." '...' """...""" '''...'''
#   heredocs:     <<~TAG / <<-TAG / <<TAG / <<"TAG" / <<'TAG' (Ruby, shell)
#   A `#` only opens a comment when it sits at the start of a line or is
#   preceded by whitespace. `Recipes#create` (Ruby method notation) and
#   `$foo#bar` (bash parameter expansion in the wild) therefore do not fire,
#   even when an Edit snippet begins mid-string and the state machine has no
#   way to know we started inside one.
#   Heredoc bodies are shielded exactly like strings: a `#` at the start of
#   a heredoc body line (a Markdown heading, a shell comment in an embedded
#   script, a `# frozen` lookalike in templated Ruby) is content, not a
#   comment. An opener (`x = <<~HTML`) queues its terminator; every following
#   line is body until a line matching the terminator closes it. Multiple
#   heredocs on one line (`foo(<<~A, <<~B)`) queue in order. The squiggly
#   (`<<~`) and dash (`<<-`) forms allow an indented terminator; the bare
#   `<<` form requires the tag to start uppercase or `_`, or be quoted, so
#   left-shift (`arr << thing`) is not mistaken for a heredoc.
#
# MODE=ruby is MODE=hash plus the Ruby literals whose contents would
# otherwise knock the string tracking out of step:
#   interpolation: `#{...}` inside "...", /.../ and interpolating %-literals
#                  is code again, so a nested "..." there opens and closes
#                  its own string instead of closing the outer one. A stack
#                  of saved literal states supports any nesting depth.
#   regex:         `/.../` opens only where a value is expected (line start,
#                  after an operator or opening bracket, or after a keyword
#                  such as `if` or `when`), so `a / b` stays division.
#   %-literals:    %q %Q %w %W %i %I %r %s %x with any delimiter, and a bare
#                  `%(...)` where a value is expected; paired delimiters
#                  nest, so `a % b` stays modulo.
#
# Strings shield their contents from comment detection. Block comments stay
# open across newlines; the emitted body is the joined content with newlines
# replaced by a single space so consumers can compare bodies as flat strings.
# Trailing whitespace is stripped from every emitted body so block-comment
# closers on their own line do not introduce a body that differs only in
# end-of-line padding from an inline equivalent.

BEGIN {
  if (MODE == "") MODE = "slash"
  state = "NORMAL"
  block_start_line = 0
  block_buf = ""
  hd_lo = 0
  hd_hi = -1
  sp = 0
}

function hd_pending() {
  return hd_hi >= hd_lo
}

function push_interpolation(saved) {
  sp++
  save_state[sp] = saved
  save_open[sp] = pct_open
  save_close[sp] = pct_close
  save_nest[sp] = pct_nest
  save_interp[sp] = pct_interp
  brace[sp] = 0
  state = "NORMAL"
}

function pop_interpolation() {
  state = save_state[sp]
  pct_open = save_open[sp]
  pct_close = save_close[sp]
  pct_nest = save_nest[sp]
  pct_interp = save_interp[sp]
  sp--
}

function ruby_value_position(src, i,    before) {
  before = substr(src, 1, i - 1)
  sub(/[[:space:]]+$/, "", before)
  if (before == "") return 1
  if (before ~ /[(,=!~{|&?:;<>+*%[-]$/) return 1
  if (before ~ /(^|[^A-Za-z0-9_])(if|unless|elsif|when|and|or|not|return|while|until|in)$/) return 1
  return 0
}

function closing_delimiter(open) {
  if (open == "(") return ")"
  if (open == "[") return "]"
  if (open == "{") return "}"
  if (open == "<") return ">"
  return open
}

function ruby_percent_literal(src, i,    type, delim, width) {
  type = substr(src, i + 1, 1)
  if (type ~ /[qQwWiIrsx]/) {
    delim = substr(src, i + 2, 1)
    width = 3
  } else {
    if (!ruby_value_position(src, i)) return 0
    type = ""
    delim = substr(src, i + 1, 1)
    width = 2
    if (delim !~ /[({[<|!]/) return 0
  }
  if (delim == "" || delim ~ /[[:alnum:][:space:]]/) return 0
  pct_open = delim
  pct_close = closing_delimiter(delim)
  pct_nest = 0
  pct_interp = (type == "" || type ~ /[QWIrx]/)
  return width
}

{
  process_line($0)
  if (state == "BLOCK") block_buf = block_buf " "
}

END {
  if (state == "BLOCK") {
    sub(/[[:space:]]+$/, "", block_buf)
    print block_start_line ":" block_buf
  }
}

function process_line(src,    n, i, ch, nx, nx2, buf, trimmed, term, rest, c2, c3, quote, ident, after, ok, squig, width) {
  if (state == "NORMAL" && hd_pending()) {
    term = hd_term[hd_lo]
    trimmed = src
    sub(/[[:space:]]+$/, "", trimmed)
    if (hd_squiggly[hd_lo]) sub(/^[[:space:]]+/, "", trimmed)
    if (trimmed == term) {
      delete hd_term[hd_lo]
      delete hd_squiggly[hd_lo]
      hd_lo++
    }
    return
  }

  n = length(src)
  i = 1
  while (i <= n) {
    ch = substr(src, i, 1)
    nx = (i < n) ? substr(src, i+1, 1) : ""
    nx2 = (i+1 < n) ? substr(src, i+2, 1) : ""

    if (state == "BLOCK") {
      if (ch == "*" && nx == "/") {
        sub(/[[:space:]]+$/, "", block_buf)
        print block_start_line ":" block_buf
        block_buf = ""
        state = "NORMAL"
        i += 2
        continue
      }
      block_buf = block_buf ch
      i++
      continue
    }

    if (state == "STRING_DQ") {
      if (ch == "\\" && i < n) { i += 2; continue }
      if (MODE == "ruby" && ch == "#" && nx == "{") { push_interpolation("STRING_DQ"); i += 2; continue }
      if (ch == "\"") { state = "NORMAL"; i++; continue }
      i++
      continue
    }

    if (state == "REGEX") {
      if (ch == "\\" && i < n) { i += 2; continue }
      if (ch == "#" && nx == "{") { push_interpolation("REGEX"); i += 2; continue }
      if (ch == "/") { state = "NORMAL"; i++; continue }
      i++
      continue
    }

    if (state == "PERCENT") {
      if (ch == "\\" && i < n) { i += 2; continue }
      if (pct_interp && ch == "#" && nx == "{") { push_interpolation("PERCENT"); i += 2; continue }
      if (ch == pct_close) {
        if (pct_nest == 0) { state = "NORMAL"; i++; continue }
        pct_nest--
        i++
        continue
      }
      if (ch == pct_open && pct_open != pct_close) pct_nest++
      i++
      continue
    }

    if (state == "STRING_SQ") {
      if (ch == "\\" && i < n) { i += 2; continue }
      if (ch == "'")  { state = "NORMAL"; i++; continue }
      i++
      continue
    }

    if (state == "TEMPLATE") {
      if (ch == "\\" && i < n) { i += 2; continue }
      if (ch == "`") { state = "NORMAL"; i++; continue }
      i++
      continue
    }

    if (state == "TRIPLE_DQ") {
      if (ch == "\\" && i < n) { i += 2; continue }
      if (ch == "\"" && nx == "\"" && nx2 == "\"") {
        state = "NORMAL"; i += 3; continue
      }
      i++
      continue
    }

    if (state == "TRIPLE_SQ") {
      if (ch == "\\" && i < n) { i += 2; continue }
      if (ch == "'" && nx == "'" && nx2 == "'") {
        state = "NORMAL"; i += 3; continue
      }
      i++
      continue
    }

    if (MODE == "slash") {
      if (ch == "\\" && i < n) { i += 2; continue }
      if (ch == "/" && nx == "/" && (i == 1 || substr(src, i-1, 1) ~ /[[:space:]]/)) {
        buf = substr(src, i+2)
        sub(/[[:space:]]+$/, "", buf)
        print NR ":" buf
        return
      }
      if (ch == "/" && nx == "*") {
        state = "BLOCK"
        block_start_line = NR
        block_buf = ""
        i += 2
        continue
      }
      if (ch == "\"") { state = "STRING_DQ"; i++; continue }
      if (ch == "'")  { state = "STRING_SQ"; i++; continue }
      if (ch == "`")  { state = "TEMPLATE"; i++; continue }
      i++
      continue
    } else {
      if (MODE == "ruby") {
        if (sp > 0 && ch == "{") { brace[sp]++; i++; continue }
        if (sp > 0 && ch == "}") {
          if (brace[sp] == 0) { pop_interpolation(); i++; continue }
          brace[sp]--
          i++
          continue
        }
        if (ch == "/" && ruby_value_position(src, i)) { state = "REGEX"; i++; continue }
        if (ch == "%") {
          width = ruby_percent_literal(src, i)
          if (width) { state = "PERCENT"; i += width; continue }
        }
      }
      if (ch == "#" && (i == 1 || substr(src, i-1, 1) ~ /[[:space:]]/)) {
        buf = substr(src, i+1)
        sub(/[[:space:]]+$/, "", buf)
        print NR ":" buf
        return
      }
      if (ch == "\"" && nx == "\"" && nx2 == "\"") {
        state = "TRIPLE_DQ"
        i += 3
        continue
      }
      if (ch == "'" && nx == "'" && nx2 == "'") {
        state = "TRIPLE_SQ"
        i += 3
        continue
      }
      if (ch == "\"") { state = "STRING_DQ"; i++; continue }
      if (ch == "'")  { state = "STRING_SQ"; i++; continue }
      if (ch == "<" && nx == "<") {
        rest = substr(src, i + 2)
        squig = 0
        if (substr(rest, 1, 1) == "~" || substr(rest, 1, 1) == "-") {
          squig = 1
          rest = substr(rest, 2)
        }
        quote = ""
        c3 = substr(rest, 1, 1)
        if (c3 == "\"" || c3 == "'" || c3 == "`") {
          quote = c3
          rest = substr(rest, 2)
        }
        if (match(rest, /^[A-Za-z_][A-Za-z0-9_]*/)) {
          ident = substr(rest, 1, RLENGTH)
          after = substr(rest, RLENGTH + 1, 1)
          ok = 0
          if (squig) ok = 1
          else if (quote != "") ok = 1
          else if (ident ~ /^[A-Z_]/) ok = 1
          if (ok && (quote == "" || after == quote)) {
            hd_hi++
            hd_term[hd_hi] = ident
            hd_squiggly[hd_hi] = squig
            i += 2 + squig + (quote != "" ? 2 : 0) + RLENGTH
            continue
          }
        }
        i += 2
        continue
      }
      i++
      continue
    }
  }
}
