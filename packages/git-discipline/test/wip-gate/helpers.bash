#!/usr/bin/env bash
# Shared setup, teardown, and fixture helpers for the wip-gate BATS suite.
#
# Strategy mirrors test/migrated-hooks/helpers.bash: a git-shim on PATH
# answers the small set of git invocations the guard makes. The guard reads:
#   git rev-parse --abbrev-ref HEAD             - current branch
#   git rev-parse --abbrev-ref --symbolic-full-name @{u}
#                                              - upstream of the current branch
#   git rev-parse --verify --quiet <ref>        - upstream existence check
#   git rev-parse --short <sha>                 - short-form commit
#   git rev-list <range>                        - commits in the push range
#   git merge-base --is-ancestor <sha> <ref>    - has <sha> already shipped
#   git log -1 --pretty=format:%B <sha>         - commit body
#   git log -1 --pretty=format:%s <sha>         - commit subject
#   git interpret-trailers --parse              - parse trailers from stdin
#
# Each shim path is driven by env vars so each test can wire its own scenario.
#
# The shim also satisfies the body/format/subject guards that run alongside
# push-wip-gate in the same dispatch pass: the trivial-commit shortstat keeps
# them quiet for non-push commands.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DISPATCH="$SCRIPT_DIR/../../hooks/dispatch.sh"

# Override the wip-push log so tests never write to the real log.
export GIT_DISCIPLINE_WIP_PUSH_LOG="$BATS_TEST_TMPDIR/git-discipline-wip-pushes.log"

# allow-comment: wip-gate tests focus on wip-vs-clean; push-body-gate fires on the same `git push` event and would deny non-schema-conformant fixtures.
export GIT_DISCIPLINE_PUSH_BODY_GATE_DISABLED=1
export GIT_DISCIPLINE_PUSH_DESTINATION_DISABLED=1

# Default shims: no upstream, no commits, no wip. Tests override per case.
export GIT_SHIM_ORIGIN_URL="https://github.com/someorg/somerepo.git"
export GIT_SHIM_SHORTSTAT=" 1 file changed, 1 insertion(+)"
export GIT_SHIM_DIFF_NAMES="docs/notes.md"
export GIT_SHIM_INTERPRET_TRAILERS_OUTPUT=""
export GIT_SHIM_LS_TREE_OUTPUT=""
export GIT_SHIM_LOG_HASHES=""
export GIT_SHIM_LOG_BODY=""
export GIT_SHIM_HEAD_ABBREV="feature/wip-gate"
export GIT_SHIM_HEAD_SHORT="deadbeef"

# wip-gate-specific knobs.
export GIT_SHIM_UPSTREAM=""                # @{u} resolution; empty = no upstream
export GIT_SHIM_VERIFY_REFS=""              # space-separated list of refs that resolve OK
export GIT_SHIM_REV_LIST_DEFAULT=""         # rev-list output for any range
# Per-range overrides: GIT_SHIM_REV_LIST__<range-key> maps "upstream..local"
# (with non-alnum chars replaced by _) to a newline-separated SHA list.

# allow-comment: default-branch + authorship knobs feeding range scoping and
# allow-comment: the ours-by-author filter. ORIGIN_HEAD answers symbolic-ref
# allow-comment: refs/remotes/origin/HEAD (empty = unset). USER_EMAIL is the
# allow-comment: pusher; author/committer default to the pusher so existing wip
# allow-comment: fixtures stay "ours", and per-sha overrides via
# allow-comment: wip_shim_set_author / _committer flip a commit to a teammate.
export GIT_SHIM_ORIGIN_HEAD=""
export GIT_SHIM_USER_EMAIL="dev@example.com"
export GIT_SHIM_DEFAULT_AUTHOR_EMAIL=""
export GIT_SHIM_DEFAULT_COMMITTER_EMAIL=""

# allow-comment: per-commit `git show` deltas feed push-body-gate's trivial-ok
# allow-comment: heuristic; defaults are non-trivial so a subject-only commit is
# allow-comment: flagged unless a test overrides per-sha via wip_shim_set_show.
export GIT_SHIM_SHOW_SHORTSTAT=" 3 files changed, 30 insertions(+)"
export GIT_SHIM_SHOW_NAMES=$'a.rb\nb.rb\nc.rb'

wip_shim_set_author() {
  local key
  key=$(printf '%s' "$1" | sed 's/[^A-Za-z0-9]/_/g')
  eval "export GIT_SHIM_AUTHOR__${key}=\"\$2\""
}

wip_shim_set_committer() {
  local key
  key=$(printf '%s' "$1" | sed 's/[^A-Za-z0-9]/_/g')
  eval "export GIT_SHIM_COMMITTER__${key}=\"\$2\""
}

