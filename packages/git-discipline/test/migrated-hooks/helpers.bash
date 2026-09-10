#!/usr/bin/env bash
# Shared setup, teardown, and fixture helpers for the migrated-hooks BATS suite.
#
# Mock strategy: identical git-shim approach as block-mode/helpers.bash. The
# guards under test (commit-trailers, git-dash-c) only need a minimal shim
# because they do not consult git state directly. We still install one so that
# guard_commit_format and guard_commit_body (which run in the same dispatch
# pass) get sane shortstat / diff / interpret-trailers values.
#
# Shim variables:
#   GIT_SHIM_ORIGIN_URL                 - "git config --get remote.origin.url"
#   GIT_SHIM_SHORTSTAT                  - "git diff --cached --shortstat"
#   GIT_SHIM_DIFF_NAMES                 - "git diff --cached --name-only"
#   GIT_SHIM_INTERPRET_TRAILERS_OUTPUT  - "git interpret-trailers --parse"
#   GIT_SHIM_LS_TREE_OUTPUT             - "git ls-tree -r HEAD --name-only"
#   GIT_SHIM_LOG_HASHES                 - "git log -5 --pretty=format:%H HEAD"
#   GIT_SHIM_LOG_BODY                   - "git log -1 --pretty=format:%B <hash>"
#   GIT_SHIM_HEAD_ABBREV / HEAD_SHORT   - rev-parse helpers used by example-synth

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DISPATCH="$SCRIPT_DIR/../../hooks/dispatch.sh"
# Anchor fixture paths here rather than on the caller's cwd. A test that
# reaches for a repo path with a bare relative string passes under
# test/run-bats (which documents repo root) and fails when a single .bats
# file is run from the package directory, reporting a missing fixture as
# if the guard under test had regressed.
PKG_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
REPO_ROOT="$(cd "$PKG_ROOT/../.." && pwd)"

# Override shadow log so tests never write to the real log.
export GIT_DISCIPLINE_SHADOW_LOG="$BATS_TEST_TMPDIR/shadow.log"

# Default shims set up a trivial commit (1 file, 1 insertion) so the body
# guard auto-skips and we can isolate the trailer / dash-c behaviour.
export GIT_SHIM_ORIGIN_URL="https://github.com/someorg/somerepo.git"
export GIT_SHIM_SHORTSTAT=" 1 file changed, 1 insertion(+)"
export GIT_SHIM_DIFF_NAMES="docs/notes.md"
export GIT_SHIM_INTERPRET_TRAILERS_OUTPUT=""
export GIT_SHIM_LS_TREE_OUTPUT=""
export GIT_SHIM_DIFF_CACHED_OUTPUT=""
export GIT_SHIM_LOG_HASHES=""
export GIT_SHIM_LOG_BODY=""
export GIT_SHIM_HEAD_ABBREV="feature/migrated-hooks"
export GIT_SHIM_HEAD_SHORT="deadbeef"

