import assert from 'node:assert/strict';
import { cpSync, mkdtempSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import { dibsRuntimePath, dibsRuntimeVersion, publishDibsRuntime } from '../bin/machine-runtime.mjs';

const packageRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const tempRoot = mkdtempSync(join(tmpdir(), 'dibs-machine-runtime-'));
try {
  const home = join(tempRoot, 'home');
  const futureSource = join(tempRoot, 'future-dibs');
  mkdirSync(futureSource, { recursive: true });
  cpSync(join(packageRoot, '.claude-plugin'), join(futureSource, '.claude-plugin'), { recursive: true });
  cpSync(join(packageRoot, 'bin'), join(futureSource, 'bin'), { recursive: true });
  const manifestPath = join(futureSource, '.claude-plugin', 'plugin.json');
  const manifest = JSON.parse(readFileSync(manifestPath, 'utf8'));
  manifest.version = '99.0.0';
  writeFileSync(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`);
  writeFileSync(join(futureSource, 'bin', 'dibs'), '#!/usr/bin/env node\nprocess.stdout.write("latest Dibs runtime\\n");\n', { mode: 0o755 });
  const codexSource = join(tempRoot, 'codex-dibs');
  mkdirSync(join(codexSource, '.codex-plugin'), { recursive: true });
  writeFileSync(join(codexSource, '.codex-plugin', 'plugin.json'), JSON.stringify({ version: '2.3.4+codex.hooks.2' }));
  assert.equal(dibsRuntimeVersion(codexSource), '2.3.4');

  const env = { ...process.env, HOME: home, LAICLUSE_HOME: undefined };
  const published = publishDibsRuntime(futureSource, undefined, env);
  assert.equal(published.version, '99.0.0');
  assert.equal(published.installed, true);
  assert.equal(readFileSync(join(home, '.laicluse', 'dibs', 'runtime', 'current.json'), 'utf8').includes('99.0.0'), true);
  const parser = spawnSync(process.execPath, [join(home, '.laicluse', 'dibs', 'runtime', 'bash-write-targets'), '/tmp'], { encoding: 'utf8', input: 'touch file.txt\n', env });
  assert.equal(parser.status, 0, parser.stderr);
  assert.equal(parser.stdout.trim(), '/tmp/file.txt');

  const oldSession = spawnSync(process.execPath, [join(packageRoot, 'bin', 'dibs'), '--help'], { encoding: 'utf8', env });
  assert.equal(oldSession.status, 0, oldSession.stderr);
  assert.match(oldSession.stdout, /latest Dibs runtime/);
  const override = spawnSync(process.execPath, [join(packageRoot, 'bin', 'dibs'), '--help'], { encoding: 'utf8', env: { ...env, DIBS_BIN: '/custom/dibs' } });
  assert.equal(override.status, 0, override.stderr);
  assert.match(override.stdout, /usage: dibs/);

  const noDowngrade = publishDibsRuntime(packageRoot, undefined, env);
  assert.equal(noDowngrade.installed, false);
  assert.equal(noDowngrade.version, '99.0.0');
  assert.equal(dibsRuntimePath(env), published.launcher);
} finally {
  rmSync(tempRoot, { recursive: true, force: true });
}
