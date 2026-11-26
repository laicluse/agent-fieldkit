---
name: clipboard
description: >-
  Copy requested content to the clipboard. Use for explicit clipboard requests, including explicit requests to copy shell commands and /clipboard; never copy unsolicited.
allowed-tools:
  - Bash(*clipboard-copy*)
---

<post-update-broadcast>
BEFORE doing the actual work below, run this one-time check only when
`CLAUDE_PLUGIN_ROOT` is set:

```bash
if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; then
  node "${CLAUDE_PLUGIN_ROOT}/bin/check-broadcast"
fi
```

If the command produces output, the clipboard plugin was updated since
the last time you saw the broadcast on this machine. Show the output
verbatim in a markdown block, prefixed with one short sentence
("clipboard was updated; here is what changed."). Then continue with
the rest of this skill.

If the command produces no output, say nothing about updates and proceed.

The helper writes the sentinel only when stdout was non-empty, so a silent
run does not mark the version as seen. In agents that do not set
`CLAUDE_PLUGIN_ROOT` the broadcast is intentionally skipped; that is the
guard's purpose, not an oversight.
</post-update-broadcast>

# Clipboard

Only write to the clipboard after an explicit request to copy content. Copy the requested content, or the core of the last answer for `/clipboard`, via `clipboard-copy`. A useful command or an answer to a question alone is not permission to replace the clipboard.

## Arguments

| Argument | Effect |
|----------|--------|
| *(none)* | Plain text via `clipboard-copy` (wraps `pbcopy`) |
| `slack` | Rich text (HTML) via `clipboard-copy --html` (wraps `pbcopy-html`). Inline code, bold, and lists render correctly when pasted into Slack. Tables are converted to ASCII in a `<pre>` block (Slack does not support HTML tables) |

## Workflow

1. **Identify the core** of your last substantive answer, the useful content, not the meta-communication around it. If the last answer was itself a clipboard action, login, or other meta-operation, look further back for the last answer with actual content
2. **Determine the content type** (see table)
3. **Choose the mode**: terminal commands always use plain text through `clipboard-copy --command`, including when `slack` was requested. For other content, `slack` uses `clipboard-copy --html`; otherwise use `clipboard-copy`.
4. **Format and copy**
5. **Confirm briefly** what was copied (type + first few words)

## Content Type Detection

| Type | Recognition | Formatting |
|------|-------------|------------|
| **JSON** | JSON object/array in answer | Pretty-printed JSON, leave intact |
| **Code** | Literal source or a script to save as a file; not fenced prose or LLM prompts | Exact code without markdown fences |
| **Command** | Input intended for a shell prompt, including fenced commands | Use `--command`; preserve internal lines, omit terminal CR/LF |
| **Email/letter** | Salutation, sign-off, formal tone | Paragraphs separated by double newline |
| **Slack/chat** | Informal tone, short message | Continuous text, single newlines between paragraphs |
| **List** | Enumeration, bullet points | Preserve list formatting with `- ` prefix |
| **Explanation/prose** | Running text, explanation | Continuous paragraphs, double newline between paragraphs |
| **Table** | Table data in answer | GitHub-flavored markdown table with `---|---|---` separator |

**Mixed content:** When an answer contains code blocks with surrounding explanation, "Code" always wins over "Explanation/prose". The user wants to copy the code, not read the explanation in another window. Copy only the code blocks, leave the prose out.

"Code wins" decides *which* content to copy, not whether to preserve wrapping. A fenced block that is actually a prompt, an email, or instructions is prose, not Code: copy it (it is the core content) and reflow its hard wraps per the reflow rule above. Literal source and JSON stay byte-for-byte. Shell commands preserve their internal bytes but never end with a carriage return or newline.

## Formatting Rules

### Reflow hard-wrapped prose (the whole point of clipboard)

The reason to call clipboard is to get pure, re-flowable content. Hard line breaks
in the middle of a sentence (the ~70-80 char wrapping Claude Code adds to its
output, or manual wrapping you put in a fenced block) paste as ugly mid-sentence
breaks in any target that does its own wrapping (chat, GitHub, docs, a prompt
field). Collapse them.

- **Within a paragraph:** join the wrapped lines into one continuous line. Let the
  target wrap. Do not preserve the source line width.
