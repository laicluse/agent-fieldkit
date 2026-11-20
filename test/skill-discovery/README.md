# Fieldkit skill discovery

This review makes discovery text more concise while preserving skill names, workflows, and host-specific invocation controls. Eleven shared skill descriptions change; concise descriptions and explicit command wording that already distinguish their tasks stay intact. All 21 Codex-compatible plugin packages gain an independently authored list subtitle of at most 30 characters. Autonomous remains Claude-only and receives no unused Codex sidecar. The manifest description remains the longer task summary.

## Method and boundaries

The baseline is `laicluse/agent-fieldkit` commit `3ef06bd`. [Cases](cases.json), the [runner](run.py), and captured results compare native skill loading before and after. Operational skill bodies are replaced by inert marker instructions. This checks discovery, not execution of the underlying workflows. Skill names and non-description frontmatter remain identical; the only instruction-body change records the host-specific fixture inventory lesson in how-plugins-work.

Twenty-eight cases cover worktree creation and pruning, lock release, quick duplication checks and parity audits, plugin diagnosis and scaffolding, shared doctrine, explicit correction and deferred prompts, clipboard and speech requests, design exploration and usability (including improving an existing page and modal placement), push authorization, rebasing and catching up with main, factual doubt, research, vault sync, an ordinary copy edit, and arithmetic as an unrelated negative control. Cases were specified before the corresponding candidate runs. The copy-edit case initially expected no skill on either host; baseline Codex selected naming-is-hard, whose existing scope includes wording. This observed host difference is retained without changing invocation policy to force agreement.

Fixtures choose `SKILL.<host>.md` when agent-specific sources exist, omit unsupported host variants, and use the generated Codex runtime frontmatter. Enumerating only shared SKILL.md files would miss Codex-only review shortcuts and incorrectly include Claude-only skills. Codex receives local skill fixtures, not an isolated temporary plugin installation. Global and built-in skills can remain visible. Positive results require a fixture marker, and unattributed or outside-fixture SKILL.md reads invalidate a run. This detector does not cover every possible reference-file read. Claude is limited to its Skill tool; Codex runs read-only. Tests run sequentially.

These are small routing diagnostics, not a reliability estimate, a full workflow test, or a measurement of billed tokens or latency. Character reduction and peer agreement alone do not demonstrate improved automatic selection. Plugin listing descriptions are not exposed by these routing fixtures, so their changes cannot explain a fixture routing difference. Separate metadata checks verify matching marketplace copy, generated subtitle roles, unchanged invocation controls, and delivered installation payloads.

## Results

Claude Code 2.1.316 uses claude-opus-5-5 for the diagnostic. Codex CLI 0.166.0 uses its unpinned host-default model. The fixture catalogs contain the supported Fieldkit sources: 89 skills for Claude and 80 for Codex. Selected native Skill events, command output, marker evidence, and completion status are retained in [results.json](results.json); repeated catalogs are stored once and temporary fixture paths are normalized. Full initialization chatter is not retained.

All 112 final comparison runs are valid. Claude selects the same entry in all 28 cases before and after. Codex selects the same entry in 27 of 28: existing-redesign enters the general visual router rather than explore directly. The unchanged router explicitly routes improving an existing surface to explore; this is a contract-supported alternate entry, not a verified native two-skill chain. Extra context or latency from that entry was not measured. Claude meets all 28 predefined exact expectations in each revision; Codex meets 27 in the baseline and 26 in the candidate. Its other exact-expectation mismatch is the unchanged naming-is-hard selection on a copy edit. The arithmetic control loads no fixture in either host or revision. No expectations were changed to make these outcomes pass.

The shared Claude runtime descriptions decrease from 11782 to 10630 characters (9.8%). Combined plugin descriptions decrease from 6209 to 3818 characters (38.5%). These are character counts, not billed-token measurements. [metadata.json](metadata.json) preserves every changed description and every plugin subtitle.

The proposed catalog selected the general visual router on existing-redesign. Restoring the baseline explore description did not restore direct selection, so shortening explore is not an established cause. The router and explore descriptions are both baseline-exact. Its baseline description is retained conservatively; [rejected-proposal.json](rejected-proposal.json) records the proposal and rollback result. No further keyword tuning was attempted to force one exact entry.

