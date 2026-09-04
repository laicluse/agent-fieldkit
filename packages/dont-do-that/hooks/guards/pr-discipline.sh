#!/bin/bash
# PreToolUse:Bash guard for gh pr create / gh pr edit. allow-comment: hook-header documenting the matchers and the operator escape, same pattern as sibling no-remote-create.sh. Blocks when the title uses a placement-verb dodge (git-discipline Rule 1 vocabulary) or the body carries fixed-section or AI-attribution template signatures (## Summary / ## Test plan headers, generated-with footer, Co-Authored-By trailer with an @anthropic.com email). Also blocks gh pr create / gh pr ready when the head branch sits behind its base, because a pull request is offered against the tip of its base and GitHub reporting MERGEABLE only means 'no conflict', not 'current'. PR-time enforcement closes the gap left by the git-discipline commit-subject and commit-trailers guards, which fire on git commit but never on gh pr create.

guard_pr_discipline() {
  local input="$1"
  local cmd
  cmd=$(jq -r '.tool_input.command // empty' <<< "$input" 2>/dev/null)
  [ -z "$cmd" ] && return 0

  local segment pr_call="" pr_verb=""
  while IFS= read -r segment; do
    if [[ "$segment" =~ ^[[:space:]]*gh[[:space:]]+pr[[:space:]]+(create|edit|ready)([[:space:]]|$) ]]; then
      pr_call="$segment"
      pr_verb="${BASH_REMATCH[1]}"
      break
    fi
  done < <(dd_command_segments "$cmd")
  [ -n "$pr_call" ] || return 0

  local title
  title=$(grep -oE -- "--title[[:space:]]+(\"[^\"]*\"|'[^']*'|[^[:space:]]+)" <<< "$pr_call" \
    | head -1 \
    | sed -E "s/^--title[[:space:]]+//; s/^[\"']//; s/[\"']$//")

  if [ -n "$title" ]; then
    local activity_re='^(Fix|Improve|Update|Change|Refactor|Add|Extract|Move|Remove|Rename|Drop|Create|Clear|Land|Make|Work|Do|Get|Tweak|Surface|Address|Apply|Plant|Place|Pin|Lay|Anchor|Set|Stand|Mount|Install|Ship|Bring|Wire|Hook|Sow|Ground)[[:space:]]'
    shopt -s nocasematch
    if [[ "$title " =~ $activity_re ]]; then
      shopt -u nocasematch
      dd_emit_deny pr-discipline "PR title '${title}' starts with a placement or git-action verb (git-discipline Rule 1 vocabulary). PR titles describe the user-visible capability that exists now, not the placement action that landed it. Rewrite so the title answers 'what can the system do now that it could not before?'."
    fi
    shopt -u nocasematch
  fi

  if grep -qE '##[[:space:]]+(Summary|Test plan)[[:space:]]*$' <<< "$cmd"; then
    dd_emit_deny pr-discipline "PR body contains '## Summary' or '## Test plan' header. The body should be one or two paragraphs about why the change matters, not a fixed-section template."
  fi

  if grep -qE '(^|[[:space:]])(🤖[[:space:]]+)?Generated with[[:space:]]' <<< "$cmd"; then
    dd_emit_deny pr-discipline "PR body contains a generated-with footer. That signals AI authorship to the reviewer in a way the operator does not want; remove it."
  fi

  if grep -qE 'Co-Authored-By:[[:space:]]+[^<]*<[^>]*@anthropic\.com>' <<< "$cmd"; then
    dd_emit_deny pr-discipline "PR body contains a Co-Authored-By trailer with an @anthropic.com email. Remove the trailer; the change is the operator's, not a co-authored work."
  fi

  dd_pr_image_links "$cmd"

  # Currency check runs last: the content checks above are local and cheap,
  # this one costs a fetch. Only offering a PR counts, so `edit` is exempt.
  case "$pr_verb" in create|ready) ;; *) return 0 ;; esac
  grep -q -- '# allow-behind-default' <<< "$cmd" && return 0
  dd_pr_behind_base "$input" "$pr_call"
}

