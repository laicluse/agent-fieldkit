---
name: programming-philosophy
description: >-
  Use when planning, writing, refactoring, or reviewing software, especially reversible decisions, scope, command-query separation, root-cause fixes, DRY, and error handling.
user-invocable: true
---

# Programming Philosophy

Principles in the tradition of Kent Beck, Robert C. Martin ("Uncle Bob"), and
Martin Fowler. This skill carries the detailed doctrine; the operational gates
live in the host's instructions.

## Three authors as the baseline

Distilled from more than 25 years of programming in this tradition.

- **Beck**: intent-revealing names, Red-Green-Refactor, KISS, do the simplest
  thing that could possibly work.
- **Martin**: Clean Code (meaningful names, no comments, SRP, exceptions over
  return codes), SOLID, the Boy Scout Rule.
- **Fowler**: Refactoring (recognizing code smells), Tell Don't Ask, explicit
  interfaces.

Treat these works as shared knowledge. When a situation is not covered by the
specific rules below, fall back on these principles.

## Make reversible decisions quickly, irreversible decisions slowly

Start with the smallest sound working choice that meets the current user goal. "Quickly" describes the time spent deciding, not the quality of implementation. Ask what it would cost to change after real use. If a value, label, algorithm, or local implementation can be changed without losing data or breaking a published contract, choose a reasonable default and test it in use. Reversibility permits a decision before every future case is known; it does not permit broken current behavior, hidden state corruption, or code that cannot be maintained. Do not build configuration, versioning, migration, compatibility, or exception handling for an imagined future change.

Slow down where a choice can destroy or reinterpret stored data, cross a public or external boundary, or leave users unable to recover. Preserve the necessary evidence and make those transitions explicit. Complexity needs a concrete current requirement, observed failure, or measured cost; a peer's hypothetical edge case is a question to evaluate, not automatically a new requirement. This applies while planning and reviewing as well as while coding.

## Simplest thing is not the quickest hack

Simple is the opposite of complex, not the opposite of hard. Spaghetti is
complex when cooked (it takes eight minutes) but simple when packaged (it takes
a whole pasta factory). Beck's KISS means the simplest *structural* solution,
not the cheapest shortcut. Using an existing, proven library is simpler than 20
lines of custom code that half-cover the same ground. A proper model is simpler
than a hash threaded through three methods.

Do the structural work needed for the current behavior and its known constraints. A shortcut that leaves today's behavior broken is not simpler. A general framework for possible later behaviors is not simpler either. When the choice is reversible, implement the smaller working structure and change it when evidence warrants it.

## Rank alternatives by present quality and cost of change

"Option 1 has the fewest lines" is not a recommendation. Compare whether each option solves the present problem, keeps today's boundaries clear, and can be revised at a reasonable cost. Spend complexity on an extension only when that extension is requested, already present, or supported by concrete evidence. Present the best fitting solution first and explain the relevant trade-off.

## Own technical choices

Make technical choices the available evidence supports. Ask the user when alternatives change a goal, product behavior, visual preference, or another outcome only they can decide. Present the actual trade-off in the host's question affordance when one is available; do not hand a routine implementation choice back as a menu.

## Intent-revealing names

Name things by what they *mean* in the domain, not by their role in the system.
`CENTRAL_NETHERLANDS_LONGITUDE = 5.0` tells the story; `DEFAULT_LONGITUDE = 5.0`
does not. This holds across every layer: code, branches, commits, files.

Single-letter variables are never acceptable, not even in block parameters,
lambdas, or tuple destructuring. `|(s, e, _), i|` is unreadable;
`|(starts_at, ends_at, _), index|` tells the story. Line length is no argument
for abbreviating names; split the block across multiple lines.

## Vertical slicing: every PR is a rideable vehicle

