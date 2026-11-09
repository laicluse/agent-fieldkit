# Upstream

The cross-toolbox audit pass behind the drydry pipeline. The premise: DRY violations between operator code and framework code are invisible from a single-codebase view. A homegrown `current_user` helper looks fine until you remember Devise ships one; the silent drift risk surfaces at the next Devise upgrade.

## Input contract

Caller supplies through `args`:

- **`project_root`**: path to the project root. Mandatory.
- **`upstream_cache_dir`**: cache directory resolved by the caller using the storage contract; use that same path for reads and writes.
- **`framework_hint`**: optional name of a specific framework to audit (`devise`, `active-job`, `swiftui`, `combine`, `react-router`, `tanstack-query`, ...). When absent, the skill auto-detects from manifests.
- **`scope`**: optional sub-directory; when provided, the audit is limited to that scope.
- **`max_helpers_per_framework`**: optional cap, default 10. Prevents one framework with broad surface from dominating.

## Output contract

Return a markdown section the orchestrator folds into the audit artefact:

```markdown
## Upstream duplication

### Framework: <framework_name> <version_if_known>

- Finding 1
  - operator_helper: `<path>:<line>` `<symbol_name>`
  - upstream_offering: `<framework_module>.<symbol>` (cite the docs URL)
  - duplication_kind: identical | partial | semantic
  - drift_hypothesis: <one sentence; the Chapter 4 test must pass>
  - upgrade_risk: <what breaks when the framework version moves>
  - convergence_path: <replace operator helper with upstream | wrap upstream | keep as documented divergence>
  - verifier_command: <runnable command to re-find both sites>
```

Findings without a verified upstream offering (the verification check failed) are dropped.

When a framework is detected but no findings survive verification, emit the header alone with an explicit empty marker so the orchestrator's fold-in step does not silently omit the framework:

```markdown
### Framework: <framework_name> <version_if_known>

_no upstream duplications found; the verification pass dropped every candidate. See "## Detection method chosen" for which candidates were inspected._
```

Resolve the cache directory using [artifact storage](../artifact-storage.md) before reading or writing cache files. Use that same resolved directory throughout this task. If cache access is unavailable, perform the required review without caching and return its findings normally; do not write a replacement cache into the checkout.

## Workflow

### 1. DETECT frameworks

Walk `project_root` for known manifest signatures:

| Manifest | Frameworks to consider |
|----------|------------------------|
| `Gemfile` / `Gemfile.lock` | Rails, Devise, Pundit, CanCanCan, Sidekiq, Active Job, dry-rb, RSpec, FactoryBot |
| `Package.swift` / `*.xcodeproj` | SwiftUI, UIKit, Combine, swift-collections, Vapor |
| `package.json` | React, Next, Remix, TanStack Query, React Router, Vue, Svelte, lodash, date-fns |
| `pyproject.toml` / `requirements.txt` | Django, Flask, FastAPI, SQLAlchemy, pydantic |
| `Cargo.toml` | actix, axum, serde, tokio |
| `go.mod` | gin, echo, chi, sqlx |

When `framework_hint` is set, audit only that framework; skip auto-detection. When auto-detecting, parse the manifest and pick the three to five most load-bearing frameworks (the ones whose absence would break the project).

### 2. INSPECT operator helpers

For each framework selected, identify the operator's helper-shaped code: standalone utility modules, "helpers/" directories, `Extensions.swift`-style files, `lib/` directories. Run a grep with framework-relevant signatures (`def current_user`, `func authenticated`, `useAuth`, `useToast`, `formatDate`, ...) to find candidates.

Each candidate becomes a tuple `(helper_path:line, symbol_name, surface)` for the duplication reviewer.

### 3. RUN duplication review per framework (with version-keyed cache gate)

For each framework, decide first whether a live search pass is necessary. The discipline is "verify against the pinned framework version", not "fetch documentation every time". When the project's lock file (`Gemfile.lock`, `Package.resolved`, `package-lock.json`, `pyproject.lock`) hash for this framework matches the hash recorded in the cache file `<upstream_cache_dir>/<framework>-<pinned-version>.md`, reuse the cached findings and skip the live search. Invalidate and re-run the live search when (a) no cache exists for this framework or version, (b) the lock-file hash differs, or (c) the pinned version is newer than the current model's training cutoff (in which case the cache cannot be trusted and the search is needed for ground truth).

