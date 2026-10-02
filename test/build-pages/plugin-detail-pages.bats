#!/usr/bin/env bats
# test/build-pages/plugin-detail-pages.bats
#
# build-pages owns the public website. Plugin detail pages are generated from
# package READMEs so deep links stay synchronized with marketplace changes.

SCRIPT="$BATS_TEST_DIRNAME/../../bin/build-pages"
SOURCE_REPO="$BATS_TEST_DIRNAME/../.."

setup() {
  export REPO="$BATS_TEST_TMPDIR/repo"
  mkdir -p \
    "$REPO/.claude-plugin" \
    "$REPO/.agents/plugins" \
    "$REPO/packages/dibs/.claude-plugin" \
    "$REPO/packages/clipboard/.claude-plugin" \
    "$REPO/docs/agent-fieldkit/removed"
  git -C "$REPO" init -q -b trunk

  cat > "$REPO/.claude-plugin/marketplace.json" <<'JSON'
{
  "name": "demo-marketplace",
  "plugins": [
    { "name": "dibs", "description": "demo dibs plugin", "source": "./packages/dibs" },
    { "name": "clipboard", "description": "demo clipboard plugin", "source": "./packages/clipboard" }
  ]
}
JSON
  cat > "$REPO/.agents/plugins/marketplace.json" <<'JSON'
{
  "name": "demo-marketplace",
  "plugins": [
    { "name": "dibs" },
    { "name": "clipboard" }
  ]
}
JSON
  cat > "$REPO/packages/dibs/.claude-plugin/plugin.json" <<'JSON'
{ "name": "dibs", "description": "demo dibs plugin", "version": "2.0.23" }
JSON
  cat > "$REPO/packages/clipboard/.claude-plugin/plugin.json" <<'JSON'
{ "name": "clipboard", "description": "demo clipboard plugin", "version": "2.0.10" }
JSON
  cat > "$REPO/packages/dibs/README.md" <<'MD'
# dibs

A single-occupancy lock for a working directory with an [external reference](https://example.test/dibs) and `inline code`.

## CLI

```bash
dibs claim <dir> [--description <text>] [--json]
```

## Runnable example

```bash copy
dibs check .
```

## Installation

```bash
claude plugins install dibs@laicluse-agent-fieldkit
codex plugin add dibs@laicluse-agent-fieldkit
```

## Commands

| Command | Purpose |
|---------|---------|
| `dibs check` | Reports status |

## Parser cases

| Prompt input | What the session writes | Expected hits |
|--------------|-------------------------|---------------|
| Plate audit | Pattern `plate-outside-formatter`: run `rg -n '\\(plate\\|kenteken)\\b' Sources/` | One regex cell |

## Code spans

Nested JS template literals (`` `${`inner //`}` ``) may close the outer template state early.

Inline HTML code keeps pipes literal: <code>rg -n 'a\\|b' src/</code> for raw matches.

## Skills

### `/dibs:claim`

Claims a directory.

### `/dibs:release`

Releases it again.

- Claims a directory.
- Reports the current holder.
MD
  cat > "$REPO/packages/clipboard/README.md" <<'MD'
# clipboard

Copy answer content to a clipboard.

## Install

Claude Code:

```bash
claude plugins install clipboard@laicluse-agent-fieldkit
```

Codex:

```bash
codex plugin add clipboard@laicluse-agent-fieldkit
```
MD
  cat > "$REPO/docs/index.html" <<'HTML'
<link rel="canonical" href="https://example.test/old/">
<meta property="og:url" content="https://example.test/old/">
<meta property="og:image" content="https://example.test/assets/og-image.png?v=dev">
<meta property="og:image:secure_url" content="https://example.test/assets/og-image.png?v=dev">
<meta name="twitter:image" content="https://example.test/assets/og-image.png?v=dev">
HTML
  cat > "$REPO/docs/agent-fieldkit/index.html" <<'HTML'
<link rel="canonical" href="https://example.test/old/">
<meta property="og:url" content="https://example.test/old/">
<meta property="og:image" content="https://example.test/assets/og-image.png?v=dev">
<meta property="og:image:secure_url" content="https://example.test/assets/og-image.png?v=dev">
<meta name="twitter:image" content="https://example.test/assets/og-image.png?v=dev">
<link rel="stylesheet" href="styles.css">
<script src="site.js"></script>
HTML
  cat > "$REPO/docs/agent-fieldkit/removed/index.html" <<'HTML'
stale plugin page
HTML
  node "$SCRIPT" "$REPO" > /dev/null
}

@test "build-pages writes one detail page per current plugin" {
  [ -f "$REPO/docs/agent-fieldkit/index.html" ]
  [ -f "$REPO/docs/agent-fieldkit/dibs/index.html" ]
  [ -f "$REPO/docs/agent-fieldkit/clipboard/index.html" ]
}

@test "detail pages render package README content" {
  grep -q '<h1>dibs</h1>' "$REPO/docs/agent-fieldkit/dibs/index.html"
  grep -q 'A single-occupancy lock for a working directory' "$REPO/docs/agent-fieldkit/dibs/index.html"
  grep -q '<h2 id="cli">CLI</h2>' "$REPO/docs/agent-fieldkit/dibs/index.html"
  grep -q '<pre><code class="language-bash"><span class="code-line">dibs claim &lt;dir&gt;' "$REPO/docs/agent-fieldkit/dibs/index.html"
  grep -q '<pre data-copyable><code class="language-bash"><span class="code-line">dibs check .' "$REPO/docs/agent-fieldkit/dibs/index.html"
  grep -Eq '<script src="../../code-panel-copy\.js\?v=[0-9a-f]{10}"></script>' "$REPO/docs/agent-fieldkit/dibs/index.html"
  grep -q '<a href="https://example.test/dibs">external reference</a>' "$REPO/docs/agent-fieldkit/dibs/index.html"
  grep -q '<table>' "$REPO/docs/agent-fieldkit/dibs/index.html"
  grep -q 'Reports status' "$REPO/docs/agent-fieldkit/dibs/index.html"
}

@test "Circus website explains shared and agent-specific prompt composition" {
  grep -Fq 'shared/*.md + specific/claude.md -> ~/.claude/CLAUDE.md' "$SOURCE_REPO/packages/circus/README.md"
  grep -Fq 'shared/*.md + specific/codex.md -> ~/.codex/AGENTS.md' "$SOURCE_REPO/packages/circus/README.md"
  grep -Fq 'shared/*.md + specific/claude.md -&gt; ~/.claude/CLAUDE.md' "$SOURCE_REPO/docs/agent-fieldkit/circus/index.html"
  grep -Fq 'shared/*.md + specific/codex.md -&gt; ~/.codex/AGENTS.md' "$SOURCE_REPO/docs/agent-fieldkit/circus/index.html"
}

@test "README tables keep escaped pipes inside code spans in the same cell" {
  run node - <<'NODE' "$REPO/docs/agent-fieldkit/dibs/index.html"
const fs = require("fs");
const html = fs.readFileSync(process.argv[2], "utf8");
const table = html.match(/<h2 id="parser-cases">Parser cases<\/h2>\n(<table>[\s\S]*?<\/table>)/);
if (!table) throw new Error("parser cases table not found");
const rows = [...table[1].matchAll(/<tr>([\s\S]*?)<\/tr>/g)].map((match) => match[1]);
const bodyRow = rows[rows.length - 1];
const bodyCells = [...bodyRow.matchAll(/<td[ >]/g)].length;
if (bodyCells !== 3) throw new Error(`expected 3 body cells, got ${bodyCells}`);
if (!bodyRow.includes("\\\\|kenteken")) throw new Error("escaped pipe moved out of regex cell");
NODE
  [ "$status" -eq 0 ]
}

@test "README inline HTML code elements render as code" {
  run node - <<'NODE' "$REPO/docs/agent-fieldkit/dibs/index.html"
const fs = require("fs");
const html = fs.readFileSync(process.argv[2], "utf8");
if (html.includes("&lt;code&gt;")) throw new Error("inline <code> was escaped into visible text");
if (!html.includes("<code>rg -n 'a" + "\\".repeat(2) + "|b' src/</code>")) throw new Error("inline <code> content missing or unescaped");
NODE
  [ "$status" -eq 0 ]
}

@test "README rendering supports variable-length backtick code spans" {
  run node - <<'NODE' "$REPO/docs/agent-fieldkit/dibs/index.html"
const fs = require("fs");
const html = fs.readFileSync(process.argv[2], "utf8");
if (!html.includes("<code>`${`inner //`}`</code>")) {
  throw new Error("variable-length backtick code span did not render as one code element");
}
NODE
  [ "$status" -eq 0 ]
}

@test "detail pages expose canonical deep-link metadata" {
  grep -q '<title>dibs · l'\''Aicluse Agent Fieldkit</title>' "$REPO/docs/agent-fieldkit/dibs/index.html"
  grep -q '<link rel="canonical" href="https://laicluse.com/agent-fieldkit/dibs/">' "$REPO/docs/agent-fieldkit/dibs/index.html"
  grep -q '<meta property="og:url" content="https://laicluse.com/agent-fieldkit/dibs/">' "$REPO/docs/agent-fieldkit/dibs/index.html"
  grep -q '<meta property="og:title" content="dibs · l'\''Aicluse Agent Fieldkit">' "$REPO/docs/agent-fieldkit/dibs/index.html"
}

@test "source links use the repository default branch" {
  run node - <<'NODE' "$REPO/docs/site-data.json"
const data = require(process.argv[2]);
const plugin = data.plugins.find((entry) => entry.name === "dibs");
const change = data.changelog.find((entry) => entry.plugin === "dibs");
if (!plugin.sourceUrl.includes("/tree/trunk/packages/dibs")) {
  throw new Error(`plugin sourceUrl did not use default branch: ${plugin.sourceUrl}`);
}
if (change && !change.sourceUrl.includes("/blob/trunk/packages/dibs/CHANGELOG.md")) {
  throw new Error(`changelog sourceUrl did not use default branch: ${change.sourceUrl}`);
}
NODE
  [ "$status" -eq 0 ]
}

@test "detail pages link back to the Fieldkit landing" {
  grep -Eq '<link rel="stylesheet" href="../../styles\.css\?v=[0-9a-f]{10}">' "$REPO/docs/agent-fieldkit/dibs/index.html"
  grep -Eq '<script src="../../agent-command-switch\.js\?v=[0-9a-f]{10}"></script>' "$REPO/docs/agent-fieldkit/dibs/index.html"
  grep -q '<a class="brand" href="../" aria-label="l'\''Aicluse Agent Fieldkit home">' "$REPO/docs/agent-fieldkit/dibs/index.html"
  grep -q '<span class="wordmark" aria-hidden="true"></span><span class="brand-suffix">Agent Fieldkit</span><span class="sr-only">l'\''Aicluse Agent Fieldkit</span>' "$REPO/docs/agent-fieldkit/dibs/index.html"
  ! grep -q 'brand-mark' "$REPO/docs/agent-fieldkit/dibs/index.html"
  grep -q '<a href="../#catalog">Catalog</a>' "$REPO/docs/agent-fieldkit/dibs/index.html"
  grep -q '<a class="back-link" href="../#catalog">Catalog</a>' "$REPO/docs/agent-fieldkit/dibs/index.html"
}

@test "detail page renders one hero install command switch" {
  run node - <<'NODE' "$REPO/docs/agent-fieldkit/dibs/index.html"
const fs = require("fs");
const html = fs.readFileSync(process.argv[2], "utf8");
const allSwitches = (html.match(/class="agent-command-switch"/g) || []).length;
const install = html.match(/<aside class="detail-install"[\s\S]*?<\/aside>/);
if (!install) throw new Error("detail install panel not found");
const installSwitches = (install[0].match(/class="agent-command-switch"/g) || []).length;
if (allSwitches !== 1) throw new Error(`expected one install command switch, got ${allSwitches}`);
if (installSwitches !== 1) throw new Error("install panel does not own the install switch");
if (html.includes('<h2 id="installation">Installation</h2>')) throw new Error("README installation section still renders in the body");
const codeTexts = [...install[0].matchAll(/<code[^>]*>([\s\S]*?)<\/code>/g)].map((match) => match[1].replace(/<[^>]+>/g, ""));
if (!codeTexts.includes('claude plugins install dibs@laicluse-agent-fieldkit')) throw new Error("missing Claude command");
if (!codeTexts.includes('codex plugin add dibs@laicluse-agent-fieldkit')) throw new Error("missing Codex command");
if (codeTexts.some((text) => text.includes('claude plugins') && text.includes('codex plugin'))) {
	throw new Error("commands still render as one combined code block");
}
NODE
  [ "$status" -eq 0 ]
}

@test "README agent command fences render through the shared switch" {
  run node - <<'NODE' "$REPO/docs/agent-fieldkit/dibs/index.html"
const fs = require("fs");
const html = fs.readFileSync(process.argv[2], "utf8");
const install = html.match(/<aside class="detail-install"[\s\S]*?<\/aside>/);
if (!install) throw new Error("detail install panel not found");
if (!install[0].includes('class="agent-command-switch"')) throw new Error("install panel did not render as command switch");
if (html.includes('<h2 id="installation">Installation</h2>')) throw new Error("README install section should be suppressed on detail pages");
NODE
  [ "$status" -eq 0 ]
}

@test "split Claude and Codex README command sections merge into one switch" {
  run node - <<'NODE' "$REPO/docs/agent-fieldkit/clipboard/index.html"
const fs = require("fs");
const html = fs.readFileSync(process.argv[2], "utf8");
if (html.includes('<h2 id="install">Install</h2>')) throw new Error("clipboard README install section should be suppressed");
const switchCount = (html.match(/class="agent-command-switch"/g) || []).length;
if (switchCount !== 1) throw new Error(`expected one merged switch, got ${switchCount}`);
if (html.includes("Claude Code:") || html.includes("Codex:")) throw new Error("agent labels leaked as duplicate headings");
NODE
  [ "$status" -eq 0 ]
}

@test "site data points catalog cards at generated detail pages" {
  run node -e 'const data=require(process.argv[1]); const plugin=data.plugins.find((item)=>item.name==="dibs"); process.stdout.write(plugin.detailPath)' "$REPO/docs/site-data.json"
  [ "$output" = "agent-fieldkit/dibs/" ]
}

@test "stale plugin detail pages are removed on rebuild" {
  [ ! -e "$REPO/docs/agent-fieldkit/removed/index.html" ]
}

@test "rebuild leaves unchanged pages untouched" {
  page="$REPO/docs/agent-fieldkit/dibs/index.html"
  touch -t 202001010000 "$page"
  before="$(ls -l -T "$page" 2>/dev/null || ls -l --time-style=full-iso "$page")"
  run "$SCRIPT" "$REPO"
  [ "$status" -eq 0 ]
  [ "$(ls -l -T "$page" 2>/dev/null || ls -l --time-style=full-iso "$page")" = "$before" ]
}

@test "detail page lists its README sections in an on-this-page nav" {
  run node - <<'NODE' "$REPO/docs/agent-fieldkit/dibs/index.html"
const fs = require("fs");
const html = fs.readFileSync(process.argv[2], "utf8");
const nav = html.match(/<nav class="detail-toc"[\s\S]*?<\/nav>/);
if (!nav) throw new Error("on-this-page nav not found");
for (const id of ["commands", "parser-cases", "code-spans"]) {
	if (!nav[0].includes(`href="#${id}"`)) throw new Error(`nav misses #${id}`);
}
if (nav[0].includes('href="#installation"')) throw new Error("nav lists the suppressed install section");
NODE
  [ "$status" -eq 0 ]
}

@test "short command definitions render as one scannable group" {
  run node - <<'NODE' "$REPO/docs/agent-fieldkit/dibs/index.html"
const fs = require("fs");
const html = fs.readFileSync(process.argv[2], "utf8");
const group = html.match(/<div class="readme-scan">[\s\S]*?<\/div>/);
if (!group) throw new Error("short command definitions are not grouped");
if (!group[0].includes("/dibs:claim") || !group[0].includes("/dibs:release")) throw new Error("group misses a command");
NODE
  [ "$status" -eq 0 ]
}

@test "README code blocks keep each command option on one line" {
  run node - <<'NODE' "$REPO/docs/agent-fieldkit/dibs/index.html"
const fs = require("fs");
const html = fs.readFileSync(process.argv[2], "utf8");
if (!html.includes('<span class="code-unit">[--description &lt;text&gt;]</span>')) {
  throw new Error("bracketed option is not kept together");
}
NODE
  [ "$status" -eq 0 ]
}

@test "README code block lines render as hanging lines" {
  run node - <<'NODE' "$REPO/docs/agent-fieldkit/dibs/index.html"
const fs = require("fs");
const html = fs.readFileSync(process.argv[2], "utf8");
if (!html.includes('<code class="language-bash"><span class="code-line">dibs claim &lt;dir&gt; ')) {
  throw new Error("code block line is not wrapped as one hanging line");
}
NODE
  [ "$status" -eq 0 ]
}

@test "install commands break between words or before the marketplace" {
  run node - <<'NODE' "$REPO/docs/agent-fieldkit/dibs/index.html"
const fs = require("fs");
const html = fs.readFileSync(process.argv[2], "utf8");
const expected = '<span class="code-unit">dibs</span><wbr><span class="code-unit">@laicluse-agent-fieldkit</span>';
if (!html.includes(expected)) throw new Error("install command name can still break inside a hyphenated word");
NODE
  [ "$status" -eq 0 ]
}
