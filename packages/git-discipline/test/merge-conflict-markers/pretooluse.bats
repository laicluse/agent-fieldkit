#!/usr/bin/env bats
# packages/git-discipline/test/merge-conflict-markers/pretooluse.bats
#
# PreToolUse:Bash layer for the conflict-marker guard. Drives hooks/dispatch.sh
# against a real repo left mid-merge, asserting that a merge-finalizing command
# is denied while markers remain and passes once the tree is clean.

load helpers

@test "git commit with conflict markers in working tree is denied, naming the file" {
  seed_conflict
  run_dispatch_in_repo 'git commit -m "resolve"'

  [ "$status" -eq 2 ]
  [[ "$output" == *"[git-discipline/merge-conflict-markers]"* ]]
  [[ "$output" == *"f.txt"* ]]
}

@test "git merge --continue with conflict markers is denied" {
  seed_conflict
  run_dispatch_in_repo 'git merge --continue'

  [ "$status" -eq 2 ]
  [[ "$output" == *"[git-discipline/merge-conflict-markers]"* ]]
}

@test "git rebase --continue with conflict markers is denied" {
  seed_conflict
  run_dispatch_in_repo 'git rebase --continue'

  [ "$status" -eq 2 ]
  [[ "$output" == *"[git-discipline/merge-conflict-markers]"* ]]
}

@test "git cherry-pick --continue with conflict markers is denied" {
  seed_cherry_pick_conflict
  run_dispatch_in_repo 'git cherry-pick --continue'

  [ "$status" -eq 2 ]
  [[ "$output" == *"[git-discipline/merge-conflict-markers]"* ]]
}

@test "git am --continue with conflict markers is denied" {
  seed_conflict
  run_dispatch_in_repo 'git am --continue'

  [ "$status" -eq 2 ]
  [[ "$output" == *"[git-discipline/merge-conflict-markers]"* ]]
}

@test "git commit --amend with conflict markers is denied" {
  seed_conflict
  git -C "$TEST_REPO" add f.txt
  run_dispatch_in_repo 'git commit --amend --no-edit'

  [ "$status" -eq 2 ]
  [[ "$output" == *"[git-discipline/merge-conflict-markers]"* ]]
}

@test "starting a merge (no --continue) is not a finalizing command, passes silently" {
  seed_conflict
  run_dispatch_in_repo 'git merge sidebranch'

  [ "$status" -eq 0 ]
  [[ "$output" != *"[git-discipline/merge-conflict-markers]"* ]]
}

@test "a hand-pasted conflict block (no merge in progress) is denied on commit" {
  seed_pasted_markers
  run_dispatch_in_repo 'git commit -m "land it"'

  [ "$status" -eq 2 ]
  [[ "$output" == *"[git-discipline/merge-conflict-markers]"* ]]
  [[ "$output" == *"f.txt"* ]]
}

@test "GIT_DISCIPLINE_ALLOW_CONFLICT_MARKERS set to a non-1 value does not escape" {
  seed_conflict
  export GIT_DISCIPLINE_ALLOW_CONFLICT_MARKERS=true
  run_dispatch_in_repo 'git commit -m "resolve"'
  unset GIT_DISCIPLINE_ALLOW_CONFLICT_MARKERS

  [ "$status" -eq 2 ]
  [[ "$output" == *"[git-discipline/merge-conflict-markers]"* ]]
}

@test "git commit with markers staged (the add-then-commit case) is denied" {
  seed_conflict
  git -C "$TEST_REPO" add f.txt   # stage the still-conflicted file
  run_dispatch_in_repo 'git commit -m "resolve"'

  [ "$status" -eq 2 ]
  [[ "$output" == *"[git-discipline/merge-conflict-markers]"* ]]
  [[ "$output" == *"f.txt"* ]]
}

@test "git commit after a clean resolution passes" {
  seed_conflict
  resolve_clean
  run_dispatch_in_repo 'git commit -m "resolve"'

  [ "$status" -eq 0 ]
  [[ "$output" != *"[git-discipline/merge-conflict-markers]"* ]]
}

@test "markdown ======= underline of non-conflict length does not trip the guard" {
  seed_conflict
  resolve_clean
  # 9-equals setext underline: not a 7-char conflict separator.
  printf 'Heading\n=========\nbody\n' > "$TEST_REPO/notes.md"
  git -C "$TEST_REPO" add notes.md
  run_dispatch_in_repo 'git commit -m "resolve"'

  [ "$status" -eq 0 ]
  [[ "$output" != *"[git-discipline/merge-conflict-markers]"* ]]
}

@test "a setext underline of exactly seven equals signs does not trip the guard" {
  seed_conflict
  resolve_clean
  printf 'Notulen\n=======\nbody\n' > "$TEST_REPO/notes.md"
  git -C "$TEST_REPO" add notes.md
  run_dispatch_in_repo 'git commit -m "resolve"'

  [ "$status" -eq 0 ]
  [[ "$output" != *"[git-discipline/merge-conflict-markers]"* ]]
}