wip_shim_set_show() {
  local key
  key=$(printf '%s' "$1" | sed 's/[^A-Za-z0-9]/_/g')
  eval "export GIT_SHIM_SHOW_SHORTSTAT__${key}=\"\$2\""
  eval "export GIT_SHIM_SHOW_NAMES__${key}=\"\$3\""
}

# wip_shim_set_published <sha>
# Mark a commit as already on the default branch, the way
# `git merge-base --is-ancestor` reports it in a real repository.
wip_shim_set_published() {
  local key
  key=$(printf '%s' "$1" | sed 's/[^A-Za-z0-9]/_/g')
  eval "export GIT_SHIM_PUBLISHED__${key}=1"
}

# wip_shim_set_revlist <range> <sha-list-newline-separated>
wip_shim_set_revlist() {
  local range="$1"
  local list="$2"
  local key
  key=$(printf '%s' "$range" | sed 's/[^A-Za-z0-9]/_/g')
  eval "export GIT_SHIM_REV_LIST__${key}=\"\$list\""
}

# wip_shim_set_body <sha> <body>
wip_shim_set_body() {
  local sha="$1"
  local body="$2"
  local key
  key=$(printf '%s' "$sha" | sed 's/[^A-Za-z0-9]/_/g')
  eval "export GIT_SHIM_BODY__${key}=\"\$body\""
}

# wip_shim_set_subject <sha> <subject>
wip_shim_set_subject() {
  local sha="$1"
  local subject="$2"
  local key
  key=$(printf '%s' "$sha" | sed 's/[^A-Za-z0-9]/_/g')
  eval "export GIT_SHIM_SUBJECT__${key}=\"\$subject\""
}