- **Between paragraphs:** keep exactly one blank line.
- **Never reflow where the newline is meaningful:** code, commands, JSON, ASCII
  diagrams, ASCII tables, and list items keep their line breaks exactly. Reflow
  only running-prose blocks; a single answer can mix both (reflow the prose,
  preserve the diagram).

A block being shown inside a ``` fence is NOT a reason to preserve its wrapping.
The fence is a display choice in the chat, not a signal about the content. If the
fenced text is a prompt, an email, instructions, or any prose (not literal
source/commands/JSON), reflow it exactly like prose. This is the most common miss:
copying a fenced prompt verbatim drags every hard wrap into the paste.

### Cleaning up terminal artefacts

Claude Code output often contains:
- Newlines with leading spaces (terminal wrapping)
- Markdown formatting (`**bold**`, `` `code` ``, `### headers`)
- Bullet points as `- ` or `* `

**Always remove:**
- Markdown bold/italic markers (`**`, `*`, `_`)
- Markdown header markers (`#`, `##`, etc.)
- Leading/trailing whitespace per line

**Keep:**
- Inline code backticks (`` `technical terms` `` always stay)
- Structural newlines (paragraph breaks, list items)
- Indentation that belongs to the content type (code, JSON)

### Per type

**JSON:** Use `jq .` formatting. No extra processing.

**Code:** Exact code from the code block. No markdown fences. With multiple blocks: separate with one blank line.

**Command:** For input intended for a terminal, always use `clipboard-copy --command`, including fenced snippets and copies requested outside `/clipboard`. This mode removes terminal CR/LF bytes, including a heredoc’s final newline, while preserving internal line breaks. Never send terminal input through the default or HTML mode. A script meant to be saved as a file is Code and retains its final newline. Shell code explicitly requested for sharing as a message or snippet is also Code and may use HTML with `slack`; the `slack` argument alone does not change a terminal command into a shared message. Removing a trailing Enter does not make arbitrary multiline shell input safe to execute.

**Email/letter:** Plain text with paragraphs. No markdown. Double newline between paragraphs.

**Slack/chat:** Continuous text. Single newline only at a real paragraph break. No unnecessary line breaks.

**Explanation/prose:** Continuous paragraphs. No bullets unless the original structure requires it. Merge terminal line-wrapping into continuous sentences.

**Table:** GitHub-flavored markdown with pipe-formatting and `---|---|---` separator between header and body. Pasteable in GitHub issues, PRs, Notion, Slack (with GFM support).

## Copying

The `clipboard-copy` helper lives in this plugin's `bin/` directory and is not
on `$PATH`. Resolve the active Codex plugin root once before copying:

```bash
CLIPBOARD_PLUGIN_ROOT=$(codex plugin list --json | jq -er '.installed[] | select(.pluginId == "clipboard@laicluse-agent-fieldkit") | .source.path')
```

If the lookup fails, report that `clipboard@laicluse-agent-fieldkit` is not
installed or enabled in Codex. Do not guess a cache path. The helper then
points at the active install, so there is no stale-cache or
uninstalled-plugin failure mode to defend against. Run the resolver and the
helper call in the same shell invocation.

### Shell commands

Use command mode for every shell-command handoff:

```bash
"${CLIPBOARD_PLUGIN_ROOT}/bin/clipboard-copy" --command <<'CLIPBOARD'
[shell command here]
CLIPBOARD
```

### Default (plain text)

Use a heredoc to avoid formatting issues:

```bash
"${CLIPBOARD_PLUGIN_ROOT}/bin/clipboard-copy" <<'CLIPBOARD'
[content here]
CLIPBOARD
```

**Note:** Keep the heredoc delimiter quoted so variables, command substitutions and backticks remain literal. Do not evaluate the content while copying it. If a content line equals the delimiter, choose a different quoted delimiter.

### Slack mode

When the `slack` argument is provided, generate HTML instead of plain text and call `clipboard-copy --html`:

```bash
"${CLIPBOARD_PLUGIN_ROOT}/bin/clipboard-copy" --html <<'CLIPBOARD'
[HTML content here]
CLIPBOARD
```

`clipboard-copy --html` passes the HTML through `pbcopy-html.swift`, which places it on the clipboard as rich text (via `NSPasteboard`). Slack picks this up and renders formatting correctly. A plain text fallback (HTML tags stripped) is also included for apps that do not support rich text.

#### Do not regress to mrkdwn plain text

