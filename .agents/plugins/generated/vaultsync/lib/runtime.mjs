import { accessSync, closeSync, constants, existsSync, lstatSync, mkdirSync, openSync, readFileSync, realpathSync, readdirSync, renameSync, rmSync, statSync, unlinkSync, writeFileSync } from 'node:fs';
import { delimiter, dirname, isAbsolute, join, relative, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';
import { createHash, randomUUID } from 'node:crypto';
import { homedir, platform, userInfo } from 'node:os';
import { fileURLToPath } from 'node:url';
import { parseArgs } from 'node:util';
import { machineLauncherPath } from './machine-runtime.mjs';

export const DEFAULT_DEBOUNCE_SECONDS = 300;
export const DEFAULT_IDLE_POLL_SECONDS = 300;
export const DEFAULT_PAUSE_MINUTES = 120;
export const DIBS_PAUSE_EXTENSION_MINUTES = 60;
export const SERVICE_LABEL = 'com.laicluse.vaultsync';
const REGISTRATION_VERSION = 1;
const DAEMON_SLEEP_MS = 10000;
const MAX_REBASE_RESOLUTION_STEPS = 20;
const MAX_VERIFICATION_REPAIR_STEPS = 5;
const MAX_VERIFICATION_REPAIR_FILES = 1;
const MAX_VERIFICATION_REPAIR_FILE_BYTES = 60000;
const MAX_VERIFICATION_REPAIR_DETAIL_BYTES = 60000;
const GIT_MAX_BUFFER_BYTES = 256 * 1024 * 1024;
const LEGACY_VALIDATOR_NAME = 'legacy-verify';
const VALIDATOR_NAME_PATTERN = /^[a-z0-9][a-z0-9._-]{0,63}$/;
const REGISTRATION_LOCK_TIMEOUT_MS = 30000;
const DAEMON_SHUTDOWN_TIMEOUT_MS = 3000;

const sleepSlot = new Int32Array(new SharedArrayBuffer(4));

function sleepMs(ms) {
  Atomics.wait(sleepSlot, 0, 0, ms);
}

export function laicluseHome(env = process.env) {
  if (process.env.NODE_TEST_CONTEXT && !env.LAICLUSE_HOME && env.HOME === homedir()) {
    throw new Error('vaultsync: refusing the real laicluse home under the test runner; set LAICLUSE_HOME or HOME to a temp dir');
  }
  return env.LAICLUSE_HOME || join(env.HOME || homedir(), '.laicluse');
}

export function vaultsyncDir(env = process.env) {
  return join(laicluseHome(env), 'vaultsync');
}

export function registrationsDir(env = process.env) {
  return join(vaultsyncDir(env), 'registrations');
}

export function logsDir(env = process.env) {
  return join(vaultsyncDir(env), 'logs');
}

function ensureRuntimeDirs(env = process.env) {
  mkdirSync(registrationsDir(env), { recursive: true });
  mkdirSync(logsDir(env), { recursive: true });
}

function nowIso() {
  return new Date().toISOString();
}

function writeJsonAtomic(path, payload) {
  mkdirSync(dirname(path), { recursive: true });
  const tmp = `${path}.${process.pid}.tmp`;
  writeFileSync(tmp, `${JSON.stringify(payload, null, 2)}\n`);
  renameSync(tmp, path);
}

export function repoKey(rootRealpath) {
  return createHash('sha256').update(rootRealpath).digest('hex');
}

export function registrationPathForKey(key, env = process.env) {
  return join(registrationsDir(env), `${key}.json`);
}

export function registrationPathForRoot(rootRealpath, env = process.env) {
  return registrationPathForKey(repoKey(rootRealpath), env);
}

function processIsAlive(pid) {
  if (!Number.isInteger(pid) || pid <= 0) return false;
  try {
    process.kill(pid, 0);
    return true;
  } catch (err) {
    return err.code === 'EPERM';
  }
}

function daemonLeasePath(env = process.env) {
  return join(vaultsyncDir(env), 'daemon.lock');
}

export function acquireDaemonLease(env = process.env) {
  ensureRuntimeDirs(env);
  const path = daemonLeasePath(env);
  const token = `${process.pid}:${randomUUID()}`;
  for (let attempt = 0; attempt < 2; attempt += 1) {
    let descriptor;
    try {
      descriptor = openSync(path, 'wx', 0o600);
      writeFileSync(descriptor, `${token}\n`);
      closeSync(descriptor);
      let released = false;
      return {
        path,
        release() {
          if (released) return;
          released = true;
          let current = '';
          try { current = readFileSync(path, 'utf8').trim(); } catch {}
          if (current === token) rmSync(path, { force: true });
        },
      };
    } catch (err) {
      if (descriptor !== undefined) closeSync(descriptor);
      if (err.code !== 'EEXIST') throw err;
      let owner = '';
      try { owner = readFileSync(path, 'utf8').trim(); } catch {}
      const ownerPid = Number.parseInt(owner.split(':', 1)[0], 10);
      if (owner && processIsAlive(ownerPid)) return null;
      rmSync(path, { force: true });
    }
  }
  return null;
}

function withRegistrationLock(key, env, operation) {
  ensureRuntimeDirs(env);
  const lockPath = `${registrationPathForKey(key, env)}.lock`;
  const token = `${process.pid}:${randomUUID()}`;
  const deadline = Date.now() + REGISTRATION_LOCK_TIMEOUT_MS;
  let descriptor;
  while (descriptor === undefined) {
    try {
      descriptor = openSync(lockPath, 'wx', 0o600);
      writeFileSync(descriptor, `${token}\n`);
    } catch (err) {
      if (err.code !== 'EEXIST') throw err;
      let owner = '';
      try { owner = readFileSync(lockPath, 'utf8').trim(); } catch {}
      const ownerPid = Number.parseInt(owner.split(':', 1)[0], 10);
      const age = (() => {
	try { return Date.now() - statSync(lockPath).mtimeMs; } catch { return Number.POSITIVE_INFINITY; }
      })();
      if ((owner && !processIsAlive(ownerPid)) || (!owner && age >= 5000)) {
	rmSync(lockPath, { force: true });
	continue;
      }
      if (Date.now() >= deadline) throw new Error(`timed out waiting for Vaultsync registration update held by process ${ownerPid || 'unknown'}`);
      sleepMs(25);
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

function readJsonFile(path) {
  return JSON.parse(readFileSync(path, 'utf8'));
}

export function loadRegistrations(env = process.env) {
  const dir = registrationsDir(env);
  if (!existsSync(dir)) return [];
  return readdirSync(dir)
    .filter((entry) => entry.endsWith('.json'))
    .sort()
    .map((entry) => {
      const path = join(dir, entry);
      try {
        return { ...readJsonFile(path), path };
      } catch (err) {
        return { path, unreadable: true, error: err.message };
      }
    });
}

export function saveRegistration(registration, env = process.env) {
  return withRegistrationLock(registration.key, env, () => {
    const path = registrationPathForKey(registration.key, env);
    const current = existsSync(path) ? readJsonFile(path) : null;
    const validatorsChanged = current
      && JSON.stringify(current.validators || {}) !== JSON.stringify(registration.validators || {});
    const merged = validatorsChanged
      ? { ...registration, validators: current.validators || {}, lastValidation: current.lastValidation || null }
      : registration;
    const updated = { ...merged, updatedAt: nowIso() };
    writeJsonAtomic(path, updated);
    return updated;
  });
}

function normalizeRepairPolicy(repair, legacy = false) {
  if (legacy) return { mode: 'automatic', authority: 'diagnostics-and-changed' };
  const mode = repair?.mode;
  const authority = repair?.authority;
  if (!['none', 'automatic'].includes(mode)) throw new Error(`invalid validator repair mode: ${mode || '(missing)'}`);
  if (mode === 'none' && authority !== 'none') throw new Error('validator repair mode none requires authority none');
  if (mode === 'automatic' && !['diagnostics', 'diagnostics-and-changed'].includes(authority)) {
    throw new Error(`invalid validator repair authority: ${authority || '(missing)'}`);
  }
  return { mode, authority };
}

function normalizeNamedValidator(name, validator) {
  if (!VALIDATOR_NAME_PATTERN.test(name) || name === LEGACY_VALIDATOR_NAME) throw new Error(`invalid or reserved validator name: ${name}`);
  if (!validator || typeof validator.command !== 'string' || !validator.command.trim()) throw new Error(`validator ${name} requires a command`);
  return {
    name,
    command: validator.command,
    repair: normalizeRepairPolicy(validator.repair),
    legacy: false,
  };
}

export function configuredValidators(registration) {
  const validators = [];
  if (typeof registration.verifyCommand === 'string' && registration.verifyCommand.trim()) {
    validators.push({
      name: LEGACY_VALIDATOR_NAME,
      command: registration.verifyCommand,
      repair: normalizeRepairPolicy(null, true),
      legacy: true,
    });
  }
  for (const name of Object.keys(registration.validators || {}).sort()) {
    validators.push(normalizeNamedValidator(name, registration.validators[name]));
  }
  return validators;
}

function git(cwd, args, options = {}) {
  const result = spawnSync('git', args, {
    cwd,
    input: options.input,
    encoding: 'utf8',
    maxBuffer: GIT_MAX_BUFFER_BYTES,
    env: { ...process.env, ...(options.env || {}) },
  });
  if (result.error) {
    const err = new Error(result.error.message);
    err.exitCode = result.status || 1;
    throw err;
  }
  if (result.status !== 0 && !options.allowFailure) {
    const message = (result.stderr || result.stdout || `git ${args.join(' ')} failed`).trim();
    const err = new Error(message);
    err.exitCode = result.status || 1;
    throw err;
  }
  return result;
}

function gitOut(cwd, args, options = {}) {
  return git(cwd, args, options).stdout.trim();
}

function gitCombinedOutput(result) {
  return [result.stdout, result.stderr].filter(Boolean).join('\n');
}

function isManagedSyncGitGuard(output) {
  return /via '[^']+ sync' beheerd/.test(output) && output.includes('--no-verify');
}

function isAlreadyCheckpointed(output) {
  return /nothing to commit(?:, working tree clean)?/i.test(output);
}

function throwGitResult(result, fallbackMessage) {
  const output = gitCombinedOutput(result).trim();
  const err = new Error(output || fallbackMessage);
  err.exitCode = result.status || 1;
  throw err;
}

export function resolveGitRoot(dir, env = process.env) {
  const requested = resolve(dir || env.PWD || process.cwd());
  const result = spawnSync('git', ['-C', requested, 'rev-parse', '--show-toplevel'], { encoding: 'utf8' });
  if (result.status !== 0) {
    throw new Error(`not inside a Git worktree: ${requested}`);
  }
  return realpathSync(result.stdout.trim());
}

function resolveGitCommonDir(root) {
  const raw = gitOut(root, ['rev-parse', '--git-common-dir']);
  return realpathSync(resolve(root, raw));
}

function branchName(root) {
  const branch = gitOut(root, ['rev-parse', '--abbrev-ref', 'HEAD']);
  if (branch === 'HEAD') throw new Error('detached HEAD is not supported');
  return branch;
}

function upstreamName(root) {
  const result = git(root, ['rev-parse', '--abbrev-ref', '--symbolic-full-name', '@{u}'], { allowFailure: true });
  if (result.status !== 0) {
    throw new Error('current branch has no upstream');
  }
  return result.stdout.trim();
}

function optionalUpstreamName(root) {
  const result = git(root, ['rev-parse', '--abbrev-ref', '--symbolic-full-name', '@{u}'], { allowFailure: true });
  if (result.status !== 0) return null;
  return result.stdout.trim();
}

function statusPorcelain(root) {
  return gitOut(root, ['status', '--porcelain=v1', '-z']);
}

function isDirty(root) {
  return statusPorcelain(root).length > 0;
}

function changedPaths(root, staged = false) {
  const args = staged
    ? ['diff', '--cached', '--name-only', '-z']
    : ['status', '--porcelain=v1', '-z'];
  const raw = gitOut(root, args);
  if (!raw) return [];
  if (staged) return raw.split('\0').filter(Boolean);
  const entries = raw.split('\0').filter(Boolean);
  return entries.map((entry) => entry.slice(3)).filter(Boolean);
}

function addedDiffContent(diff) {
  return String(diff || '')
    .split('\n')
    .filter((line) => line.startsWith('+') && !line.startsWith('+++'))
    .map((line) => line.slice(1))
    .join('\n');
}

function localHomeLiterals(env = process.env) {
  const configuredHome = env.HOME || homedir();
  const literals = new Set([configuredHome, resolve(configuredHome)]);
  for (const literal of [...literals]) {
    literals.add(literal.replace(/\\/g, '/'));
    literals.add(literal.replace(/\//g, '\\'));
  }
  return [...literals].filter((literal) => literal.length > 1);
}

function assertPortableContent(content, env = process.env) {
  if (localHomeLiterals(env).some((literal) => content.includes(literal))) {
    throw new Error('vaultsync: refusing machine-local home path in shared Git content; use PATH, an environment override, or local configuration');
  }
}

function assertPortableOutgoingCommits(root, env = process.env) {
  if (!optionalUpstreamName(root)) return;
  const messages = gitOut(root, ['log', '--format=%B', '@{u}..HEAD']);
  const patches = gitOut(root, ['diff', '--unified=0', '@{u}...HEAD']);
  assertPortableContent(messages, env);
  assertPortableContent(addedDiffContent(patches), env);
}

function aheadBehind(root) {
  const result = git(root, ['rev-list', '--left-right', '--count', 'HEAD...@{u}'], { allowFailure: true });
  if (result.status !== 0) return { ahead: 0, behind: 0, known: false };
  const [ahead, behind] = result.stdout.trim().split(/\s+/).map((n) => Number(n));
  return { ahead: ahead || 0, behind: behind || 0, known: true };
}

export function preflightRepository(dir, env = process.env) {
  const requestedCwd = resolve(dir || env.PWD || process.cwd());
  const rootRealpath = resolveGitRoot(requestedCwd, env);
  const branch = branchName(rootRealpath);
  const upstream = optionalUpstreamName(rootRealpath);
  const gitCommonDir = resolveGitCommonDir(rootRealpath);
  return {
    requestedCwd,
    rootRealpath,
    gitCommonDir,
    key: repoKey(rootRealpath),
    branch,
    upstream,
  };
}

function isExecutable(path) {
  try {
    accessSync(path, constants.X_OK);
    return true;
  } catch {
    return false;
  }
}

export function findDibsBin(env = process.env) {
  return findDibsBinForRegistration(null, env);
}

function childDirectoryNames(path) {
  try {
    return readdirSync(path, { withFileTypes: true })
      .filter((entry) => entry.isDirectory())
      .map((entry) => entry.name);
  } catch {
    return [];
  }
}

function dibsPluginCacheRoots(env = process.env) {
  const home = env.HOME || homedir();
  return [
    join(home, '.codex', 'plugins', 'cache'),
    join(home, '.claude', 'plugins', 'cache'),
  ];
}

function versionSegmentForDibsPath(path) {
  const parts = String(path).split(/[\\/]/);
  return parts[parts.length - 3] || '';
}

function compareVersionSegments(left, right) {
  const leftMatch = /^(\d+)\.(\d+)\.(\d+)(?:[-+].*)?$/.exec(left);
  const rightMatch = /^(\d+)\.(\d+)\.(\d+)(?:[-+].*)?$/.exec(right);
  if (leftMatch && rightMatch) {
    for (let i = 1; i <= 3; i += 1) {
      const diff = Number(leftMatch[i]) - Number(rightMatch[i]);
      if (diff !== 0) return diff;
    }
    return 0;
  }
  if (leftMatch) return 1;
  if (rightMatch) return -1;
  return left.localeCompare(right);
}

function dibsCandidatesInCacheRoot(cacheRoot) {
  return childDirectoryNames(cacheRoot).flatMap((marketplace) => {
    const dibsRoot = join(cacheRoot, marketplace, 'dibs');
    return childDirectoryNames(dibsRoot).map((version) => join(dibsRoot, version, 'bin', 'dibs'));
  });
}

function dibsPluginCacheCandidates(env = process.env) {
  const candidates = dibsPluginCacheRoots(env).flatMap(dibsCandidatesInCacheRoot);
  return candidates.sort((left, right) => {
    const byVersion = compareVersionSegments(versionSegmentForDibsPath(right), versionSegmentForDibsPath(left));
    if (byVersion !== 0) return byVersion;
    return left.localeCompare(right);
  });
}

function isPluginCacheDibsPath(path) {
  const normalized = String(path).replace(/\\/g, '/');
  return normalized.includes('/plugins/cache/') && normalized.includes('/dibs/') && normalized.endsWith('/bin/dibs');
}

function findDibsBinForRegistration(registration, env = process.env) {
  const candidates = [];
  if (env.DIBS_BIN) candidates.push(env.DIBS_BIN);
  candidates.push(...dibsPluginCacheCandidates(env));
  for (const dir of (env.PATH || '').split(':').filter(Boolean)) {
    candidates.push(join(dir, 'dibs'));
  }
  if (registration?.dibsBin) candidates.push(registration.dibsBin);
  const seen = new Set();
  for (const candidate of candidates) {
    if (!candidate || seen.has(candidate)) continue;
    seen.add(candidate);
    if (isExecutable(candidate)) return candidate;
  }
  return null;
}

function registrationDibsBinForInstall(dibsBin) {
  if (!dibsBin || isPluginCacheDibsPath(dibsBin)) return null;
  return dibsBin;
}

function runDibs(registration, command, args = [], env = process.env) {
  const dibsBin = findDibsBinForRegistration(registration, env);
  if (!dibsBin) throw new Error('dibs executable not found; put dibs on PATH or set DIBS_BIN');
  const result = spawnSync(dibsBin, [command, registration.rootRealpath, '--json', ...args], {
    encoding: 'utf8',
    env,
  });
  if (result.error) {
    const err = new Error(`failed to start dibs at ${dibsBin}: ${result.error.message}`);
    err.exitCode = result.status || 1;
    throw err;
  }
  let json = null;
  try {
    json = result.stdout ? JSON.parse(result.stdout) : null;
  } catch {
    json = null;
  }
  if (result.status !== 0) {
    const err = new Error((json && json.error) || (result.stderr || '').trim() || (result.stdout || '').trim() || `dibs ${command} failed`);
    err.exitCode = result.status || 1;
    err.result = json;
    throw err;
  }
  return json;
}

function isHeldByThisProcess(checkResult) {
  return checkResult?.state === 'held'
    && checkResult.holder?.pid === process.pid
    && checkResult.holder?.agent === 'vaultsync';
}

function externalDibsLockActive(registration, env = process.env) {
  const result = runDibs(registration, 'check', [], env);
  return result.state === 'held' && !isHeldByThisProcess(result);
}

function claimDibs(registration, env = process.env) {
  return runDibs(registration, 'claim', [
    '--pid', String(process.pid),
    '--agent', 'vaultsync',
    '--session', `vaultsync-${registration.key}`,
    '--owner', registration.key,
    '--description', 'vaultsync auto-commit cycle',
  ], env);
}

function releaseDibs(registration, claimResult, env = process.env) {
  if (claimResult?.state === 'excluded') return null;
  const args = ['--pid', String(process.pid)];
  if (claimResult?.holder?.nonce) args.push('--nonce', claimResult.holder.nonce);
  return runDibs(registration, 'release', args, env);
}

function visualEvidenceTrailer(paths, message = '') {
  if (/^Visual:\s*\S/im.test(message)) return [];
  const viewer = paths.find((path) => path.toLowerCase().endsWith('.html'));
  return viewer ? [`Visual: ${viewer}`] : [];
}

export const COMMIT_MESSAGE_DIFF_FILE_LIMIT = 64 * 1024;
export const COMMIT_MESSAGE_DIFF_TOTAL_LIMIT = 256 * 1024;

function splitDiffSections(diff) {
  const sections = [];
  let current = null;
  for (const line of String(diff || '').split('\n')) {
    if (line.startsWith('diff --git ')) {
      current = { header: [line], hunks: [] };
      sections.push(current);
      continue;
    }
    if (!current) {
      current = { header: [], hunks: [] };
      sections.push(current);
    }
    if (current.hunks.length === 0 && !line.startsWith('@@')) current.header.push(line);
    else current.hunks.push(line);
  }
  return sections;
}

function omittedHunks(section) {
  const hunks = section.hunks.join('\n');
  const bytes = Buffer.byteLength(hunks, 'utf8');
  return { ...section, hunks: [`[vaultsync: ${bytes} bytes of hunks omitted from the commit-message prompt]`], omitted: true };
}

function sectionText(section) {
  return [...section.header, ...section.hunks].join('\n');
}

function hunkBytes(section) {
  return section.omitted ? 0 : Buffer.byteLength(section.hunks.join('\n'), 'utf8');
}

export function commitMessageDiff(diff, limits = {}) {
  const fileLimit = limits.fileLimit ?? COMMIT_MESSAGE_DIFF_FILE_LIMIT;
  const totalLimit = limits.totalLimit ?? COMMIT_MESSAGE_DIFF_TOTAL_LIMIT;
  const text = String(diff || '');
  if (Buffer.byteLength(text, 'utf8') <= Math.min(fileLimit, totalLimit)) return text;
  let sections = splitDiffSections(text).map((section) => (hunkBytes(section) > fileLimit ? omittedHunks(section) : section));
  const totalBytes = () => Buffer.byteLength(sections.map(sectionText).join('\n'), 'utf8');
  while (totalBytes() > totalLimit) {
    const largest = sections.reduce((best, section) => (hunkBytes(section) > hunkBytes(best) ? section : best), sections[0]);
    if (!largest || hunkBytes(largest) === 0) break;
    sections = sections.map((section) => (section === largest ? omittedHunks(section) : section));
  }
  return sections.map(sectionText).join('\n');
}

export function fallbackCommitMessage(reason = 'debounce', paths = [], diff = '') {
  const fingerprint = createHash('sha256').update(diff || `${reason}\0${paths.join('\0')}`).digest('hex').slice(0, 10);
  const pathCount = paths.length === 1 ? '1 changed vault path' : `${paths.length} changed vault paths`;
  return [
    'Sync vault content',
    '',
    `Vaultsync captured staged change set ${fingerprint} before remote`,
    `reconciliation. It contains ${pathCount}.`,
    'This keeps the vault state durable and ready for the next sync cycle.',
    '',
    'Tests: n/a (docs-only)',
    'Slice: docs-only',
    'Red-then-green: n/a (no executable behaviour changed)',
    ...visualEvidenceTrailer(paths),
    `Vaultsync-Reason: ${reason}`,
  ].join('\n');
}

function withoutCommitTrailerBlock(message) {
  const lines = String(message || '').split('\n');
  let cursor = lines.length - 1;
  while (cursor >= 0 && !lines[cursor].trim()) cursor -= 1;
  let foundTrailer = false;
  while (cursor >= 0) {
    const line = lines[cursor];
    if (/^[ \t]+\S/.test(line)) {
      cursor -= 1;
      continue;
    }
    if (/^[A-Za-z0-9-]+:\s*\S/.test(line)) {
      foundTrailer = true;
      cursor -= 1;
      continue;
    }
    break;
  }
  if (!foundTrailer || (cursor >= 0 && lines[cursor].trim())) return message;
  return lines.slice(0, cursor + 1).join('\n').trimEnd();
}

function withoutVaultsyncTrailers(message) {
  const filtered = message
    .split('\n')
    .filter((line) => !/^(Tests|Slice|Red-then-green|Vaultsync-Reason):\s*/i.test(line.trim()))
    .join('\n');
  return withoutCommitTrailerBlock(filtered)
    .replace(/\n{3,}/g, '\n\n')
    .trim();
}

function normalizeCommitMessage(message, reason, paths = [], diff = '') {
  const cleaned = String(message || '').replace(/\r\n/g, '\n').trim();
  if (!cleaned) return fallbackCommitMessage(reason, paths, diff);
  const content = withoutVaultsyncTrailers(cleaned);
  const [subject, ...rest] = content.split('\n');
  const body = rest.join('\n').trim();
  return [
    subject.trim() || 'Sync vault content',
    '',
    body || 'This sync records the local vault changes before reconciling with the remote truth.',
    '',
    'Tests: n/a (docs-only)',
    'Slice: docs-only',
    'Red-then-green: n/a (no executable behaviour changed)',
    ...visualEvidenceTrailer(paths, cleaned),
    `Vaultsync-Reason: ${reason}`,
  ].join('\n');
}

export function commitNarrative(message) {
  const [, ...body] = withoutVaultsyncTrailers(String(message || '').replace(/\r\n/g, '\n')).split('\n');
  return body
    .filter((line) => !/^Visual:\s*/i.test(line.trim()))
    .join(' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function repeatsRecentCommitNarrative(root, message, limit = 5) {
  const narrative = commitNarrative(message);
  if (!narrative) return false;
  const result = git(root, ['log', `-${limit}`, '--format=%B%x00'], { allowFailure: true });
  if (result.status !== 0) return false;
  return result.stdout
    .split('\0')
    .some((recent) => commitNarrative(recent) === narrative);
}

function shellCommand(command, { cwd, input, env = process.env, timeoutMs = 120000 } = {}) {
  const result = spawnSync(command, {
    cwd,
    input,
    env,
    shell: true,
    encoding: 'utf8',
    timeout: timeoutMs,
    maxBuffer: 20 * 1024 * 1024,
  });
  if (result.error) {
    const err = new Error(result.error.message);
    err.exitCode = result.status || 1;
    throw err;
  }
  return result;
}

function redactDiagnostic(value) {
  return String(value || '')
    .replace(/\b(Bearer)\s+\S+/gi, '$1 [redacted]')
    .replace(/\b([A-Z][A-Z0-9_]*(?:TOKEN|SECRET|PASSWORD|CREDENTIAL|API_KEY)[A-Z0-9_]*)\s*=\s*\S+/gi, '$1=[redacted]')
    .replace(/("[^"]*(?:token|secret|password|credential|api[_-]?key)[^"]*"\s*:\s*")[^"]*"/gi, '$1[redacted]"')
    .replace(/([?&](?:access_token|refresh_token|api_key)=)[^&\s]+/gi, '$1[redacted]')
    .replace(/\b(?:gh[opusr]_[A-Za-z0-9_]{20,}|sk-[A-Za-z0-9_-]{16,})\b/g, '[redacted]')
    .replace(/\beyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\b/g, '[redacted]')
    .replace(/([a-z][a-z0-9+.-]*:\/\/)[^\s/@:]+:[^\s/@]+@/gi, '$1[redacted]@')
    .slice(0, 4000)
    .trim();
}

function providerFailure(result) {
  const detail = redactDiagnostic([result.stderr, result.stdout].filter(Boolean).join('\n')) || 'Configured provider command failed';
  const structured = detail.split('\n').map((line) => {
    try {
      return JSON.parse(line);
    } catch {
      return null;
    }
  }).find((entry) => entry?.protocol === 'vaultsync.llm.error.v1');
  const oauthExpired = /OAuth session expired/i.test(detail);
  const err = new Error(redactDiagnostic(structured?.message) || (oauthExpired ? 'OAuth session expired.' : detail.split('\n')[0]));
  err.phase = 'commit-message-generation';
  err.detail = detail;
  err.recovery = redactDiagnostic(structured?.recovery) || (oauthExpired ? 'Re-authenticate the configured provider and retry sync.' : null);
  err.exitCode = result.status || 1;
  return err;
}

function callLlm(registration, payload, { mandatory = false, timeoutMs = 120000 } = {}) {
  if (!registration.llmCommand) {
    if (mandatory) throw new Error('llmCommand is required for this vaultsync task');
    return null;
  }
  const result = shellCommand(registration.llmCommand, {
    cwd: registration.rootRealpath,
    input: `${JSON.stringify(payload)}\n`,
    timeoutMs,
  });
  if (result.status !== 0) {
    if (!mandatory) throw providerFailure(result);
    const err = new Error(redactDiagnostic(result.stderr || result.stdout) || 'LLM command failed');
    err.detail = redactDiagnostic([result.stderr, result.stdout].filter(Boolean).join('\n'));
    err.exitCode = result.status || 1;
    throw err;
  }
  try {
    return JSON.parse(result.stdout);
  } catch (err) {
    if (mandatory) throw new Error(`LLM command returned invalid JSON: ${err.message}`);
    return null;
  }
}

export function probeLlmCommand(llmCommand, rootRealpath = process.cwd()) {
  const registration = { llmCommand, rootRealpath };
  const result = callLlm(registration, {
    protocol: 'vaultsync.llm.v1',
    task: 'resolve_conflict',
    repository: { root: rootRealpath },
    path: 'probe.md',
    policy: {
      remoteTruth: true,
      sidecarPattern: '<name>.conflict-<extra-info>.md',
    },
    content: [
      '<<<<<<< HEAD',
      'Local draft line.',
      '=======',
      'Remote truth line.',
      '>>>>>>> upstream',
      '',
    ].join('\n'),
  }, { mandatory: true });
  if (!result || typeof result.resolved !== 'string' || result.resolved.includes('<<<<<<<')) {
    throw new Error('LLM command probe failed: resolve_conflict must return JSON with a resolved string and no conflict markers');
  }
  return true;
}

function llmCommitMessage(registration, diff, paths, reason) {
  try {
    const result = callLlm(registration, {
      protocol: 'vaultsync.llm.v1',
      task: 'commit_message',
      repository: {
	root: registration.rootRealpath,
	branch: safeGitInfo(registration.rootRealpath, branchName),
	upstream: safeGitInfo(registration.rootRealpath, upstreamName),
      },
      reason,
      paths,
      diff,
      requirements: {
	language: 'English',
	substantive: true,
	includeBody: true,
	includeSliceTrailer: true,
      },
    }, { mandatory: false });
    if (!result || typeof result.message !== 'string') return { message: fallbackCommitMessage(reason, paths, diff), failure: null };
    const message = normalizeCommitMessage(result.message, reason, paths, diff);
    return {
      message: repeatsRecentCommitNarrative(registration.rootRealpath, message)
	? fallbackCommitMessage(reason, paths, diff)
	: message,
      failure: null,
    };
  } catch (err) {
    return { message: fallbackCommitMessage(reason, paths, diff), failure: err };
  }
}

function safeGitInfo(root, fn) {
  try {
    return fn(root);
  } catch {
    return null;
  }
}

function resolveConflictFile(registration, path) {
  const fullPath = join(registration.rootRealpath, path);
  const content = readFileSync(fullPath, 'utf8');
  const result = callLlm(registration, {
    protocol: 'vaultsync.llm.v1',
    task: 'resolve_conflict',
    repository: {
      root: registration.rootRealpath,
      branch: safeGitInfo(registration.rootRealpath, branchName),
      upstream: safeGitInfo(registration.rootRealpath, upstreamName),
    },
    path,
    policy: {
      remoteTruth: true,
      sidecarPattern: '<name>.conflict-<extra-info>.md',
    },
    content,
  }, { mandatory: true, timeoutMs: 240000 });
  if (!result || typeof result.resolved !== 'string' || result.resolved.includes('<<<<<<<')) {
    throw new Error(`LLM did not resolve conflict markers in ${path}`);
  }
  writeFileSync(fullPath, result.resolved);
  git(registration.rootRealpath, ['add', '--', path]);
}

function conflictedPaths(root) {
  const raw = gitOut(root, ['diff', '--name-only', '--diff-filter=U', '-z']);
  return raw.split('\0').filter(Boolean);
}

function rebaseInProgress(root) {
  const common = resolveGitCommonDir(root);
  return existsSync(join(common, 'rebase-merge')) || existsSync(join(common, 'rebase-apply'));
}

function abortRebase(root) {
  if (!rebaseInProgress(root)) return;
  git(root, ['rebase', '--abort'], { allowFailure: true });
}

function pullRebaseWithLlm(registration) {
  const root = registration.rootRealpath;
  const pull = git(root, ['pull', '--rebase'], { allowFailure: true });
  if (pull.status === 0) return { rebased: true, conflictsResolved: 0 };
  if (!rebaseInProgress(root)) {
    const err = new Error((pull.stderr || pull.stdout || 'git pull --rebase failed').trim());
    err.exitCode = pull.status || 1;
    throw err;
  }
  let resolved = 0;
  try {
    for (let step = 0; step < MAX_REBASE_RESOLUTION_STEPS; step++) {
      const paths = conflictedPaths(root);
      if (paths.length === 0) {
        const cont = git(root, ['rebase', '--continue'], {
          allowFailure: true,
          env: { GIT_EDITOR: 'true' },
        });
        if (cont.status === 0) return { rebased: true, conflictsResolved: resolved };
        if (!rebaseInProgress(root)) {
          const err = new Error((cont.stderr || cont.stdout || 'git rebase --continue failed').trim());
          err.exitCode = cont.status || 1;
          throw err;
        }
        continue;
      }
      for (const path of paths) {
        resolveConflictFile(registration, path);
        resolved += 1;
      }
      const cont = git(root, ['rebase', '--continue'], {
        allowFailure: true,
        env: { GIT_EDITOR: 'true' },
      });
      if (cont.status === 0) return { rebased: true, conflictsResolved: resolved };
    }
    throw new Error('rebase did not complete after repeated conflict-resolution attempts');
  } catch (err) {
    abortRebase(root);
    throw err;
  }
}

function validatorFailure(validator, result, cause = null) {
  const err = new Error(`verification command failed: ${validator.command}`);
  const detail = cause
    ? String(cause.message || cause)
    : [result.stdout, result.stderr].filter(Boolean).join('\n').trim();
  err.detail = detail.slice(0, 4000);
  err.repairDetail = detail.slice(0, MAX_VERIFICATION_REPAIR_DETAIL_BYTES);
  err.exitCode = cause?.exitCode || result?.status || 1;
  err.validatorName = validator.name;
  return err;
}

function executeValidator(registration, validator) {
  let result;
  try {
    result = shellCommand(validator.command, {
      cwd: registration.rootRealpath,
      timeoutMs: 10 * 60 * 1000,
    });
  } catch (cause) {
    const error = validatorFailure(validator, null, cause);
    return {
      validator,
      error,
      outcome: { name: validator.name, state: 'failed', exitCode: error.exitCode, detail: redactDiagnostic(error.detail) || null },
    };
  }
  if (result.status !== 0) {
    const error = validatorFailure(validator, result);
    return {
      validator,
      error,
      outcome: { name: validator.name, state: 'failed', exitCode: error.exitCode, detail: redactDiagnostic(error.detail) || null },
    };
  }
  return {
    validator,
    error: null,
    outcome: { name: validator.name, state: 'passed', exitCode: 0, detail: null },
  };
}

function validationFailure(executions, validation) {
  const failures = executions.filter((execution) => execution.error);
  const primary = failures[0].error;
  if (failures.length > 1) {
    primary.detail = failures.map((failure) => {
      const detail = failure.error.detail || failure.error.message;
      return `[${failure.validator.name}] ${detail}`;
    }).join('\n');
  }
  primary.validation = validation;
  primary.validatorFailures = failures;
  primary.secondary = failures.slice(1).map((failure) => ({
    phase: `verification:${failure.validator.name}`,
    message: failure.error.message,
    detail: failure.error.detail || null,
  }));
  return primary;
}

function runVerification(registration) {
  const validators = configuredValidators(registration);
  if (validators.length === 0) return { skipped: true, passed: true, validators: [] };
  const executions = validators.map((validator) => executeValidator(registration, validator));
  const validation = {
    skipped: false,
    passed: executions.every((execution) => !execution.error),
    validators: executions.map((execution) => execution.outcome),
  };
  if (!validation.passed) throw validationFailure(executions, validation);
  return validation;
}

function runPreSync(registration) {
  if (!registration.preSyncCommand) return { skipped: true };
  const snapshot = captureGitVisibleWorktree(registration.rootRealpath);
  let result;
  try {
    result = shellCommand(registration.preSyncCommand, {
      cwd: registration.rootRealpath,
      timeoutMs: registration.preSyncTimeoutMs || 10 * 60 * 1000,
    });
  } catch (cause) {
    restoreGitVisibleWorktree(registration.rootRealpath, snapshot);
    const err = new Error(`pre-sync command failed: ${registration.preSyncCommand}`);
    err.detail = String(cause.message || cause).slice(0, 4000);
    err.exitCode = cause.exitCode || 1;
    throw err;
  }
  if (result.status !== 0) {
    restoreGitVisibleWorktree(registration.rootRealpath, snapshot);
    const err = new Error(`pre-sync command failed: ${registration.preSyncCommand}`);
    const detail = [result.stdout, result.stderr].filter(Boolean).join('\n').trim();
    err.detail = detail.slice(0, 4000);
    err.exitCode = result.status || 1;
    throw err;
  }
  return { skipped: false };
}

function captureGitVisibleWorktree(root) {
  const indexTree = gitOut(root, ['write-tree']);
  let worktreeTree;
  try {
    git(root, ['add', '-A']);
    worktreeTree = gitOut(root, ['write-tree']);
  } finally {
    git(root, ['read-tree', indexTree]);
  }
  return { indexTree, worktreeTree };
}

function restoreGitVisibleWorktree(root, snapshot) {
  const changed = gitOut(root, ['diff', '--name-only', '-z', snapshot.worktreeTree])
    .split('\0')
    .filter(Boolean);
  const untracked = gitOut(root, ['ls-files', '--others', '--exclude-standard', '-z'])
    .split('\0')
    .filter(Boolean);
  for (const path of new Set([...changed, ...untracked])) {
    const existsInSnapshot = git(root, ['cat-file', '-e', `${snapshot.worktreeTree}:${path}`], { allowFailure: true }).status === 0;
    if (!existsInSnapshot) rmSync(join(root, path), { force: true });
  }
  try {
    git(root, ['checkout', snapshot.worktreeTree, '--', '.']);
  } finally {
    git(root, ['read-tree', snapshot.indexTree]);
  }
}

function isTextRepairPath(path) {
  return /\.(md|markdown|txt|csv|tsv|json|ya?ml)$/i.test(path);
}

function safeRelativePath(root, path) {
  const abs = isAbsolute(path) ? path : join(root, path);
  const rel = relative(root, abs);
  if (!rel || rel.startsWith('..') || isAbsolute(rel)) return null;
  return rel;
}

function parseVerifierPaths(root, detail = '') {
  const out = [];
  const rootPrefix = `${root}/`;
  for (const line of String(detail).split('\n')) {
    const absoluteStart = line.indexOf(rootPrefix);
    const candidateText = absoluteStart >= 0 ? line.slice(absoluteStart + rootPrefix.length) : line.trimStart();
    if (absoluteStart < 0 && isAbsolute(candidateText)) continue;
    const match = candidateText.match(/^(.+?\.(?:md|markdown|txt|csv|tsv|json|ya?ml))(?=:\d*(?::\d*)?(?::|\s)|:|\s|$)/i);
    const path = match ? safeRelativePath(root, match[1]) : null;
    if (path) out.push(path);
  }
  return out;
}

function readRepairCandidate(root, path) {
  const rel = safeRelativePath(root, path);
  if (!rel || !isTextRepairPath(rel)) return null;
  const full = join(root, rel);
  if (!existsSync(full)) return null;
  const stat = lstatSync(full);
  if (!stat.isFile() || stat.isSymbolicLink() || realpathSync(full) !== resolve(full)) return null;
  const content = readFileSync(full, 'utf8');
  if (Buffer.byteLength(content, 'utf8') > MAX_VERIFICATION_REPAIR_FILE_BYTES) return null;
  return { path: rel, content };
}

function verificationRepairCandidates(registration, validator, verificationError, cyclePaths = []) {
  const root = registration.rootRealpath;
  const includeChanged = validator.repair.authority === 'diagnostics-and-changed';
  const cycle = new Set((includeChanged ? cyclePaths : []).map((p) => safeRelativePath(root, p)).filter(Boolean));
  const verifier = parseVerifierPaths(root, verificationError.repairDetail || verificationError.detail);
  const candidates = [];
  const add = (path) => {
    const candidate = readRepairCandidate(root, path);
    if (!candidate || candidates.some((c) => c.path === candidate.path)) return;
    candidates.push(candidate);
  };
  for (const path of verifier) {
    add(path);
  }
  for (const path of cycle) add(path);
  return candidates.slice(0, MAX_VERIFICATION_REPAIR_FILES);
}

function verifierDetailForFiles(root, detail, files) {
  const text = String(detail || '');
  const absolutePaths = files.map((file) => `${root}/${file.path}`);
  const lines = text.split('\n').filter((line) => absolutePaths.some((path) => line.includes(path)));
  return (lines.length > 0 ? lines.join('\n') : text).slice(0, MAX_VERIFICATION_REPAIR_DETAIL_BYTES);
}

function mechanicalVerifierRepairs(registration, validator, verificationError) {
  const root = registration.rootRealpath;
  const byPath = new Map();
  const detail = verificationError.repairDetail || verificationError.detail || '';
  for (const line of String(detail).split('\n')) {
    const path = parseVerifierPaths(root, line)[0];
    if (!path) continue;
    const current = byPath.get(path) || { trailingWhitespace: false, finalNewline: false, blankRuns: false };
    if (line.includes('trailing whitespace')) current.trailingWhitespace = true;
    if (line.includes('geen afsluitende newline')) current.finalNewline = true;
    if (line.includes('drie of meer opeenvolgende lege regels')) current.blankRuns = true;
    byPath.set(path, current);
  }
  const paths = [];
  for (const [path, fixes] of byPath) {
    const candidate = validator.repair.authority === 'none' ? null : readRepairCandidate(root, path);
    if (!candidate) continue;
    let content = candidate.content;
    if (fixes.trailingWhitespace) content = content.replace(/[ \t]+$/gm, '');
    if (fixes.blankRuns) content = content.replace(/\n{3,}/g, '\n\n');
    if (fixes.finalNewline && !content.endsWith('\n')) content = `${content}\n`;
    if (content === candidate.content) continue;
    writeFileSync(join(root, candidate.path), content);
    paths.push(candidate.path);
  }
  return { repaired: paths.length > 0, kind: 'mechanical', paths };
}

function repairVerificationFailure(registration, validator, verificationError, cyclePaths, reason) {
  const files = verificationRepairCandidates(registration, validator, verificationError, cyclePaths);
  if (files.length === 0) return { repaired: false, reason: 'no-repair-candidates', paths: [] };
  const allowed = new Set(files.map((file) => file.path));
  const repairDetail = verifierDetailForFiles(
    registration.rootRealpath,
    verificationError.repairDetail || verificationError.detail || '',
    files,
  );
  const result = callLlm(registration, {
    protocol: 'vaultsync.llm.v1',
    task: 'repair_verifier',
    repository: {
      root: registration.rootRealpath,
      branch: safeGitInfo(registration.rootRealpath, branchName),
      upstream: safeGitInfo(registration.rootRealpath, upstreamName),
    },
    reason,
    verifier: {
      name: validator.name,
      command: validator.command,
      message: verificationError.message,
      detail: repairDetail,
    },
    policy: {
      modifyOnlyIncludedFiles: true,
      preserveUserMeaning: true,
      noSecrets: true,
      noToolAttribution: true,
    },
    files,
  }, { mandatory: true, timeoutMs: 240000 });
  const repairs = Array.isArray(result?.repairs) ? result.repairs : [];
  const written = [];
  for (const repair of repairs) {
    if (!repair || typeof repair.path !== 'string' || typeof repair.content !== 'string') continue;
    const rel = safeRelativePath(registration.rootRealpath, repair.path);
    if (!rel || !allowed.has(rel) || !isTextRepairPath(rel)) continue;
    writeFileSync(join(registration.rootRealpath, rel), repair.content);
    written.push(rel);
  }
  return { repaired: written.length > 0, paths: written, validator: validator.name };
}

function verifyWithRepairs(registration, cyclePaths, reason, env = process.env) {
  const repairs = [];
  for (let step = 0; step <= MAX_VERIFICATION_REPAIR_STEPS; step += 1) {
    try {
      const verification = runVerification(registration);
      if (repairs.length > 0) verification.repairs = repairs;
      return { verification, repaired: repairs.length > 0 };
    } catch (err) {
      if (step === MAX_VERIFICATION_REPAIR_STEPS) throw err;
      const roundRepairs = [];
      for (const failure of err.validatorFailures || []) {
	const { validator, error } = failure;
	if (validator.repair.mode !== 'automatic') continue;
	let repair = mechanicalVerifierRepairs(registration, validator, error);
	if (!repair.repaired) repair = repairVerificationFailure(registration, validator, error, cyclePaths, reason);
	if (repair.repaired) roundRepairs.push({ ...repair, validator: validator.name });
      }
      if (roundRepairs.length === 0) throw err;
      const repairCommit = commitDirtyState(registration, `${reason}-verifier-repair`, env);
      if (!repairCommit.committed) throw err;
      repairs.push(...roundRepairs);
    }
  }
  throw new Error('verification repair loop exhausted unexpectedly');
}

function pushCurrentBranch(root, env = process.env) {
  assertPortableOutgoingCommits(root, env);
  const push = git(root, ['push'], { allowFailure: true });
  if (push.status === 0) return push;
  const output = gitCombinedOutput(push);
  if (!isManagedSyncGitGuard(output)) throwGitResult(push, 'git push failed');
  return git(root, ['push', '--no-verify']);
}

function sshHostForRemote(url) {
  if (url.startsWith('ssh://')) {
    try { return new URL(url).hostname || null; } catch { return null; }
  }
  const match = /^(?:[^@/:\s]+@)?(\[[^\]]+\]|[^/:\s]+):.+/.exec(url);
  return match ? match[1].replace(/^\[|\]$/g, '') : null;
}

function configuredRemoteUrl(root, env = process.env) {
  const branch = branchName(root);
  const remote = gitOut(root, ['config', '--get', `branch.${branch}.remote`], { env, allowFailure: true });
  if (!remote || remote === '.') return null;
  const result = git(root, ['remote', 'get-url', remote], { env, allowFailure: true });
  return result.status === 0 ? result.stdout.trim() : null;
}

function resolvedIdentityAgent(host, env = process.env) {
  const config = spawnSync('ssh', ['-G', host], { encoding: 'utf8', env, timeout: 5000 });
  if (config.error || config.status !== 0) return null;
  const value = config.stdout.match(/^identityagent\s+(.+)$/mi)?.[1]?.trim();
  if (!value || value === 'none') return null;
  if (value === 'SSH_AUTH_SOCK' || value === '$SSH_AUTH_SOCK') return env.SSH_AUTH_SOCK || null;
  if (value.startsWith('~/')) return join(env.HOME || homedir(), value.slice(2));
  return isAbsolute(value) ? value : null;
}

function remoteAuthenticationAvailability(root, env = process.env) {
  const url = configuredRemoteUrl(root, env);
  const host = url ? sshHostForRemote(url) : null;
  if (!host) return { available: true };
  const socket = resolvedIdentityAgent(host, env);
  if (!socket) return { available: true };
  const identities = spawnSync('ssh-add', ['-l'], {
    encoding: 'utf8',
    env: { ...env, SSH_AUTH_SOCK: socket },
    timeout: 5000,
  });
  return identities.status === 0
    ? { available: true }
    : { available: false, reason: 'ssh-agent-unavailable' };
}

function fetchRemote(root) {
  if (!optionalUpstreamName(root)) return { skipped: true };
  return git(root, ['fetch', '--quiet']);
}

function aheadChangedPaths(root) {
  const result = git(root, ['diff', '--name-only', '-z', '@{u}...HEAD'], { allowFailure: true });
  if (result.status !== 0 || !result.stdout) return [];
  return result.stdout.split('\0').filter(Boolean);
}

function errorRecord(err, at = nowIso()) {
  return {
    at,
    phase: err.phase || 'sync',
    message: redactDiagnostic(err.message) || 'Sync failed',
    detail: redactDiagnostic(err.detail) || null,
    recovery: redactDiagnostic(err.recovery) || null,
    secondary: Array.isArray(err.secondary) ? err.secondary.map((failure) => ({
      phase: failure.phase || 'sync',
      message: redactDiagnostic(failure.message) || 'Secondary sync failure',
      detail: redactDiagnostic(failure.detail) || null,
    })) : [],
  };
}

function causalFailure(primary, phase, secondary) {
  primary.secondary = [...(primary.secondary || []), {
    phase,
    message: secondary.message,
    detail: secondary.detail || null,
  }];
  const secondaryLine = `Secondary ${phase} failure: ${redactDiagnostic(secondary.message)}`;
  primary.detail = [primary.detail, secondaryLine].filter(Boolean).join('\n');
  return primary;
}

function withPhase(phase, work) {
  try {
    return work();
  } catch (err) {
    if (!err.phase) err.phase = phase;
    throw err;
  }
}

function commitDirtyState(registration, reason, env = process.env) {
  const root = registration.rootRealpath;
  git(root, ['add', '-A']);
  const diff = gitOut(root, ['diff', '--cached', '--no-ext-diff']);
  if (!diff.trim()) return { committed: false, paths: [] };
  assertPortableContent(addedDiffContent(diff), env);
  const paths = changedPaths(root, true);
  const generated = llmCommitMessage(registration, commitMessageDiff(diff), paths, reason);
  const message = generated.message;
  assertPortableContent(message, env);
  const commit = git(root, ['commit', '-F', '-'], { input: `${message.trim()}\n`, allowFailure: true });
  if (commit.status !== 0) {
    const output = gitCombinedOutput(commit);
    if (isAlreadyCheckpointed(output) && !isDirty(root)) {
      return { committed: false, paths: [], warning: generated.failure || null };
    }
    try {
      if (!isManagedSyncGitGuard(output)) throwGitResult(commit, 'git commit failed');
      git(root, ['commit', '--no-verify', '-F', '-'], { input: `${message.trim()}\n` });
    } catch (err) {
      err.phase = 'commit';
      if (generated.failure) throw causalFailure(generated.failure, 'commit', err);
      throw err;
    }
  }
  return { committed: true, paths, warning: generated.failure || null };
}

function maybeExtendExpiredPause(registration, env = process.env) {
  if (!registration.pausedUntil) return { active: false, registration };
  const until = Date.parse(registration.pausedUntil);
  if (!Number.isFinite(until)) return { active: false, registration };
  if (until > Date.now()) return { active: true, registration };
  if (externalDibsLockActive(registration, env)) {
    const extended = {
      ...registration,
      pausedUntil: new Date(Date.now() + DIBS_PAUSE_EXTENSION_MINUTES * 60000).toISOString(),
      pauseReason: registration.pauseReason || 'dibs lock still active at pause expiry',
      lastError: null,
    };
    return { active: true, registration: saveRegistration(extended, env), extended: true };
  }
  return { active: false, registration: saveRegistration({ ...registration, pausedUntil: null, pauseReason: null }, env) };
}

export async function runCycle(registration, { reason = 'daemon', force = false, env = process.env } = {}) {
  let reg = registration;
  let claim = null;
  try {
    const pause = withPhase('pause', () => maybeExtendExpiredPause(reg, env));
    reg = pause.registration;
    if (pause.active) {
      return { state: pause.extended ? 'pause-extended' : 'paused', registration: reg };
    }
    const preflight = withPhase('preflight', () => preflightRepository(reg.rootRealpath, env));
    if (preflight.key !== reg.key) {
      const err = new Error(`registration key mismatch for ${reg.rootRealpath}`);
      err.phase = 'preflight';
      throw err;
    }
    const remoteAuthentication = reason === 'manual'
      ? { available: true }
      : withPhase('authentication', () => remoteAuthenticationAvailability(reg.rootRealpath, env));
    if (remoteAuthentication.available) withPhase('fetch', () => fetchRemote(reg.rootRealpath));
    const dirty = isDirty(reg.rootRealpath);
    const relation = aheadBehind(reg.rootRealpath);
    if (!dirty && relation.ahead === 0 && relation.behind === 0 && !force) {
      const state = remoteAuthentication.available ? 'idle' : 'waiting-for-authentication';
      return saveCycleResult(reg, {
        state,
        lastPollAt: nowIso(),
        lastError: null,
        lastResult: remoteAuthentication.available ? null : { reason, remoteSkipped: remoteAuthentication.reason },
      }, env);
    }
    claim = withPhase('lock', () => claimDibs(reg, env));
    const committedPaths = [];
    let commitWarning = null;
    let preSyncRuns = 0;
    const runRegisteredPreSync = () => {
      const result = withPhase('pre-sync', () => runPreSync(reg));
      if (!result.skipped) preSyncRuns += 1;
      return result;
    };
    const commitPendingState = (commitReason) => {
      if (!isDirty(reg.rootRealpath)) return { committed: false, paths: [] };
      const result = withPhase('commit', () => commitDirtyState(reg, commitReason, env));
      committedPaths.push(...result.paths);
      if (!commitWarning && result.warning) commitWarning = result.warning;
      return result;
    };
    commitPendingState(reason);
    let afterCommitRelation = aheadBehind(reg.rootRealpath);
    let rebase = { rebased: false, conflictsResolved: 0 };
    if (remoteAuthentication.available && afterCommitRelation.known && (afterCommitRelation.behind > 0 || committedPaths.length > 0)) {
      rebase = withPhase('rebase', () => pullRebaseWithLlm(reg));
      afterCommitRelation = aheadBehind(reg.rootRealpath);
    }
    runRegisteredPreSync();
    commitPendingState(`${reason}-pre-sync`);
    afterCommitRelation = aheadBehind(reg.rootRealpath);
    const cyclePaths = [...new Set([...committedPaths, ...aheadChangedPaths(reg.rootRealpath)])];
    const verificationResult = withPhase('verification', () => verifyWithRepairs(reg, cyclePaths, reason, env));
    const verification = verificationResult.verification;
    if (verificationResult.repaired) {
      for (const repair of verification.repairs || []) committedPaths.push(...(repair.paths || []));
      runRegisteredPreSync();
      const generatedCommit = commitPendingState(`${reason}-post-verification`);
      if (generatedCommit.committed) withPhase('verification', () => runVerification(reg));
      afterCommitRelation = aheadBehind(reg.rootRealpath);
    }
    if (remoteAuthentication.available && afterCommitRelation.known && (afterCommitRelation.ahead > 0 || committedPaths.length > 0)) {
      withPhase('push', () => pushCurrentBranch(reg.rootRealpath, env));
    }
    const completedAt = nowIso();
    return saveCycleResult(reg, {
      state: remoteAuthentication.available ? 'synced' : 'waiting-for-authentication',
      lastCycleAt: completedAt,
      lastPollAt: completedAt,
      lastSuccessfulSyncAt: remoteAuthentication.available ? completedAt : reg.lastSuccessfulSyncAt,
      lastSeenDirtyAt: null,
      lastError: null,
      lastWarning: commitWarning ? errorRecord(commitWarning, completedAt) : null,
      lastValidation: verification,
      lastResult: {
        reason,
	committed: committedPaths.length > 0,
	paths: [...new Set(committedPaths)],
	preSyncRuns,
        rebased: rebase.rebased,
        conflictsResolved: rebase.conflictsResolved,
	upstream: optionalUpstreamName(reg.rootRealpath),
        remoteSkipped: remoteAuthentication.available ? null : remoteAuthentication.reason,
        verification,
      },
    }, env);
  } catch (err) {
    const at = nowIso();
    let stillDirty = true;
    try {
      stillDirty = isDirty(reg.rootRealpath);
    } catch {
      stillDirty = true;
    }
    return saveCycleResult(reg, {
      state: 'error',
      lastCycleAt: at,
      lastPollAt: at,
      lastSuccessfulSyncAt: reg.lastSuccessfulSyncAt || (!reg.lastError && reg.lastResult ? reg.lastCycleAt : null),
      lastSeenDirtyAt: stillDirty ? reg.lastSeenDirtyAt : null,
      lastError: errorRecord(err, at),
      lastValidation: err.validation || reg.lastValidation || null,
    }, env, err);
  } finally {
    if (claim) releaseDibs(reg, claim, env);
  }
}

function saveCycleResult(registration, patch, env, throwAfterSave = null) {
  const saved = saveRegistration({ ...registration, ...patch }, env);
  if (throwAfterSave) throw throwAfterSave;
  return { state: patch.state, registration: saved, result: patch.lastResult || null };
}

function registrationForDir(dir, env = process.env) {
  const root = resolveGitRoot(dir || env.PWD || process.cwd(), env);
  const path = registrationPathForRoot(root, env);
  if (!existsSync(path)) throw new Error(`vaultsync is not installed for ${root}`);
  return readJsonFile(path);
}

function managedStatusForDir(dir, env = process.env) {
  const root = resolveGitRoot(dir || env.PWD || process.cwd(), env);
  const path = registrationPathForRoot(root, env);
  if (!existsSync(path)) return { managed: false, root };
  const registration = readJsonFile(path);
  return {
    managed: registration.enabled !== false,
    root,
    enabled: registration.enabled !== false,
    pausedUntil: registration.pausedUntil || null,
  };
}

function parseCommonTarget(args, env = process.env) {
  const parsed = parseArgs({
    args,
    allowPositionals: true,
    options: {
      json: { type: 'boolean', default: false },
    },
  });
  return {
    dir: parsed.positionals[0] || env.PWD || process.cwd(),
    json: parsed.values.json,
  };
}

function emit(data, json = false) {
  if (json) process.stdout.write(`${JSON.stringify(data, null, 2)}\n`);
  else if (typeof data === 'string') process.stdout.write(`${data}\n`);
  else process.stdout.write(`${JSON.stringify(data, null, 2)}\n`);
}

async function commandInstall(args, env = process.env) {
  const parsed = parseArgs({
    args,
    allowPositionals: true,
    options: {
      'llm-command': { type: 'string' },
      'pre-sync': { type: 'string' },
      verify: { type: 'string' },
      'debounce-seconds': { type: 'string' },
      'idle-poll-seconds': { type: 'string' },
      json: { type: 'boolean', default: false },
      'no-launchd': { type: 'boolean', default: false },
    },
  });
  const dir = parsed.positionals[0] || env.PWD || process.cwd();
  const preflight = preflightRepository(dir, env);
  const dibsBin = findDibsBin(env);
  if (!dibsBin) throw new Error('dibs executable not found; put dibs on PATH or set DIBS_BIN before installing');
  const llmCommand = parsed.values['llm-command'] || env.VAULTSYNC_LLM_COMMAND;
  if (!llmCommand) throw new Error('--llm-command is required; vaultsync must have a conflict resolver');
  probeLlmCommand(llmCommand, preflight.rootRealpath);
  ensureRuntimeDirs(env);
  const existingPath = registrationPathForKey(preflight.key, env);
  const existing = existsSync(existingPath) ? readJsonFile(existingPath) : null;
  const registration = {
    version: REGISTRATION_VERSION,
    key: preflight.key,
    requestedCwd: preflight.requestedCwd,
    rootRealpath: preflight.rootRealpath,
    gitCommonDir: preflight.gitCommonDir,
    branchAtInstall: preflight.branch,
    upstreamAtInstall: preflight.upstream,
    llmCommand,
    preSyncCommand: parsed.values['pre-sync'] || null,
    verifyCommand: parsed.values.verify || null,
    debounceSeconds: numberOption(parsed.values['debounce-seconds'], DEFAULT_DEBOUNCE_SECONDS, 'debounce-seconds'),
    idlePollSeconds: numberOption(parsed.values['idle-poll-seconds'], DEFAULT_IDLE_POLL_SECONDS, 'idle-poll-seconds'),
    enabled: true,
    pausedUntil: null,
    pauseReason: null,
    lastSeenDirtyAt: null,
    lastCycleAt: null,
    lastPollAt: null,
    lastSuccessfulSyncAt: null,
    lastError: null,
    lastWarning: null,
    createdAt: nowIso(),
  };
  if (existing?.validators) registration.validators = existing.validators;
  const registrationDibsBin = registrationDibsBinForInstall(dibsBin);
  if (registrationDibsBin) registration.dibsBin = registrationDibsBin;
  const savedRegistration = saveRegistration(registration, env);
  const launchd = parsed.values['no-launchd'] ? { skipped: true } : installLaunchAgent(env);
  emit({
    installed: true,
    requestedCwd: preflight.requestedCwd,
    gitRoot: preflight.rootRealpath,
    branch: preflight.branch,
    upstream: preflight.upstream,
    registration: registrationPathForKey(savedRegistration.key, env),
    launchd,
  }, parsed.values.json);
}

function commandManaged(args, env = process.env) {
  const target = parseCommonTarget(args, env);
  emit(managedStatusForDir(target.dir, env), target.json);
}

function numberOption(value, fallback, name) {
  if (value == null) return fallback;
  const n = Number(value);
  if (!Number.isInteger(n) || n <= 0) throw new Error(`--${name} must be a positive integer`);
  return n;
}

function commandDoctor(args, env = process.env) {
  const parsed = parseArgs({
    args,
    allowPositionals: true,
    options: {
      'llm-command': { type: 'string' },
      json: { type: 'boolean', default: false },
    },
  });
  const preflight = preflightRepository(parsed.positionals[0] || env.PWD || process.cwd(), env);
  const dibsBin = findDibsBin(env);
  const llmCommand = parsed.values['llm-command'] || env.VAULTSYNC_LLM_COMMAND;
  const llmProbe = llmCommand ? probeLlmCommand(llmCommand, preflight.rootRealpath) : false;
  emit({ ...preflight, dibsBin, llmProbe }, parsed.values.json);
}

function validatorConfiguration(registration) {
  const outcomes = new Map((registration.lastValidation?.validators || []).map((outcome) => [outcome.name, outcome]));
  return configuredValidators(registration).map((validator) => ({
    name: validator.name,
    command: redactDiagnostic(validator.command),
    repair: validator.repair,
    legacy: validator.legacy,
    lastResult: outcomes.get(validator.name) || null,
  }));
}

function withoutValidatorOutcome(registration, name) {
  if (!registration.lastValidation) return registration;
  const validators = (registration.lastValidation.validators || []).filter((outcome) => outcome.name !== name);
  return {
    ...registration,
    lastValidation: {
      ...registration.lastValidation,
      skipped: validators.length === 0,
      passed: validators.every((outcome) => outcome.state === 'passed'),
      validators,
    },
  };
}

function mutateNamedValidators(key, env, mutation) {
  return withRegistrationLock(key, env, () => {
    const path = registrationPathForKey(key, env);
    const current = readJsonFile(path);
    const result = mutation(current);
    if (!result.changed) return { registration: current, ...result };
    const updated = { ...result.registration, updatedAt: nowIso() };
    writeJsonAtomic(path, updated);
    return { ...result, registration: updated };
  });
}

function commandValidator(args, env = process.env) {
  const parsed = parseArgs({
    args,
    allowPositionals: true,
    options: {
      command: { type: 'string' },
      repair: { type: 'string' },
      'repair-authority': { type: 'string' },
      json: { type: 'boolean', default: false },
    },
  });
  const [action, nameOrPath, explicitPath] = parsed.positionals;
  if (!['add', 'list', 'remove'].includes(action)) throw new Error('usage: vaultsync validator <add|list|remove> ...');
  if (action === 'list') {
    if (parsed.positionals.length > 2) throw new Error('too many positional arguments for validator list');
    if (parsed.values.command) throw new Error('--command is only valid with validator add');
    if (parsed.values.repair) throw new Error('--repair is only valid with validator add');
    if (parsed.values['repair-authority']) throw new Error('--repair-authority is only valid with validator add');
    const registration = registrationForDir(nameOrPath || env.PWD || process.cwd(), env);
    const payload = { root: registration.rootRealpath, validators: validatorConfiguration(registration) };
    if (parsed.values.json) return emit(payload, true);
    const lines = payload.validators.length === 0
      ? [`${payload.root}: no validators configured`]
      : payload.validators.flatMap((validator) => [
	`${validator.name}${validator.legacy ? ' (legacy)' : ''}`,
	`  command: ${validator.command}`,
	`  repair: ${validator.repair.mode} (${validator.repair.authority})`,
	`  last result: ${validator.lastResult?.state || '(not run)'}`,
      ]);
    return emit(lines.join('\n'));
  }

  const name = nameOrPath;
  if (!name) throw new Error(`validator ${action} requires a name`);
  if (parsed.positionals.length > 3) throw new Error(`too many positional arguments for validator ${action}`);
  if (!VALIDATOR_NAME_PATTERN.test(name) || name === LEGACY_VALIDATOR_NAME) throw new Error(`invalid or reserved validator name: ${name}`);
  const registration = registrationForDir(explicitPath || env.PWD || process.cwd(), env);
  if (action === 'remove') {
    if (parsed.values.command) throw new Error('--command is only valid with validator add');
    if (parsed.values.repair) throw new Error('--repair is only valid with validator add');
    if (parsed.values['repair-authority']) throw new Error('--repair-authority is only valid with validator add');
    const mutation = mutateNamedValidators(registration.key, env, (current) => {
      const namedValidators = { ...(current.validators || {}) };
      const removed = Object.hasOwn(namedValidators, name);
      if (!removed) return { changed: false, removed, registration: current };
      delete namedValidators[name];
      return { changed: true, removed, registration: { ...withoutValidatorOutcome(current, name), validators: namedValidators } };
    });
    const removed = mutation.removed;
    return emit({ root: registration.rootRealpath, name, removed }, parsed.values.json);
  }

  if (!parsed.values.command) throw new Error('--command is required');
  if (!parsed.values.repair) throw new Error('--repair is required');
  if (parsed.values.repair === 'automatic' && !parsed.values['repair-authority']) throw new Error('--repair-authority is required for automatic repair');
  if (parsed.values.repair === 'none' && parsed.values['repair-authority']) throw new Error('--repair-authority is not valid with --repair none');
  const validator = {
    command: parsed.values.command,
    repair: normalizeRepairPolicy({
      mode: parsed.values.repair,
      authority: parsed.values.repair === 'none' ? 'none' : parsed.values['repair-authority'],
    }),
  };
  normalizeNamedValidator(name, validator);
  const mutation = mutateNamedValidators(registration.key, env, (current) => {
    const namedValidators = { ...(current.validators || {}) };
    const unchanged = JSON.stringify(namedValidators[name]) === JSON.stringify(validator);
    if (unchanged) return { changed: false, unchanged, registration: current };
    const withoutOutcome = withoutValidatorOutcome(current, name);
    return {
      changed: true,
      unchanged,
      registration: { ...withoutOutcome, validators: { ...namedValidators, [name]: validator } },
    };
  });
  const unchanged = mutation.unchanged;
  emit({ root: registration.rootRealpath, name, updated: !unchanged, validator }, parsed.values.json);
}

function pendingChanges(root) {
  const staged = changedPaths(root, true);
  const unstagedRaw = gitOut(root, ['diff', '--name-only', '-z']);
  const unstaged = unstagedRaw ? unstagedRaw.split('\0').filter(Boolean) : [];
  const untrackedRaw = gitOut(root, ['ls-files', '--others', '--exclude-standard', '-z']);
  const untracked = untrackedRaw ? untrackedRaw.split('\0').filter(Boolean) : [];
  const paths = [...new Set([...staged, ...unstaged, ...untracked])].sort();
  const relation = aheadBehind(root);
  return {
    uncommitted: {
      count: paths.length,
      paths,
      staged: [...new Set(staged)].sort(),
      unstaged: [...new Set(unstaged)].sort(),
      untracked: [...new Set(untracked)].sort(),
    },
    unpushed: {
      commits: relation.known ? relation.ahead : 0,
      paths: relation.known ? aheadChangedPaths(root).sort() : [],
    },
  };
}

function structuredStatus(reg) {
  const root = reg.rootRealpath;
  try {
    const relation = aheadBehind(root);
    const pending = pendingChanges(root);
    const failure = reg.lastError || reg.lastWarning || null;
    let state = 'synced';
    if (reg.enabled === false) state = 'disabled';
    else if (reg.pausedUntil && Date.parse(reg.pausedUntil) > Date.now()) state = 'paused';
    else if (reg.lastError) state = 'blocked';
    else if (reg.lastWarning) state = 'degraded';
    else if (pending.uncommitted.count > 0 || pending.unpushed.commits > 0) state = 'pending';
    return {
      key: reg.key,
      root,
      managed: true,
      enabled: reg.enabled !== false,
      state,
      branch: branchName(root),
      upstream: optionalUpstreamName(root),
      ahead: relation.known ? relation.ahead : null,
      behind: relation.known ? relation.behind : null,
      pausedUntil: reg.pausedUntil || null,
      pauseReason: reg.pauseReason || null,
      lastCycleAt: reg.lastCycleAt || null,
      lastPollAt: reg.lastPollAt || null,
      lastSuccessfulSyncAt: reg.lastSuccessfulSyncAt || null,
      failure,
      validators: validatorConfiguration(reg),
      pending,
    };
  } catch (err) {
    return {
      key: reg.key,
      root,
      managed: true,
      enabled: reg.enabled !== false,
      state: 'blocked',
      failure: errorRecord(Object.assign(err, { phase: err.phase || 'status' })),
      validators: [],
      pending: null,
    };
  }
}

function commandStatus(args, env = process.env) {
  const parsed = parseArgs({
    args,
    allowPositionals: true,
    options: {
      json: { type: 'boolean', default: false },
    },
  });
  let regs;
  if (parsed.positionals[0]) {
    const root = resolveGitRoot(parsed.positionals[0], env);
    const path = registrationPathForRoot(root, env);
    if (!existsSync(path)) {
      const status = { protocol: 'vaultsync.status.v1', vaults: [{ root, managed: false, enabled: false, state: 'unmanaged', failure: null, pending: null }] };
      return emit(parsed.values.json ? status : `${root}\n  auto-sync: unmanaged`, parsed.values.json);
    }
    regs = [readJsonFile(path)];
  } else {
    regs = loadRegistrations(env).filter((reg) => !reg.unreadable);
  }
  const statuses = regs.map(structuredStatus);
  const contract = { protocol: 'vaultsync.status.v1', vaults: statuses };
  if (parsed.values.json) return emit(contract, true);
  if (statuses.length === 0) return emit('No vaultsync registrations found.');
  const lines = [];
  for (const status of statuses) {
    lines.push(status.root);
    lines.push(`  auto-sync: ${status.state}`);
    lines.push(`  branch: ${status.branch || '(unknown)'}`);
    lines.push(`  upstream: ${status.upstream || '(none)'}`);
    if (status.ahead != null) lines.push(`  ahead/behind: ${status.ahead}/${status.behind}`);
    if (status.pausedUntil) lines.push(`  paused until: ${status.pausedUntil}`);
    if (status.lastSuccessfulSyncAt) lines.push(`  last successful sync: ${status.lastSuccessfulSyncAt}`);
    lines.push(`  validators: ${status.validators.length}`);
    for (const validator of status.validators) lines.push(`    ${validator.name}: ${validator.lastResult?.state || 'not run'}; repair ${validator.repair.mode} (${validator.repair.authority})`);
    if (status.failure) {
      lines.push(`  blocked during ${status.failure.phase}: ${status.failure.message}`);
      for (const secondary of status.failure.secondary || []) lines.push(`  secondary ${secondary.phase} failure: ${secondary.message}`);
      if (status.failure.recovery) lines.push(`  recovery: ${status.failure.recovery}`);
    }
    if (status.pending) {
      lines.push(`  local changes: ${status.pending.uncommitted.count} uncommitted (${status.pending.uncommitted.staged.length} staged), ${status.pending.unpushed.commits} unpushed commits`);
    }
  }
  emit(lines.join('\n'));
}

function commandPause(args, env = process.env) {
  const parsed = parseArgs({
    args,
    allowPositionals: true,
    options: {
      minutes: { type: 'string' },
      until: { type: 'string' },
      reason: { type: 'string' },
      json: { type: 'boolean', default: false },
    },
  });
  const dir = parsed.positionals[0] || env.PWD || process.cwd();
  const reg = registrationForDir(dir, env);
  let until;
  if (parsed.values.until) {
    until = new Date(parsed.values.until);
    if (!Number.isFinite(until.getTime())) throw new Error('--until must be an ISO-like date/time');
  } else {
    const minutes = numberOption(parsed.values.minutes, DEFAULT_PAUSE_MINUTES, 'minutes');
    until = new Date(Date.now() + minutes * 60000);
  }
  const saved = saveRegistration({
    ...reg,
    pausedUntil: until.toISOString(),
    pauseReason: parsed.values.reason || 'manual pause',
  }, env);
  emit({ paused: true, root: saved.rootRealpath, until: saved.pausedUntil }, parsed.values.json);
}

function commandResume(args, env = process.env) {
  const target = parseCommonTarget(args, env);
  const reg = registrationForDir(target.dir, env);
  const saved = saveRegistration({ ...reg, pausedUntil: null, pauseReason: null }, env);
  emit({ resumed: true, root: saved.rootRealpath }, target.json);
}

async function commandNow(args, env = process.env) {
  const target = parseCommonTarget(args, env);
  const reg = registrationForDir(target.dir, env);
  const result = await runCycle(reg, { reason: 'manual', force: true, env });
  emit(result, target.json);
}

async function commandDaemon(args, env = process.env) {
  const parsed = parseArgs({
    args,
    allowPositionals: false,
    options: {
      once: { type: 'boolean', default: false },
      json: { type: 'boolean', default: false },
    },
  });
  ensureRuntimeDirs(env);
  if (parsed.values.once) {
    const result = await daemonTick(env);
    emit(result, parsed.values.json);
    return;
  }
  const lease = acquireDaemonLease(env);
  if (!lease) {
    emit({ state: 'already-running', label: SERVICE_LABEL }, parsed.values.json);
    return;
  }
  process.stdout.write(`vaultsync daemon running (${SERVICE_LABEL})\n`);
  const stop = () => {
    lease.release();
    process.exit(0);
  };
  process.on('SIGTERM', stop);
  process.on('SIGINT', stop);
  try {
    await daemonTick(env);
    while (true) {
      sleepMs(DAEMON_SLEEP_MS);
      await daemonTick(env);
    }
  } finally {
    lease.release();
  }
}

export async function daemonTick(env = process.env) {
  const registrations = loadRegistrations(env).filter((reg) => !reg.unreadable && reg.enabled !== false);
  const results = [];
  for (const reg of registrations) {
    let cycleAttempted = false;
    try {
      const dirty = isDirty(reg.rootRealpath);
      const now = Date.now();
      const lastSeenDirtyAt = reg.lastSeenDirtyAt ? Date.parse(reg.lastSeenDirtyAt) : null;
      if (dirty && !lastSeenDirtyAt) {
        saveRegistration({ ...reg, lastSeenDirtyAt: nowIso() }, env);
        results.push({ root: reg.rootRealpath, state: 'debouncing' });
        continue;
      }
      const debounceMs = (reg.debounceSeconds || DEFAULT_DEBOUNCE_SECONDS) * 1000;
      if (dirty && lastSeenDirtyAt && now - lastSeenDirtyAt >= debounceMs) {
	cycleAttempted = true;
        results.push(await runCycle(reg, { reason: 'debounce', force: true, env }));
        continue;
      }
      const lastPollAt = reg.lastPollAt ? Date.parse(reg.lastPollAt) : 0;
      const pollMs = (reg.idlePollSeconds || DEFAULT_IDLE_POLL_SECONDS) * 1000;
      if (!dirty && now - lastPollAt >= pollMs) {
	cycleAttempted = true;
        results.push(await runCycle(reg, { reason: 'poll', force: false, env }));
        continue;
      }
      results.push({ root: reg.rootRealpath, state: dirty ? 'debouncing' : 'waiting' });
    } catch (err) {
      let saved = null;
      if (cycleAttempted) {
	const latest = readJsonFile(registrationPathForKey(reg.key, env));
	if (latest.lastError?.phase) saved = latest;
      }
      if (!saved) {
	if (!err.phase) err.phase = 'daemon';
	saved = saveRegistration({ ...reg, lastError: errorRecord(err) }, env);
      }
      results.push({ root: reg.rootRealpath, state: 'error', registration: saved, error: err.message });
    }
  }
  return results;
}

function xmlEscape(value) {
  return String(value)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&apos;');
}

export function launchAgentPlist(env = process.env) {
  const outLog = join(logsDir(env), 'daemon.out.log');
  const errLog = join(logsDir(env), 'daemon.err.log');
  const path = [...new Set([
    dirname(process.execPath),
    ...(env.PATH || '').split(delimiter).filter(Boolean),
  ])].join(delimiter);
  return `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${SERVICE_LABEL}</string>
  <key>ProgramArguments</key>
  <array>
    <string>${xmlEscape(machineLauncherPath(env))}</string>
    <string>daemon</string>
  </array>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key>
    <string>${xmlEscape(path)}</string>
  </dict>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <dict>
    <key>SuccessfulExit</key>
    <false/>
  </dict>
  <key>StandardOutPath</key>
  <string>${xmlEscape(outLog)}</string>
  <key>StandardErrorPath</key>
  <string>${xmlEscape(errLog)}</string>
</dict>
</plist>
`;
}

function launchAgentStatePath(env = process.env) {
  return join(vaultsyncDir(env), 'launch-agent.json');
}

export function launchAgentNeedsReconciliation(version, env = process.env) {
  try {
    return readJsonFile(launchAgentStatePath(env)).version !== version;
  } catch {
    return true;
  }
}

function regexEscape(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

export function vaultsyncDaemonPids(processTable, env = process.env, currentPid = process.pid) {
  const stable = regexEscape(machineLauncherPath(env));
  const releases = regexEscape(join(vaultsyncDir(env), 'runtime', 'releases'));
  const daemonCommand = new RegExp(`(?:${stable}|${releases}/[^/\\s]+/bin/vaultsync)\\s+daemon(?:\\s|$)`);
  return String(processTable || '')
    .split('\n')
    .map((row) => /^\s*(\d+)\s+(.+)$/.exec(row))
    .filter(Boolean)
    .filter(([, pid, command]) => Number(pid) !== currentPid && daemonCommand.test(command) && !/\sdaemon\s+--once(?:\s|$)/.test(command))
    .map(([, pid]) => Number(pid));
}

function terminateVaultsyncDaemons(env = process.env) {
  const processes = spawnSync('ps', ['-axo', 'pid=,command='], { encoding: 'utf8' });
  if (processes.status !== 0) return [];
  const pids = vaultsyncDaemonPids(processes.stdout, env);
  for (const pid of pids) {
    try { process.kill(pid, 'SIGTERM'); } catch {}
  }
  const deadline = Date.now() + DAEMON_SHUTDOWN_TIMEOUT_MS;
  while (pids.some(processIsAlive) && Date.now() < deadline) sleepMs(50);
  for (const pid of pids.filter(processIsAlive)) {
    try { process.kill(pid, 'SIGKILL'); } catch {}
  }
  return pids;
}

export function installLaunchAgent(env = process.env, version = null) {
  if (platform() !== 'darwin') return { skipped: true, reason: 'launchd is only available on macOS' };
  ensureRuntimeDirs(env);
  const launchAgents = join(env.HOME || homedir(), 'Library', 'LaunchAgents');
  mkdirSync(launchAgents, { recursive: true });
  const plistPath = join(launchAgents, `${SERVICE_LABEL}.plist`);
  writeFileSync(plistPath, launchAgentPlist(env));
  const uid = userInfo().uid;
  spawnSync('launchctl', ['bootout', `gui/${uid}`, plistPath], { encoding: 'utf8' });
  const terminatedPids = terminateVaultsyncDaemons(env);
  const bootstrap = spawnSync('launchctl', ['bootstrap', `gui/${uid}`, plistPath], { encoding: 'utf8' });
  if (bootstrap.status !== 0) {
    throw new Error((bootstrap.stderr || bootstrap.stdout || 'launchctl bootstrap failed').trim());
  }
  spawnSync('launchctl', ['kickstart', '-k', `gui/${uid}/${SERVICE_LABEL}`], { encoding: 'utf8' });
  if (version) writeJsonAtomic(launchAgentStatePath(env), { version });
  return { installed: true, label: SERVICE_LABEL, plist: plistPath, terminatedPids };
}

export function launchAgentIsInstalled(env = process.env) {
  if (platform() !== 'darwin') return false;
  return existsSync(join(env.HOME || homedir(), 'Library', 'LaunchAgents', `${SERVICE_LABEL}.plist`));
}

export async function runCommand(command, args, env = process.env) {
  switch (command) {
    case 'install': return commandInstall(args, env);
    case 'managed': return commandManaged(args, env);
    case 'status': return commandStatus(args, env);
    case 'pause': return commandPause(args, env);
    case 'resume': return commandResume(args, env);
    case 'now': return commandNow(args, env);
    case 'daemon': return commandDaemon(args, env);
    case 'doctor': return commandDoctor(args, env);
    case 'validator': return commandValidator(args, env);
    default: throw new Error(`unknown command: ${command}`);
  }
}

export function testInternals() {
  return {
    git,
    gitOut,
    isDirty,
    aheadBehind,
    statusPorcelain,
    changedPaths,
  };
}
