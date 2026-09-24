import { randomUUID } from 'node:crypto';
import { chmodSync, closeSync, cpSync, existsSync, mkdirSync, openSync, readFileSync, renameSync, rmSync, statSync, unlinkSync, writeFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { dirname, join } from 'node:path';

const sleepSlot = new Int32Array(new SharedArrayBuffer(4));
const sleep = (ms) => Atomics.wait(sleepSlot, 0, 0, ms);
const rootFor = (env = process.env) => join(env.LAICLUSE_HOME || join(env.HOME || homedir(), '.laicluse'), 'git-discipline', 'runtime');

function compareVersions(left, right) {
  const parse = (value) => {
    const match = String(value).match(/^(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z.-]+))?(?:\+[0-9A-Za-z.-]+)?$/);
    if (!match) throw new Error(`invalid git-discipline version: ${value}`);
    return { numbers: match.slice(1, 4).map(Number), prerelease: match[4] };
  };
  const a = parse(left); const b = parse(right);
  for (let i = 0; i < 3; i += 1) if (a.numbers[i] !== b.numbers[i]) return a.numbers[i] - b.numbers[i];
  if (a.prerelease === b.prerelease) return 0;
  if (a.prerelease === undefined) return 1;
  if (b.prerelease === undefined) return -1;
  return a.prerelease.localeCompare(b.prerelease, 'en', { numeric: true });
}

function readActive(env) {
  try {
    const pointer = JSON.parse(readFileSync(join(rootFor(env), 'current.json'), 'utf8'));
    compareVersions(pointer.version, pointer.version);
    if (!/^[0-9A-Za-z.+-]+$/.test(pointer.release)) throw new Error('invalid git-discipline runtime pointer');
    return pointer;
  } catch (error) { if (error.code === 'ENOENT') return null; throw error; }
}

function withLock(env, fn) {
  const root = rootFor(env); const lockPath = join(root, '.install.lock'); const token = `${process.pid}:${randomUUID()}`;
  const deadline = Date.now() + 30000; mkdirSync(root, { recursive: true }); let fd;
  while (fd === undefined) {
    try { fd = openSync(lockPath, 'wx', 0o600); writeFileSync(fd, `${token}\n`); }
    catch (error) {
      if (error.code !== 'EEXIST') throw error;
      let owner = ''; try { owner = readFileSync(lockPath, 'utf8').trim(); } catch {}
      const pid = Number.parseInt(owner.split(':', 1)[0], 10); let alive = false;
      try { if (pid > 0) { process.kill(pid, 0); alive = true; } } catch (probe) { alive = probe.code === 'EPERM'; }
      let age = Infinity; try { age = Date.now() - statSync(lockPath).mtimeMs; } catch {}
      if ((!owner && age > 5000) || (owner && !alive)) { rmSync(lockPath, { force: true }); continue; }
      if (Date.now() >= deadline) throw new Error(`timed out waiting for git-discipline runtime install held by ${pid || 'unknown'}`);
      sleep(50);
    }
  }
  try { return fn(); } finally {
    closeSync(fd); let current = ''; try { current = readFileSync(lockPath, 'utf8').trim(); } catch {}
    if (current === token) unlinkSync(lockPath);
  }
}

function atomicWrite(path, content, mode) {
  mkdirSync(dirname(path), { recursive: true }); const temp = `${path}.${process.pid}.${randomUUID()}.tmp`;
  try { writeFileSync(temp, content, { mode }); chmodSync(temp, mode); renameSync(temp, path); }
  catch (error) { rmSync(temp, { force: true }); throw error; }
}

