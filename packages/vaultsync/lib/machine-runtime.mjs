import { randomUUID } from 'node:crypto';
import {
  accessSync,
  chmodSync,
  closeSync,
  cpSync,
  existsSync,
  mkdirSync,
  openSync,
  readFileSync,
  renameSync,
  rmSync,
  statSync,
  unlinkSync,
  writeFileSync,
} from 'node:fs';
import { constants } from 'node:fs';
import { homedir } from 'node:os';
import { dirname, join } from 'node:path';

const LOCK_TIMEOUT_MS = 30000;
const STALE_EMPTY_LOCK_MS = 5000;
const sleepSlot = new Int32Array(new SharedArrayBuffer(4));

function sleep(ms) {
  Atomics.wait(sleepSlot, 0, 0, ms);
}

function stateRoot(env = process.env) {
  return env.LAICLUSE_HOME || join(env.HOME || homedir(), '.laicluse');
}

function runtimeRoot(env = process.env) {
  return join(stateRoot(env), 'vaultsync', 'runtime');
}

function compareVersions(left, right) {
  const parse = (version) => {
    const match = String(version).match(/^(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z.-]+))?(?:\+[0-9A-Za-z.-]+)?$/);
    if (!match) throw new Error(`invalid Vaultsync version: ${version}`);
    return { numbers: match.slice(1, 4).map(Number), prerelease: match[4] };
  };
  const a = parse(left);
  const b = parse(right);
  for (let index = 0; index < 3; index += 1) {
    if (a.numbers[index] !== b.numbers[index]) return a.numbers[index] - b.numbers[index];
  }
  if (a.prerelease === b.prerelease) return 0;
  if (a.prerelease === undefined) return 1;
  if (b.prerelease === undefined) return -1;
  return a.prerelease.localeCompare(b.prerelease, 'en', { numeric: true });
}

function atomicWrite(path, content, mode) {
  mkdirSync(dirname(path), { recursive: true });
  const temporary = `${path}.${process.pid}.${randomUUID()}.tmp`;
  try {
    writeFileSync(temporary, content, mode === undefined ? undefined : { mode });
    if (mode !== undefined) chmodSync(temporary, mode);
    renameSync(temporary, path);
  } catch (error) {
    rmSync(temporary, { force: true });
    throw error;
  }
}

function processIsAlive(pid) {
  if (!Number.isInteger(pid) || pid <= 0) return false;
  try {
    process.kill(pid, 0);
    return true;
  } catch (error) {
    return error.code === 'EPERM';
  }
}

function withInstallLock(env, operation) {
  const root = runtimeRoot(env);
  const lockPath = join(root, '.install.lock');
  const token = `${process.pid}:${randomUUID()}`;
  const deadline = Date.now() + LOCK_TIMEOUT_MS;
  mkdirSync(root, { recursive: true });
  let descriptor;
  while (descriptor === undefined) {
    try {
      descriptor = openSync(lockPath, 'wx', 0o600);
      writeFileSync(descriptor, `${token}\n`);
    } catch (error) {
      if (error.code !== 'EEXIST') throw error;
      const ownerText = (() => {
	try { return readFileSync(lockPath, 'utf8').trim(); } catch { return ''; }
      })();
      const ownerPid = Number.parseInt(ownerText.split(':', 1)[0], 10);
      const age = (() => {
	try { return Date.now() - statSync(lockPath).mtimeMs; } catch { return Number.POSITIVE_INFINITY; }
      })();
      if ((!ownerText && age >= STALE_EMPTY_LOCK_MS) || (ownerText && !processIsAlive(ownerPid))) {
	rmSync(lockPath, { force: true });
	continue;
      }
      if (Date.now() >= deadline) throw new Error(`timed out waiting for Vaultsync runtime installation held by process ${ownerPid || 'unknown'}`);
      sleep(50);
    }
  }
  try {
    return operation();
  } finally {
    closeSync(descriptor);
    let current = '';
    try { current = readFileSync(lockPath, 'utf8').trim(); } catch {}
    if (current === token) unlinkSync(lockPath);
  }
}

