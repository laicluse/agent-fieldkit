#!/bin/bash
# packages/git-discipline/hooks/guards/repo-deny.sh
# PreToolUse:Bash guard. Honours a per-repo lock set by /git-discipline:disable-git.
# When the sentinel ".git/git-discipline-deny" exists in the active repo, every git
# command that is not a known read-only inspection form is blocked.
#
# Allow-list (read-only inspection):
#   status, log, diff, show, blame, rev-parse, rev-list, name-rev, describe,
#   reflog, shortlog, cat-file, ls-files, ls-tree, ls-remote, for-each-ref,
#   grep, whatchanged, merge-base, symbolic-ref, var, version, help,
#   remote (read-only forms), config (read-only forms),
#   branch / tag in list form,
#   bisect view|log, worktree list,
#   submodule status|summary, stash list|show, notes list|show.
#
# Anything else is treated as a mutation and blocked while the sentinel
# exists. Default deny is intentional: a new git subcommand should not slip
# through the lock just because we forgot to add it.
#
# Bypass: /git-discipline:enable-git removes the sentinel.

# Read-only top-level subcommands. No argument inspection needed: these never
# mutate.
_RD_READ_ONLY_PLAIN=(
  status log diff show blame rev-parse rev-list name-rev describe reflog
  shortlog cat-file ls-files ls-tree ls-remote for-each-ref grep
  whatchanged merge-base symbolic-ref var version help archive
)

# Subcommands whose "read-only-ness" depends on the next positional arg.
# Implementation in _rd_subcommand_is_read_only.
_RD_CONDITIONAL=(remote config branch tag bisect worktree submodule stash notes)

# _rd_strip_global_flags <args...>
# Drops leading global flags that come between `git` and the subcommand
# (-c key=value, -C path, --git-dir=, --work-tree=, --no-pager, ...).
# Echoes the remaining args, one per line.
_rd_strip_global_flags() {
  local skip_next=0
  local seen_subcmd=0
  local out=()
  local arg
  for arg in "$@"; do
    if [[ "$seen_subcmd" -eq 1 ]]; then
      out+=("$arg")
      continue
    fi
    if [[ "$skip_next" -eq 1 ]]; then
      skip_next=0
      continue
    fi
    case "$arg" in
      -c|-C)
        skip_next=1
        ;;
      --git-dir=*|--work-tree=*|--namespace=*|--exec-path=*|\
      --no-pager|--paginate|--no-replace-objects|--bare|--exec-path|\
      -P|--literal-pathspecs|--glob-pathspecs|--noglob-pathspecs|\
      --icase-pathspecs|--no-optional-locks|--no-advice|\
      --list-cmds=*|--super-prefix=*)
        ;;
      *)
        seen_subcmd=1
        out+=("$arg")
        ;;
    esac
  done
  printf '%s\n' "${out[@]}"
}

# _rd_subcommand_is_read_only <subcmd> [args...]
# Returns 0 (true) when the subcommand+args is a known read-only inspection
# form, 1 (false) otherwise.
_rd_subcommand_is_read_only() {
  local sub="$1"
  shift
  local arr a

  for a in "${_RD_READ_ONLY_PLAIN[@]}"; do
    [[ "$sub" == "$a" ]] && return 0
  done

  case "$sub" in
    remote)
      # `git remote` (no args) and `git remote -v` are list. `git remote
      # show <name>` is read-only too. Anything starting with add/remove/
      # rename/set-url/set-head/prune/update is a write.
      local first
      first=$(_rd_first_positional "$@")
      case "$first" in
        ""|show|get-url) return 0 ;;
        *) return 1 ;;
      esac
      ;;
    config)
      # `git config --get|--get-all|--get-regexp|--list|-l` is read-only.
      # Bare `git config` prints help (read-only). Anything else writes.
      local has_write=0 has_read=0 had_any=0
      for a in "$@"; do
        had_any=1
        case "$a" in
          --get|--get-all|--get-regexp|--get-urlmatch|--list|-l|\
          --show-origin|--show-scope|--name-only|--includes|\
          --no-includes|--default=*|--type=*)
            has_read=1
            ;;
          --add|--unset|--unset-all|--replace-all|--rename-section|\
          --remove-section|--edit|-e|--set|--set-all)
            has_write=1
            ;;
          -*)
            ;;
          *)
            ;;
        esac
      done
      if [[ "$had_any" -eq 0 ]]; then
        return 0
      fi
      if [[ "$has_write" -eq 1 ]]; then
        return 1
      fi
      if [[ "$has_read" -eq 1 ]]; then
        return 0
      fi
      # config with only positionals (e.g. `git config user.email`) is a
      # read of a single key; treat as read-only.
      return 0
      ;;
    branch)
      # `git branch` (no args) lists. `-l|--list|-a|-r|--show-current|-v|-vv|
      # --merged|--no-merged|--contains|--points-at` are list. Anything else
      # mutates (create / delete / rename / move / set-upstream-to / etc.).
      local first
      first=$(_rd_first_positional "$@")
      if [[ -z "$first" ]]; then
        # Only flags. List flags are read-only; mutation flags are write.
        for a in "$@"; do
          case "$a" in
            -d|-D|--delete|-m|-M|--move|-c|-C|--copy|--set-upstream-to=*|\
            --set-upstream|-u|--unset-upstream|--track|--no-track|\
            --edit-description|-f|--force)
              return 1
              ;;
          esac
        done
        return 0
      fi
      return 1
      ;;
    tag)
      # `git tag` (no args) and `tag -l|--list|-n` is list. Anything with a
      # positional arg or a write flag is a write.
      local first
      first=$(_rd_first_positional "$@")
      if [[ -z "$first" ]]; then
        for a in "$@"; do
          case "$a" in
            -d|--delete|-f|--force|-s|-u|-a|--annotate|--sign)
              return 1
              ;;
          esac
        done
        return 0
      fi
      return 1
      ;;
    bisect)
      # `view` and `log` are pure inspection. `visualize` opens gitk; while
      # technically read-only it spawns a GUI side-effect that the operator
      # likely does not want when the lock is on, so it is denied.
      local first
      first=$(_rd_first_positional "$@")
      case "$first" in
        view|log) return 0 ;;
        *) return 1 ;;
      esac
      ;;
    worktree)
      local first
      first=$(_rd_first_positional "$@")
      case "$first" in
        list) return 0 ;;
        *) return 1 ;;
      esac
      ;;
    submodule)
      local first
      first=$(_rd_first_positional "$@")
      case "$first" in
        ""|status|summary) return 0 ;;
        *) return 1 ;;
      esac
      ;;
    stash)
      # Bare `git stash` is shorthand for `git stash push`; only `list` and
      # `show` are inspection forms.
      local first
      first=$(_rd_first_positional "$@")
      case "$first" in
        list|show) return 0 ;;
        *) return 1 ;;
      esac
      ;;
    notes)
      local first
      first=$(_rd_first_positional "$@")
      case "$first" in
        ""|list|show) return 0 ;;
        *) return 1 ;;
      esac
      ;;
  esac

  return 1
}

