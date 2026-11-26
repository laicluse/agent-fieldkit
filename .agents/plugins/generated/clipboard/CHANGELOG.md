# clipboard changelog

The post-update broadcast (see `bin/check-broadcast`) shows the topmost
section once per machine whenever the installed `version` in
`.claude-plugin/plugin.json` changes. Entry headers record the version at
which the entry was written; a pre-commit hook auto-bumps `plugin.json` on
every commit, so the header may lag the shipped version. Header numbers are
informational, the broadcast is positional. Use the `--force` flag on the
helper to re-read at any time.

Categories:

- **Breaking**: user must adapt
- **Added**: new commands, new optional behavior
- **Changed**: non-breaking adjustments worth knowing about
- **Fixed**: silent unless the bug was user-visible

Patch-level fixes that change nothing the user can observe are intentionally
omitted; the broadcast budget is for things the user benefits from knowing.
The helper writes the sentinel only when stdout is non-empty, so a CHANGELOG
without a `## [vX.Y.Z]` section stays silent on every update.

## [v2.0.14]

### Fixed

- Shell-command handoffs use `--command` to remove trailing newlines and carriage returns. Internal formatting and ordinary text or JSON remain unchanged.
- Explicit requests to copy commands now select the skill without requiring `/clipboard`. Copying remains opt-in; quoted heredocs keep the supplied command literal.

## [v2.0.8]

### Fixed

- **Codex now gets its own `/clipboard` helper-resolution instructions.**
  Claude still uses `${CLAUDE_PLUGIN_ROOT}`; Codex resolves the active plugin
  root through `codex plugin list --json` before invoking `bin/clipboard-copy`.

## [v2.0.7]

### Fixed

- **Copying a fenced prompt or prose no longer drags hard line-wraps into the
  paste.** A fenced block is a display choice in the chat, not a signal to keep
  the source line width. Only literal source, commands, or JSON stay
  byte-for-byte; prompts, emails, and prose get their mid-sentence line breaks
  reflowed so the paste re-wraps cleanly in the target. ASCII diagrams, tables,
  and list items keep their newlines.

## [v2.0.1]

### Breaking

- **clipboard now ships from the public laicluse-agent-fieldkit marketplace.**
  Install the Fieldkit copy for the current `/clipboard` and `/clipboard slack`
  commands.
  The commands are unchanged: `/clipboard` and `/clipboard slack`.

### Changed

- **The skill resolves its helper via the plugin root instead of a jq lookup
  of `installed_plugins.json`.** The `bin/clipboard-paths.sh` shim is gone;
  the plugin root always points at the active install, so the stale-cache and
  uninstalled-plugin failure modes the shim defended against no longer exist.

## [v1.0.21]

- **Changed**: `/clipboard slack` produces rich text again. Bold pastes as bold, lists as bullets, inline code in monospace. If you saw literal `*bold*` characters after `/clipboard slack`, that stops now.
- **Added**: Anti-regression note in the SKILL so the next "make this more consistent" pass does not flip back to plain-text mrkdwn.