# allow-comment: a pull request is read against the tip of its base branch. When the head branch is behind that tip, the reviewer sees a diff that differs from what merging would produce, and the rebase lands on them instead of the author. GitHub's MERGEABLE/CLEAN answers "does it conflict", never "is it current", so it cannot stand in for this.
dd_pr_behind_base() {
  local input="$1" pr_call="$2"

  local target=""
  if [[ "$pr_call" =~ ^[[:space:]]*cd[[:space:]]+(\"[^\"]+\"|\'[^\']+\'|[^[:space:]\&]+)[[:space:]]*\&\& ]]; then
    target="${BASH_REMATCH[1]}"
    target="${target#\"}"; target="${target%\"}"
    target="${target#\'}"; target="${target%\'}"
    target="${target/#\~/$HOME}"
  fi
  if [ -z "$target" ]; then
    target=$(jq -r '.cwd // .tool_input.cwd // empty' <<< "$input" 2>/dev/null)
  fi
  if [ -n "$target" ] && [ -d "$target" ]; then
    cd "$target" 2>/dev/null || true
  fi

  git rev-parse --git-dir >/dev/null 2>&1 || return 0
  git remote get-url origin >/dev/null 2>&1 || return 0

  local head_ref="HEAD" named_head
  named_head=$(dd_pr_flag_value "$pr_call" --head)
  if [ -n "$named_head" ]; then
    git rev-parse --verify --quiet "$named_head" >/dev/null 2>&1 || return 0
    head_ref="$named_head"
  fi

  local base
  base=$(dd_pr_flag_value "$pr_call" --base)
  [ -n "$base" ] || base=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##')
  [ -n "$base" ] || base=$(git config --get init.defaultBranch 2>/dev/null)
  [ -n "$base" ] || return 0

  # Exact fetch: writes FETCH_HEAD only, leaving remote-tracking refs and any
  # force-with-lease baseline untouched. Offline or unknown base: stay silent
  # rather than block on a network failure.
  git fetch -q origin "refs/heads/$base" >/dev/null 2>&1 || return 0

  local behind
  behind=$(git rev-list --count "$head_ref..FETCH_HEAD" 2>/dev/null) || return 0
  [ -n "$behind" ] || return 0
  [ "$behind" -gt 0 ] 2>/dev/null || return 0

  dd_emit_deny pr-discipline "This branch is ${behind} commit(s) behind ${base}. A pull request is offered against the tip of its base, so rebase onto ${base} and resolve any conflicts before opening it; leaving that to the reviewer hands them a diff that differs from what merging would produce. GitHub reporting MERGEABLE or CLEAN answers 'does it conflict', never 'is it current'. For a deliberate exception, append '# allow-behind-default' to the command."
}

dd_pr_flag_value() {
  grep -oE -- "$2[[:space:]]+(\"[^\"]*\"|'[^']*'|[^[:space:]]+)" <<< "$1" \
    | head -1 \
    | sed -E "s/^$2[[:space:]]+//; s/^[\"']//; s/[\"']\$//"
}

# allow-comment: a capture belongs in the PR body as a picture, not as a link the reviewer has to click. Two link shapes lose the picture: a markdown link or bare URL whose target is an image file, and a blob URL to a committed image without ?raw=true (GitHub renders the file page, not the bytes). The fix is spelled out in the deny so the retry lands in one attempt.
dd_pr_image_links() {
  local cmd="$1"
  grep -q -- '# allow-image-link' <<< "$cmd" && return 0

  local image_ext='\.(png|gif|jpe?g|webp|svg|mov|mp4|webm)'
  local linked
  linked=$(grep -oE "(^|[^!])\[[^]]*\]\((https?://[^) ]*${image_ext}(\?[^) ]*)?)\)" <<< "$cmd" | head -1)
  if [ -n "$linked" ]; then
    dd_emit_deny pr-discipline "PR body links to an image instead of showing it: ${linked#?}. A capture is inline, so the reviewer sees it without clicking: markdown image syntax ![alt](url) with a URL that serves the bytes. For a file committed in the repo use the blob URL with ?raw=true (https://github.com/OWNER/REPO/blob/BRANCH/path.png?raw=true); otherwise upload it as a release asset (pr-NUMBER-assets) and use its download URL. Portrait shots go in a table with captions (two or more) or in <img width=...> (one). Append '# allow-image-link' for a deliberate link."
  fi

  local blob
  blob=$(grep -oE "(!\[[^]]*\]\(|<img[^>]*src=\"?)https?://github\.com/[^/ ]+/[^/ ]+/blob/[^) \"]*${image_ext}(\)|\"|[[:space:]])" <<< "$cmd" | head -1)
  if [ -n "$blob" ]; then
    dd_emit_deny pr-discipline "PR body embeds a committed image through its blob page URL, which renders as a link to the file page instead of the picture. Append ?raw=true to the blob URL (https://github.com/OWNER/REPO/blob/BRANCH/path.png?raw=true) so GitHub serves the image bytes inline. Append '# allow-image-link' for a deliberate exception."
  fi

  local bare
  bare=$(grep -oE "(^|[[:space:]])https?://[^ <>()]*${image_ext}(\?[^ <>()]*)?([[:space:]]|$)" <<< "$cmd" | head -1)
  if [ -n "$bare" ]; then
    dd_emit_deny pr-discipline "PR body contains a bare image URL:${bare% }. Show the picture instead of the address: ![alt](url) for a landscape shot, a captioned table for two or more portrait shots, <img src=... width=...> for a single portrait shot. Append '# allow-image-link' for a deliberate link."
  fi
  return 0
}
