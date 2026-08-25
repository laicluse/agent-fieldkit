import assert from 'node:assert/strict';
import { chmodSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawn, spawnSync } from 'node:child_process';
import test from 'node:test';

import {
  activeMachineRuntime,
  installMachineRuntime,
  machineLauncherPath,
} from '../machine-runtime.mjs';

function sourceFixture(root, version, message, manifestDirectory = '.claude-plugin') {
  const sourceRoot = join(root, `source-${version}`);
  mkdirSync(join(sourceRoot, 'bin'), { recursive: true });
  mkdirSync(join(sourceRoot, 'lib'));
  mkdirSync(join(sourceRoot, manifestDirectory));
  writeFileSync(join(sourceRoot, manifestDirectory, 'plugin.json'), `${JSON.stringify({ name: 'vaultsync', version })}\n`);
  writeFileSync(join(sourceRoot, 'package.json'), '{"type":"module"}\n');
  writeFileSync(join(sourceRoot, 'bin', 'vaultsync'), `#!/usr/bin/env node\nprocess.stdout.write(${JSON.stringify(`${message}\n`)});\n`);
  chmodSync(join(sourceRoot, 'bin', 'vaultsync'), 0o755);
  return sourceRoot;
}

test('the machine runtime survives removal of the plugin version that published it', () => {
  const root = mkdtempSync(join(tmpdir(), 'vaultsync-machine-runtime-'));
  const env = { ...process.env, HOME: join(root, 'home'), LAICLUSE_HOME: join(root, 'state'), VAULTSYNC_BIN_DIR: join(root, 'bin') };
  const sourceRoot = sourceFixture(root, '2.0.17', 'machine-owned runtime');

  const installed = installMachineRuntime({ sourceRoot, version: '2.0.17', env });
  rmSync(sourceRoot, { recursive: true, force: true });
  const result = spawnSync(installed.launcher, [], { encoding: 'utf8', env });

  assert.equal(result.status, 0, result.stderr);
  assert.equal(result.stdout, 'machine-owned runtime\n');
  assert.equal(machineLauncherPath(env), installed.launcher);
});

test('independent plugin versions only move the active machine runtime forward', () => {
  const root = mkdtempSync(join(tmpdir(), 'vaultsync-machine-runtime-'));
  const env = { ...process.env, HOME: join(root, 'home'), LAICLUSE_HOME: join(root, 'state'), VAULTSYNC_BIN_DIR: join(root, 'bin') };
  const older = sourceFixture(root, '2.0.16', 'older');
  const current = sourceFixture(root, '2.0.17', 'current');
  const newest = sourceFixture(root, '2.1.0', 'newest');

  installMachineRuntime({ sourceRoot: current, version: '2.0.17', env });
  const downgrade = installMachineRuntime({ sourceRoot: older, version: '2.0.16', env });
  assert.equal(downgrade.installed, false);
  assert.equal(activeMachineRuntime(env).version, '2.0.17');

  installMachineRuntime({ sourceRoot: newest, version: '2.1.0', env });
  assert.equal(activeMachineRuntime(env).version, '2.1.0');
  const result = spawnSync(machineLauncherPath(env), [], { encoding: 'utf8', env });
  assert.equal(result.stdout, 'newest\n');
});

test('the active pointer only names a complete immutable release', () => {
  const root = mkdtempSync(join(tmpdir(), 'vaultsync-machine-runtime-'));
  const env = { ...process.env, HOME: join(root, 'home'), LAICLUSE_HOME: join(root, 'state'), VAULTSYNC_BIN_DIR: join(root, 'bin') };
  const sourceRoot = sourceFixture(root, '2.0.17', 'complete');

  const installed = installMachineRuntime({ sourceRoot, version: '2.0.17', env });
  const pointer = activeMachineRuntime(env);

  assert.equal(pointer.version, '2.0.17');
  assert.equal(pointer.release, '2.0.17');
  assert.equal(readFileSync(join(installed.releaseRoot, '.vaultsync-runtime.json'), 'utf8').includes('2.0.17'), true);
  assert.equal(readFileSync(join(installed.releaseRoot, 'bin', 'vaultsync'), 'utf8').includes('complete'), true);
});

test('a generated Codex package can publish the same host-neutral runtime version', () => {
  const root = mkdtempSync(join(tmpdir(), 'vaultsync-machine-runtime-'));
  const env = { ...process.env, HOME: join(root, 'home'), LAICLUSE_HOME: join(root, 'state'), VAULTSYNC_BIN_DIR: join(root, 'bin') };
  const sourceRoot = sourceFixture(root, '2.0.17+codex.hooks.2', 'codex', '.codex-plugin');

  const installed = installMachineRuntime({ sourceRoot, version: '2.0.17', env });

  assert.equal(installed.version, '2.0.17');
  assert.equal(activeMachineRuntime(env).version, '2.0.17');
  assert.equal(spawnSync(machineLauncherPath(env), [], { encoding: 'utf8', env }).stdout, 'codex\n');
});

test('concurrent plugin publishers converge on the newest complete release', async () => {
  const root = mkdtempSync(join(tmpdir(), 'vaultsync-machine-runtime-'));
  const env = { ...process.env, HOME: join(root, 'home'), LAICLUSE_HOME: join(root, 'state'), VAULTSYNC_BIN_DIR: join(root, 'bin') };
  const older = sourceFixture(root, '2.0.16', 'older');
  const newest = sourceFixture(root, '2.1.0', 'newest');
  const moduleUrl = new URL('../machine-runtime.mjs', import.meta.url).href;
  const publish = (sourceRoot, version) => new Promise((resolve, reject) => {
    const script = `import { installMachineRuntime } from ${JSON.stringify(moduleUrl)}; installMachineRuntime({ sourceRoot: process.argv[1], version: process.argv[2] });`;
    const child = spawn(process.execPath, ['--input-type=module', '--eval', script, sourceRoot, version], { env, stdio: ['ignore', 'ignore', 'pipe'] });
    let stderr = '';
    child.stderr.on('data', (chunk) => { stderr += chunk; });
    child.on('error', reject);
    child.on('exit', (code) => code === 0 ? resolve() : reject(new Error(stderr || `publisher exited ${code}`)));
  });

  await Promise.all(Array.from({ length: 12 }, (_, index) => publish(index % 2 === 0 ? older : newest, index % 2 === 0 ? '2.0.16' : '2.1.0')));

  assert.equal(activeMachineRuntime(env).version, '2.1.0');
  const result = spawnSync(machineLauncherPath(env), [], { encoding: 'utf8', env });
  assert.equal(result.status, 0, result.stderr);
  assert.equal(result.stdout, 'newest\n');
});

test('an invalid staged release never replaces the active pointer', () => {
  const root = mkdtempSync(join(tmpdir(), 'vaultsync-machine-runtime-'));
  const env = { ...process.env, HOME: join(root, 'home'), LAICLUSE_HOME: join(root, 'state'), VAULTSYNC_BIN_DIR: join(root, 'bin') };
  const valid = sourceFixture(root, '2.0.17', 'valid');
  const mismatched = sourceFixture(root, '2.1.0', 'invalid');
  writeFileSync(join(mismatched, '.claude-plugin', 'plugin.json'), '{"name":"vaultsync","version":"9.0.0"}\n');
  installMachineRuntime({ sourceRoot: valid, version: '2.0.17', env });

  assert.throws(() => installMachineRuntime({ sourceRoot: mismatched, version: '2.1.0', env }), /manifest version 9\.0\.0 does not match 2\.1\.0/);
  assert.equal(activeMachineRuntime(env).version, '2.0.17');
});
