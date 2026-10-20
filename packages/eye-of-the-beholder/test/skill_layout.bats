#!/usr/bin/env bats

@test "both hosts ship the same skill bodies and supporting assets" {
  run node - "$BATS_TEST_DIRNAME" <<'NODE'
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const root = path.resolve(process.argv[2], '../../..');
const source = path.join(root, 'packages/eye-of-the-beholder/skills');
const generated = path.join(root, '.agents/plugins/generated/eye-of-the-beholder/skills');
function files(dir, base = dir) {
  return fs.readdirSync(dir, {withFileTypes: true}).flatMap(entry => {
    const full = path.join(dir, entry.name);
    return entry.isDirectory() ? files(full, base) : [path.relative(base, full)];
  }).sort();
}
const names = files(source);
assert.deepEqual(files(generated), names, 'generated tree lost or retained a stale skill asset');
assert.deepEqual(names.filter(name => path.basename(name) === 'SKILL.md'), [
  'define/SKILL.md', 'explore/SKILL.md', 'eye-of-the-beholder/SKILL.md', 'obvious/SKILL.md', 'review/SKILL.md'
], 'public skill inventory changed');
for (const name of names) {
  let a = fs.readFileSync(path.join(source, name));
  let b = fs.readFileSync(path.join(generated, name));
  if (path.basename(name) === 'SKILL.md') {
    // Codex sanitizes host-specific frontmatter; instruction bodies must remain identical.
    a = a.toString().replace(/^---\r?\n[\s\S]*?\r?\n---\r?\n/, '');
    b = b.toString().replace(/^---\r?\n[\s\S]*?\r?\n---\r?\n/, '');
  }
  assert.deepEqual(b, a, name);
}
NODE
  [ "$status" -eq 0 ]
}

@test "every shipped local markdown link resolves in each host tree" {
  run node - "$BATS_TEST_DIRNAME" <<'NODE'
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const root = path.resolve(process.argv[2], '../../..');
function scan(dir) {
  for (const entry of fs.readdirSync(dir, {withFileTypes: true})) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) { scan(full); continue; }
    if (!entry.name.endsWith('.md')) continue;
    for (const match of fs.readFileSync(full, 'utf8').matchAll(/\]\(([^)]+)\)/g)) {
      const ref = match[1];
      if (ref.includes('://') || ref.startsWith('#')) continue;
      assert.ok(fs.existsSync(path.resolve(path.dirname(full), ref.split('#')[0])), `${full}: ${ref}`);
    }
  }
}
scan(path.join(root, 'packages/eye-of-the-beholder/skills'));
scan(path.join(root, '.agents/plugins/generated/eye-of-the-beholder/skills'));
NODE
  [ "$status" -eq 0 ]
}
