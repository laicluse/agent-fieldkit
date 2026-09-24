import { randomUUID } from 'node:crypto';
import { spawnSync } from 'node:child_process';
import {
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
import { homedir } from 'node:os';
import { dirname, join } from 'node:path';

const sleepSlot = new Int32Array(new SharedArrayBuffer(4));

function sleep(ms) {
  Atomics.wait(sleepSlot, 0, 0, ms);
}

function runtimeRoot(env = process.env) {
  return join(env.LAICLUSE_HOME || join(env.HOME || homedir(), '.laicluse'), 'dibs', 'runtime');
}

function compareVersions(left, right) {
  const parse = (version) => {
    const match = String(version).replace(/\+codex\.hooks\.\d+$/, '').match(/^(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z.-]+))?$/);
    if (!match) throw new Error(`invalid Dibs version: ${version}`);
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

function activeRuntime(env = process.env) {
  try {
    const pointer = JSON.parse(readFileSync(join(runtimeRoot(env), 'current.json'), 'utf8'));
    compareVersions(pointer.version, pointer.version);
    if (!/^[0-9A-Za-z.+-]+$/.test(pointer.release)) throw new Error('invalid Dibs runtime release pointer');
    return { ...pointer, root: join(runtimeRoot(env), 'releases', pointer.release) };
  } catch (error) {
    if (error.code === 'ENOENT') return null;
    throw error;
  }
}

function launcherSource() {
  return `#!/usr/bin/env node
'use strict';
const { existsSync, readFileSync } = require('node:fs');
const { homedir } = require('node:os');
const { join } = require('node:path');
const { spawnSync } = require('node:child_process');

const root = join(process.env.LAICLUSE_HOME || join(process.env.HOME || homedir(), '.laicluse'), 'dibs', 'runtime');
let pointer;
try { pointer = JSON.parse(readFileSync(join(root, 'current.json'), 'utf8')); }
catch (error) { process.stderr.write(\`dibs: machine runtime is not installed: \${error.message}\\n\`); process.exit(1); }
const entrypoint = join(root, 'releases', pointer.release, 'bin', 'dibs');
if (!existsSync(entrypoint)) { process.stderr.write(\`dibs: active runtime \${pointer.version} is incomplete\\n\`); process.exit(1); }
const child = spawnSync(process.execPath, [entrypoint, ...process.argv.slice(2)], { stdio: 'inherit', env: { ...process.env, DIBS_RUNTIME_ACTIVE: '1' } });
if (child.error) { process.stderr.write(\`dibs: could not start active runtime: \${child.error.message}\\n\`); process.exit(1); }
process.exit(child.status ?? 1);
`;
}

function parserLauncherSource() {
  return `#!/usr/bin/env node
'use strict';
const { existsSync, readFileSync } = require('node:fs');
const { homedir } = require('node:os');
const { join } = require('node:path');
const { spawnSync } = require('node:child_process');
const root = join(process.env.LAICLUSE_HOME || join(process.env.HOME || homedir(), '.laicluse'), 'dibs', 'runtime');
let pointer;
try { pointer = JSON.parse(readFileSync(join(root, 'current.json'), 'utf8')); }
catch (error) { process.stderr.write(\`dibs: machine runtime is not installed: \${error.message}\\n\`); process.exit(1); }
const entrypoint = join(root, 'releases', pointer.release, 'bin', 'bash-write-targets');
if (!existsSync(entrypoint)) { process.stderr.write(\`dibs: active runtime \${pointer.version} is incomplete\\n\`); process.exit(1); }
const child = spawnSync(process.execPath, [entrypoint, ...process.argv.slice(2)], { stdio: 'inherit' });
if (child.error) { process.stderr.write(\`dibs: could not start active parser: \${child.error.message}\\n\`); process.exit(1); }
process.exit(child.status ?? 1);
`;
}

function withInstallLock(env, operation) {
  const root = runtimeRoot(env);
  const lock = join(root, '.install.lock');
  const token = `${process.pid}:${randomUUID()}`;
  const deadline = Date.now() + 30000;
  mkdirSync(root, { recursive: true });
  let descriptor;
  while (descriptor === undefined) {
    try {
      descriptor = openSync(lock, 'wx', 0o600);
      writeFileSync(descriptor, `${token}\n`);
    } catch (error) {
      if (error.code !== 'EEXIST') throw error;
      let owner = '';
      try { owner = readFileSync(lock, 'utf8').trim(); } catch {}
      const pid = Number.parseInt(owner.split(':', 1)[0], 10);
      let age = Number.POSITIVE_INFINITY;
      try { age = Date.now() - statSync(lock).mtimeMs; } catch {}
      let alive = false;
      try { if (pid > 0) { process.kill(pid, 0); alive = true; } } catch (probe) { alive = probe.code === 'EPERM'; }
      if ((!owner && age > 5000) || (owner && !alive)) { rmSync(lock, { force: true }); continue; }
      if (Date.now() >= deadline) throw new Error(`timed out waiting for Dibs runtime installation held by process ${pid || 'unknown'}`);
      sleep(50);
    }
  }
  try { return operation(); }
  finally {
    closeSync(descriptor);
    let current = '';
    try { current = readFileSync(lock, 'utf8').trim(); } catch {}
    if (current === token) unlinkSync(lock);
  }
}

function atomicWrite(path, content, mode) {
  mkdirSync(dirname(path), { recursive: true });
  const temporary = `${path}.${process.pid}.${randomUUID()}.tmp`;
  try {
    writeFileSync(temporary, content, { mode });
    chmodSync(temporary, mode);
    renameSync(temporary, path);
  } catch (error) {
    rmSync(temporary, { force: true });
    throw error;
  }
}

export function dibsRuntimeVersion(sourceRoot) {
  const manifestPath = [join(sourceRoot, '.claude-plugin', 'plugin.json'), join(sourceRoot, '.codex-plugin', 'plugin.json'), join(sourceRoot, '.dibs-runtime.json')].find(existsSync);
  if (!manifestPath) throw new Error('Dibs plugin manifest not found');
  const manifest = JSON.parse(readFileSync(manifestPath, 'utf8'));
  const version = String(manifest.version || '').replace(/\+codex\.hooks\.\d+$/, '');
  compareVersions(version, version);
  return version;
}

export function dibsRuntimePath(env = process.env) {
  return join(runtimeRoot(env), 'dibs');
}

export function publishDibsRuntime(sourceRoot, version = dibsRuntimeVersion(sourceRoot), env = process.env) {
  compareVersions(version, version);
  if (dibsRuntimeVersion(sourceRoot) !== version) throw new Error(`Dibs runtime source version does not match ${version}`);
  return withInstallLock(env, () => {
    const root = runtimeRoot(env);
    const releases = join(root, 'releases');
    const active = activeRuntime(env);
    if (active && compareVersions(active.version, version) > 0) {
      return { installed: false, version: active.version, launcher: dibsRuntimePath(env), releaseRoot: active.root };
    }
    const releaseRoot = join(releases, version);
    if (!existsSync(releaseRoot)) {
      mkdirSync(releases, { recursive: true });
      const staging = join(releases, `.staging-${version}-${process.pid}-${randomUUID()}`);
      try {
        mkdirSync(staging);
        cpSync(join(sourceRoot, 'bin'), join(staging, 'bin'), { recursive: true, errorOnExist: true });
        writeFileSync(join(staging, '.dibs-runtime.json'), `${JSON.stringify({ name: 'dibs', version }, null, 2)}\n`, { mode: 0o600 });
        chmodSync(join(staging, 'bin', 'dibs'), 0o755);
        renameSync(staging, releaseRoot);
      } catch (error) {
        rmSync(staging, { recursive: true, force: true });
        throw error;
      }
    }
    const manifest = JSON.parse(readFileSync(join(releaseRoot, '.dibs-runtime.json'), 'utf8'));
    if (manifest.version !== version) throw new Error(`Dibs runtime manifest ${manifest.version} does not match ${version}`);
    atomicWrite(dibsRuntimePath(env), launcherSource(), 0o755);
    atomicWrite(join(root, 'bash-write-targets'), parserLauncherSource(), 0o755);
    const installed = !active || compareVersions(active.version, version) < 0;
    atomicWrite(join(root, 'current.json'), `${JSON.stringify({ version, release: version }, null, 2)}\n`, 0o600);
    return { installed, version, launcher: dibsRuntimePath(env), releaseRoot };
  });
}

export function forwardToActiveDibs(sourceVersion, args = process.argv.slice(2), env = process.env) {
  if (env.DIBS_RUNTIME_ACTIVE === '1' || env.DIBS_BIN || args[0] === 'runtime') return false;
  const active = activeRuntime(env);
  if (!active || compareVersions(active.version, sourceVersion) <= 0) return false;
  const entrypoint = join(active.root, 'bin', 'dibs');
  const child = spawnSync(process.execPath, [entrypoint, ...args], { stdio: 'inherit', env: { ...env, DIBS_RUNTIME_ACTIVE: '1' } });
  if (child.error) { process.stderr.write(`dibs: could not start active runtime: ${child.error.message}\n`); process.exit(1); }
  process.exit(child.status ?? 1);
}

export function currentDibsRuntime(env = process.env) {
  return activeRuntime(env);
}