@test "a staged conflict region still trips the guard after the working tree is cleaned" {
  seed_conflict
  git -C "$TEST_REPO" add f.txt
  printf 'resolved\n' > "$TEST_REPO/f.txt"
  run_dispatch_in_repo 'git commit -m "resolve"'

  [ "$status" -eq 2 ]
  [[ "$output" == *"f.txt"* ]]
}

@test "a leftover diff3 base marker still trips the guard" {
  seed_conflict
  printf 'l1\n||||||| base\nMERGED\nl3\n' > "$TEST_REPO/f.txt"
  git -C "$TEST_REPO" add f.txt
  run_dispatch_in_repo 'git commit -m "resolve"'

  [ "$status" -eq 2 ]
  [[ "$output" == *"f.txt"* ]]
}

@test "an unstaged conflict is found from a subdirectory" {
  mkdir -p "$TEST_REPO/docs"
  seed_conflict
  pretool_json 'git commit -am "resolve"' > "$BATS_TEST_TMPDIR/payload.json"
  run bash -c "cd '$TEST_REPO/docs' && bash '$DISPATCH' < '$BATS_TEST_TMPDIR/payload.json'"

  [ "$status" -eq 2 ]
  [[ "$output" == *"f.txt"* ]]
}

@test "a new setext underline beside a quoted conflict example passes" {
  printf 'Example\n\n```\n<<<<<<< ours\n```\n' > "$TEST_REPO/notes.md"
  git -C "$TEST_REPO" add notes.md
  git -C "$TEST_REPO" commit -q -m "example" --no-verify
  printf 'Example\n\n```\n<<<<<<< ours\n```\n\nNotulen\n=======\n' > "$TEST_REPO/notes.md"
  git -C "$TEST_REPO" add notes.md
  run_dispatch_in_repo 'git commit -m "notes"'

  [ "$status" -eq 0 ]
  [[ "$output" != *"[git-discipline/merge-conflict-markers]"* ]]
}

@test "a lone separator left in a non-markdown file still trips the guard" {
  seed_conflict
  printf 'l1\nMERGED\n=======\nl3\n' > "$TEST_REPO/f.txt"
  git -C "$TEST_REPO" add f.txt
  run_dispatch_in_repo 'git commit -m "resolve"'

  [ "$status" -eq 2 ]
  [[ "$output" == *"f.txt"* ]]
}

@test "a separator under an ATX heading or a fence still trips the guard" {
  printf '# Inleiding\n=======\n' > "$TEST_REPO/intro.md"
  printf '```\nvalue = 1\n=======\n```\n' > "$TEST_REPO/fence.md"
  git -C "$TEST_REPO" add intro.md fence.md
  run_dispatch_in_repo 'git commit -m "notes"'

  [ "$status" -eq 2 ]
  [[ "$output" == *"intro.md"* ]]
  [[ "$output" == *"fence.md"* ]]
}

@test "a setext underline passes from a subdirectory with relative diff paths" {
  mkdir -p "$TEST_REPO/docs"
  git -C "$TEST_REPO" config diff.relative true
  printf 'Notulen\n=======\n' > "$TEST_REPO/docs/notes.md"
  git -C "$TEST_REPO" add docs/notes.md
  pretool_json 'git commit -m "notes"' > "$BATS_TEST_TMPDIR/payload.json"
  run bash -c "cd '$TEST_REPO/docs' && bash '$DISPATCH' < '$BATS_TEST_TMPDIR/payload.json'"

  [ "$status" -eq 0 ]
  [[ "$output" != *"[git-discipline/merge-conflict-markers]"* ]]
}

@test "magic-comment escape allows the commit despite markers" {
  seed_conflict
  run_dispatch_in_repo 'git commit -m "resolve" # allow-conflict-markers'

  [ "$status" -eq 0 ]
  [[ "$output" != *"[git-discipline/merge-conflict-markers]"* ]]
}

@test "exported env-var escape allows the commit despite markers" {
  seed_conflict
  export GIT_DISCIPLINE_ALLOW_CONFLICT_MARKERS=1
  run_dispatch_in_repo 'git commit -m "resolve"'
  unset GIT_DISCIPLINE_ALLOW_CONFLICT_MARKERS

  [ "$status" -eq 0 ]
  [[ "$output" != *"[git-discipline/merge-conflict-markers]"* ]]
}

@test "non-commit git command passes silently" {
  seed_conflict
  run_dispatch_in_repo 'git status'

  [ "$status" -eq 0 ]
  [[ "$output" != *"[git-discipline/merge-conflict-markers]"* ]]
}