Work that lands across multiple PRs or iterations is sliced vertically, not
horizontally. The image is Henrik Kniberg's ("Making sense of MVP"): skateboard
→ scooter → bicycle → motorcycle → car. The wrong way builds a wheel first, then
a chassis, then a body, each piece worthless until the final merge. The right
way delivers, at every step, a complete usable thing that already does the core
job (get from A to B) and gets better. Translated: every PR cuts through all the
layers (model, logic, UI, delivery) and delivers the core job end to end, more
completely than the last.

Map the iterations onto Earliest Testable → Usable → Lovable. The skateboard is
the first thing a user can actually do something with, however rough, even if
you push it with your foot; the bicycle the first thing an early adopter uses
willingly; the motorcycle the first thing someone falls in love with. Do not
force the vehicle mapping literally (a skateboard is not a subset of car parts);
the only test is: does this PR already do the core job, end to end?

Whatever a slice needs to ride safely (the brakes: a working opt-out on a first mass send, an idempotent ledger on real sends) belongs in that slice, not in a later horizontal "safety PR."

**Red flag:** a PR breakdown like "PR 1 all models and migrations, PR 2 all
controllers, PR 3 the views" is horizontal slicing, every layer worthless until
the last. Stop and reorder into thin end-to-end slices that each do a smaller
version of the whole job.

## DRY with judgment

Don't repeat yourself, but avoid over-abstraction. Three similar lines are better than a premature abstraction. If the requested change needs one value to remain consistent across several places, establish one source of truth for that value. Do not refactor unrelated duplication merely because you encountered it.

**No parallel paths for the same action.** For an "also do X from here" on an
action that already lives elsewhere: grep on the action name, reuse that call
site, or factor it out into a shared helper. Two paths for one action drift
apart over time. On discovering duplication after the fact: converge explicitly
on one implementation.

## Command-Query Separation: views do not change state

Apply Bertrand Meyer's Command-Query Separation (CQS) at every public boundary. A **query** returns information and leaves observable state unchanged. A **command** changes state and is invoked as a deliberate action. Keep them as separate methods, routes, jobs, messages, and UI affordances; do not hide a command inside a query for convenience.

For web applications, rendering a view is a query. `GET`, page load, refresh, polling, previews, and link traversal must never create, update, delete, enqueue, mark, settle, regenerate, or otherwise advance domain state. Repeating or prefetching the same view must be safe. Rails-style resource actions make the boundary visible: `show` and `index` read; `create`, `update`, and `destroy` mutate through an explicit form or button using the corresponding non-GET request.

The characteristic violation is an `ensure*`, `find_or_create*`, generation call, write, or mutating callback reached while assembling a view. A page that needs missing state shows that state and offers the command that creates it; it does not run the command because the page was opened. Client-side code that fires a mutating request on mount is the same violation with the call moved to JavaScript.

Before accepting a view or query path, trace its complete call graph to storage and external adapters. Name every operation that can write, enqueue, send, or change lifecycle state. Move each one behind an explicit command boundary and test the invariant at the route or public API: invoking the query repeatedly leaves domain state unchanged, while the command changes it only when deliberately invoked.

## Single source of truth for cross-boundary state

Mutable state (auth cookies, session tokens, CSRF tokens, cache entries,
replicated counters, denormalized counts, config flags) that lives in two or
more stores each accepting writes from independent sources is always a red flag.
A one-shot snapshot at init without re-sync is a latent logout or
cache-inconsistency bug; the out-of-band write (server, another process,
third-party SDK) arrives sooner or later and one of the stores goes quietly
stale. Document the sync frequency explicitly (write-through, event bus,
scheduled refresh) or replace it with a live binding on one source.

A concrete pattern this touches: a native HTTP client with its own cookie store
and an embedded webview with its own store, synced by a single snapshot on first
navigation. On a server-side token rotation, one of the two gets the new value;
the other is logged out on next use. Fix: re-sync on every navigation that
follows a mutating call, or refactor toward one shared live source. The same
mechanism is behind cache-vs-DB inconsistencies, localStorage-vs-server-session
drift, and denormalized counters that no longer compute what their source
measures.

