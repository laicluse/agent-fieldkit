#!/usr/bin/env bats
# clean-repo.bats
# An empty git repo with no existing hooks. install.sh writes both
# commit-msg and post-commit into .git/hooks/, executable, with the
# placeholder substituted by the resolved plugin install path.

load helpers

@test "fresh install lands commit-msg and post-commit" {
  run_install "$TEST_REPO"

  [ "$status" -eq 0 ]
  [ -f "$(hook_target_path commit-msg)" ]
  [ -f "$(hook_target_path post-commit)" ]
}

@test "installed hooks are executable" {
  run_install "$TEST_REPO"

  [ "$status" -eq 0 ]
  [ -x "$(hook_target_path commit-msg)" ]
  [ -x "$(hook_target_path post-commit)" ]
}

@test "placeholder __PLUGIN_INSTALL_PATH__ is replaced in the installed hook" {
  run_install "$TEST_REPO"

  [ "$status" -eq 0 ]
  ! grep -q '__PLUGIN_INSTALL_PATH__' "$(hook_target_path commit-msg)"
  # The installed hook must reference the validator at an absolute path.
  grep -q '/hooks/lib/validate-body.sh' "$(hook_target_path commit-msg)"
}

@test "installer prefers the script-local plugin root over a stale Claude install" {
  stale="$BATS_TEST_TMPDIR/stale-claude-install"
  mkdir -p "$stale/hooks/lib" "$HOME/.claude/plugins"
  printf 'stale validator\n' > "$stale/hooks/lib/validate-body.sh"
  cat > "$HOME/.claude/plugins/installed_plugins.json" <<JSON
{
  "plugins": {
    "git-discipline@laicluse-agent-fieldkit": [
      { "installPath": "$stale" }
    ]
  }
}
JSON

  run_install "$TEST_REPO"

  [ "$status" -eq 0 ]
  grep -q 'GIT_DISCIPLINE_RUNTIME_ROOT:-' "$(hook_target_path commit-msg)"
  grep -q "PLUGIN_PATH=.*$REPO_ROOT/packages/git-discipline" "$(hook_target_path commit-msg)"
  ! grep -q "$stale" "$(hook_target_path commit-msg)"
}

@test "post-commit does not need the placeholder substitution but installs cleanly" {
  run_install "$TEST_REPO"

  [ "$status" -eq 0 ]
  grep -q 'runtime/git-discipline-hook' "$(hook_target_path post-commit)"
  grep -q 'post-commit' "$(hook_target_path post-commit)"
}

@test "second run is an idempotent no-op (no errors, no extra writes)" {
  run_install "$TEST_REPO"
  [ "$status" -eq 0 ]

  run_install "$TEST_REPO"
  [ "$status" -eq 0 ]
  [[ "$output" == *"identical content"* ]]
}