setup() {
  local shim_bin="$BATS_TEST_TMPDIR/bin"
  install -d "$shim_bin" 2>/dev/null || true

  cat > "$shim_bin/git" <<'SHIM'
#!/usr/bin/env bash
args=("$@")

# rev-parse handlers (order matters: most specific first).
if [[ "${args[0]}" = "rev-parse" ]]; then
  # --abbrev-ref --symbolic-full-name @{u}
  if [[ "${args[*]}" =~ "--symbolic-full-name" ]]; then
    if [[ -n "$GIT_SHIM_UPSTREAM" ]]; then
      printf '%s\n' "$GIT_SHIM_UPSTREAM"
      exit 0
    fi
    exit 1
  fi
  if [[ "${args[1]}" = "--verify" ]]; then
    # --verify --quiet <ref>
    target="${args[*]: -1}"
    for ref in $GIT_SHIM_VERIFY_REFS; do
      if [[ "$ref" = "$target" ]]; then
        printf '%s\n' "fakefakefake"
        exit 0
      fi
    done
    exit 1
  fi
  if [[ "${args[1]}" = "--abbrev-ref" ]]; then
    printf '%s\n' "$GIT_SHIM_HEAD_ABBREV"
    exit 0
  fi
  if [[ "${args[1]}" = "--short" ]]; then
    target="${args[2]}"
    # Return first 7 chars of the SHA, mimicking git rev-parse --short.
    printf '%s\n' "${target:0:7}"
    exit 0
  fi
  if [[ "${args[1]}" = "HEAD" ]]; then
    printf 'deadbeef00000000\n'
    exit 0
  fi
fi

if [[ "${args[0]}" = "symbolic-ref" ]]; then
  if [[ "${args[*]}" =~ refs/remotes/origin/HEAD ]]; then
    if [[ -n "$GIT_SHIM_ORIGIN_HEAD" ]]; then
      if [[ "${args[*]}" =~ --short ]]; then
	printf '%s\n' "${GIT_SHIM_ORIGIN_HEAD#refs/remotes/}"
	exit 0
      fi
      printf '%s\n' "$GIT_SHIM_ORIGIN_HEAD"
      exit 0
    fi
    exit 1
  fi
  exit 1
fi

if [[ "${args[0]}" = "show" ]]; then
  sha="${args[*]: -1}"
  key=$(printf '%s' "$sha" | sed 's/[^A-Za-z0-9]/_/g')
  if [[ "${args[*]}" =~ "--shortstat" ]]; then
    var="GIT_SHIM_SHOW_SHORTSTAT__${key}"
    printf '%s\n' "${!var:-$GIT_SHIM_SHOW_SHORTSTAT}"
    exit 0
  fi
  if [[ "${args[*]}" =~ "--name-only" ]]; then
    var="GIT_SHIM_SHOW_NAMES__${key}"
    printf '%s\n' "${!var:-$GIT_SHIM_SHOW_NAMES}"
    exit 0
  fi
  exit 0
fi

if [[ "${args[0]}" = "merge-base" && "${args[1]}" = "--is-ancestor" ]]; then
  sha="${args[2]}"
  key=$(printf '%s' "$sha" | sed 's/[^A-Za-z0-9]/_/g')
  var="GIT_SHIM_PUBLISHED__${key}"
  [[ -n "${!var:-}" ]] && exit 0
  exit 1
fi

if [[ "${args[0]}" = "rev-list" ]]; then
  range="${args[1]}"
  key=$(printf '%s' "$range" | sed 's/[^A-Za-z0-9]/_/g')
  var="GIT_SHIM_REV_LIST__${key}"
  if [[ -n "${!var:-}" ]]; then
    printf '%s\n' "${!var}"
    exit 0
  fi
  if [[ -n "$GIT_SHIM_REV_LIST_DEFAULT" ]]; then
    printf '%s\n' "$GIT_SHIM_REV_LIST_DEFAULT"
    exit 0
  fi
  exit 0
fi

if [[ "${args[0]}" = "log" ]]; then
  # log -1 --pretty=format:%B <sha> -> body
  # log -1 --pretty=format:%s <sha> -> subject
  if [[ "${args[*]}" =~ "%B" ]]; then
    sha="${args[*]: -1}"
    key=$(printf '%s' "$sha" | sed 's/[^A-Za-z0-9]/_/g')
    var="GIT_SHIM_BODY__${key}"
    printf '%s\n' "${!var:-$GIT_SHIM_LOG_BODY}"
    exit 0
  fi
  if [[ "${args[*]}" =~ "%s" ]]; then
    sha="${args[*]: -1}"
    key=$(printf '%s' "$sha" | sed 's/[^A-Za-z0-9]/_/g')
    var="GIT_SHIM_SUBJECT__${key}"
    printf '%s\n' "${!var:-default subject}"
    exit 0
  fi
  if [[ "${args[*]}" =~ "%H" ]]; then
    [[ -n "$GIT_SHIM_LOG_HASHES" ]] && printf '%s\n' "$GIT_SHIM_LOG_HASHES"
    exit 0
  fi
  if [[ "${args[*]}" =~ "%ae" ]]; then
    sha="${args[*]: -1}"
    key=$(printf '%s' "$sha" | sed 's/[^A-Za-z0-9]/_/g')
    var="GIT_SHIM_AUTHOR__${key}"
    printf '%s\n' "${!var:-${GIT_SHIM_DEFAULT_AUTHOR_EMAIL:-$GIT_SHIM_USER_EMAIL}}"
    exit 0
  fi
  if [[ "${args[*]}" =~ "%ce" ]]; then
    sha="${args[*]: -1}"
    key=$(printf '%s' "$sha" | sed 's/[^A-Za-z0-9]/_/g')
    var="GIT_SHIM_COMMITTER__${key}"
    printf '%s\n' "${!var:-${GIT_SHIM_DEFAULT_COMMITTER_EMAIL:-$GIT_SHIM_USER_EMAIL}}"
    exit 0
  fi
fi

if [[ "${args[0]}" = "interpret-trailers" && "${args[1]}" = "--parse" ]]; then
  # The pre-push lib pipes the body in on stdin and expects trailers out.
  # We naively forward stdin, then grep the slice line at the end.
  body=$(cat)
  # Emit any line that looks like a trailer (Key: Value) at the tail.
  printf '%s\n' "$body" | awk '
    BEGIN { found=0 }
    /^[[:space:]]*$/ { in_trailers=1; next }
    in_trailers && /^[A-Za-z][A-Za-z0-9-]*:[[:space:]]/ { print; found=1; next }
    in_trailers && !/^[A-Za-z][A-Za-z0-9-]*:[[:space:]]/ { in_trailers=0 }
  '
  exit 0
fi

if [[ "${args[0]}" = "config" && "${args[*]}" =~ "user.email" ]]; then
  printf '%s\n' "$GIT_SHIM_USER_EMAIL"
  exit 0
fi
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
if [[ "${args[0]}" = "ls-tree" ]]; then
  printf '%s' "$GIT_SHIM_LS_TREE_OUTPUT"
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

  # Pre-seed commit-subject rotation state so any non-push commands that
  # accidentally route through other guards do not spam reminders.
  local _state_file="$BATS_TEST_TMPDIR/commit-rule-state"
  printf '%s\n%s\n%s\n' '-1' '3' '0' > "$_state_file"
  export GIT_DISCIPLINE_COMMIT_RULE_STATE_FILE="$_state_file"
}

teardown() {
  : # BATS_TEST_TMPDIR cleanup handled by bats-core.
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