Helper names that suggest a snapshot (`inject*`, `seed*`, `prime*`,
`bootstrap*`) that run once at init and are never called again from the response
handler of a mutating endpoint are the signature. When you write or read such a
helper: ask explicitly who may mutate the source besides you, and what the path
is by which your store sees the new value.

## Published agent tooling: host-owned capability contract, not a hard route

When you build a system that touches *published* or *shareable* agent coding
tooling (a plugin, skill, hook, marketplace, or cross-agent workflow that a
stranger host executes: Claude, Codex, a future agent, or an operator who does
not know your machine), there is an extra boundary. The consumer does not share
your local setup: not your private tools, not your path names, not your MCP
servers, not your habits. A dependency route that leans on that setup works on
your machine and breaks or leaks everywhere else.

The right form is Ports and Adapters (Cockburn, Hexagonal Architecture). The
published artifact defines a **driven (secondary) port**: the abstract
capability or outcome it needs, described as behavior and not as implementation
("notify the operator when done", "drive a browser", "provide an independent
reviewer", "keep the loop alive"). The concrete integration is an **adapter**
the **host** supplies. That the host decides which adapter fills the port, and
guarantees it is live, is the **configurable dependency**: the artifact stays
tool-agnostic at that edge. In doctrine terms this is the **host-owned
capability contract**: describe the outcome the active host must arrange, do not
hard-code a route A→B→C that calls tool X in step 1 and Y in step 2 by name.

**The leak test.** A concrete adapter never belongs in the shared artifact: no
private tool name, no person's name, no local path, no specific MCP server, no
operator habit. Ask, for every line that crosses the artifact boundary: can a
stranger host or unknown operator, without my setup, fill this port with their
own adapter? If not, a hardcoded route is leaking and it has to go. This is the
architecture side of "no tooling leak in shareable artifacts": there it is
hygiene, here it is the structure that makes the leak impossible.

**When hard-coding IS allowed.** Only when the dependency is itself the public
API or the artifact the workflow is about. A skill that is literally about `gh`,
`git rebase`, or a specific MCP server names it; there the tool IS the subject,
not a replaceable adapter. The test: is the dependency the contract itself, or
just one possible fulfillment of it? Only the first may appear by name in the
artifact.

A concrete shape: a report-on-completion is a driven notify-port with a
convention path and a fixed `<command> <event> <payload-path>` contract. The
plugin owns the port; the operator supplies the adapter (their own channel) and
wires it; the plugin never learns which channel. A second host plugs its own
adapter into the same port. That is the form. An `if vendor == ...` branch or a
hardcoded channel call is the anti-form: then the port is nailed shut on one
adapter and the artifact is no longer shareable.

## Cruft zero tolerance

Remove code made obsolete by the current change instead of keeping parallel or unused paths. This applies to columns, fields, parameters, endpoints, imports, and other structures the change replaces. Report unrelated existing cruft without silently expanding the task.

Conversely: do not build structure for content that does not exist yet. Empty
directories with `.gitkeep`, placeholder files, and scaffolding for a future
layout are premature structure. Let tooling (`mkdir_p`, `FileUtils`) create
directories when the first content lands in them.

The self-inflicted species of cruft, the residue your own iterative fixing leaves behind across code, changelogs, commits, PRs, and tests, is scar tissue; cut it in a deliberate pass before you hand work over. The scar-tissue skill carries that discipline.

## Finish current work; defer speculative work

Finish the requested behavior and fix defects your change causes. A known gap in that behavior cannot be excused with "improve later." A possible future requirement is different: leave it out until the operator requests it or evidence makes it current. The user decides scope and timing, not you.

**"For now" needs a concrete check.** Does the choice meet the requested use and remain easy to change, or does it hide a known defect or irreversible cost? Keep the former; repair the latter. Do not turn a reversible starting value into a permanent abstraction merely because it may change.

## Code guidelines

- No comments (Clean Code, Ch. 4). Use local variables to improve readability.
  **Exception: load-bearing comments stay.** A comment that carries an
  instruction to the agent (when may I use these creds / this endpoint), a
  security/credential note, a non-obvious WHY, a citation, or a pragma is not
  cruft but load-bearing and is kept; a no-comments rule should let such a
  comment through with an explicit reason marker (the marker must be on every
  comment line, so condense load-bearing prose to one line). **Before you
  REMOVE a comment under cruft-zero or the no-comments reflex: first name what it
  does.** Does it carry such an instruction/rule? Then it is not cruft, leave it.
  A stale reference inside it means fixing the reference, not demolishing the
  whole comment. This is the comment variant of the predicate principle: name the
  purpose before you act, not after.
- When disabling a linter rule, prefer the narrowest possible scope (line >
  method > file).
- Always make sure files end with a newline character.
- When you change a file, do NOT let the formatter reformat the whole file. Add
  new lines in the style of the existing file. Formatting-only changes do not
  belong in feature commits and make the diff needlessly noisy for reviewers.

## Error handling

Methods should either succeed (return data/nil) or fail (raise an exception). Do
not use Result Object patterns (returning hashes with `success:`, `error:`,
`data:` keys). Use the language's native exception/error mechanism.

## Waiting on conditions

Never use `sleep` with long durations (>10s) to wait on something. Always build
a retry loop with short intervals (max 5s) that actively checks whether the
condition has been reached. Long sleeps hide whether something has long been
done or is never going to succeed.

## Hiding symptoms is forbidden

Defensive filtering (skipping, ignoring, or clamping unexpected values) hides
bugs. If code has to catch "unexpected" values, ask: why are they unexpected?

**Forbidden:** Guards that mask symptoms instead of fixing the cause.
**Required:** Trace the data flow back to the source. Fix where the invariant
breaks, not where the symptom becomes visible.

## Clean is the only route; a proxy is a bug, not polish

A quick reversible decision still needs sound execution. Do not hide a current defect behind "fine for now" or deliver a brittle workaround as finished work. Keep the design as small as the current requirement permits; a general framework for hypothetical cases does not make the present code cleaner.

**The correlated-proxy smell.** Deriving a gate/boolean from a downstream
symptom that happens to correlate with the fact, instead of reading the fact at
the source, is a latent bug, not a style. `schedule == nil` as "not logged in"
works until someone is logged in with a temporarily nil schedule;
`!engine.isConfigured` IS "not logged in". `composition == nil || schedule ==
nil` to derive "no timeline so hide the login CTA" is the same error.
Tell-Don't-Ask (Fowler) plus single source of truth: ask the owner of the fact,
do not reconstruct it from symptoms. The proxy gives the right pixels in the
visible case and is therefore tempting; that the output is correct does not prove
the predicate is correct. This is the positive counterpart of "hiding symptoms":
there you mask a bad value, here you build a state out of a correlate.

**Forcing function: name the semantics before you accept a predicate.** Before an
`if`, a boolean, or a gate lands: say in one sentence what it means and check
that it reads the source fact. Are you keying on something that only *implies*
the fact (an absent schedule, an empty balance, a missing session) to establish
a positive state ("logged in", "ready", "active", "hide")? Stop, replace it with
the direct source. The visible case is not the acceptance criterion; the full
state space is. Enumerate the axes (e.g. `isConfigured × schedule × session`) and
check every cell where proxy and source diverge.

| Reflex/excuse | Reality |
|---|---|
| "It works in this case, can be cleaner later" | The proxy is wrong in the cells you did not see; later does not come. Correctness debt, not a TODO. |
| "This condition was already in the path" | Local cohesion is not semantic correctness. The nearest signal is rarely the right one. |
| "The screenshot/build is correct, so it is done" | Output correct is not predicate correct. A correlated proxy gives the right output AND is wrong. |
| "I will just offer hack-or-clean so the operator picks" | No menu over your own quality. Clean is the default, not option A. |
