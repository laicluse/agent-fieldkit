import { accessSync, constants, existsSync, mkdirSync, readFileSync, realpathSync, readdirSync, renameSync, rmSync, writeFileSync } from 'node:fs';
import { delimiter, dirname, isAbsolute, join, relative, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { homedir, platform, userInfo } from 'node:os';
import { fileURLToPath } from 'node:url';
import { parseArgs } from 'node:util';

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
  const updated = { ...registration, updatedAt: nowIso() };
  writeJsonAtomic(registrationPathForKey(updated.key, env), updated);
  return updated;
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
  const patches = gitOut(root, ['log', '--format=', '--patch', '--unified=0', '@{u}..HEAD']);
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

function withoutVaultsyncTrailers(message) {
  return message
    .split('\n')
    .filter((line) => !/^(Tests|Slice|Red-then-green|Vaultsync-Reason):\s*/i.test(line.trim()))
    .join('\n')
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

function commitNarrative(message) {
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

function runVerification(registration) {
  if (!registration.verifyCommand) return { skipped: true };
  const result = shellCommand(registration.verifyCommand, {
    cwd: registration.rootRealpath,
    timeoutMs: 10 * 60 * 1000,
  });
  if (result.status !== 0) {
    const err = new Error(`verification command failed: ${registration.verifyCommand}`);
    const detail = [result.stdout, result.stderr].filter(Boolean).join('\n').trim();
    err.detail = detail.slice(0, 4000);
    err.repairDetail = detail.slice(0, MAX_VERIFICATION_REPAIR_DETAIL_BYTES);
    err.exitCode = result.status || 1;
    throw err;
  }
  return { skipped: false };
}

function runPreSync(registration) {
  if (!registration.preSyncCommand) return { skipped: true };
  const result = shellCommand(registration.preSyncCommand, {
    cwd: registration.rootRealpath,
    timeoutMs: 10 * 60 * 1000,
  });
  if (result.status !== 0) {
    const err = new Error(`pre-sync command failed: ${registration.preSyncCommand}`);
    const detail = [result.stdout, result.stderr].filter(Boolean).join('\n').trim();
    err.detail = detail.slice(0, 4000);
    err.exitCode = result.status || 1;
    throw err;
  }
  return { skipped: false };
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
    const start = line.indexOf(rootPrefix);
    if (start < 0) continue;
    const tail = line.slice(start + rootPrefix.length);
    const match = tail.match(/^(.+?\.(?:md|markdown|txt|csv|tsv|json|ya?ml))(?::|\s|$)/i);
    if (match) out.push(match[1]);
  }
  return out;
}

function readRepairCandidate(root, path) {
  const rel = safeRelativePath(root, path);
  if (!rel || !isTextRepairPath(rel)) return null;
  const full = join(root, rel);
  if (!existsSync(full)) return null;
  const content = readFileSync(full, 'utf8');
  if (Buffer.byteLength(content, 'utf8') > MAX_VERIFICATION_REPAIR_FILE_BYTES) return null;
  return { path: rel, content };
}

function verificationRepairCandidates(registration, verificationError, cyclePaths = []) {
  const root = registration.rootRealpath;
  const cycle = new Set(cyclePaths.map((p) => safeRelativePath(root, p)).filter(Boolean));
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

function mechanicalVerifierRepairs(registration, verificationError) {
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
    const candidate = readRepairCandidate(root, path);
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

function repairVerificationFailure(registration, verificationError, cyclePaths, reason) {
  const files = verificationRepairCandidates(registration, verificationError, cyclePaths);
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
      command: registration.verifyCommand,
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
  return { repaired: written.length > 0, paths: written };
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
      let repair = mechanicalVerifierRepairs(registration, err);
      if (!repair.repaired) repair = repairVerificationFailure(registration, err, cyclePaths, reason);
      if (!repair.repaired) throw err;
      const repairCommit = commitDirtyState(registration, `${reason}-verifier-repair`, env);
      if (!repairCommit.committed) throw err;
      repairs.push(repair);
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
  const generated = llmCommitMessage(registration, diff, paths, reason);
  const message = generated.message;
  assertPortableContent(message, env);
  const commit = git(root, ['commit', '-F', '-'], { input: `${message.trim()}\n`, allowFailure: true });
  if (commit.status !== 0) {
    const output = gitCombinedOutput(commit);
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
    withPhase('fetch', () => fetchRemote(reg.rootRealpath));
    const dirty = isDirty(reg.rootRealpath);
    const relation = aheadBehind(reg.rootRealpath);
    if (!dirty && relation.ahead === 0 && relation.behind === 0 && !force) {
      return saveCycleResult(reg, { state: 'idle', lastPollAt: nowIso(), lastError: null }, env);
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
    if (afterCommitRelation.known && (afterCommitRelation.behind > 0 || committedPaths.length > 0)) {
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
    if (afterCommitRelation.known && (afterCommitRelation.ahead > 0 || committedPaths.length > 0)) {
      withPhase('push', () => pushCurrentBranch(reg.rootRealpath, env));
    }
    const completedAt = nowIso();
    return saveCycleResult(reg, {
      state: 'synced',
      lastCycleAt: completedAt,
      lastPollAt: completedAt,
      lastSuccessfulSyncAt: completedAt,
      lastSeenDirtyAt: null,
      lastError: null,
      lastWarning: commitWarning ? errorRecord(commitWarning, completedAt) : null,
      lastResult: {
        reason,
	committed: committedPaths.length > 0,
	paths: [...new Set(committedPaths)],
	preSyncRuns,
        rebased: rebase.rebased,
        conflictsResolved: rebase.conflictsResolved,
	upstream: optionalUpstreamName(reg.rootRealpath),
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
  const result = await daemonTick(env);
  if (parsed.values.once) {
    emit(result, parsed.values.json);
    return;
  }
  process.stdout.write(`vaultsync daemon running (${SERVICE_LABEL})\n`);
  process.on('SIGTERM', () => process.exit(0));
  process.on('SIGINT', () => process.exit(0));
  while (true) {
    sleepMs(DAEMON_SLEEP_MS);
    await daemonTick(env);
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

function currentBinPath() {
  return fileURLToPath(new URL('../bin/vaultsync', import.meta.url));
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
    <string>${xmlEscape(process.execPath)}</string>
    <string>${xmlEscape(currentBinPath())}</string>
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

export function installLaunchAgent(env = process.env) {
  if (platform() !== 'darwin') return { skipped: true, reason: 'launchd is only available on macOS' };
  ensureRuntimeDirs(env);
  const launchAgents = join(env.HOME || homedir(), 'Library', 'LaunchAgents');
  mkdirSync(launchAgents, { recursive: true });
  const plistPath = join(launchAgents, `${SERVICE_LABEL}.plist`);
  writeFileSync(plistPath, launchAgentPlist(env));
  const uid = userInfo().uid;
  spawnSync('launchctl', ['bootout', `gui/${uid}`, plistPath], { encoding: 'utf8' });
  const bootstrap = spawnSync('launchctl', ['bootstrap', `gui/${uid}`, plistPath], { encoding: 'utf8' });
  if (bootstrap.status !== 0) {
    throw new Error((bootstrap.stderr || bootstrap.stdout || 'launchctl bootstrap failed').trim());
  }
  spawnSync('launchctl', ['kickstart', '-k', `gui/${uid}/${SERVICE_LABEL}`], { encoding: 'utf8' });
  return { installed: true, label: SERVICE_LABEL, plist: plistPath };
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
