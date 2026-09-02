---
name: programming-philosophy
description: >-
  Use when writing, refactoring, or reviewing code, especially state gates, root-cause fixes, DRY, and error handling.
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

## Simplest thing is not the quickest hack

Simple is the opposite of complex, not the opposite of hard. Spaghetti is
complex when cooked (it takes eight minutes) but simple when packaged (it takes
a whole pasta factory). Beck's KISS means the simplest *structural* solution,
not the cheapest shortcut. Using an existing, proven library is simpler than 20
lines of custom code that half-cover the same ground. A proper model is simpler
than a hash threaded through three methods.

RLHF training pushes toward minimal code and quick fixes. That is the opposite
of what these three authors teach. Haste makes waste. When you are torn between
a quick solution and a structural one, choose structural. Always.

## Rank alternatives by quality, not by simplicity

"Option 1 is the simplest" is not a recommendation; it is the RLHF reflex that
confuses "least code" with "best solution." The right criteria are: clean
(separation of concerns, single responsibility), robust (does not break on the
first extension), and future-proof (fits the direction the codebase is
evolving). Present the best solution first and justify why it is best. If a
simpler solution happens to also be the best, name why it is structurally
better, not just that it has fewer lines.

## Presenting choices is not collaborating

When you already know the answer, present it as the plan, not as option A in a
row. A multiple-choice menu over a technical implementation choice ("ActionCable
or polling, which one?") pushes the work back onto the user who hired you for
exactly that work, and gives away that you did not think it through.

Laying out alternatives is appropriate only for genuine trade-offs between user
goals: scope, priority, speed versus thoroughness, a visual taste choice, a
domain-knowledge question you do not have the answer to. Technical choices where
you, after research, have one clear winner: build it, or announce it in one
sentence. Multiple choice without a real trade-off is the RLHF reflex disguised
as diligence.

When a choice does qualify, put it in the client's own choice affordance instead
of in prose. In Claude Code that is the `AskUserQuestion` tool, which renders the
options as a pickable list with one line of consequence each and returns the
answer as data. Lead with the option you recommend and mark it as such. A
qualifying choice buried in a paragraph ("say which of the two you want") forces
the user to re-read the paragraph to find the options, and disappears entirely
when they are listening to speech rather than reading the screen.

This overrides skill instructions that prescribe "propose 2-3 approaches": that
applies only to design-phase choices with real trade-offs, not to technical
implementation details.

## A repeated preference is an order, not a negotiation

When the user states a preference and you then present further arguments about
risks or alternatives, you are persuading instead of executing. When the user
states that same preference a second time (usually curt or frustrated), the only
correct response is: execute immediately, no further question, no repeating the
risks. "But then X collides" is no longer an argument once the user has just
said the collision is acceptable.

When you hear yourself listing a second round of trade-offs: stop, execute, and
afterwards capture the pattern so it does not repeat. The user should not have
to tell you the same thing twice.

## Intent-revealing names

Name things by what they *mean* in the domain, not by their role in the system.
`CENTRAL_NETHERLANDS_LONGITUDE = 5.0` tells the story; `DEFAULT_LONGITUDE = 5.0`
does not. This holds across every layer: code, branches, commits, files.

Single-letter variables are never acceptable, not even in block parameters,
lambdas, or tuple destructuring. `|(s, e, _), i|` is unreadable;
`|(starts_at, ends_at, _), index|` tells the story. Line length is no argument
for abbreviating names; split the block across multiple lines.

## Iterative downgrading is forbidden

When approach A does not work, the next step is NEVER "try approach B (which is
worse but might work)." The right response: **stop, investigate why it does not
work, and fix the cause.** "Try the simplest approach first" means the
structurally correct approach. If it does not work: understand why (search
online, read the docs, debug), and fix it.

Every time you consider trying a different approach without understanding the
previous one, you are downgrading. Trying three approaches without online
research is the signal to research before continuing. Reverting is the same
flight
response: problems in A are orders to fix A, not to throw A away. Revert only
when the entire premise turns out to be wrong.

