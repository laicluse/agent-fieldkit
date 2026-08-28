#!/bin/bash
# Shared body validator for git-discipline commit-discipline enforcement.
# Called by the PreToolUse:Bash guard (commit-body.sh), the git-native
# commit-msg hook, and the prepare-commit-msg hook.
#
# Interface:
#   validate_body <commit-msg-file-path>
#     exit 0: validated OK, nothing on stdout
#     exit 1: violation; diagnostic on stderr (format: "<code>: <detail>")
#     exit 2: file unreadable or not a commit message; skip non-blocking
#
#   validate_body_classify_skip <subject>
#     exit 0: subject matches a skip pattern (Merge / Revert / fixup! / squash! / amend!)
#     exit 1: subject does not match any skip pattern

# Note: no "set -euo pipefail" here. This file is sourced as a library by
# dispatch.sh, git hooks, and test harnesses. Caller shells already control
# their own errexit/pipefail; setting it here would cause "read -r" at EOF
# (exit 1) and other expected non-zero returns to abort the sourcing shell.
# All errors are handled explicitly via conditional checks below.

_VB_LIB_DIR_CTX="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
. "$_VB_LIB_DIR_CTX/vb-context.sh"

# ---------------------------------------------------------------------------
# Skip-pattern classifier
# ---------------------------------------------------------------------------

# validate_body_classify_skip <subject>
# Returns 0 (match) if the subject starts with a well-known auto-generated
# prefix that should bypass body validation entirely, or if the subject
# contains the standard git cherry-pick trailer phrase.
validate_body_classify_skip() {
  local subject="$1"
  if [[ "$subject" =~ ^(Merge\ |Revert\ |fixup\!|squash\!|amend\!) ]]; then
    return 0
  fi
  # Cherry-pick commits: git appends "(cherry picked from commit <sha>)" to
  # the subject when using `git cherry-pick -x`. Match that standard phrase.
  if [[ "$subject" == *"(cherry picked from commit "* ]]; then
    return 0
  fi
  return 1
}

# allow-comment: validate_body_has_rebase_skip <content> returns 0 when the body
# allow-comment: carries a `Discipline:` trailer whose value begins with `skip`
# allow-comment: (the rebase carry-along marker). A rebase rewrites every commit
# allow-comment: it replays, so the stamper amends this trailer onto commits
# allow-comment: whose subject-only bodies predate the discipline; the marker
# allow-comment: then exempts them so a force-push does not re-litigate
# allow-comment: already-shipped commits. Honoured inside validate_body so every
# allow-comment: enforcement path inherits it from one source.
validate_body_has_rebase_skip() {
  local content="$1"
  local trailers value
  trailers=$(_vb_trailers "$content")
  value=$(_vb_trailer_value "$trailers" "Discipline")
  [[ "$value" == skip* ]]
}

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

# _vb_sha1 <text>
# Emit the SHA-1 hex digest of the given text (normalised: trimmed,
# whitespace collapsed). Falls back gracefully if sha1sum is absent.
_vb_sha1() {
  local text="$1"
  local normalised
  normalised=$(printf '%s' "$text" | tr -s '[:space:]' ' ' | sed 's/^ //;s/ $//')
  if command -v sha1sum >/dev/null 2>&1; then
    printf '%s' "$normalised" | sha1sum | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    printf '%s' "$normalised" | shasum -a 1 | awk '{print $1}'
  else
    # Cannot compute SHA1; return empty so the duplicate-why check is skipped.
    printf ''
  fi
}

# _vb_log_skip <label> <reason>
# Append a skip-log entry to ${LAICLUSE_HOME:-~/.laicluse}/git-discipline/git-discipline-skips.log.
_vb_log_skip() {
  local label="$1"
  local reason="$2"
  local log_dir="${LAICLUSE_HOME:-$HOME/.laicluse}/git-discipline"
  local log_file="$log_dir/git-discipline-skips.log"
  # Create dir if it does not exist.  The Write-tool note says never use
  # mkdir; this is runtime bash, not a repo file, so mkdir -p is fine here.
  mkdir -p "$log_dir"
  local branch
  branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || printf 'unknown')
  printf '%s|%s|%s\n' "$label" "$branch" "$reason" >> "$log_file"
}

# _vb_trailers <commit-msg-content>
# Parse trailers using git interpret-trailers --parse.
# Returns "Key: Value" lines on stdout.
_vb_trailers() {
  local content="$1"
  # git interpret-trailers requires a file or stdin.
  git interpret-trailers --parse <<< "$content" 2>/dev/null || true
}

# _vb_trailer_value <trailers-text> <key>
# Extract the value of the first matching trailer (case-insensitive key match).
_vb_trailer_value() {
  local trailers="$1"
  local key="$2"
  grep -i "^${key}:[[:space:]]*" <<< "$trailers" | head -1 | sed "s/^[^:]*:[[:space:]]*//" || true
}

