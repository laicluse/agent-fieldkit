---
name: branch-policy
user-invocable: true
description: >-
  Choose the authoring branch and checkout before Git writes: feature branches by default, direct trunk authoring or mandatory feature worktrees per repository.
---

# Branch policy

Resolve the installed git-discipline root from the host's plugin inventory: use `CLAUDE_PLUGIN_ROOT` in Claude when supplied, or `codex plugin list --json` and the enabled `git-discipline@laicluse-agent-fieldkit` entry's `source.path` in Codex. Run that root's `bin/git-discipline branch-policy` before choosing an authoring branch. It is read-only and prints `policy`, `checkout`, `current_branch`, `authoring_branch`, `worktree_required` and `action`.

Repository-local `codingAgent.git.branchPolicy` selects:

| Policy | Primary checkout | Linked worktree |
|---|---|---|
| `feature` (unset default) | Feature branch | Feature branch |
| `trunk` | Default branch | Feature branch |
| `worktree` | Integration target only | Feature branch |

Configure with `git config --local codingAgent.git.branchPolicy <feature|trunk|worktree>`. Global values are ignored. Existing `current` normalizes to `feature`, `default` to `trunk`; legacy local `laicluse.requireWorktree=true` still forces `worktree`. The first commit may initialize a repository with no branch refs in every mode; with Dibs worktree-only enforcement use `git commit --allow-empty` before creating the feature worktree outside the primary checkout or through Bonsai; a plain-Git destination in `worktrees/` needs an existing ignore rule. If default metadata is absent, record that explicitly chosen initial branch as local `init.defaultBranch`. Actual in-progress merges and paused rebases on a valid authoring line may complete; ordinary detached-HEAD commits require attaching a branch. These are Git-state exceptions, not a content audit or permission to add unrelated changes to a merge. Native pre-commit hooks enforce the authoring rule; branch creation itself is not intercepted.

Honor the returned action: `author`, `create-feature-branch`, `return-to-default`, `create-worktree`, `complete-merge`, `complete-rebase`, `attach-branch` or `initialize-repository`. Use an existing valid task branch; do not create another branch for the same work. An empty `authoring_branch` means a feature branch or worktree must be chosen, not a detached checkout. Integrate existing completed work before returning to default; never stash or relocate dirty work to satisfy the policy.

Before mutations, follow the checkout's occupancy mechanism when installed. If another session holds the primary checkout, use a separate feature worktree. If the task branch itself is checked out there, do not force it into a second checkout or create a competing branch for the same task: coordinate with its holder or wait. A project-specific canonical-only constraint takes priority: wait for that checkout instead. Dibs owns occupancy, not branch selection. Bonsai can create and prepare the chosen worktree; without it use Git's worktree commands and the project's setup procedure. Without Dibs use the project's coordination mechanism, without inventing a replacement lock. This resolver requires neither plugin and does not probe occupancy or create checkouts.

Branch policy chooses where to author. Push policy separately decides whether publishing is authorized. Worktree lifecycle, merge and deployment workflows retain their own gates; none of these policies grants permission to publish or delete work.

An existing repository needs `origin/HEAD` or repository-local `init.defaultBranch`; global initial-branch preferences are not repository default metadata. If the resolver reports it missing, repair `origin/HEAD` with `git remote set-head origin -a`, or configure local `init.defaultBranch` to the verified existing default. Do not guess a branch name.
