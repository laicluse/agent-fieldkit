# clipboard

Copy the core content of the last assistant answer to the macOS clipboard.
Plain text is the default; Slack-flavored rich text is available on request.

Use it when the answer itself is the artefact you need to paste elsewhere: a
summary, command block, code snippet, Slack update, or short handoff. The skill
tries to copy the useful body, not the chat wrapper around it.

## Installation

```bash
claude plugins install clipboard@laicluse-agent-fieldkit
codex plugin add clipboard@laicluse-agent-fieldkit
```

In a Claude Code session, version 2.1.275 or later, one line installs it straight from the marketplace repository:

```
/plugin install clipboard --marketplace laicluse/agent-fieldkit
```

## Commands

### `/clipboard`

Copies the relevant content of the last answer to the clipboard as plain text via the `clipboard-copy` helper (which wraps `pbcopy`). The skill picks the core content (code block, summary, answer body) rather than the full response wrapper.

### `/clipboard slack`

Copies as Slack rich text via `clipboard-copy --html` (which wraps `pbcopy-html`), preserving bold, italic, code spans, and code blocks when pasted into Slack.

## Requirements

macOS, with Node.js on `$PATH` (the `clipboard-copy` helper and the
update-broadcast check are Node scripts). Plain text mode uses the built-in
`pbcopy` and works out of the box; the skill calls the `clipboard-copy` helper
that ships inside `bin/` of the active plugin install, so no PATH-level install
step is needed. Claude resolves that root through `${CLAUDE_PLUGIN_ROOT}`;
Codex resolves it through `codex plugin list --json`.

Rich text mode (`/clipboard slack`) drives `pbcopy-html`, a Swift script shipped with the plugin. Copy it onto your `$PATH` if you want to invoke `pbcopy-html` directly from a shell; `clipboard-copy --html` already resolves it relative to its own location. The `jq` lookup below is a shell convenience for finding the active install from your terminal (where `${CLAUDE_PLUGIN_ROOT}` is not set); the skill itself never uses it, and the copy is repeated after each plugin update per the note below. The marketplace is symlink-free to keep Windows consumers working, so install with `cp -f`:

```bash
SRC=$(jq -r '.plugins["clipboard@laicluse-agent-fieldkit"][0].installPath // empty' ~/.claude/plugins/installed_plugins.json)
[ -n "$SRC" ] || { echo "clipboard@laicluse-agent-fieldkit is not installed"; exit 1; }
cp -f "$SRC/skills/clipboard/pbcopy-html.swift" /usr/local/bin/pbcopy-html
```

The script runs via its `#!/usr/bin/env swift` shebang; no compile step is needed.

Re-run after each `claude plugins update clipboard@laicluse-agent-fieldkit` so the installed copy matches the updated plugin.

## Consuming from another plugin

A skill in a different plugin cannot use `${CLAUDE_PLUGIN_ROOT}` to find this
plugin's helper (that variable points at its own root). The canonical
resolution idiom for cross-plugin consumers is one lookup against the
harness's install index, with a graceful skip when clipboard is absent:

```bash
IP=$(jq -r '.plugins["clipboard@laicluse-agent-fieldkit"][0].installPath // empty' ~/.claude/plugins/installed_plugins.json 2>/dev/null)
if [ -n "$IP" ] && [ -x "$IP/bin/clipboard-copy" ]; then
  printf 'content' | "$IP/bin/clipboard-copy"
fi
```

Copy this idiom rather than inventing a variant; it is the one place the
install key lives outside this plugin.