The `slack` argument exists specifically to produce rich text. If you are tempted to switch this back to Slack-native mrkdwn syntax (single-asterisk `*bold*`, `•` bullets, triple-backtick tables) because rich text paste feels unreliable somewhere, do not. That regression has been made before and reverted. The user has explicitly stated that rich text is the entire point of `slack`: bold must paste as bold, not as the literal characters `*bold*`. The frontmatter description ("for rich text") and the plugin description in `plugin.json` ("pbcopy-html for Slack rich text") are load-bearing, not stale text.

Plain-text mrkdwn does survive consistently across Slack desktop, web, and mobile, but that consistency was a worse-of-both: a user who reads the pasted message before sending sees `*bold*` instead of bold formatting. The user does not want that. If a specific HTML construct genuinely renders worse than its mrkdwn equivalent in some Slack client, narrow the fix to that construct (alternative HTML element, ASCII fallback, narrower wrapper); do not flip the whole mode back to plain text.

#### Markdown to HTML conversion

Convert the content to HTML before passing it to `clipboard-copy --html`:

| Markdown | HTML |
|----------|------|
| `` `code` `` | `<code>code</code>` |
| `**bold**` | `<b>bold</b>` |
| `*italic*` or `_italic_` | `<i>italic</i>` |
| `- list item` | `<li>list item</li>` (in `<ul>`) |
| `1. numbered` | `<li>numbered</li>` (in `<ol>`) |
| Empty line | `<br><br>` |
| Line break | `<br>` (newlines in HTML source are ignored by rich text paste, ALWAYS use `<br>` for line breaks) |
| `[text](url)` | `<a href="url">text</a>` |
| Special characters | **NEVER escape** with HTML entities (`&amp;`, `&gt;`, `&lt;`, `&quot;`). Many apps (Slack, Notion, Teams) render entities literally on rich text paste: `&gt;` appears as the text "&gt;" instead of ">". Write `&`, `>`, `<` directly. Only escape when the character would break an HTML tag (e.g. `<` immediately before a letter). |

Do NOT wrap the full content in `<html>` or `<body>` tags. Rich text paste expects HTML fragments, not complete documents.

#### Tables in Slack mode

Slack does NOT support `<table>` HTML elements. A `<table>` is flattened to unreadable text without structure.

**NEVER use `<table>`, `<tr>`, `<th>`, or `<td>` tags in Slack mode.**

Convert tables to ASCII format in a `<pre>` block. Slack renders `<pre>` as a monospace code block, keeping columns neatly aligned.

```html
<pre>
Requirement                    | Current state           | Gap
-------------------------------|-------------------------|---------------------------
Load management at panel level | SensorMaxPowerLimiter   | Depends on sensor data
Priority per user profile      | Planner on departure    | Concept does not exist
</pre>
```

Rules for ASCII tables in `<pre>`:
- Columns separated by ` | ` (space-pipe-space)
- Header separated from body by `---...|---...` line
- Column width: pad with spaces so pipes align vertically
- No HTML tags inside `<pre>` (no `<code>`, `<b>`, etc.)

#### Example

Markdown content:
```
De job is goed uitgevoerd. Alle platforms uit `PLATFORM_TIMEOUTS` zijn **volledig** backfilled.
```

Becomes:
```bash
"${CLIPBOARD_PLUGIN_ROOT}/bin/clipboard-copy" --html <<'CLIPBOARD'
De job is goed uitgevoerd. Alle platforms uit <code>PLATFORM_TIMEOUTS</code> zijn <b>volledig</b> backfilled.
CLIPBOARD
```

## Confirmation

After copying, confirm with one line:

```
[type] copied: "[first ~30 characters]..."
```

Examples:
- `JSON copied: "{"name":"my-project","vers..."`
- `Code copied: "def calculate_price(kwh..."`
- `Slack message copied: "Hey team, de deploy van..."`
- `Table copied (slack/rich text): "De job is goed uitgev..."`

## Looking back past meta-answers

If the immediately preceding answer has no copyable core (clipboard confirmation, login, skill invocation), look further back in the conversation. "Last answer" means the last answer with substantive content, not necessarily the chronologically last one.

## Nothing to copy

Only when there is no copyable content anywhere in the recent conversation (e.g. session just started, only questions asked), report briefly:

```
No copyable content found in the conversation.
```
