#!/usr/bin/env bats
# packages/git-discipline/test/repo-deny/git-word-in-path.bats
#
# The guard must locate the real git invocation, not the first "git"
# substring on the line: a cd into github.com/... precedes many commands.

load helpers

@test "lock allows git status behind a path that contains the word git" {
  write_sentinel
  run_dispatch 'cd /tmp/github.com/owner/repo && git status --short'
  [ "$status" -eq 0 ]
}

@test "lock allows git log behind a path that contains the word git" {
  write_sentinel
  run_dispatch 'cd /tmp/github.com/owner/repo && git log --oneline -1'
  [ "$status" -eq 0 ]
}

@test "lock still blocks git push behind a path that contains the word git" {
  write_sentinel
  run_dispatch 'cd /tmp/github.com/owner/repo && git push origin main'
  [ "$status" -eq 2 ]
  [[ "$output" == *"[git-discipline/disable-git]"* ]]
}

@test "lock still blocks git commit behind a path that contains the word git" {
  write_sentinel
  run_dispatch 'cd /tmp/github.com/owner/repo && git commit -m foo'
  [ "$status" -eq 2 ]
}