When a live search is needed, use the host's native research/review capability with this brief (inspire-style for the discovery, ground-style for the verification). In Claude Code this can be an Agent tool pass with WebSearch/WebFetch; in Codex use native browsing/subagents when exposed, otherwise perform the research in the current session and record that limitation in the returned method notes:

```
You audit a project for duplication of <framework> functionality.

Operator helpers (candidates): <list of tuples>

Tasks:
1. For each candidate, search the <framework> documentation
   with browsing/search for an upstream symbol that does the same
   job. Cite the canonical docs URL.
2. ground-style verification: confirm the symbol actually exists in
   the version of <framework> the project pins (read Gemfile.lock,
   Package.resolved, package-lock.json). If you cannot verify the
   symbol exists in the pinned version, mark the candidate dropped
   and explain why.
3. Classify duplication: identical (operator helper is a thin wrapper
   matching upstream signature), partial (overlap with extra concern),
   semantic (same purpose, different shape, Type-4).
4. Write a drift hypothesis: what bad thing happens when the
   framework version moves and the operator helper does not?
5. Produce a verifier_command (rg or grep) that re-finds both sites.

Return one finding per verified candidate. Drop unverified candidates.
Drop candidates where the duplication is genuinely deliberate (the
operator's helper adds value the upstream does not provide; explain
in one sentence).
```

### 4. CAP, CACHE, RETURN

Apply `max_helpers_per_framework` per framework. Write the per-framework findings to `<upstream_cache_dir>/<framework>-<pinned-version>.md` with a header line that records the lock-file hash; this is what step 3's cache gate will read on the next run. Return the assembled markdown to the caller.

## Common upstream-duplication patterns to watch for

These are seed examples the review brief includes so the search has direction:

### Rails

- `current_user` helpers that mirror Devise's `current_<scope>`
- Custom `before_action :authenticate!` chains that duplicate Devise's `authenticate_<scope>!`
- Hand-rolled background-job retry loops that duplicate `retry_on` from Active Job
- Custom `assert_difference`-style helpers that duplicate ActiveSupport's `assert_changes`
- Bespoke string slug methods that duplicate ActiveSupport's `parameterize`

### SwiftUI / Foundation

- Custom `.task { }` wrappers around `URLSession` that duplicate `async/await` URLSession APIs
- Hand-rolled `ObservableObject` patterns that duplicate `@Observable` macro behaviour (Swift 5.9+)
- Custom date-formatting helpers that duplicate `Date.FormatStyle`
- Custom locale-aware string interpolation that duplicates `String(localized:)`

### React / TypeScript

- Custom `useAsync` hooks that duplicate TanStack Query's `useQuery`
- Hand-rolled cache-and-revalidate logic that duplicates SWR or TanStack Query
- Bespoke form-state hooks duplicating React Hook Form
- Hand-rolled focus-trap hooks duplicating Radix or Reach focus-trap primitives

### Django / Python

- Custom permission-check decorators that duplicate `permission_required`
- Hand-rolled query-aggregation helpers that duplicate `annotate` / `aggregate`
- Custom validation decorators duplicating Django form `clean_*` patterns

The reviewer uses these as priors, not a closed list.

## Rules

- **Verification before reporting.** A finding lands only if the upstream symbol is confirmed to exist in the pinned framework version (`ground`-style discipline). The operator's pinned version, not the latest version.
- **Drift hypothesis is mandatory.** A finding without a Chapter 4 sentence is dropped. "It would be cleaner to use Devise" is not a drift hypothesis; "Devise's session-token storage changed in 4.9 and the operator's hand-rolled helper will silently miss the new format on the next upgrade" is.
- **Deliberate divergence is not a finding.** When the operator helper exists because the framework's shape was insufficient (rate-limiting, multi-tenancy, an extra concern), the reviewer drops the candidate. Drydry is not "use upstream for everything"; it is "duplications that will silently drift hurt you".
- **No auto-fix.** This task returns findings the orchestrator folds into the audit artefact. The operator decides whether to converge.