The exact [body and inventory check](check-metadata.py) compares the baseline with the audited commit `1ba229e`, both read from Git so later skill changes do not affect it. It verifies that every baseline source still exists, flags are unchanged, and instruction bodies differ only by the deliberately added inventory lesson. It caught a global description replacement inside three how-plugins-work examples before those examples were restored; the check failed before restoration and passed afterward.

The existing subtitle-generator regression and all 21 plugin detail-page tests pass, as does the adapter check. The generated page was inspected at desktop size: the existing layout and installation context remain readable. No visual layout change is part of this review.

## Independent review

Opus (claude-opus-5-5) reviewed the proposal, two evidence-led follow-ups, and the remaining routing difference. Its useful findings restored natural task cues and explicit command discoverability, retained baseline wording where savings were unconvincing, and caught the accidental body-example replacement. Claims that the subtitle generator was absent or that identical guru skill names meant identical host workflows were rejected against the actual source. The [review dispositions](review.json) preserve accepted, reverted, rejected, and optional findings. The final review confirmed the corrected body delta and listing claims; its additional source-inventory check is implemented.

## Existing installations

All 22 existing Claude plugins and 21 existing Codex plugins were refreshed from the canonical checkout. Enabled states and installation membership are unchanged. Every installed manifest and every delivered runtime SKILL.md matches its canonical host-specific source; Codex subtitles and long descriptions match their authoring sources. Both installed Circus binaries pass the repository adapter check. Autonomous is Claude-only and remains absent in Codex. Existing sessions may retain loaded code until reload or restart. [Installation evidence](installations.json) and the [verifier](verify-installations.py) preserve the comparison.

| Plugin | Claude | Codex |
| --- | --- | --- |
| anger-management | 2.0.17 | 2.0.17 |
| autonomous | 2.0.12 | No adapter |
| bonsai | 2.0.41 | 2.0.41 |
| circus | 2.0.9 | 2.0.9 |
| clipboard | 2.0.12 | 2.0.12 |
| dibs | 2.0.79 | 2.0.79+codex.hooks.2 |
| dont-do-that | 2.0.91 | 2.0.91+codex.hooks.2 |
| drydry | 2.0.7 | 2.0.7 |
| eye-of-the-beholder | 2.0.26 | 2.0.26 |
| git-discipline | 2.0.99 | 2.0.99+codex.hooks.2 |
| gurus | 2.0.12 | 2.0.12 |
| house-rules | 2.0.30 | 2.0.30 |
| how-plugins-work | 2.0.48 | 2.0.48 |
| intervision | 2.0.26 | 2.0.26+codex.hooks.2 |
| laicluse-agent-fieldkit | 2.0.6 | 2.0.6 |
| lifeline | 2.0.4 | 2.0.4 |
| pattern-memory | 2.0.3 | 2.0.3 |
| rover | 2.0.33 | 2.0.33 |
| saysay | 2.0.10 | 2.0.10 |
| self-improvement | 2.0.11 | 2.0.11 |
| vaultsync | 2.0.34 | 2.0.34+codex.hooks.2 |
| whywhy | 2.0.5 | 2.0.5 |

## Research

Official documentation was checked on 2026-10-31. Both hosts use skill names and descriptions before loading full instructions, so descriptions lead with recognizable tasks and distinguishing triggers. [Claude skill documentation](https://code.claude.com/docs/en/skills), [OpenAI skill documentation](https://learn.chatgpt.com/docs/build-skills), and [Anthropic authoring guidance](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices#writing-effective-descriptions) distinguish discovery from execution. [OpenAI's skill eval guide](https://developers.openai.com/blog/eval-skills) motivates explicit, contextual, and negative-control cases.

Claude invocation flags and Codex skill policy are different controls. This review does not add restrictions or attempt to force host parity. Plugin subtitles are human-facing listing copy; the [OpenAI listing guidance](https://developers.openai.com/plugins/deploy/submission#listing-metadata) distinguishes a short subtitle from the longer task explanation. The new subtitles use the existing Circus interface.codex.json mechanism, without changes to the generator.