# _vb_why_block <commit-msg-content> <trailers-text>
# Extract the WHY block: everything between the subject+blank-line and the
# start of the trailer block (or end of message if no trailers).
_vb_why_block() {
  local content="$1"
  local trailers="$2"

  # Strip subject line and the following blank line.
  local body
  body=$(printf '%s' "$content" | tail -n +3)

  if [[ -z "$trailers" ]]; then
    printf '%s' "$body"
    return 0
  fi

  # Find the first trailer line in the body and cut before it.
  # Build a pattern from the first trailer key.
  local first_trailer_line
  first_trailer_line=$(printf '%s' "$trailers" | head -1)
  local first_key
  first_key=$(printf '%s' "$first_trailer_line" | sed 's/:.*//')

  # Remove the trailer block from the body.
  local why
  why=$(printf '%s' "$body" | awk -v key="$first_key" '
    BEGIN { found=0 }
    tolower($0) ~ tolower("^" key ":") { found=1 }
    !found { print }
  ')
  # Strip trailing blank lines.
  why=$(printf '%s' "$why" | sed '/^[[:space:]]*$/{ H; d }; /[^[:space:]]/{ P; D }' 2>/dev/null \
        || printf '%s' "$why")
  printf '%s' "$why"
}

# UI-touch heuristic lives in its own lib so example-synth.sh and
# prepare-commit-msg can source the helper without dragging in the full
# validator. Provides _vb_ui_touched_files and _vb_is_ui_touch.
_VB_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
# shellcheck disable=SC1091
. "$_VB_LIB_DIR/published-commit.sh"
# shellcheck disable=SC1091
. "$_VB_LIB_DIR/ui-touch.sh"

# ---------------------------------------------------------------------------
# Main validator
# ---------------------------------------------------------------------------

# validate_body <commit-msg-file-path>
# allow-comment: batched-error contract. Every batchable trailer/body check
# allow-comment: accumulates into _vb_errors[] (defined after the early returns)
# allow-comment: and all violations are emitted on stderr in one block at the
# allow-comment: end of the call. Terminal early-returns are reserved for cases
# allow-comment: that make downstream checks moot: unreadable file (return 2),
# allow-comment: empty/no-subject (return 2), skip patterns + cherry-pick + trivial
# allow-comment: single-line (return 0), and the structural single-error states
# allow-comment: (vsd-skip-removed, single-line missing-body, review-pass-batch)
# allow-comment: that block further validation regardless of other failures.
validate_body() {
  local msg_file="$1"

  # exit 2: file unreadable or empty.
  if [[ ! -f "$msg_file" ]] || [[ ! -r "$msg_file" ]]; then
    printf 'unreadable-file: commit message file not found or not readable\n' >&2
    return 2
  fi

  local content
  content=$(cat "$msg_file")

  # Strip comment lines (lines starting with #) that git inserts.
  content=$(printf '%s' "$content" | grep -v '^#' || true)

  if [[ -z "$content" ]]; then
    printf 'empty-message: commit message is empty\n' >&2
    return 2
  fi

  # Rule: the legacy `# vsd-skip: <reason>` magic comment is no longer an
  # escape. The strict commit-discipline rules apply to every commit; reject
  # the comment so commits that relied on it surface clearly instead of
  # silently passing under the old lenient mode.
  if printf '%s' "$(cat "$msg_file")" | grep -qE '^#[[:space:]]*vsd-skip:'; then
    printf 'vsd-skip-removed: the "# vsd-skip" magic comment is no longer accepted. Fill in the schema trailers (Tests / Slice / Red-then-green / Verified, and Visual when UI files are touched).\n' >&2
    return 1
  fi

  # Parse subject (first non-empty line).
  local subject
  subject=$(printf '%s' "$content" | head -1)

  # exit 2: looks like a template or empty subject.
  if [[ -z "$subject" ]]; then
    printf 'empty-subject: first line of commit message is empty\n' >&2
    return 2
  fi

  # Rule: skip-pattern check (subject-level).
  if validate_body_classify_skip "$subject"; then
    return 0
  fi

  # Rule: cherry-pick detection in body. git cherry-pick -x appends the
  # "(cherry picked from commit <sha>)" line to the body, not just the subject.
  # When the body contains this phrase on its own line, skip validation.
  if printf '%s' "$content" | grep -qF '(cherry picked from commit '; then
    return 0
  fi

  # allow-comment: rebase carry-along. A `Discipline: skip ...` trailer is the
  # allow-comment: explicit opt-out for commits whose bodies predate the
  # allow-comment: discipline and were rewritten by a rebase; skip the schema and
  # allow-comment: log the bypass so it stays auditable.
  if validate_body_has_rebase_skip "$content"; then
    _vb_log_skip "discipline-skip" "rebase carry-along"
    return 0
  fi

  # Determine if this is a single-line commit (no body lines after subject).
  local body_lines
  body_lines=$(printf '%s' "$content" | tail -n +2 | grep -v '^[[:space:]]*$' || true)
  local is_single_line=0
  if [[ -z "$body_lines" ]]; then
    is_single_line=1
  fi

  # Rule: single-line commit requires either GIT_DISCIPLINE_TRIVIAL_OK=1 or a body.
  if [[ "$is_single_line" -eq 1 ]]; then
    if [[ "${GIT_DISCIPLINE_TRIVIAL_OK:-0}" = "1" ]]; then
      return 0
    fi
    printf 'missing-body: subject-only commits require body or trivial flag from caller\n' >&2
    return 1
  fi

  # Parse trailers.
  local trailers
  trailers=$(_vb_trailers "$content")

  # Extract WHY block.
  local why_block
  why_block=$(_vb_why_block "$content" "$trailers")

  # Rule: a commit body that names a review pass (pride pass, end-user
  # pass, technical pass, review pass, review findings) is a review-pass
  # commit. Those commits tend to bundle multiple unrelated findings
  # behind one subject, which makes the resulting history hard to revert
  # or read by finding. The check counts bullet-list lines in the WHY
  # block; two or more bullets in a review-pass commit signals batched
  # findings and is rejected. The author should split into one commit
  # per finding. A review-pass commit that addresses exactly one
  # finding has no list at all (the WHY paragraph names the finding
  # in prose) and passes through.
  local why_lower
  why_lower=$(printf '%s' "$why_block" | tr '[:upper:]' '[:lower:]')
  local review_pass_re='(pride pass|end-user pass|technical pass|review pass|review findings|pride contrarian|review contrarian)'
  if [[ "$why_lower" =~ $review_pass_re ]]; then
    local bullet_count
    bullet_count=$(printf '%s\n' "$why_block" | grep -cE '^[[:space:]]*[-*][[:space:]]' || true)
    if [[ "$bullet_count" -ge 2 ]]; then
      printf 'review-pass-batch: WHY block names a review pass and lists %s findings as bullets. Split into one commit per finding so each fate (fix, second-pass reject) is its own reviewable change. Rewrite the WHY in prose for a single finding, or remove the review-pass keyword if this is not a review-pass commit.\n' "$bullet_count" >&2
      return 1
    fi
  fi

  # allow-comment: batched-error accumulator. Each schema check below calls
  # allow-comment: _vb_err to push a "<code>: <message>" line onto _vb_errors[]
  # allow-comment: rather than emitting + returning. The block at the bottom of
  # allow-comment: validate_body emits every accumulated line on stderr and
  # allow-comment: returns 1 if any landed.
  local _vb_errors=()
  _vb_err() { _vb_errors+=("$1"); }
  # allow-comment: path-existence checks (Tests/Red-then-green/Visual/Verified
  # allow-comment: paths resolving against the live tree or the filesystem) only
  # allow-comment: hold at commit time, where the context is the staged area or
  # allow-comment: HEAD (an --amend). The push-body-gate re-walks historical
  # allow-comment: commits with context=<sha>, where a /tmp screenshot is long
  # allow-comment: gone and a moved spec is a false positive; skip them there.
  # allow-comment: Structural checks (subject, WHY, trailer presence, path
  # allow-comment: format, n/a rationale) still run in every context.
  local at_commit_time=0
  case "${GIT_DISCIPLINE_VALIDATE_CONTEXT:-staged}" in
    staged|HEAD|head) at_commit_time=1 ;;
  esac
  # allow-comment: hash literal used in printf format args. The comment-detect
  # allow-comment: hook tokenizer false-positives on a bare # in nested quotes,
  # allow-comment: so the literal is passed via %s instead of inlined.
  local _vb_hash='#'
  # allow-comment: closed-enum category regex shared by the Visual: n/a and
  # allow-comment: Verified: n/a rationale checks. Defined once so a future
  # allow-comment: new category lands in one edit rather than two adjacent
  # allow-comment: regexes that drift independently.
  local _vb_category_re='(extract[ -]?only|accessibility[ -]?only|accessibility metadata|debug[ -]?only|spec[ -]?only|test[ -]?only|copy[ -]?only|copy change|metadata[ -]?only|no behaviour change|no behavior change|no visual change|no ui change|no visual impact|no ui impact|byte[ -]?identical|render unchanged|pixel[ -]?identical|backend (rewrite|only)|no ui touched|sound[ -]?only|audio[ -]?only|log[ -]?only|telemetry[ -]?only)'

  # Extract trailer values.
  local slice_value
  slice_value=$(_vb_trailer_value "$trailers" "Slice")

  local tests_value
  tests_value=$(_vb_trailer_value "$trailers" "Tests")

  local rtg_value
  rtg_value=$(_vb_trailer_value "$trailers" "Red-then-green")
  # Defensive trailing-whitespace strip: a copy-pasted trailer with a
  # trailing space would otherwise widen the captured path past its real
  # name, producing a path-not-in-staged diagnostic that does not name the
  # actual cause.
  rtg_value=$(printf '%s' "$rtg_value" | sed 's/[[:space:]]*$//')

  # Opt-out enum tokens. spec-only added: commits touching only spec/test
  # files don't need a Tests trailer (the diff is itself the test evidence).
  local OPT_OUT_ENUM="docs-only config-only migration-only spec-only chore-deps revert merge wip"

  # RTG-exempt tokens (subset of opt-out that also exempts Red-then-green).
  # migration-only and spec-only are exempt: a migration has no meaningful
  # red-then-green sequence; a spec-only commit is the red (the spec was
  # written first and drives the implementation in the next commit).
  local RTG_EXEMPT="docs-only config-only migration-only spec-only chore-deps"

  # Rule: Slice trailer must be present and non-empty.
  if [[ -z "$slice_value" ]]; then
    local missing_slice_message='missing-slice: Slice trailer is absent or empty'
    if grep -qiE '^[[:space:]]*Slice:[[:space:]]*[^[:space:]]' <<< "$content"; then
      missing_slice_message+='. A Slice line exists in the message text but git interpret-trailers did not parse it, usually because multiple -m flags or blank lines split the trailer block. Keep Tests, Slice, Red-then-green, Verified, and Visual lines contiguous at the bottom of one heredoc commit message.'
    fi
    _vb_err "$missing_slice_message"
  fi

  # Determine if Slice value is an opt-out token.
  local slice_is_optout=0
  local token
  for token in $OPT_OUT_ENUM; do
    if [[ "$slice_value" = "$token" ]]; then
      slice_is_optout=1
      break
    fi
  done

  # Rule: free-text Slice must be at least 10 chars to carry meaningful context.
  # allow-comment: track whether Slice is structurally invalid (missing or
  # allow-comment: too-short). Used downstream to suppress derivative Tests/
  # allow-comment: RTG/Verified errors that would all disappear once Slice
  # allow-comment: is fixed; symmetric with the missing-slice suppression.
  local slice_invalid=0
  [[ -z "$slice_value" ]] && slice_invalid=1
  if [[ -n "$slice_value" ]] && [[ "$slice_is_optout" -eq 0 ]] && [[ ${#slice_value} -lt 10 ]]; then
    _vb_err "$(printf 'slice-too-short: free-text Slice must be at least 10 chars (got: "%s")' "$slice_value")"
    slice_invalid=1
  fi

  # Determine if Slice value is RTG-exempt.
  local slice_is_rtg_exempt=0
  for token in $RTG_EXEMPT; do
    if [[ "$slice_value" = "$token" ]]; then
      slice_is_rtg_exempt=1
      break
    fi
  done

  # allow-comment: when Slice is missing entirely, suppress dependent checks
  # allow-comment: (missing-tests, missing-RTG, missing-verified) so the
  # allow-comment: operator does not see derivative errors that disappear
  # allow-comment: as soon as the Slice trailer lands. missing-slice already
  # allow-comment: surfaced above; fix that first, downstream checks fire on
  # allow-comment: retry when they apply.
  if [[ "$slice_invalid" -eq 0 && "$slice_is_optout" -eq 0 ]]; then
    if [[ -z "$tests_value" ]]; then
      _vb_err 'missing-tests: Tests trailer is absent; required when Slice is not an opt-out token'
    else
      # Rule: at least one Tests path must exist in HEAD tree or staged diff.
      local tests_ok=0
      local path

      # Collect paths from Tests value (comma- or newline-separated).
      local tests_paths
      tests_paths=$(printf '%s' "$tests_value" | tr ',' '\n' | sed 's/^[[:space:]]*//' | grep -v '^$' || true)

      # Build HEAD tree listing (best-effort; may fail on initial commit).
      local head_tree=""
      head_tree=$(git ls-tree -r HEAD --name-only 2>/dev/null || true)

      # Build staged diff listing.
      local staged_files=""
      staged_files=$(_vb_delta_files)

      while IFS= read -r path; do
        # Strip anchor suffixes like #method_name.
        local clean_path="${path%%#*}"
        clean_path="${clean_path%%,*}"
        clean_path=$(printf '%s' "$clean_path" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        [[ -z "$clean_path" ]] && continue

        if grep -qF "$clean_path" <<< "$head_tree" 2>/dev/null \
           || grep -qF "$clean_path" <<< "$staged_files" 2>/dev/null; then
          tests_ok=1
          break
        fi
      done <<< "$tests_paths"

      # Validate path format for at least one entry.
      local path_re='[a-zA-Z0-9_./ -]+\.(rb|py|js|ts|go|rs|sh|bash|bats|feature|tsx|jsx|swift)$'
      local has_valid_format=0
      while IFS= read -r path; do
        local clean_path="${path%%#*}"
        clean_path=$(printf '%s' "$clean_path" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        [[ -z "$clean_path" ]] && continue
        if [[ "$clean_path" =~ $path_re ]]; then
          has_valid_format=1
          break
        fi
      done <<< "$tests_paths"

      if [[ "$has_valid_format" -eq 0 ]]; then
        _vb_err 'missing-tests: Tests trailer contains no valid path (expected e.g. spec/foo_spec.rb)'
      fi

      if [[ "$at_commit_time" -eq 1 && "$tests_ok" -eq 0 ]]; then
        _vb_err 'tests-path-not-found: no Tests path exists in HEAD tree or staged diff'
      fi
    fi
  fi

  # Rule: Red-then-green required unless Slice is RTG-exempt.
  # allow-comment: gated on slice_value presence so a missing-slice does not
  # allow-comment: cascade into a derivative missing-red-then-green.
  if [[ "$slice_invalid" -eq 0 && "$slice_is_rtg_exempt" -eq 0 ]]; then
    if [[ -z "$rtg_value" ]]; then
      _vb_err 'missing-red-then-green: Red-then-green trailer is absent; required for this Slice type'
    elif [[ "$rtg_value" = "yes" ]]; then
      _vb_err 'red-then-green-bare-yes: bare "yes" is no longer accepted. Name the spec that was seen red as "<path>" or path:line followed by hash and test name (the path must appear in the staged diff, the line must exist in the staged file, and the test name must match a test declaration). n/a (reason >= 10 chars) remains valid when no red-then-green sequence applies.'
    elif [[ "$rtg_value" =~ ^n/a[[:space:]]*\((.+)\)$ ]]; then
      local rationale="${BASH_REMATCH[1]}"
      if [[ ${#rationale} -lt 10 ]]; then
        _vb_err "$(printf 'missing-red-then-green: n/a rationale must be at least 10 chars (got: %s)' "$rationale")"
      fi
    elif [[ "$rtg_value" = "n/a" ]]; then
      _vb_err 'missing-red-then-green: bare "n/a" requires a rationale in parens: n/a (reason >= 10 chars)'
    else
      # Spec-path forms: "<path>" or "<path>:<line> # <test-name>".
      # The path must end in a recognized spec extension and must appear in
      # the staged diff so the rote attestation "yes" cannot be replaced by
      # an equally rote "name some random spec file in the repo".
      local rtg_path_re='^([a-zA-Z0-9_./ -]+\.(rb|py|js|ts|tsx|jsx|go|rs|sh|bash|bats|feature|swift))(:.*)?$'
      if [[ "$rtg_value" =~ $rtg_path_re ]]; then
        local rtg_path="${BASH_REMATCH[1]}"
        local rtg_suffix="${BASH_REMATCH[3]#:}"
        # Path char class allows internal spaces (paths with spaces exist),
        # but a trailing space on the path captured before the colon is a
        # copy-paste hazard: it produces a path-not-in-staged diagnostic
        # rather than a clearer format error. Strip trailing whitespace so
        # the staged-diff lookup uses the canonical name.
        rtg_path=$(printf '%s' "$rtg_path" | sed 's/[[:space:]]*$//')
        # allow-comment: path-in-staged is a commit-time check (the spec must be
        # allow-comment: in the change under review). On push re-validation the
        # allow-comment: spec may live in a sibling commit's delta, so skip it
        # allow-comment: and leave path-ok true; the suffix format check below
        # allow-comment: still runs in every context.
        local rtg_path_ok=1
        if [[ "$at_commit_time" -eq 1 ]]; then
          local rtg_staged
          rtg_staged=$(_vb_delta_files)
          if ! grep -qF "$rtg_path" <<< "$rtg_staged" 2>/dev/null; then
            _vb_err "$(printf 'red-then-green-path-not-in-staged: Red-then-green path "%s" is not in the staged diff. Name a spec file that this commit actually touches, so the red-then-green claim is anchored to the change under review.' "$rtg_path")"
            rtg_path_ok=0
          fi
        fi
        if [[ -n "$rtg_suffix" ]] && [[ "$rtg_path_ok" -eq 1 ]]; then
          # Combined form only: <line> # <test-name>. The bare line-only and
          # bare test-name-only forms were retired: a line number without a
          # name is fragile (line numbers shift), and a name without a line
          # number breaks the file:line click-to-open convention shared by
          # iTerm2 Semantic History, VSCode terminalLinkParsing, and Ghostty.
          # The "#" separator is the RSpec / Cucumber wire format and is
          # treated as a hard boundary by all three terminal link parsers.
          # Line number is 1-based: line 0 is rejected up-front so the
          # range check below does not silently accept it (rtg_lines is
          # always >= 0 so "0 < 0" never fires).
          local rtg_combined_re='^([1-9][0-9]*)[[:space:]]+#[[:space:]]+(.+)$'
          if ! [[ "$rtg_suffix" =~ $rtg_combined_re ]]; then
            _vb_err "$(printf 'missing-red-then-green: suffix must be "<line> %s <test-name>" (RSpec/Cucumber convention, keeps path:line clickable in iTerm2/VSCode/Ghostty). Bare "<line>" or bare "<test-name>" forms are no longer accepted; got: "%s"' "$_vb_hash" "$rtg_suffix")"
          elif [[ "$at_commit_time" -eq 1 ]]; then
            # allow-comment: line-out-of-range and test-not-found read the spec
            # allow-comment: blob; on push re-validation the blob may be absent
            # allow-comment: or shifted, so they run at commit time only.
            local rtg_line="${BASH_REMATCH[1]}"
            local rtg_name="${BASH_REMATCH[2]}"

            local rtg_blob
            rtg_blob=$(_vb_show_blob "$rtg_path")
            if [[ -z "$rtg_blob" ]] && [[ -f "$rtg_path" ]]; then
              rtg_blob=$(cat "$rtg_path" 2>/dev/null || true)
            fi

            # Line-count check: staged blob must have at least <line> lines.
            # awk's NR counts lines including an unterminated final line, and
            # is correct on empty input (NR=0). wc -l with a printf wrapper
            # over- or under-counts depending on whether the blob ends with a
            # newline; awk avoids that.
            local rtg_lines
            rtg_lines=$(printf '%s' "$rtg_blob" | awk 'END { print NR }')
            if [[ "$rtg_lines" -lt "$rtg_line" ]]; then
              _vb_err "$(printf 'red-then-green-line-out-of-range: Red-then-green names line %s in "%s", but the staged file has only %s lines. Name a line that exists in the file as it stands in this commit.' "$rtg_line" "$rtg_path" "$rtg_lines")"
            else
              # Test-name check: try each known runner pattern. First hit wins.
              # Quoted-name patterns (Quick / RSpec / Jest / Mocha / bats /
              # Swift Testing / Cucumber Scenario): match the literal name
              # inside the quotes or after the keyword. Function-name patterns
              # (XCTest, pytest): match the bare identifier.
              local rtg_esc
              rtg_esc=$(printf '%s' "$rtg_name" | sed 's/[][\.*^$(){}+?|/]/\\&/g')
              local rtg_patterns=(
				"(it|test|describe|context|specify)[[:space:]]*\\(?[[:space:]]*[\"']${rtg_esc}[\"']"
				"(@test|@Test\\()[[:space:]]*[\"']${rtg_esc}[\"']"
                "Scenario:[[:space:]]*${rtg_esc}([[:space:]]|$)"
                "func[[:space:]]+${rtg_esc}[[:space:]]*\\("
                "def[[:space:]]+${rtg_esc}[[:space:]]*\\("
              )
              local pat
              local rtg_found=0
              for pat in "${rtg_patterns[@]}"; do
                if printf '%s' "$rtg_blob" | grep -Eq "$pat" 2>/dev/null; then
                  rtg_found=1
                  break
                fi
              done
              if [[ "$rtg_found" -eq 0 ]]; then
				_vb_err "$(printf 'red-then-green-test-not-found: Red-then-green names "%s" in "%s", but no matching test (it/test/Scenario/@test/@Test/func/def) was found in the staged file. Name the test you actually saw red, in the form it appears in the file (the quoted description, the Scenario name, or the func/def identifier).' "$rtg_name" "$rtg_path")"
              fi
            fi
          fi
        fi
      else
        _vb_err "$(printf 'missing-red-then-green: value must be "yes", "n/a (reason)", "<path>", or "<path>:<line> %s <test-name>"; got: "%s"' "$_vb_hash" "$rtg_value")"
      fi
    fi
  fi

  # Rule: Visual trailer.
  # Format is validated whenever the trailer is present, regardless of the
  # UI-touch heuristic; a malformed value is always a bug. The UI-touch
  # heuristic only decides whether ABSENCE of the trailer is a bug. Slice
  # tokens are not consulted: the trailer fires correctly on rare cases like
  # a chore-deps slice that also bumped a CSS dependency, and the format
  # check stays honest when an operator opts in on a backend-only commit.
  local visual_value
  visual_value=$(_vb_trailer_value "$trailers" "Visual")
  # git interpret-trailers normalises but a defensive trailing-whitespace
  # strip keeps the path-existence check honest if a trailer ever arrives
  # with trailing spaces.
  visual_value=$(printf '%s' "$visual_value" | sed 's/[[:space:]]*$//')

  # Compute the touched-files list once so the missing-visual error can name
  # them. _vb_ui_touched_files runs `git diff --cached --name-only` exactly
  # once per validator pass; reuse the output for both the absence check and
  # the error message.
  local visual_ui_touched
  visual_ui_touched=$(_vb_ui_touched_files)

  if [[ -n "$visual_value" ]]; then
    if [[ "$visual_value" =~ ^n/a[[:space:]]*\((.+)\)$ ]]; then
      local rationale="${BASH_REMATCH[1]}"
      if [[ ${#rationale} -lt 10 ]]; then
        _vb_err "$(printf 'missing-visual: n/a rationale must be at least 10 chars (got: "%s")' "$rationale")"
      fi
      # Reject rationales that defer the screenshot to a future event.
      # The trailer's purpose is to either capture the screenshot now
      # (Visual: <path>) or document why no screenshot is meaningful at
      # all (extract-only refactor, accessibility metadata, debug-only
      # surface, copy-only). A rationale that promises a screenshot
      # later silently turns the trailer into a TODO; the discipline
      # then validates the format of the TODO instead of the evidence.
      local rationale_lower
      rationale_lower=$(printf '%s' "$rationale" | tr '[:upper:]' '[:lower:]')
      local deferral_re='(later|deferred|follow[ -]?up|post[ -]?merge|next iteration|iteration when|to be captured|captured on next|captured later|saved for later|next pass|coming next|will capture|will add|will attach|will supply|will provide|will upload|will take|will make)'
      if [[ "$rationale_lower" =~ $deferral_re ]]; then
        local matched="${BASH_REMATCH[1]}"
        _vb_err "$(printf 'visual-rationale-defers: Visual: n/a rationale uses deferral language ("%s") that promises a screenshot at a future event. The trailer cannot validate that promise. Either supply Visual: <path> now, or rewrite the rationale to describe why a screenshot has no meaning for this change (extract-only refactor, accessibility metadata, debug-only surface, copy-only).' "$matched")"
      fi
      # Reject rationales that do not name a recognized non-applicable
      # category. The trailer's two legitimate forms are Visual: <path>
      # and Visual: n/a (CATEGORY ...). The category set is closed and
      # describes WHY a screenshot has no meaning for this change. Free
      # narrative rationales without one of these tokens read as the
      # author hand-waving past the heuristic; the closed set forces the
      # claim to be classified.
      if ! [[ "$rationale_lower" =~ $_vb_category_re ]]; then
        _vb_err "$(printf 'visual-rationale-vague: Visual: n/a rationale must name a recognized category that explains why a screenshot has no meaning for this change. Recognized tokens (case-insensitive): extract-only, accessibility-only, accessibility metadata, debug-only, spec-only, test-only, copy-only, copy change, metadata-only, no behaviour change, no visual change, no ui change, byte-identical, render unchanged, pixel-identical, backend rewrite, backend only, no ui touched, sound-only, audio-only, log-only, telemetry-only. The rationale (got: "%s") matched none of those.' "$rationale")"
      fi
      # Visual: n/a is never accepted on UI-touched commits: the rationale
      # was structurally a deferral ("evidence lands later") that rarely
      # paid off. Capture a screenshot or recording and supply Visual: <path>.
      if [[ -n "$visual_ui_touched" ]]; then
        local na_ui_files
        na_ui_files=$(printf '%s' "$visual_ui_touched" | tr '\n' ',' | sed 's/,$//;s/,/, /g')
        _vb_err "$(printf 'visual-na-on-ui-touch: Visual: n/a is not accepted when UI files are touched (%s). Capture by any available route (browser drivers, OS-native utilities, simulator tools, project-launch flows) and supply Visual: <path>.' "$na_ui_files")"
      fi
    elif [[ "$visual_value" = "n/a" ]]; then
      _vb_err 'missing-visual: bare "n/a" requires a rationale in parens: n/a (reason >= 10 chars)'
    else
      # Resolve relative to repo root so the check is stable whether the
      # caller is the git-native commit-msg hook (always repo root) or the
      # PreToolUse:Bash dispatcher (whatever subdirectory Claude invoked
      # from). Absolute paths in the trailer pass through unchanged.
      local repo_root
      repo_root=$(git rev-parse --show-toplevel 2>/dev/null || true)
      local resolved="$visual_value"
      if [[ -n "$repo_root" && "$resolved" != /* ]]; then
        resolved="$repo_root/$resolved"
      fi
      if [[ "$at_commit_time" -eq 1 && ! -f "$resolved" ]]; then
        _vb_err "$(printf 'visual-path-not-found: Visual path "%s" was not found on disk (relative to repo root). Add the file or use Visual: n/a (rationale).' "$visual_value")"
      fi
    fi
  elif [[ -n "$visual_ui_touched" ]]; then
    # Join the newline-separated list with ", " for the single-line error.
    local joined
    joined=$(printf '%s' "$visual_ui_touched" | tr '\n' ',' | sed 's/,$//;s/,/, /g')
    _vb_err "$(printf 'missing-visual: Visual trailer is absent; UI files in this commit: %s. Capture by any available route (browser drivers, OS-native utilities, simulator tools, project-launch flows) and supply Visual: <path>.' "$joined")"
  fi

  # Rule: Verified trailer (self-assessment of how the behaviour change was
  # verified). Required for every non-opt-out commit. Forces an explicit
  # answer to "did the operator see this work, is there an artefact in the
  # repo, or was there a red-then-green test", so a commit cannot slip
  # through on bare attestation (the Tests / Red-then-green trailers do not
  # ask this question directly: a `Red-then-green: yes` is self-attested and
  # under non-autonomous mode is never anchored to anything).
  # allow-comment: gated on slice_value presence so a missing-slice does not
  # allow-comment: cascade into a derivative missing-verified.
  if [[ "$slice_invalid" -eq 0 && "$slice_is_optout" -eq 0 ]]; then
    local verified_value
    verified_value=$(_vb_trailer_value "$trailers" "Verified")
    verified_value=$(printf '%s' "$verified_value" | sed 's/[[:space:]]*$//')

    if [[ -z "$verified_value" ]]; then
      _vb_err 'missing-verified: Verified trailer is absent. Self-assessment required: how was the new behaviour verified? Use one of: "operator-confirmed" (operator saw it work this session), "agent-confirmed" (the agent ran the change this session and saw it work), "<path>" (screenshot/recording/log artefact in repo), "red-then-green" (covered by Red-then-green trailer), or "n/a (reason)" with a recognised category token (extract-only, no behaviour change, copy-only, ...).'
    elif [[ "$verified_value" = "operator-confirmed" ]]; then
      : # OK: operator attested in conversation; nothing else to anchor.
    elif [[ "$verified_value" = "agent-confirmed" ]]; then
      local agent_how
      agent_how=$(_vb_trailer_value "$trailers" "Verified-how")
      agent_how=$(printf '%s' "$agent_how" | sed 's/[[:space:]]*$//')
      if [[ ${#agent_how} -lt 20 ]]; then
        _vb_err 'missing-verified-how: Verified: agent-confirmed requires a companion "Verified-how:" trailer with a concrete sentence (>= 20 chars) stating why the agent verified instead of the operator and how, in the shape "Due to <reason>, this was confirmed by <what the agent ran and observed>" (e.g. "Due to no operator at the keyboard, this was confirmed by running the helper against live agents and seeing the dry-run mapping print"). This keeps the self-attestation honest and leaves a paper trail.'
      fi
    elif [[ "$verified_value" = "red-then-green" ]]; then
      # The Verified trailer points at the Red-then-green trailer as the
      # verification anchor. That only makes sense when Red-then-green is
      # itself a positive attestation (<path> / <path>:<line> # <name>).
      # If Red-then-green is n/a (...), the chain breaks: the author claims
      # tests were the verification while simultaneously claiming no tests
      # apply.
      if [[ "$rtg_value" =~ ^n/a ]]; then
        _vb_err "$(printf 'verified-red-then-green-mismatch: Verified: red-then-green requires the Red-then-green trailer to be a positive attestation (<path> / <path>:<line> %s <test-name>), but Red-then-green is "n/a". Pick a different Verified form (operator-confirmed, agent-confirmed, <path>, or n/a (reason)).' "$_vb_hash")"
      fi
    elif [[ "$verified_value" = "build-only" ]]; then
      # build-only was a deferral mechanism that rarely materialised into
      # actual verification. The trailer no longer accepts it; supply a
      # concrete anchor (operator-confirmed, <path>, red-then-green) or
      # n/a (reason) when no behaviour applies.
      _vb_err 'verified-build-only-removed: Verified: build-only is no longer accepted. Either exercise the change and supply Verified: <path> (screenshot / log / recording), Verified: operator-confirmed, Verified: agent-confirmed, or Verified: red-then-green (with a real Red-then-green anchor), or fall back to Verified: n/a (reason).'
    elif [[ "$verified_value" =~ ^n/a[[:space:]]*\((.+)\)$ ]]; then
      local v_rationale="${BASH_REMATCH[1]}"
      if [[ ${#v_rationale} -lt 10 ]]; then
        _vb_err "$(printf 'missing-verified: n/a rationale must be at least 10 chars (got: "%s")' "$v_rationale")"
      else
        # Reuse the closed Visual: n/a category set: the question "why is no
        # screenshot meaningful" and "why is no verification meaningful" have
        # the same answer space (extract-only refactor, copy change, byte-
        # identical render, backend-only, no behaviour change, ...).
        local v_rationale_lower
        v_rationale_lower=$(printf '%s' "$v_rationale" | tr '[:upper:]' '[:lower:]')
        if ! [[ "$v_rationale_lower" =~ $_vb_category_re ]]; then
          _vb_err "$(printf 'verified-rationale-vague: Verified: n/a rationale must name a recognised category that explains why no verification is meaningful for this change. Recognised tokens (case-insensitive): extract-only, accessibility-only, accessibility metadata, debug-only, spec-only, test-only, copy-only, copy change, metadata-only, no behaviour change, no visual change, no ui change, byte-identical, render unchanged, pixel-identical, backend rewrite, backend only, no ui touched, sound-only, audio-only, log-only, telemetry-only. The rationale (got: "%s") matched none of those.' "$v_rationale")"
        fi
      fi
    elif [[ "$verified_value" = "n/a" ]]; then
      _vb_err 'missing-verified: bare "n/a" requires a rationale in parens: n/a (reason >= 10 chars)'
    elif [[ "$verified_value" == */* ]] || [[ "$verified_value" =~ \.(png|jpg|jpeg|gif|webp|heic|mov|mp4|webm|pdf|txt|log|md|json|html|svg|tiff|bmp)$ ]]; then
      # Path form: artefact in repo. Resolve relative to repo root.
      local v_repo_root
      v_repo_root=$(git rev-parse --show-toplevel 2>/dev/null || true)
      local v_resolved="$verified_value"
      if [[ -n "$v_repo_root" && "$v_resolved" != /* ]]; then
        v_resolved="$v_repo_root/$v_resolved"
      fi
      if [[ "$at_commit_time" -eq 1 && ! -f "$v_resolved" ]]; then
        _vb_err "$(printf 'verified-path-not-found: Verified path "%s" was not found on disk (relative to repo root). Add the artefact or use a different Verified form.' "$verified_value")"
      fi
    else
      _vb_err "$(printf 'missing-verified: value must be "operator-confirmed", "agent-confirmed", "red-then-green", "build-only", "<path>", or "n/a (reason)"; got: "%s"' "$verified_value")"
    fi
  fi

  # Rule: WHY block length.
  # Require >= 2 non-empty lines OR (>= 60 chars AND ends with . ! or ?).
  if [[ -n "$why_block" ]]; then
    local nonempty_line_count
    nonempty_line_count=$(printf '%s' "$why_block" | grep -c '[^[:space:]]' || true)
    local why_charcount=${#why_block}
    local why_trimmed
    why_trimmed=$(printf '%s' "$why_block" | sed 's/[[:space:]]*$//')
    local last_char="${why_trimmed: -1}"

    local why_ok=0
    if [[ "$nonempty_line_count" -ge 2 ]]; then
      why_ok=1
    elif [[ "$why_charcount" -ge 60 ]] && [[ "$last_char" = "." || "$last_char" = "!" || "$last_char" = "?" ]]; then
      why_ok=1
    fi

    if [[ "$why_ok" -eq 0 ]]; then
      _vb_err 'why-too-short: WHY block needs >= 2 non-empty lines or >= 60 chars ending in . ! or ?'
    fi
  else
    # No WHY block at all for a multi-line commit counts as too short.
    _vb_err 'why-too-short: commit has a trailer block but no WHY narrative above it'
  fi

  # Rule: Anti-copy-paste. Compare SHA1 of WHY block against previous 5 commits.
  #
  # Scope note: the comparison is HEAD-linear (last 5 first-parent commits in
  # git log order), not strictly branch-scoped. A commit on a feature branch
  # will be compared against commits from main that HEAD is descended from if
  # those are within the 5-commit window. This is a deliberate choice: it
  # catches copy-paste from recently-merged main commits without requiring the
  # branch's merge-base to be computed, which is costly and fragile on shallow
  # clones. Trade-off: a commit immediately after a merge of a large batch may
  # compare against main-branch commits that are topically unrelated. In
  # practice the risk is low because the WHY blocks of unrelated commits rarely
  # hash-collide after whitespace normalisation.
  local why_sha
  why_sha=$(_vb_sha1 "$why_block")

  if [[ -n "$why_sha" ]]; then
    local cmp_anchor
    case "${GIT_DISCIPLINE_VALIDATE_CONTEXT:-staged}" in
      staged) cmp_anchor="HEAD" ;;
      HEAD|head) cmp_anchor="HEAD^" ;;
      *) cmp_anchor="${GIT_DISCIPLINE_VALIDATE_CONTEXT}^" ;;
    esac

    local log_bodies
    log_bodies=$(git log -5 --pretty=format:'%B' "$cmp_anchor" 2>/dev/null || true)

    if [[ -n "$log_bodies" ]]; then
      local prev_sha=""
      local prev_hash=""
      while IFS= read -r commit_hash; do
        local prev_body
        prev_body=$(git log -1 --pretty=format:'%B' "$commit_hash" 2>/dev/null || true)
        local prev_trailers
        prev_trailers=$(_vb_trailers "$prev_body")
        local prev_why
        prev_why=$(_vb_why_block "$prev_body" "$prev_trailers")
        prev_sha=$(_vb_sha1 "$prev_why")
        if [[ -n "$prev_sha" ]] && [[ "$prev_sha" = "$why_sha" ]]; then
          local short_hash="${commit_hash:0:7}"
          _vb_err "$(printf 'duplicate-why: identical narrative as commit %s' "$short_hash")"
          break
        fi
      done < <(git log -5 --pretty=format:'%H' "$cmp_anchor" 2>/dev/null || true)
    fi
  fi

  # allow-comment: emission point. Print every accumulated error on stderr in
  # allow-comment: the order they were detected, then signal failure if any
  # allow-comment: landed. Order matters: callers that head-pick (push-body-gate)
  # allow-comment: still see the most foundational miss first because the trailer
  # allow-comment: checks run before WHY-block and duplicate-why checks.
  if [[ "${#_vb_errors[@]}" -gt 0 ]]; then
    local _vb_err_line
    for _vb_err_line in "${_vb_errors[@]}"; do
      printf '%s\n' "$_vb_err_line" >&2
    done
    return 1
  fi

  return 0
}

# allow-comment: vb_validate_commit <sha> validates one existing commit's body
# allow-comment: with the same trivial-ok and skip-classify rules the PreToolUse
# allow-comment: guard applies to staged work, but reading the real object via
# allow-comment: the range context. It echoes the first violation line on stdout
# allow-comment: and returns 1 on a real miss; returns 0 when clean, skip-
# allow-comment: classified, or unreadable. This is the single home for the
# allow-comment: per-commit loop body that push-body-gate, the PostToolUse net,
# allow-comment: and the git-native pre-push hook all share.
vb_validate_commit() {
  local sha="$1"
  local subject shortstat file_count insertion_count trivial_ok tmpfile out rc slice
  subject=$(git log -1 --pretty=format:%s "$sha" 2>/dev/null || true)
  if validate_body_classify_skip "$subject"; then
    return 0
  fi
  # allow-comment: a Slice: wip commit is intentionally incomplete and governed
  # allow-comment: solely by the wip-gate (blocked at push, bypassable on purpose);
  # allow-comment: the body schema does not apply, so every body-gate layer that
  # allow-comment: routes through here exempts it uniformly.
  slice=$(git log -1 --pretty=format:%B "$sha" 2>/dev/null | git interpret-trailers --parse 2>/dev/null | sed -n 's/^Slice:[[:space:]]*//p' | head -1)
  if [[ "$slice" = "wip" ]]; then
    return 0
  fi
  # allow-comment: a commit that already sits on the default branch has shipped;
  # allow-comment: asking a later push to improve its body would be asking for a
  # allow-comment: rewrite of public history. The push ranges narrow the walk,
  # allow-comment: but only this predicate holds for every push shape and for
  # allow-comment: hook bodies installed before the range arithmetic changed.
  if published_commit_is_published "$sha"; then
    return 0
  fi
  shortstat=$(GIT_DISCIPLINE_VALIDATE_CONTEXT="$sha" _vb_delta_shortstat)
  file_count=$(GIT_DISCIPLINE_VALIDATE_CONTEXT="$sha" _vb_delta_files | grep -c . | tr -d ' ')
  insertion_count=0
  if [[ "$shortstat" =~ ([0-9]+)[[:space:]]+insertion ]]; then
    insertion_count="${BASH_REMATCH[1]}"
  fi
  trivial_ok=0
  if [[ "$file_count" -le 1 && "$insertion_count" -le 5 ]]; then
    trivial_ok=1
  fi
  tmpfile=$(mktemp "${TMPDIR:-/tmp}/git-discipline-vb-commit-XXXXXX")
  git log -1 --pretty=format:%B "$sha" > "$tmpfile" 2>/dev/null
  out=$(GIT_DISCIPLINE_VALIDATE_CONTEXT="$sha" GIT_DISCIPLINE_TRIVIAL_OK="$trivial_ok" validate_body "$tmpfile" 2>&1)
  rc=$?
  rm -f "$tmpfile"
  if [[ "$rc" -eq 1 ]]; then
    printf '%s' "$(printf '%s' "$out" | head -1)"
    return 1
  fi
  return 0
}
