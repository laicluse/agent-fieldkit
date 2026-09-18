#!/usr/bin/env bats
# allow-comment: Walks the push-destination matrix against fixture repositories whose regime is declared through codingAgent.git.* overrides, with gh and vaultsync stubbed so no network or daemon is involved.

DISPATCH="$BATS_TEST_DIRNAME/../../hooks/dispatch.sh"

setup() {
  export FAKEBIN="$BATS_TEST_TMPDIR/fakebin"
  export LAICLUSE_HOME="$BATS_TEST_TMPDIR/laicluse"
  mkdir -p "$FAKEBIN" "$LAICLUSE_HOME"
  printf '#!/usr/bin/env bash\nexit 1\n' > "$FAKEBIN/gh"
  cat > "$FAKEBIN/vaultsync" <<'SH'
#!/usr/bin/env bash
case "$2" in
  *daemon-vault*) printf '{"managed": true}\n' ;;
  *) printf '{"managed": false}\n' ;;
esac
SH
  chmod +x "$FAKEBIN/gh" "$FAKEBIN/vaultsync"
}

make_repo() {
  local name="$1" visibility="$2" collaboration="$3" policy="$4"
  local repo="$BATS_TEST_TMPDIR/$name"
  git init -q --bare "$BATS_TEST_TMPDIR/$name-origin.git"
  git init -q -b main "$repo"
  git -C "$repo" config core.hooksPath /dev/null
  git -C "$repo" config user.email test@example.invalid
  git -C "$repo" config user.name Test
  git -C "$repo" config codingAgent.git.pushAccess write
  git -C "$repo" config codingAgent.git.visibility "$visibility"
  git -C "$repo" config codingAgent.git.collaboration "$collaboration"
  git -C "$repo" config codingAgent.git.defaultBranchPolicy "$policy"
  git -C "$repo" remote add origin "$BATS_TEST_TMPDIR/$name-origin.git"
  echo root > "$repo/README.md"
  git -C "$repo" add README.md
  git -C "$repo" commit -q -m init
  git -C "$repo" branch feature
  git -C "$repo" tag v1.0.0
  printf '%s\n' "$repo"
}

push_from() {
  local payload
  payload=$(jq -cn --arg cwd "$1" --arg cmd "$2" '{hook_event_name:"PreToolUse", tool_name:"Bash", cwd:$cwd, tool_input:{command:$cmd}}')
  run env PATH="$FAKEBIN:$PATH" VAULTSYNC_BIN="$FAKEBIN/vaultsync" bash -c 'printf "%s" "$1" | bash "$2"' _ "$payload" "$DISPATCH"
}

held() {
  [ "$status" -eq 2 ]
  [[ "$output" == *"[git-discipline/push-destination] Push held for agreement."* ]]
}

refused() {
  [ "$status" -eq 2 ]
  [[ "$output" == *"[git-discipline/push-destination] Push refused."* ]]
}

passes() {
  [[ "$output" != *"push-destination"* ]]
}

@test "a carte blanche repo pushes its default branch without a word" {
  repo=$(make_repo solo private individual pushable)
  push_from "$repo" 'git push origin main'
  passes
  push_from "$repo" 'git push'
  passes
}

@test "a release repo holds its default branch until the operator agreed" {
  repo=$(make_repo marketplace public individual pushable)
  push_from "$repo" 'git push origin main'
  held
  [[ "$output" == *"is a release here"* ]]
  [[ "$output" == *"Unpushed committed work is done and safe"* ]]
  [[ "$output" == *"a remark about pushing is not agreement"* ]]
  push_from "$repo" 'git push origin main # push-agreed'
  passes
}

@test "a push aimed at another repository is judged by that repository" {
  solo=$(make_repo solo private individual pushable)
  marketplace=$(make_repo marketplace public individual pushable)
  push_from "$solo" "cd $marketplace && git push origin main 2>&1 | tail -3"
  held
  push_from "$solo" "git -C $marketplace push origin main"
  [ "$status" -eq 2 ]
}

@test "a pull request repo never pushes its default branch, agreed or not" {
  repo=$(make_repo team private shared protected)
  push_from "$repo" 'git push origin main'
  refused
  [[ "$output" == *"changes only through a pull request merge"* ]]
  [[ "$output" == *"whether the remote would reject the push does not matter"* ]]
  push_from "$repo" 'git push origin main # push-agreed'
  refused
  push_from "$repo" 'git push origin HEAD:main'
  refused
  push_from "$repo" 'git push origin +feature:refs/heads/main'
  refused
}

@test "a pull request repo pushes its branches as part of the work" {
  repo=$(make_repo team private shared protected)
  push_from "$repo" 'git push -u origin feature'
  passes
  push_from "$repo" 'git push --force-with-lease origin feature'
  passes
  git -C "$repo" checkout -q feature
  push_from "$repo" 'git push'
  passes
}

