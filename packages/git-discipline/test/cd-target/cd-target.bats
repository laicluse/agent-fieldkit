#!/usr/bin/env bats
# allow-comment: dd_cd_to_bash_target follows the repo a commit actually targets so the body validator reads the right index: the `cd <dir> &&` prefix and the `git -C <dir>` form both reposition the gate, even when the session cwd is an unrelated repo.

setup() {
  SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
  source "$SCRIPT_DIR/../../hooks/lib/common.sh"
  ORIGIN="$PWD"
  TARGET="$BATS_TEST_TMPDIR/target-repo"
  install -d "$TARGET"
}

teardown() {
  cd "$ORIGIN" 2>/dev/null || true
}

pretool_json() {
  jq -cn --arg c "$1" '{tool_input:{command:$c}}'
}

@test "cd prefix repositions the gate" {
  cd "$ORIGIN"
  dd_cd_to_bash_target "$(pretool_json "cd $TARGET && git commit -m x")"
  [ "$PWD" = "$TARGET" ]
}

@test "git -C repositions the gate" {
  cd "$ORIGIN"
  dd_cd_to_bash_target "$(pretool_json "git -C $TARGET commit -m x")"
  [ "$PWD" = "$TARGET" ]
}

@test "git -C with a quoted path repositions the gate" {
  cd "$ORIGIN"
  dd_cd_to_bash_target "$(pretool_json "git -C \"$TARGET\" commit -m x")"
  [ "$PWD" = "$TARGET" ]
}

@test "cd prefix with a newline separator repositions the gate" {
  cd "$ORIGIN"
  dd_cd_to_bash_target "$(pretool_json "$(printf 'cd %s\ngit commit -m x' "$TARGET")")"
  [ "$PWD" = "$TARGET" ]
}

@test "cd prefix with a semicolon separator repositions the gate" {
  cd "$ORIGIN"
  dd_cd_to_bash_target "$(pretool_json "cd $TARGET; git commit -m x")"
  [ "$PWD" = "$TARGET" ]
}

@test "cd prefix wins over a later git -C" {
  cd "$ORIGIN"
  local other="$BATS_TEST_TMPDIR/other-repo"
  install -d "$other"
  dd_cd_to_bash_target "$(pretool_json "cd $TARGET && git -C $other status")"
  [ "$PWD" = "$TARGET" ]
}

@test "no cd and no -C leaves the gate where it was" {
  cd "$ORIGIN"
  dd_cd_to_bash_target "$(pretool_json "git commit -m x")"
  [ "$PWD" = "$ORIGIN" ]
}

@test "a nonexistent -C target leaves the gate where it was" {
  cd "$ORIGIN"
  dd_cd_to_bash_target "$(pretool_json "git -C $BATS_TEST_TMPDIR/missing commit -m x")"
  [ "$PWD" = "$ORIGIN" ]
}

@test "explicit tool workdir repositions a command without a cd prefix" {
  dd_cd_to_bash_target "$(jq -cn --arg target "$TARGET" '{tool_input:{command:"git status",workdir:$target}}')"
  [ "$PWD" = "$TARGET" ]
}

@test "payload cwd provides the base for a relative tool workdir" {
  dd_cd_to_bash_target "$(jq -cn --arg base "$BATS_TEST_TMPDIR" '{cwd:$base,tool_input:{command:"git status",workdir:"target-repo"}}')"
  [ "$PWD" = "$TARGET" ]
}

@test "a relative cd prefix resolves inside the tool workdir" {
  install -d "$TARGET/nested"
  dd_cd_to_bash_target "$(jq -cn --arg target "$TARGET" '{tool_input:{command:"cd nested && git status",workdir:$target}}')"
  [ "$PWD" = "$TARGET/nested" ]
}

@test "relative workdir ignores CDPATH and emits no directory output" {
  local other="$BATS_TEST_TMPDIR/elsewhere" actual
  install -d "$other/target-repo"
  actual=$(
    CDPATH="$other" dd_cd_to_bash_target "$(jq -cn --arg base "$BATS_TEST_TMPDIR" '{cwd:$base,tool_input:{command:"git status",workdir:"target-repo"}}')"
    printf '%s' "$PWD"
  )
  [ "$actual" = "$TARGET" ]
}

@test "a workdir beginning with a dash is a directory rather than a cd option" {
  install -d "$BATS_TEST_TMPDIR/-target"
  dd_cd_to_bash_target "$(jq -cn --arg base "$BATS_TEST_TMPDIR" '{cwd:$base,tool_input:{command:"git status",workdir:"-target"}}')"
  [ "$PWD" = "$BATS_TEST_TMPDIR/-target" ]
}

@test "payload cwd alone repositions a Claude-shaped command" {
  dd_cd_to_bash_target "$(jq -cn --arg target "$TARGET" '{cwd:$target,tool_input:{command:"git status"}}')"
  [ "$PWD" = "$TARGET" ]
}

@test "tool cwd alias overrides the payload cwd" {
  dd_cd_to_bash_target "$(jq -cn --arg base "$BATS_TEST_TMPDIR" --arg target "$TARGET" '{cwd:$base,tool_input:{command:"git status",cwd:$target}}')"
  [ "$PWD" = "$TARGET" ]
}