setup() {
  local shim_bin="$BATS_TEST_TMPDIR/bin"
  install -d "$shim_bin" 2>/dev/null || true

  cat > "$shim_bin/git" <<'SHIM'
#!/usr/bin/env bash
args=("$@")

if [[ "${args[0]}" = "config" && "${args[*]}" =~ "remote.origin.url" ]]; then
  printf '%s\n' "$GIT_SHIM_ORIGIN_URL"
  exit 0
fi
if [[ "${args[0]}" = "diff" && "${args[*]}" =~ "--shortstat" ]]; then
  printf '%s\n' "$GIT_SHIM_SHORTSTAT"
  exit 0
fi
if [[ "${args[0]}" = "diff" && "${args[*]}" =~ "--name-only" ]]; then
  printf '%s\n' "$GIT_SHIM_DIFF_NAMES"
  exit 0
fi
if [[ "${args[0]}" = "interpret-trailers" && "${args[1]}" = "--parse" ]]; then
  printf '%s' "$GIT_SHIM_INTERPRET_TRAILERS_OUTPUT"
  exit 0
fi
if [[ "${args[0]}" = "ls-tree" ]]; then
  printf '%s' "$GIT_SHIM_LS_TREE_OUTPUT"
  exit 0
fi
if [[ "${args[0]}" = "log" && "${args[*]}" =~ "%H" ]]; then
  [[ -n "$GIT_SHIM_LOG_HASHES" ]] && printf '%s\n' "$GIT_SHIM_LOG_HASHES"
  exit 0
fi
if [[ "${args[0]}" = "log" && "${args[*]}" =~ "%B" ]]; then
  printf '%s\n' "$GIT_SHIM_LOG_BODY"
  exit 0
fi
if [[ "${args[0]}" = "rev-parse" && "${args[1]}" = "--abbrev-ref" ]]; then
  printf '%s\n' "$GIT_SHIM_HEAD_ABBREV"
  exit 0
fi
if [[ "${args[0]}" = "rev-parse" && "${args[1]}" = "--short" ]]; then
  printf '%s\n' "$GIT_SHIM_HEAD_SHORT"
  exit 0
fi
if [[ "${args[0]}" = "rev-parse" && "${args[1]}" = "HEAD" ]]; then
  if [[ -n "${GIT_SHIM_HEAD_SHA+set}" ]]; then
    [[ -n "$GIT_SHIM_HEAD_SHA" ]] && printf '%s\n' "$GIT_SHIM_HEAD_SHA"
    [[ -z "$GIT_SHIM_HEAD_SHA" ]] && exit 1
    exit 0
  fi
  printf 'deadbeef00000000\n'
  exit 0
fi

# allow-comment: parent-of helper for commit-subject amend detection.
# allow-comment: Mock returns a deterministic fake parent so distinct shas
# allow-comment: resolve to distinct parents (regular new commit, slot
# allow-comment: advances) and identical shas resolve to identical parents
# allow-comment: (amend, slot stays). GIT_SHIM_NO_PARENT=1 exits 1 to
# allow-comment: simulate a root commit.
if [[ "${args[0]}" = "rev-parse" ]] && \
   [[ "${args[*]}" =~ "--verify" ]] && [[ "${args[*]}" =~ "--quiet" ]] && \
   [[ "${args[*]}" == *"^" ]]; then
  if [[ "${GIT_SHIM_NO_PARENT:-0}" = "1" ]]; then
    exit 1
  fi
  raw="${args[$((${#args[@]} - 1))]}"
  base="${raw%^}"
  printf 'parentof_%s\n' "$base"
  exit 0
fi

# git rev-parse --show-toplevel
# Sandboxed to BATS_TEST_TMPDIR so the validator's Visual: path-resolution
# does not escape the per-test tempdir. GIT_SHIM_TOPLEVEL overrides for
# tests that exercise per-toplevel state-file namespacing.
if [[ "${args[0]}" = "rev-parse" && "${args[1]}" = "--show-toplevel" ]]; then
  printf '%s\n' "${GIT_SHIM_TOPLEVEL:-${BATS_TEST_TMPDIR:-/}}"
  exit 0
fi

REAL_GIT=$(PATH="/usr/bin:/bin:/opt/homebrew/bin:/usr/local/bin" command -v git 2>/dev/null || true)
if [[ -n "$REAL_GIT" ]]; then
  exec "$REAL_GIT" "$@"
fi

printf 'git shim: unhandled: %s\n' "$*" >&2
exit 1
SHIM
  chmod +x "$shim_bin/git"

  export PATH="$shim_bin:$PATH"

  # Pre-seed commit-subject rotation state so ack-rule4 passes immediately,
  # so that any test using a clean subject does not hit the rotation reminder.
  # Uses the canonical key=value format the production writer emits.
  local _state_file="$BATS_TEST_TMPDIR/commit-rule-state"
  printf 'pv=-1\npr=3\nrp=0\nack_pending_sha=\n' > "$_state_file"
  export GIT_DISCIPLINE_COMMIT_RULE_STATE_FILE="$_state_file"
}

# Helpers shared by the rotation bats specs: read individual fields out
# of a state file regardless of whether it is in legacy positional or
# canonical key=value form.
read_state_field() {
  local file="$1" field="$2"
  if grep -qE '^[a-z_]+=' "$file" 2>/dev/null; then
    grep -E "^${field}=" "$file" | head -1 | cut -d= -f2-
  else
    case "$field" in
      pv)              sed -n '1p' "$file" ;;
      pr)              sed -n '2p' "$file" ;;
      rp)              sed -n '3p' "$file" ;;
      ack_pending_sha) sed -n '4p' "$file" ;;
    esac
  fi
}

teardown() {
  : # BATS_TEST_TMPDIR cleaned up by bats-core.
}

# pretool_bash_json <bash-command-string>
pretool_bash_json() {
  local cmd="$1"
  jq -cn --arg c "$cmd" \
    '{hook_event_name:"PreToolUse",tool_name:"Bash",tool_input:{command:$c}}'
}

# run_dispatch <bash-command-string>
run_dispatch() {
  local cmd="$1"
  local json
  json=$(pretool_bash_json "$cmd")
  run bash "$DISPATCH" <<< "$json"
}

posttool_bash_json() {
  local cmd="$1"
  jq -cn --arg c "$cmd" \
    '{hook_event_name:"PostToolUse",tool_name:"Bash",tool_input:{command:$c}}'
}

run_posttool_dispatch() {
  local cmd="$1"
  local json
  json=$(posttool_bash_json "$cmd")
  run bash "$DISPATCH" <<< "$json"
}