@test "an undetermined default branch policy counts as pull request flow" {
  repo=$(make_repo unknown private shared pushable)
  git -C "$repo" config --unset codingAgent.git.defaultBranchPolicy
  git -C "$repo" remote set-url origin git@github.com:org/repo.git
  push_from "$repo" 'git push origin main'
  refused
}

@test "a daemon-synced checkout leaves its default branch to the daemon" {
  repo=$(make_repo daemon-vault private individual pushable)
  push_from "$repo" 'git push origin main'
  refused
  [[ "$output" == *"sync daemon owns"* ]]
}

@test "the first push of a branch in a public repo is held, later pushes pass" {
  repo=$(make_repo marketplace public individual pushable)
  push_from "$repo" 'git push -u origin feature'
  held
  [[ "$output" == *"makes its content public"* ]]
  git -C "$repo" push -q origin feature
  push_from "$repo" 'git push origin feature'
  passes
}

@test "tags, bulk pushes, deletions, plain force are held" {
  repo=$(make_repo team private shared protected)
  push_from "$repo" 'git push origin v1.0.0'
  held
  push_from "$repo" 'git push origin tag v1.0.0'
  held
  push_from "$repo" 'git push --tags'
  held
  push_from "$repo" 'git push --all origin'
  held
  push_from "$repo" 'git push --mirror'
  held
  push_from "$repo" 'git push origin :feature'
  held
  push_from "$repo" 'git push origin --delete feature'
  held
  push_from "$repo" 'git push --force origin feature'
  held
  [[ "$output" == *"--force-with-lease"* ]]
}

@test "a remote other than the repository's own is held" {
  repo=$(make_repo solo private individual pushable)
  git init -q --bare "$BATS_TEST_TMPDIR/deploy.git"
  git -C "$repo" remote add heroku "$BATS_TEST_TMPDIR/deploy.git"
  push_from "$repo" 'git push heroku main'
  held
  [[ "$output" == *"deploy target or somebody else's repository"* ]]
}

@test "a rewrite of a carte blanche default branch is held" {
  repo=$(make_repo solo private individual pushable)
  push_from "$repo" 'git push --force origin main'
  held
}

@test "what cannot be classified is held" {
  repo=$(make_repo solo private individual pushable)
  push_from "$repo" 'git push origin "$BRANCH"'
  held
  push_from "$repo" 'git push origin no-such-ref'
  held
  push_from "$repo" 'cd "$SOMEWHERE" && git push'
  held
  git -C "$repo" checkout -q --detach
  push_from "$repo" 'git push'
  held
}

@test "a dry run, a repo without a remote, push text that is data all pass" {
  repo=$(make_repo marketplace public individual pushable)
  push_from "$repo" 'git push --dry-run origin main'
  passes
  push_from "$repo" 'git commit --allow-empty -m "explain git push origin main"'
  passes
  push_from "$repo" 'git stash push -m parked'
  passes
  git -C "$repo" remote remove origin
  push_from "$repo" 'git push'
  passes
}

@test "a release push of a locally installed marketplace names the local update route" {
  repo=$(make_repo marketplace public individual pushable)
  mkdir -p "$BATS_TEST_TMPDIR/home/.claude/plugins" "$BATS_TEST_TMPDIR/home/.codex"
  jq -n --arg path "$repo" '{"local-kit": {source: {source: "directory", path: $path}}}' > "$BATS_TEST_TMPDIR/home/.claude/plugins/known_marketplaces.json"
  printf '[marketplaces.local-kit]\nsource_type = "local"\nsource = "%s"\n' "$repo" > "$BATS_TEST_TMPDIR/home/.codex/config.toml"
  payload=$(jq -cn --arg cwd "$repo" '{hook_event_name:"PreToolUse", tool_name:"Bash", cwd:$cwd, tool_input:{command:"git push origin main"}}')
  run env HOME="$BATS_TEST_TMPDIR/home" PATH="$FAKEBIN:$PATH" VAULTSYNC_BIN="$FAKEBIN/vaultsync" bash -c 'printf "%s" "$1" | bash "$2"' _ "$payload" "$DISPATCH"
  held
  [[ "$output" == *"Local plugin installs read this checkout and need no push."* ]]
}

@test "a release push of a repository no local marketplace reads stays silent about local installs" {
  repo=$(make_repo marketplace public individual pushable)
  mkdir -p "$BATS_TEST_TMPDIR/home"
  payload=$(jq -cn --arg cwd "$repo" '{hook_event_name:"PreToolUse", tool_name:"Bash", cwd:$cwd, tool_input:{command:"git push origin main"}}')
  run env HOME="$BATS_TEST_TMPDIR/home" PATH="$FAKEBIN:$PATH" VAULTSYNC_BIN="$FAKEBIN/vaultsync" bash -c 'printf "%s" "$1" | bash "$2"' _ "$payload" "$DISPATCH"
  held
  [[ "$output" != *"Local plugin installs"* ]]
}