function launcherSource() {
  return `#!/usr/bin/env node
'use strict';
const { existsSync, readFileSync } = require('node:fs');
const { homedir } = require('node:os');
const { join } = require('node:path');
const { spawn } = require('node:child_process');

const stateRoot = process.env.LAICLUSE_HOME || join(process.env.HOME || homedir(), '.laicluse');
const runtimeRoot = join(stateRoot, 'vaultsync', 'runtime');
let pointer;
try {
  pointer = JSON.parse(readFileSync(join(runtimeRoot, 'current.json'), 'utf8'));
} catch (error) {
  process.stderr.write(\`vaultsync: machine runtime is not installed: \${error.message}\\n\`);
  process.exit(1);
}

const entrypoint = join(runtimeRoot, 'releases', pointer.release, 'bin', 'vaultsync');
if (!existsSync(entrypoint)) {
  process.stderr.write(\`vaultsync: active runtime \${pointer.version} is incomplete\\n\`);
  process.exit(1);
}
const child = spawn(process.execPath, [entrypoint, ...process.argv.slice(2)], { stdio: 'inherit', env: process.env });
for (const signal of ['SIGINT', 'SIGTERM', 'SIGHUP']) process.on(signal, () => child.kill(signal));
child.on('error', (error) => {
  process.stderr.write(\`vaultsync: could not start active runtime: \${error.message}\\n\`);
  process.exitCode = 1;
});
child.on('exit', (code, signal) => {
  if (signal) process.kill(process.pid, signal);
  else process.exitCode = code ?? 1;
});
`;
}

function validateRelease(releaseRoot, version) {
  const manifest = JSON.parse(readFileSync(join(releaseRoot, '.vaultsync-runtime.json'), 'utf8'));
  if (manifest.version !== version) throw new Error(`Vaultsync runtime manifest version ${manifest.version} does not match ${version}`);
  accessSync(join(releaseRoot, 'bin', 'vaultsync'), constants.X_OK);
}

export function sourceRuntimeVersion(sourceRoot) {
  const candidates = [
    join(sourceRoot, '.vaultsync-runtime.json'),
    join(sourceRoot, '.claude-plugin', 'plugin.json'),
    join(sourceRoot, '.codex-plugin', 'plugin.json'),
  ];
  const path = candidates.find((candidate) => existsSync(candidate));
  if (!path) throw new Error('Vaultsync runtime manifest not found');
  const manifest = JSON.parse(readFileSync(path, 'utf8'));
  const version = String(manifest.version || '').replace(/\+codex\.hooks\.\d+$/, '');
  compareVersions(version, version);
  return version;
}

export function machineLauncherPath(env = process.env) {
  const directory = env.VAULTSYNC_BIN_DIR || join(env.HOME || homedir(), '.local', 'bin');
  return join(directory, process.platform === 'win32' ? 'vaultsync.cmd' : 'vaultsync');
}

export function activeMachineRuntime(env = process.env) {
  const pointerPath = join(runtimeRoot(env), 'current.json');
  if (!existsSync(pointerPath)) return undefined;
  const pointer = JSON.parse(readFileSync(pointerPath, 'utf8'));
  compareVersions(pointer.version, pointer.version);
  if (!/^[0-9A-Za-z.+-]+$/.test(pointer.release)) throw new Error('invalid Vaultsync runtime release pointer');
  return pointer;
}

export function installMachineRuntime({ sourceRoot, version, env = process.env }) {
  compareVersions(version, version);
  const sourceVersion = sourceRuntimeVersion(sourceRoot);
  if (sourceVersion !== version) throw new Error(`Vaultsync runtime manifest version ${sourceVersion} does not match ${version}`);
  return withInstallLock(env, () => {
    const root = runtimeRoot(env);
    const releases = join(root, 'releases');
    const launcher = machineLauncherPath(env);
    const active = activeMachineRuntime(env);
    if (active && compareVersions(active.version, version) > 0) {
      return { installed: false, version: active.version, launcher, releaseRoot: join(releases, active.release) };
    }

    const release = version;
    const releaseRoot = join(releases, release);
    if (!existsSync(releaseRoot)) {
      mkdirSync(releases, { recursive: true });
      const staging = join(releases, `.staging-${version}-${process.pid}-${randomUUID()}`);
      try {
	mkdirSync(staging);
	for (const entry of ['bin', 'lib', 'package.json']) cpSync(join(sourceRoot, entry), join(staging, entry), { recursive: true, errorOnExist: true });
	writeFileSync(join(staging, '.vaultsync-runtime.json'), `${JSON.stringify({ name: 'vaultsync', version }, null, 2)}\n`, { mode: 0o600 });
	chmodSync(join(staging, 'bin', 'vaultsync'), 0o755);
	validateRelease(staging, version);
	renameSync(staging, releaseRoot);
      } catch (error) {
	rmSync(staging, { recursive: true, force: true });
	throw error;
      }
    }
    validateRelease(releaseRoot, version);

    atomicWrite(launcher, launcherSource(), 0o755);
    const installed = !active || compareVersions(active.version, version) < 0;
    atomicWrite(join(root, 'current.json'), `${JSON.stringify({ version, release }, null, 2)}\n`, 0o600);
    return { installed, version, launcher, releaseRoot };
  });
}