function launcherSource() {
  return `#!/usr/bin/env node
'use strict';
const { existsSync, readFileSync } = require('node:fs');
const { homedir } = require('node:os');
const { join } = require('node:path');
const { spawnSync } = require('node:child_process');
const root = join(process.env.LAICLUSE_HOME || join(process.env.HOME || homedir(), '.laicluse'), 'git-discipline', 'runtime');
let pointer;
try { pointer = JSON.parse(readFileSync(join(root, 'current.json'), 'utf8')); }
catch (error) { process.stderr.write(\`git-discipline: runtime unavailable: \${error.message}\\n\`); process.exit(1); }
const hook = process.argv[2];
if (!/^(pre-commit|commit-msg|prepare-commit-msg|post-commit|post-rewrite|pre-push)$/.test(hook || '')) { process.stderr.write('git-discipline: unknown hook\\n'); process.exit(2); }
const release = join(root, 'releases', pointer.release);
const source = join(release, 'skills', 'commit-discipline', 'git-hooks', hook);
if (!existsSync(source)) { process.stderr.write(\`git-discipline: active runtime \${pointer.version} is incomplete\\n\`); process.exit(1); }
const child = spawnSync('/bin/bash', [source, ...process.argv.slice(3)], { stdio: 'inherit', env: { ...process.env, GIT_DISCIPLINE_RUNTIME_ROOT: release } });
if (child.error) { process.stderr.write(\`git-discipline: could not start hook: \${child.error.message}\\n\`); process.exit(1); }
process.exit(child.status ?? 1);
`;
}

export function gitDisciplineRuntimeVersion(sourceRoot) {
  const manifestPath = [join(sourceRoot, '.claude-plugin', 'plugin.json'), join(sourceRoot, '.codex-plugin', 'plugin.json')].find(existsSync);
  if (!manifestPath) throw new Error('git-discipline plugin manifest not found');
  const manifest = JSON.parse(readFileSync(manifestPath, 'utf8'));
  const version = String(manifest.version || '').replace(/\+codex\.hooks\.\d+$/, '');
  compareVersions(version, version); return version;
}

export function gitDisciplineRuntimePath(env = process.env) { return join(rootFor(env), 'git-discipline-hook'); }

export function publishGitDisciplineRuntime(sourceRoot, version = gitDisciplineRuntimeVersion(sourceRoot), env = process.env) {
  if (gitDisciplineRuntimeVersion(sourceRoot) !== version) throw new Error(`runtime source does not match ${version}`);
  return withLock(env, () => {
    const root = rootFor(env); const active = readActive(env);
    if (active && compareVersions(active.version, version) > 0) return { installed: false, version: active.version, launcher: gitDisciplineRuntimePath(env) };
    const releaseRoot = join(root, 'releases', version);
    if (!existsSync(releaseRoot)) {
      const releases = join(root, 'releases'); mkdirSync(releases, { recursive: true });
      const staging = join(releases, `.staging-${version}-${process.pid}-${randomUUID()}`);
      try {
        mkdirSync(staging);
        for (const relative of ['bin', 'hooks', 'skills/commit-discipline/git-hooks']) cpSync(join(sourceRoot, relative), join(staging, relative), { recursive: true, errorOnExist: true });
        const nativeHooks = join(staging, 'skills', 'commit-discipline', 'git-hooks');
        for (const name of ['pre-commit', 'commit-msg', 'prepare-commit-msg', 'post-commit', 'post-rewrite', 'pre-push']) {
          const path = join(nativeHooks, name);
          const source = readFileSync(path, 'utf8')
            .replaceAll('__PLUGIN_INSTALL_PATH__', releaseRoot)
            .replaceAll('__NODE_EXECUTABLE__', process.execPath);
          writeFileSync(path, source, { mode: 0o755 });
        }
        writeFileSync(join(staging, '.git-discipline-runtime.json'), `${JSON.stringify({ name: 'git-discipline', version }, null, 2)}\n`, { mode: 0o600 });
        renameSync(staging, releaseRoot);
      } catch (error) { rmSync(staging, { recursive: true, force: true }); throw error; }
    }
    const launcher = gitDisciplineRuntimePath(env);
    atomicWrite(launcher, launcherSource(), 0o755);
    atomicWrite(join(root, 'current.json'), `${JSON.stringify({ version, release: version }, null, 2)}\n`, 0o600);
    return { installed: !active || compareVersions(active.version, version) < 0, version, launcher, releaseRoot };
  });
}
