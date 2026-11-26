import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, readFileSync, rmSync, writeFileSync, existsSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import test from 'node:test';

const helper = process.env.CLIPBOARD_COPY_TEST_HELPER || fileURLToPath(new URL('../../packages/clipboard/bin/clipboard-copy', import.meta.url));

function copy(input, args = []) {
  const directory = mkdtempSync(join(tmpdir(), 'clipboard-command-'));
  const output = join(directory, 'copied');
  writeFileSync(join(directory, 'pbcopy'), '#!/bin/sh\n/bin/cat > "$CLIPBOARD_TEST_OUTPUT"\n', { mode: 0o755 });
  try {
    const result = spawnSync(process.execPath, [helper, ...args], {
      input,
      env: { ...process.env, PATH: `${directory}:${process.env.PATH}`, CLIPBOARD_TEST_OUTPUT: output }
    });
    return { ...result, copied: existsSync(output) ? readFileSync(output) : null };
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
}

for (const ending of ['\n', '\r\n', '\n\r\n', '\r', '']) {
  test(`command mode removes terminal line endings ${JSON.stringify(ending)}`, { skip: process.platform !== 'darwin' }, () => {
    const result = copy(`printf '%s' "$VALUE"${ending}`, ['--command']);
    assert.equal(result.status, 0, result.stderr.toString());
    assert.deepEqual(result.copied, Buffer.from('printf \'%s\' "$VALUE"'));
  });
}

test('command mode preserves internal newlines, indentation and literal shell syntax', { skip: process.platform !== 'darwin' }, () => {
  const command = 'cat <<\'PAYLOAD\'\n  $(literal) `literal` café\nPAYLOAD';
  const result = copy(`${command}\n`, ['--command']);
  assert.equal(result.status, 0, result.stderr.toString());
  assert.deepEqual(result.copied, Buffer.from(command));
});

test('plain text remains byte exact, including final newlines', { skip: process.platform !== 'darwin' }, () => {
  for (const content of ['A paragraph.\n\n', '{"value":"café"}\r\n', 'const value = 1;\n']) {
    const result = copy(content);
    assert.equal(result.status, 0, result.stderr.toString());
    assert.deepEqual(result.copied, Buffer.from(content));
  }
});

test('command mode preserves internal CRLF and trailing spaces or tabs', { skip: process.platform !== 'darwin' }, () => {
  const command = 'echo first\r\necho second \t';
  const result = copy(`${command}\r\n`, ['--command']);
  assert.equal(result.status, 0, result.stderr.toString());
  assert.deepEqual(result.copied, Buffer.from(command));
});

test('unknown arguments cannot invoke the clipboard', { skip: process.platform !== 'darwin' }, () => {
  const result = copy('echo ok\n', ['--unknown']);
  assert.equal(result.status, 2);
  assert.equal(result.copied, null);
});

test('command mode refuses HTML and empty content without invoking the clipboard', { skip: process.platform !== 'darwin' }, () => {
  for (const [input, args, status] of [['echo ok\n', ['--command', '--html'], 2], ['\r\n', ['--command'], 3], ['', ['--command'], 3]]) {
    const result = copy(input, args);
    assert.equal(result.status, status, result.stderr.toString());
    assert.equal(result.copied, null);
  }
});
