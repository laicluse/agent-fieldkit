import assert from 'node:assert/strict';
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import { gitDisciplineRuntimePath, gitDisciplineRuntimeVersion, publishGitDisciplineRuntime } from '../bin/machine-runtime.mjs';

const packageRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const tempRoot = mkdtempSync(join(tmpdir(), 'git-discipline-machine-runtime-'));
try {
  const env = { ...process.env, HOME: join(tempRoot, 'home'), LAICLUSE_HOME: undefined };
  const codexSource = join(tempRoot, 'codex-git-discipline');
  mkdirSync(join(codexSource, '.codex-plugin'), { recursive: true });
  writeFileSync(join(codexSource, '.codex-plugin', 'plugin.json'), JSON.stringify({ version: '2.3.4+codex.hooks.2' }));
  assert.equal(gitDisciplineRuntimeVersion(codexSource), '2.3.4');
  const published = publishGitDisciplineRuntime(packageRoot, undefined, env);
  assert.equal(published.installed, true);
  assert.equal(gitDisciplineRuntimePath(env), published.launcher);
  const pointer = JSON.parse(readFileSync(join(env.HOME, '.laicluse', 'git-discipline', 'runtime', 'current.json'), 'utf8'));
  assert.equal(pointer.version, published.version);

  const hook = spawnSync(published.launcher, ['pre-push'], { encoding: 'utf8', input: '', env });
  assert.equal(hook.status, 0, hook.stderr);
} finally {
  rmSync(tempRoot, { recursive: true, force: true });
}
