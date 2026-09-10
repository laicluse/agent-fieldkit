#!/usr/bin/env bats
# Pointer fix for commit-subject deny messages: the rotation reminder
# names the SKILL.md path so the password lookup is a direct Read, not
# a grep through the plugin cache. Paths under $HOME are shown with a
# leading "~" so the deny stays portable across machines and does not
# leak the operator's home prefix; the underlying path must still
# resolve to a real file. Broken installs surface loudly rather than
# silently degrading to the slash-command form (which would re-introduce
# grep-fishing).

load helpers

@test "rotation reminder names a SKILL.md path that resolves to the file" {
  run_dispatch "git commit -m 'Drop bad reading on transaction events'"
  [ "$status" -eq 2 ]
  # Capture the path the hook emitted: either absolute (/...) or
  # home-relative (~/...), up to "/SKILL.md".
  local extracted
  extracted=$(printf '%s' "$output" | grep -oE '(~|/)[A-Za-z0-9_./ -]*/SKILL\.md' | head -1)
  [[ -n "$extracted" ]] || {
    printf 'expected SKILL.md path in output, got: %s\n' "$output" >&2
    return 1
  }
  [[ "$extracted" == /* || "$extracted" == "~/"* ]] || {
    printf 'expected path to be absolute or home-relative, got: %s\n' "$extracted" >&2
    return 1
  }
  local resolved="${extracted/#\~/$HOME}"
  [ -f "$resolved" ] || {
    printf 'expected SKILL.md to exist on disk at: %s (resolved from %s)\n' "$resolved" "$extracted" >&2
    return 1
  }
  [[ "$output" =~ "Rotation reminders" ]] || {
    printf 'expected section anchor in output, got: %s\n' "$output" >&2
    return 1
  }
}

@test "deny still tells the operator to paste the ack token" {
  run_dispatch "git commit -m 'Drop bad reading on transaction events'"
  [ "$status" -eq 2 ]
  [[ "$output" =~ "ack-rule" ]] || {
    printf 'expected ack-rule instruction in output, got: %s\n' "$output" >&2
    return 1
  }
}

@test "broken install surfaces a loud deny instead of silently degrading" {
  # Force the skill-path resolution to fail by relocating commit-subject.sh
  # into a fake install root that lacks the skills/commit-discipline subtree
  # alongside it. The guard sets `_DD_HERE` at source time from
  # `$BASH_SOURCE[0]`, which resolves to the relocated copy here, so the
  # `cd "$_DD_HERE/../../skills/commit-discipline"` path is missing and the
  # install-broken deny fires. With no slash-command fallback any more, the
  # hook must emit that deny rather than silently degrading.
  local broken_root="$BATS_TEST_TMPDIR/no-such-install"
  mkdir -p "$broken_root/hooks/guards"
  cp "$PKG_ROOT/hooks/guards/commit-subject.sh" "$broken_root/hooks/guards/"
  cp "$PKG_ROOT/hooks/lib/rotation-rules.sh" "$broken_root/hooks/guards/"
  run bash -c "
    source '$PKG_ROOT/hooks/lib/common.sh'
    DD_RULE_PASSWORD=()
    source '$PKG_ROOT/hooks/lib/rotation-rules.sh'
    source '$broken_root/hooks/guards/commit-subject.sh'
    json='{\"tool_input\":{\"command\":\"git commit -m \\\"Some subject\\\"\"}}'
    guard_commit_subject \"\$json\"
  "
  [ "$status" -eq 2 ]
  [[ "$output" =~ "install appears broken" ]] || {
    printf 'expected install-broken deny in output, got: %s\n' "$output" >&2
    return 1
  }
  [[ "$output" =~ "Reinstall git-discipline@laicluse-agent-fieldkit" ]] || {
    printf 'expected reinstall instruction in output, got: %s\n' "$output" >&2
    return 1
  }
}