# _rd_first_positional <args...>
# Echoes the first arg that does not start with "-" (and is not the value
# of an option). For our use: `--foo=bar` is one token, so we just need to
# skip leading dash-tokens.
_rd_first_positional() {
  local a
  for a in "$@"; do
    case "$a" in
      -*) ;;
      *) printf '%s' "$a"; return 0 ;;
    esac
  done
  return 0
}

guard_repo_deny() {
  local input="$1"
  local command
  command=$(jq -r '.tool_input.command // empty' <<< "$input" 2>/dev/null)
  [[ -z "$command" ]] && return 0

  # Only consider commands that begin (after leading whitespace, env-var
  # assignments, or a pipeline boundary) with `git`. We do not chase
  # complex compound commands; if Claude wraps git in a subshell to
  # evade the guard that is on the operator's side of the line.
  local git_re='(^|[[:space:];&|(])git([[:space:]]|$)'
  if [[ ! "$command" =~ $git_re ]]; then
    return 0
  fi

  # Tokenize. The command can contain quotes; for subcommand and flag
  # detection a shell-style word split is good enough because subcommand
  # tokens, global-flag names, and write-flag names are always plain words
  # without embedded spaces. Use `read -ra` so quoted-string fragments stay
  # in their own token rather than splitting on inner whitespace.
  local rest="${command#*git}"
  rest="${rest#"${rest%%[![:space:]]*}"}"
  local -a raw_args=()
  read -ra raw_args <<< "$rest"

  # Strip global flags.
  local stripped
  stripped=$(_rd_strip_global_flags "${raw_args[@]}")
  if [[ -z "$stripped" ]]; then
    # Bare `git` (help). Read-only.
    return 0
  fi
  local -a args=()
  while IFS= read -r line; do
    args+=("$line")
  done <<< "$stripped"

  local subcmd="${args[0]}"
  if [[ -z "$subcmd" ]]; then
    return 0
  fi
  local rest_args=("${args[@]:1}")

  if _rd_subcommand_is_read_only "$subcmd" "${rest_args[@]}"; then
    return 0
  fi

  # Mutation candidate. Locate the .git directory by walking up from $PWD
  # in pure bash. This avoids a `git rev-parse` subprocess on every git
  # command (a non-trivial cost in chatty sessions) and keeps the guard
  # callable from environments where `git` is shimmed or unavailable.
  local sentinel="" dir="$PWD"
  while [[ -n "$dir" && "$dir" != "/" ]]; do
    if [[ -d "$dir/.git" ]]; then
      sentinel="$dir/.git/git-discipline-deny"
      break
    fi
    if [[ -f "$dir/.git" ]]; then
      # Linked worktree. The .git file points at the worktree-specific
      # gitdir; the lock lives in the common dir. Read the gitdir, then
      # resolve via `commondir` if present.
      local gitdir
      gitdir=$(sed -n 's/^gitdir: //p' "$dir/.git" 2>/dev/null)
      if [[ -n "$gitdir" ]]; then
        # commondir file (relative path) points to the main .git/.
        if [[ -f "$gitdir/commondir" ]]; then
          local commondir
          commondir=$(< "$gitdir/commondir")
          if [[ "$commondir" = /* ]]; then
            sentinel="$commondir/git-discipline-deny"
          else
            sentinel="$gitdir/$commondir/git-discipline-deny"
          fi
        else
          sentinel="$gitdir/git-discipline-deny"
        fi
      fi
      break
    fi
    dir=$(dirname "$dir")
  done

  [[ -n "$sentinel" && -f "$sentinel" ]] || return 0

  local reason_part
  reason_part=$(dd_lock_suffix "$sentinel")

  # allow-comment: name who may lift the lock rather than telling the reader to
  # allow-comment: run the toggle. An agent cannot: the command is operator-only
  # allow-comment: and sentinel-protect denies agent-driven removal, so an
  # allow-comment: instruction phrased at the agent sends it into a refusal.
  dd_emit_deny "disable-git" \
"This repo is locked by the git-discipline plugin (.git/git-discipline-deny).${reason_part} Subcommand '$subcmd' is a mutation. You cannot lift this yourself: the sentinel-protect guard denies agent-driven removal, and the toggle is operator-invoked only. Ask the operator to type /git-discipline:enable-git. Read-only git keeps working meanwhile (status, log, diff, show, rev-parse, blame)."
}
