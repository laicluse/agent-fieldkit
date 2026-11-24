#!/usr/bin/env bats
# allow-comment: PostToolUse commit-body net over real commits. A body written by
# allow-comment: a path the PreToolUse string parser cannot see (-F file, editor,
# allow-comment: rebase, amend) must still be caught at creation time via the
# allow-comment: snapshot..HEAD range, because a remote-less repo never pushes.

GOOD_BODY=$'Add a clear capability\n\nThe system gains a real behaviour here, described in two sentences so the\nWHY block is satisfied and the gate is happy.\n\nSlice: docs-only\nVerified: n/a (no behaviour change)'

BAD_BODY=$'Add a clear capability\n\nThe system gains a real behaviour here, described in two sentences so the\nWHY block is satisfied and the gate is happy.\n\nSlice: docs-only\n\nVerified: n/a (no behaviour change)'

setup() {
  DISPATCH="$BATS_TEST_DIRNAME/../../hooks/dispatch.sh"
  REPO="$(mktemp -d)"
  export LAICLUSE_HOME="$(mktemp -d)"
  export GIT_DISCIPLINE_VERSION_SKEW_DISABLED=1
  cd "$REPO"
  git init -q
  git config user.email tester@example.com
  git config user.name Tester
  printf 'base\n' > base.txt
  git add base.txt
  git commit -q -m "Merge base" --no-verify
}

teardown() {
  rm -rf "$REPO" "$LAICLUSE_HOME"
}

pre_json() { jq -cn --arg c "$1" '{hook_event_name:"PreToolUse",tool_name:"Bash",tool_input:{command:$c},session_id:"sess-posttool"}'; }
post_json() { jq -cn --arg c "$1" '{hook_event_name:"PostToolUse",tool_name:"Bash",tool_input:{command:$c},session_id:"sess-posttool"}'; }

commit_with_body() {
  printf '%s' "$1" > .mwrite
  printf 'change %s\n' "$RANDOM" >> base.txt
  git add base.txt
  git commit -q -F .mwrite --no-verify
  rm -f .mwrite
}

@test "a clean -F commit passes the PostToolUse net" {
  bash "$DISPATCH" <<< "$(pre_json 'git commit -F msg')" || true
  commit_with_body "$GOOD_BODY"
  run bash "$DISPATCH" <<< "$(post_json 'git commit -F msg')"
  [ "$status" -eq 0 ]
}

@test "a malformed -F commit is caught by the PostToolUse net" {
  bash "$DISPATCH" <<< "$(pre_json 'git commit -F msg')" || true
  commit_with_body "$BAD_BODY"
  run bash "$DISPATCH" <<< "$(post_json 'git commit -F msg')"
  [ "$status" -eq 2 ]
  [[ "$output" == *"[git-discipline/commit-body]"* ]]
  [[ "$output" == *"just wrote"* ]]
}

@test "two malformed commits from one writer command are both reported" {
  bash "$DISPATCH" <<< "$(pre_json 'git rebase -i HEAD~2')" || true
  commit_with_body "$BAD_BODY"
  commit_with_body "$BAD_BODY"
  run bash "$DISPATCH" <<< "$(post_json 'git rebase -i HEAD~2')"
  [ "$status" -eq 2 ]
  local count
  count=$(printf '%s\n' "$output" | grep -c 'Add a clear capability')
  [ "$count" -eq 2 ]
}

@test "a teammate-authored commit in the range is skipped by the ours filter" {
  bash "$DISPATCH" <<< "$(pre_json 'git rebase main')" || true
  printf '%s' "$BAD_BODY" > .mwrite
  printf 'mate\n' >> base.txt
  git add base.txt
  GIT_AUTHOR_EMAIL=mate@example.com GIT_AUTHOR_NAME=Mate \
    GIT_COMMITTER_EMAIL=mate@example.com GIT_COMMITTER_NAME=Mate \
    git commit -q -F .mwrite --no-verify
  rm -f .mwrite
  run bash "$DISPATCH" <<< "$(post_json 'git rebase main')"
  [ "$status" -eq 0 ]
}

@test "a non-writer command does not trigger the net" {
  commit_with_body "$BAD_BODY"
  run bash "$DISPATCH" <<< "$(post_json 'git status')"
  [ "$status" -eq 0 ]
}

VISUAL_BODY=$'Add a clear capability\n\nThe system gains a real behaviour here, described in two sentences so the\nWHY block is satisfied and the gate is happy.\n\nSlice: docs-only\nVisual: the reset button stands first in the list -> notes/visual-checks/reset-first.png\nVerified: n/a (no behaviour change)'

NO_VISUAL_CHECK_BODY=$'Add a clear capability\n\nThe system gains a real behaviour here, described in two sentences so the\nWHY block is satisfied and the gate is happy.\n\nSlice: docs-only\nVisual: n/a (no visual change)\nVerified: n/a (no behaviour change)'

@test "a commit that carries a visual check reminds to show the capture" {
  bash "$DISPATCH" <<< "$(pre_json 'git commit -F msg')" || true
  commit_with_body "$VISUAL_BODY"
  run bash "$DISPATCH" <<< "$(post_json 'git commit -F msg')"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[git-discipline/visual-shown]"* ]]
  [[ "$output" == *"notes/visual-checks/reset-first.png"* ]]
  [ "$(jq -s 'length' <<< "$output")" -eq 1 ]
}

@test "a commit without a visual check gives no reminder to show one" {
  bash "$DISPATCH" <<< "$(pre_json 'git commit -F msg')" || true
  commit_with_body "$NO_VISUAL_CHECK_BODY"
  run bash "$DISPATCH" <<< "$(post_json 'git commit -F msg')"
  [ "$status" -eq 0 ]
  [[ "$output" != *"visual-shown"* ]]
}

ARROW_PATH_BODY=$'Add a clear capability\n\nThe system gains a real behaviour here, described in two sentences so the\nWHY block is satisfied and the gate is happy.\n\nSlice: docs-only\nVisual: the list is sorted -> captures/before -> after.png\nVerified: n/a (no behaviour change)'

NO_CHECK_THEN_ARROW_BODY=$'Add a clear capability\n\nThe system gains a real behaviour here, described in two sentences so the\nWHY block is satisfied and the gate is happy.\n\nSlice: docs-only\nVisual: n/a (no visual change)\nVisual: stray second trailer -> captures/unchecked.png\nVerified: n/a (no behaviour change)'

@test "the reminder names the capture after the first arrow, like the validator" {
  bash "$DISPATCH" <<< "$(pre_json 'git commit -F msg')" || true
  commit_with_body "$ARROW_PATH_BODY"
  run bash "$DISPATCH" <<< "$(post_json 'git commit -F msg')"
  [ "$status" -eq 0 ]
  [[ "$output" == *"captures/before -> after.png"* ]]
}

@test "only the first Visual trailer counts, so a stray second one gives no reminder" {
  bash "$DISPATCH" <<< "$(pre_json 'git commit -F msg')" || true
  commit_with_body "$NO_CHECK_THEN_ARROW_BODY"
  run bash "$DISPATCH" <<< "$(post_json 'git commit -F msg')"
  [[ "$output" != *"visual-shown"* ]]
}
