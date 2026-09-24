#!/bin/bash
# packages/git-discipline/skills/install-hooks/lib/install.sh
#
# Idempotent install of git-discipline's git-native hooks into the current repo.
# Detects core.hooksPath; refuses to overwrite without --force; supports
# --dry-run.
#
# Source hooks live next to this script under:
#   packages/git-discipline/skills/commit-discipline/git-hooks/
# Each source hook references "__PLUGIN_INSTALL_PATH__/hooks/lib/validate-body.sh".
# At install time the placeholder is substituted with the absolute plugin
# install path resolved from the plugin root that contains this script.
#
# Slice 6 ships commit-msg + post-commit. The script also installs
# prepare-commit-msg and pre-push when they exist so slices 7 and 8 do not
# need to touch this file.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILLS_ROOT="$(cd "$SKILL_DIR/.." && pwd)"
PLUGIN_ROOT="$(cd "$SKILLS_ROOT/.." && pwd)"
SOURCE_HOOKS_DIR="$SKILLS_ROOT/commit-discipline/git-hooks"

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

force=0
dry_run=0

for arg in "$@"; do
  case "$arg" in
    --force)   force=1 ;;
    --dry-run) dry_run=1 ;;
    --help|-h)
      grep '^#' "$0" | head -25 | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      printf 'Unknown option: %s\n' "$arg" >&2
      exit 1
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Repo guard
# ---------------------------------------------------------------------------

if ! git_dir=$(git rev-parse --git-common-dir 2>/dev/null); then
  printf 'git-discipline:install-hooks ERROR: not inside a git repository.\n' >&2
  exit 1
fi

# Resolve to absolute path (rev-parse may return a relative ".git").
git_dir=$(cd "$git_dir" && pwd)

# ---------------------------------------------------------------------------
# Resolve target hooks directory
# ---------------------------------------------------------------------------

target_dir=""
hooks_path_config=$(git config --local --get core.hooksPath 2>/dev/null || true)
configure_local_hooks_path=0