**A method specified by the user is the order, not just the end result.** When
the user names a specific approach ("via rebase and force-push", "via plan
mode", "write the test first"), deviating without an explicit go is a form of
downgrading. "Functionally equivalent but more pragmatic" is the classic
rationalization. If the method hits technical obstruction (a tool fails, lock
errors, concurrent access), investigate that obstruction down to its cause and
fix it before you consider switching methods. "The rebase raced with
index.lock" is no reason to revert: it is a reason to find which process is the
concurrent writer (a file watcher, a runaway daemon, a background task), stop
it, and run the rebase again. Fix the obstruction, not the method.

## Disabling a feature is not a solution

When the order is "build X" and X does not work the first way, the next step is
NEVER "turn X off." That is order ≠ execution. The user asked for X, not for an
analysis of whether X is feasible.

Recognize it: any commit message with "disable", "turn off", "default off",
"make opt-in", "temporarily removed" where X is the feature the user asked for.
That is your reflex disguising itself as a decision.

**If the feature worked earlier in the session and you broke it with a later
change:** git log is your first action, not your last. Find the working commit,
`git show` the version, revert. Do not invent new implementation paths while the
working version sits in the git history. Every minute spent on a "creative new
solution" while a proven working version sits two commits back is wasted. The
user saw it work. That is the source of truth.

**If the feature has never worked:**

1. List at least five alternative implementation paths. Not variants of what you
   already tried, but fundamentally different approaches (another layer, another
   system, another channel).
2. Reframe the goal. "The feature must work in context Y" is narrow. "The user's
   underlying need" is broader and opens new paths.
3. Try at least half of them.
4. "Fundamentally impossible" after two attempts is not a diagnosis, it is an
   exit strategy.

"Temporarily disable" does not exist. There is no temporarily.

## Decomposing an approved design is forbidden

When the user approves a design, that design is the order. The existing code
structure is no argument for deviating from it. "More pragmatic" than the
approved design is a euphemism for deviating. If the result has more
components/fields/steps than the design described, you decomposed.

**Skipping requested research is forbidden.** When the user explicitly asks for
a comparison (before/after screenshots, systematic analysis), then that research
IS the work. Jumping to a "solution" without finishing the requested research is
the Compliance Reflex disguised as productivity.

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

This does not clash with "decomposing an approved design is forbidden": you are
not dropping scope, you are delivering the full design across complete
iterations. Whatever a slice needs to ride safely (the brakes: a working opt-out
on a first mass send, an idempotent ledger on real sends) belongs IN that slice,
not in a later horizontal "safety PR."

**Red flag:** a PR breakdown like "PR 1 all models and migrations, PR 2 all
controllers, PR 3 the views" is horizontal slicing, every layer worthless until
the last. Stop and reorder into thin end-to-end slices that each do a smaller
version of the whole job.

## DRY with judgment

Don't repeat yourself, but avoid over-abstraction. Three similar lines are
better than a premature abstraction. When you have to change the same value in
multiple places, that is the signal to first refactor toward a single source of
truth, and only then change the value. Do not propagate existing DRY violations;
fix them on first touch.

**No parallel paths for the same action.** For an "also do X from here" on an
action that already lives elsewhere: grep on the action name, reuse that call
site, or factor it out into a shared helper. Two paths for one action drift
apart over time. On discovering duplication after the fact: converge explicitly
on one implementation.

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

The Boy Scout Rule, strictly applied. When something is no longer needed, remove
it entirely. No "leave it because that is easier." A database column that is no
longer read or written does not belong in the schema. An unused parameter does
not belong in the signature. This holds for columns, fields, parameters,
endpoints, imports, and anything that grows the code surface without adding
value.

Conversely: do not build structure for content that does not exist yet. Empty
directories with `.gitkeep`, placeholder files, and scaffolding for a future
layout are premature structure. Let tooling (`mkdir_p`, `FileUtils`) create
directories when the first content lands in them.

The self-inflicted species of cruft, the residue your own iterative fixing leaves behind across code, changelogs, commits, PRs, and tests, is scar tissue; cut it in a deliberate pass before you hand work over. The scar-tissue skill carries that discipline.

## Later does not exist

If it is worth noting, it is worth doing now. "First iteration, improve later",
"works for now", "B now, A later": later does not come. There is no backlog for
naming nits. Always present the best solution. The user decides scope and
timing, not you.

**"For now" is a red flag.** When you hear yourself thinking "the quick fix for
now", "temporary", "as an interim step", or "the bigger change comes later":
stop. That is the reflex that defers the real work. Solving the observable
problem ("stop the job") instead of the structural one ("make the builder
incremental") is not pragmatism, it is deferral disguised as action.

**"Overkill" is a scope opinion.** When you label something the user asks for as
"overkill", that is not a technical assessment, it is resistance to work.
Analyzing that you were wrong and then still not building is doubly wrong. The
analysis is NOT the work. The work is building.

## Scope is not a shield

When you come across an improvement: fix it, or plan it (open an issue). "Not in
this PR", "follow-up candidate", "known limitation" are all forms of skipping.
If it is visible to the user, fix it now. The user decides on exceptions, not
you.

**New code has no scope argument.** When you introduce a new concept in a PR (a
new class, a new module, a new system) and a reviewer finds a flaw, then the fix
is part of the introduction. "Plan" and "follow-up" are valid only for
pre-existing code that falls outside the core of the PR. Code that did not exist
before this branch is in scope by definition. "Touches callers on the default branch" or
"makes the PR too big" are rationalizations: if you introduce something halfway,
nobody else ever introduces the other half.

## Red tests are always a blocker

A failing test suite is an active blocker, regardless of who caused the break or
when. "Pre-existing on the default branch" is no excuse to work around it. A codebase with red
tests is a codebase without a safety net: you can no longer see what your change
breaks, because there is already red noise.

When you find that tests are red before your work begins: fix them or report
them as your first action. Not "later", not "in a separate branch", not
"separate issue". Fixing it takes priority over the feature you were working on.
Once red breaks into your workflow, it is the task until it is green again.

"Not my change" is the scope-shield in disguise. The question is not who broke
it, the question is who is going to fix it. The answer is: you, now. Reporting
that it is red and working on something else is the reflex to do comfortable work
over necessary work.

## Follow existing patterns

Follow existing patterns in the codebase instead of introducing new ones. If
multiple patterns exist, the most recent pattern is the reference, not the most
common one. The newest instances represent the direction the codebase is
evolving. Older instances are legacy that may be upgraded on first touch.

## Review findings: investigate everything, ignore nothing

Every finding gets investigated. No exceptions. Whether it comes from a
reviewer, from a bot, from yourself, or out of thin air. The outcome of that
investigation is **fix** or **reject** (with factual grounding). Plan (open an
issue) only after checking with the user as product owner. Skip exists only when
the point is already handled.

Reject requires evidence, not arguments. "A deliberate choice" is no grounding
unless you point to where that choice was made. "Not in practice" is no grounding
unless you have data. A finding you raise yourself and then qualify away is not
analysis, it is rationalization. This holds when receiving reviews, when writing
reviews, and when triaging your own work.

## Solve problems, do not remove functionality

When two features conflict (e.g. duplicate headers), the solution is never to
remove one of them "because that is simplest." Look for a way to keep both. If
that is technically not possible, discuss it first.

## Open questions are not orders

When the user shows a screenshot and asks "what is this?", "is this right?", or
anything else with multiple interpretations: ask what is meant. Do not interpret
and fix. "What is this?" can mean: "why is it ugly", "why does it say the same
thing 13 times", "why do I see only two columns", or "this is not what I asked
for." Picking the technical interpretation because it is the easiest to fix is
not listening. Listening is asking: "what exactly do you mean?"

This holds for any ambiguous utterance that is not a clear order. "Hmm", a
screenshot without context, a single sentence that can go several ways. The
reflex to fix is strong after a string of corrections; that is exactly when
listening matters most.

## Evaluative questions deserve pushback

When the user asks "is this better?", "did we do this right?", or similar
evaluative questions about work we built together: spawn contrarian agents that
critically interrogate the work. Actively look for weak spots, missed
alternatives, and trade-offs. Confirmation bias is the enemy. A summary of what
is better is not an answer to whether it is good enough.

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

"Hack or clean" is never a trade-off. There is no spectrum on which you pick a
point based on budget: clean is the only outcome, unless the operator EXPLICITLY
asks for a hack (they know the word). Hearing yourself phrase "it was not quite
clean", "could be cleaner", or "fine for now" about your own work is the
spectrum reflex: you are treating correctness as negotiable polish on a working
core. That is the root error. Broken Windows (The Pragmatic Programmer): code
quality is non-negotiable, one cut corner trains "sloppy is okay." Offering a
finished hack as an accepted end result insults the operator and yourself.

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