if [[ -n "$hooks_path_config" ]]; then
  # core.hooksPath can be relative to the repo root.
  if [[ "$hooks_path_config" = /* ]]; then
    target_dir="$hooks_path_config"
  else
    repo_root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
    target_dir="$repo_root/$hooks_path_config"
  fi
  hooks_dir_label="$hooks_path_config (core.hooksPath)"
else
  target_dir="$git_dir/hooks"
  hooks_dir_label="$git_dir/hooks"
  inherited_hooks_path=$(git config --get core.hooksPath 2>/dev/null || true)
  if [[ -n "$inherited_hooks_path" ]]; then
    configure_local_hooks_path=1
    hooks_dir_label="$git_dir/hooks (repo-local override of inherited core.hooksPath)"
  fi
fi

# ---------------------------------------------------------------------------
# Resolve plugin install path
# ---------------------------------------------------------------------------
# Strategy:
# 1. Prefer the plugin root that contains this script. This works for Claude
#    cache installs, Codex generated installs, and development checkouts.
# 2. Fall back to Claude's installed_plugins.json only for legacy layouts where
#    the script-local root does not contain the shared hook libraries.

plugin_install_path=""

if [[ -f "$PLUGIN_ROOT/hooks/lib/validate-body.sh" ]]; then
  plugin_install_path="$PLUGIN_ROOT"
else
  plugins_json="$HOME/.claude/plugins/installed_plugins.json"
  if [[ -f "$plugins_json" ]] && command -v jq >/dev/null 2>&1; then
    plugin_install_path=$(jq -r \
      '.plugins["git-discipline@laicluse-agent-fieldkit"][0].installPath // empty' \
      "$plugins_json" 2>/dev/null || true)
  fi
fi

# Validate: the resolved path must contain hooks/lib/validate-body.sh.
if [[ -z "$plugin_install_path" ]] \
   || [[ ! -f "$plugin_install_path/hooks/lib/validate-body.sh" ]]; then
  printf 'git-discipline:install-hooks ERROR: cannot resolve plugin install path.\n' >&2
  printf '  Tried script-local root : %s\n' "$PLUGIN_ROOT" >&2
  printf '  Tried Claude fallback   : %s\n' "${plugin_install_path:-<empty>}" >&2
  exit 1
fi

node_executable=$(node -p 'process.execPath' 2>/dev/null || true)
if [[ -z "$node_executable" ]] && command -v asdf >/dev/null 2>&1; then
  node_version=$(asdf list nodejs 2>/dev/null | sed 's/^[[:space:]*]*//' | tail -1)
  if [[ -n "$node_version" ]]; then
    node_executable=$(ASDF_NODEJS_VERSION="$node_version" node -p 'process.execPath' 2>/dev/null || true)
  fi
fi
if [[ -z "$node_executable" ]] || [[ ! -x "$node_executable" ]]; then
  printf 'git-discipline:install-hooks ERROR: cannot resolve a Node.js executable.\n' >&2
  exit 1
fi

if [[ "$dry_run" -eq 0 ]]; then
  "$node_executable" "$PLUGIN_ROOT/bin/git-discipline" runtime install >/dev/null
fi

# ---------------------------------------------------------------------------
# Hooks to install
# ---------------------------------------------------------------------------
# Slice 6 set: commit-msg, post-commit.
# Slice 7 will add pre-push, slice 8 prepare-commit-msg. Both will be
# auto-picked up here when the source files appear, no edits needed.

hook_candidates=(pre-commit commit-msg prepare-commit-msg post-commit post-rewrite pre-push)

# ---------------------------------------------------------------------------
# Install loop
# ---------------------------------------------------------------------------

installed=()
skipped_identical=()
skipped_conflict=()
backups=()
missing_sources=()

ts_label=$(date +%Y%m%dT%H%M%S)

if [[ "$dry_run" -eq 0 ]]; then
  mkdir -p "$target_dir"
  if [[ "$configure_local_hooks_path" -eq 1 ]]; then
    git config --local core.hooksPath "$target_dir"
  fi
fi

# rendered_source <hook-name>
# Reads the source script and substitutes runtime paths.
rendered_source() {
  local hook="$1"
  local src="$SOURCE_HOOKS_DIR/$hook"
  cat <<EOF
#!/bin/bash
runtime_launcher="\${LAICLUSE_HOME:-\$HOME/.laicluse}/git-discipline/runtime/git-discipline-hook"
if [[ -x "\$runtime_launcher" ]]; then
  exec "\$runtime_launcher" "$hook" "\$@"
fi
EOF
  # sed -i not portable across BSD/GNU; render to stdout instead.
  sed \
    -e "s|__PLUGIN_INSTALL_PATH__|$plugin_install_path|g" \
    -e "s|__NODE_EXECUTABLE__|$node_executable|g" \
    "$src"
}

exit_code=0

for hook in "${hook_candidates[@]}"; do
  src="$SOURCE_HOOKS_DIR/$hook"
  if [[ ! -f "$src" ]]; then
    missing_sources+=("$hook")
    continue
  fi

  target="$target_dir/$hook"
  new_content=$(rendered_source "$hook")

  if [[ -f "$target" ]]; then
    existing_content=$(cat "$target")
    if [[ "$existing_content" = "$new_content" ]]; then
      skipped_identical+=("$hook")
      # Make sure the executable bit is set (idempotent).
      if [[ "$dry_run" -eq 0 ]]; then
        chmod +x "$target" 2>/dev/null || true
      fi
      continue
    fi

    if [[ "$force" -eq 0 ]]; then
      printf '\n'
      printf 'WARN: %s already exists with different content.\n' "$target"
      printf -- '--- existing (%s)\n' "$target"
      printf -- '+++ new (from %s)\n' "$src"
      diff -u <(printf '%s\n' "$existing_content") <(printf '%s\n' "$new_content") || true
      printf '\n'
      printf 'Refusing to overwrite. Re-run with --force to backup-and-replace.\n'
      skipped_conflict+=("$hook")
      exit_code=1
      continue
    fi

    backup="$target.bak.$ts_label"
    if [[ "$dry_run" -eq 0 ]]; then
      cp -p "$target" "$backup"
    fi
    backups+=("$hook -> $backup")
  fi

  if [[ "$dry_run" -eq 1 ]]; then
    printf 'dry-run: would install %s -> %s\n' "$hook" "$target"
  else
    # Use the same byte-stream as the source: rendered_source preserves the
    # trailing newline that "$()" command-substitution would strip.
    rendered_source "$hook" > "$target"
    chmod +x "$target"
  fi

  installed+=("$hook")
done

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

printf '\ngit-discipline:install-hooks\n'
printf '  hooks dir   : %s\n' "$hooks_dir_label"
printf '  plugin path : %s\n' "$plugin_install_path"

if [[ "$dry_run" -eq 1 ]]; then
  printf '  mode        : dry-run (no files written)\n'
  if [[ "$configure_local_hooks_path" -eq 1 ]]; then
    printf '  would-set   : repo-local core.hooksPath=%s\n' "$target_dir"
  fi
fi

if [[ "${#installed[@]}" -gt 0 ]]; then
  for h in "${installed[@]}"; do
    if [[ "$dry_run" -eq 1 ]]; then
      printf '  would-install: %s\n' "$h"
    else
      printf '  installed   : %s\n' "$h"
    fi
  done
else
  printf '  installed   : (none)\n'
fi

if [[ "${#skipped_identical[@]}" -gt 0 ]]; then
  for h in "${skipped_identical[@]}"; do
    printf '  skipped     : %s (identical content)\n' "$h"
  done
fi

if [[ "${#skipped_conflict[@]}" -gt 0 ]]; then
  for h in "${skipped_conflict[@]}"; do
    printf '  conflict    : %s (use --force to overwrite)\n' "$h"
  done
fi

if [[ "${#backups[@]}" -gt 0 ]]; then
  for b in "${backups[@]}"; do
    printf '  backup      : %s\n' "$b"
  done
fi

if [[ "${#missing_sources[@]}" -gt 0 ]]; then
  for h in "${missing_sources[@]}"; do
    printf '  not-yet     : %s (source not present in this plugin version)\n' "$h"
  done
fi

if [[ "$exit_code" -eq 0 ]]; then
  printf 'done.\n'
fi

exit $exit_code
