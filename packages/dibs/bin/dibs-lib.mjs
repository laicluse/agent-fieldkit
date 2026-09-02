import { mkdirSync, writeFileSync, readFileSync, readdirSync, realpathSync, rmSync, existsSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { homedir, hostname } from 'node:os';
import { createHash, randomBytes } from 'node:crypto';

const MAX_CLAIM_ATTEMPTS = 3;
const STABLE_READ_TRIES = 10;
const STABLE_READ_SLEEP_MS = 15;
export const BLOCKED_DIRECTORY_SUGGESTION = [
  'Create a separate git worktree on a new branch',
  '(for example with bonsai:bonsai, or plain git worktree if you do not have it),',
  'then claim that worktree path. Do not make a loose non-git copy as a substitute;',
  'it is only a spike, not a deliverable working tree.',
].join(' ');
const MAX_DESCRIPTION_LENGTH = 80;

function agentHomeDir() {
  return process.env.LAICLUSE_HOME || join(homedir(), '.laicluse');
}

function locksDir() {
  return join(agentHomeDir(), 'locks');
}

function ensureLocksDir() {
  mkdirSync(locksDir(), { recursive: true });
}

// allow-comment: load-bearing default. Locked out of dibs everywhere: the agent-config homes, where two sessions editing their own runtime config must not steer each other aside (the git-native backstop covers those repos), plus /tmp, transient scratch that no agent should ever contend over, plus /dev, the device tree that is never a working tree and is where the ubiquitous 2>/dev/null stderr-suppression resolves. Without this every agent contends a single global /dev lock. Additions live in the excludes file; these ship with every install.
export const DEFAULT_EXCLUDES = ['/dev', '/tmp', '~/.claude', '~/.codex', '~/.config/opencode'];

function excludesFile() {
  return join(agentHomeDir(), 'dibs', 'excludes');
}

function expandTilde(p) {
  if (p === '~') return homedir();
  if (p.startsWith('~/')) return join(homedir(), p.slice(2));
  return p;
}

function canonicalizeExclude(entry) {
  const abs = expandTilde(String(entry).trim());
  if (!abs) return null;
  try {
    return existsSync(abs) ? realpathSync(abs) : abs;
  } catch {
    return abs;
  }
}

function readExcludeEntries() {
  const file = excludesFile();
  if (!existsSync(file)) return [];
  return readFileSync(file, 'utf8')
    .split('\n')
    .map((line) => line.replace(/#.*$/, '').trim())
    .filter((line) => line.length > 0);
}

function loadExcludes() {
  const out = [];
  const seen = new Set();
  for (const entry of [...DEFAULT_EXCLUDES, ...readExcludeEntries()]) {
    const canon = canonicalizeExclude(entry);
    if (canon && !seen.has(canon)) {
      seen.add(canon);
      out.push(canon);
    }
  }
  return out;
}

function isExcluded(realpath) {
  for (const excluded of loadExcludes()) {
    if (realpath === excluded || realpath.startsWith(`${excluded}/`)) return true;
  }
  return false;
}

function isDefaultExclude(canon) {
  return DEFAULT_EXCLUDES.some((entry) => canonicalizeExclude(entry) === canon);
}

export function listExcludes() {
  return {
    ok: true,
    defaults: DEFAULT_EXCLUDES,
    file: excludesFile(),
    configured: readExcludeEntries(),
    effective: loadExcludes(),
  };
}

export function excludeDir(path) {
  const entry = String(path).trim();
  if (!entry) throw new Error('exclude needs a directory path');
  const file = excludesFile();
  const canon = canonicalizeExclude(entry);
  if (isDefaultExclude(canon)) return { ok: true, state: 'already-default', path: entry, file };
  if (readExcludeEntries().some((e) => canonicalizeExclude(e) === canon)) {
    return { ok: true, state: 'already-excluded', path: entry, file };
  }
  mkdirSync(dirname(file), { recursive: true });
  const current = existsSync(file) ? readFileSync(file, 'utf8') : '';
  const separator = current.length && !current.endsWith('\n') ? '\n' : '';
  writeFileSync(file, `${current}${separator}${entry}\n`);
  return { ok: true, state: 'excluded', path: entry, file };
}

export function includeDir(path) {
  const entry = String(path).trim();
  if (!entry) throw new Error('include needs a directory path');
  const file = excludesFile();
  const canon = canonicalizeExclude(entry);
  if (existsSync(file)) {
    let removed = false;
    const kept = readFileSync(file, 'utf8').split('\n').filter((line) => {
      const stripped = line.replace(/#.*$/, '').trim();
      if (stripped && canonicalizeExclude(stripped) === canon) {
        removed = true;
        return false;
      }
      return true;
    });
    if (removed) {
      writeFileSync(file, kept.join('\n'));
      return { ok: true, state: 'included', path: entry, file };
    }
  }
  return { ok: true, state: isDefaultExclude(canon) ? 'is-default' : 'not-excluded', path: entry, file };
}

function canonicalDir(dir) {
  if (!dir || !String(dir).trim()) throw new Error('a directory path is required');
  if (!existsSync(dir)) throw new Error(`directory does not exist: ${dir}`);
  return realpathSync(dir);
}

function gitWorktreeRoot(realpath) {
  let candidate = realpath;
  while (true) {
    if (existsSync(join(candidate, '.git'))) return candidate;
    const parent = dirname(candidate);
    if (parent === candidate) return null;
    candidate = parent;
  }
}

function occupancyRoot(dir) {
  const realpath = canonicalDir(dir);
  return gitWorktreeRoot(realpath) || realpath;
}

function lockPathForRealpath(realpath) {
  const sha = createHash('sha256').update(realpath).digest('hex');
  return join(locksDir(), `${sha}.lock`);
}

function isAlive(pid) {
  if (!Number.isInteger(pid) || pid <= 0) return false;
  try {
    process.kill(pid, 0);
    return true;
  } catch (err) {
    return err.code === 'EPERM';
  }
}

// allow-comment: load-bearing contract. One place turns a host's hook payload plus its environment into the fields dibs needs, so a host that supplies less produces one named gap instead of a patch at whichever call site noticed first. Every field a caller cannot determine is listed in `missing`, and callers decide what a gap means: `workdir` absent is why a Codex Bash target cannot be resolved, `description` absent is why a claim would be anonymous. `conversationDir` is reported separately from `workdir` on purpose, because the directory a conversation runs in is not evidence about what a command writes to.
export function resolveContext(payload = {}, env = process.env) {
  const agent = env.DIBS_AGENT || (env.PLUGIN_ROOT ? 'codex' : env.CLAUDE_PLUGIN_ROOT ? 'claude' : 'agent');
  const session = payload.session_id || payload.sessionId || env.DIBS_SESSION || env.CLAUDE_CODE_SESSION_ID || '';
  const codexOwner = agent === 'codex'
    ? (env.CMUX_TAB_ID || env.CMUX_WORKSPACE_ID || env.CODEX_THREAD_ID || '')
    : '';
  const owner = env.DIBS_OWNER || codexOwner || session;
  const description = env.DIBS_DESCRIPTION || '';

  const conversationDir = existingDir(payload.cwd);
  const toolInput = payload.tool_input && typeof payload.tool_input === 'object' ? payload.tool_input : {};
  const declaredWorkdir = toolInput.workdir || toolInput.cwd || '';
  const shellWithoutWorkdir = !declaredWorkdir && agent === 'codex' && payload.tool_name === 'Bash';
  const workdir = declaredWorkdir
    ? existingDir(declaredWorkdir.startsWith('/') ? declaredWorkdir : join(conversationDir || '', declaredWorkdir))
    : (shellWithoutWorkdir ? '' : conversationDir);

  const missing = [];
  if (!session) missing.push('session');
  if (!owner) missing.push('owner');
  if (!description) missing.push('description');
  if (!workdir) missing.push('workdir');

  return { agent, session, owner, description, workdir, conversationDir, missing };
}

function existingDir(candidate) {
  if (!candidate) return '';
  try {
    return existsSync(candidate) ? realpathSync(candidate) : '';
  } catch {
    return '';
  }
}

export function normalizeDescription(description) {
  if (description == null) return null;
  const compact = String(description)
    .trim()
    .replace(/[\u0000-\u001f\u007f]+/g, ' ')
    .replace(/[-_/]+/g, ' ')
    .replace(/\s+/g, ' ')
    .slice(0, MAX_DESCRIPTION_LENGTH)
    .trim();
  return compact || null;
}

export function formatHolder(record) {
  const work = record.description ? `; work: ${record.description}` : '';
  return `held by ${record.agent} (pid ${record.pid}) on ${record.hostname} since ${record.acquiredAt}${work}`;
}

function refusalResult(path, holder, reason) {
  return {
    ok: false,
    state: 'refused',
    path,
    holder,
    reason,
    suggestion: BLOCKED_DIRECTORY_SUGGESTION,
  };
}

function buildRecord({ realpath, pid, agent, session, owner, description }) {
  return {
    realpath,
    pid,
    agent: agent || 'unknown',
    session: session || null,
    owner: owner || null,
    description: normalizeDescription(description),
    hostname: hostname(),
    nonce: randomBytes(8).toString('hex'),
    acquiredAt: new Date().toISOString(),
  };
}

function readRecord(path) {
  try {
    const rec = JSON.parse(readFileSync(path, 'utf8'));
    if (!rec || typeof rec !== 'object' || typeof rec.pid !== 'number') return null;
    return rec;
  } catch {
    return null;
  }
}

const SLEEP_SLOT = new Int32Array(new SharedArrayBuffer(4));

function sleepMs(ms) {
  Atomics.wait(SLEEP_SLOT, 0, 0, ms);
}

// allow-comment: a partial write makes the record briefly unreadable; retry that, but treat a record still unreadable past the window as genuinely corrupt
function readRecordStable(path) {
  for (let i = 0; i < STABLE_READ_TRIES; i++) {
    const rec = readRecord(path);
    if (rec) return rec;
    if (!existsSync(path)) return null;
    sleepMs(STABLE_READ_SLEEP_MS);
  }
  return null;
}

function ageExceeded(record, maxAgeHours) {
  if (!maxAgeHours || maxAgeHours <= 0) return false;
  const acquired = Date.parse(record.acquiredAt);
  if (Number.isNaN(acquired)) return false;
  return Date.now() - acquired > maxAgeHours * 3600 * 1000;
}

function classifyHolder(record, maxAgeHours) {
  const sameHost = record.hostname === hostname();
  const alive = sameHost ? isAlive(record.pid) : null;
  if (sameHost) {
    if (!alive) return { breakable: true, reason: 'holder-dead', alive };
    if (ageExceeded(record, maxAgeHours)) return { breakable: true, reason: 'age-cap', alive };
    return { breakable: false, reason: 'holder-alive', alive };
  }
  if (ageExceeded(record, maxAgeHours)) return { breakable: true, reason: 'age-cap-foreign-host', alive };
  return { breakable: false, reason: 'foreign-host', alive };
}

function sameOwner(existing, incoming) {
  return existing.owner
    && incoming.owner
    && existing.owner === incoming.owner
    && existing.agent === incoming.agent;
}

function legacyCodexResume(existing, incoming, enabled) {
  return enabled
    && !existing.owner
    && incoming.owner
    && existing.agent === 'codex'
    && incoming.agent === 'codex'
    && existing.hostname !== hostname();
}

function inspectExisting(path, incoming, maxAgeHours, legacyCodexResumeEnabled) {
  const existing = readRecordStable(path);
  if (!existing) {
    return existsSync(path) ? { action: 'break', reason: 'corrupt' } : { action: 'retry' };
  }
  if (existing.hostname === hostname() && existing.pid === incoming.pid) {
    return { action: 'held-by-self', holder: existing };
  }
  if (sameOwner(existing, incoming)) {
    return { action: 'reclaim-by-owner', reason: 'same-owner', previous: existing };
  }
  if (legacyCodexResume(existing, incoming, legacyCodexResumeEnabled)) {
    return { action: 'reclaim-by-owner', reason: 'legacy-codex-resume', previous: existing };
  }
  const decision = classifyHolder(existing, maxAgeHours);
  return decision.breakable
    ? { action: 'break', reason: decision.reason, previous: existing }
    : { action: 'refuse', reason: decision.reason, holder: existing };
}

export function claim({ dir, pid, agent, session, owner, description, maxAgeHours, legacyCodexResume: legacyCodexResumeEnabled }) {
  const realpath = occupancyRoot(dir);
  if (isExcluded(realpath)) return { ok: true, state: 'excluded', path: null, realpath };
  const path = lockPathForRealpath(realpath);
  // allow-comment: re-claiming a lock this same process already holds keeps its original description, so the mandatory-description gate must skip held-by-self; only creating or taking over a lock demands a fresh description.
  const priorHold = readRecordStable(path);
  if (priorHold && priorHold.hostname === hostname() && priorHold.pid === pid) {
    return { ok: true, state: 'held-by-self', path, holder: priorHold };
  }
  if (!normalizeDescription(description)) {
    throw new Error('a work description is required: run `dibs claim <dir> --description "<the change you are making here>"`. Name the change, not the activity, because whoever finds this lock weeks from now reads it to decide whether the work finished: "revert the stop-release trigger" passes, "session work" tells them nothing. A non-interactive runner that knows its task up front may pass it in DIBS_DESCRIPTION for that run; a value pinned once for every session makes every lock read alike and is worse than none. dibs will not create an anonymous lock.');
  }
  ensureLocksDir();
  const record = buildRecord({ realpath, pid, agent, session, owner, description });
  const json = JSON.stringify(record, null, 2);
  let displaced = null;
  let displacedState = null;
  for (let attempt = 0; attempt < MAX_CLAIM_ATTEMPTS; attempt++) {
    try {
      // allow-comment: the exclusive wx create is the sole arbiter; do not relax it to an overwrite
      writeFileSync(path, json, { flag: 'wx' });
      if (displacedState === 'reclaimed-by-owner') return { ok: true, state: 'reclaimed-by-owner', path, holder: record, reclaimed: displaced };
      return displaced
        ? { ok: true, state: 'took-over-stale', path, holder: record, brokeStale: displaced }
        : { ok: true, state: 'claimed', path, holder: record };
    } catch (err) {
      if (err.code !== 'EEXIST') throw err;
    }
    const verdict = inspectExisting(path, record, maxAgeHours, legacyCodexResumeEnabled);
    if (verdict.action === 'held-by-self') {
      return { ok: true, state: 'held-by-self', path, holder: verdict.holder };
    }
    if (verdict.action === 'refuse') {
      return refusalResult(path, verdict.holder, verdict.reason);
    }
    if (verdict.action === 'break') {
      rmSync(path, { force: true });
      displaced = { reason: verdict.reason, previous: verdict.previous };
      displacedState = 'took-over-stale';
    }
    if (verdict.action === 'reclaim-by-owner') {
      rmSync(path, { force: true });
      displaced = { reason: verdict.reason, previous: verdict.previous };
      displacedState = 'reclaimed-by-owner';
    }
  }
  const finalHolder = readRecordStable(path);
  if (!finalHolder) return refusalResult(path, null, 'contended');
  return refusalResult(path, finalHolder, classifyHolder(finalHolder, maxAgeHours).reason);
}

export function release({ dir, pid, nonce, session, owner, agent }) {
  const path = lockPathForRealpath(occupancyRoot(dir));
  const existing = readRecordStable(path);
  if (!existing) return { ok: true, state: 'not-held', path };
  const holderIdentityMatches = existing.pid === pid
    || heldBySelf(existing, { session, owner, agent }).self;
  const mine = existing.hostname === hostname()
    && holderIdentityMatches
    && (nonce === undefined || existing.nonce === nonce);
  if (mine) {
    rmSync(path, { force: true });
    return { ok: true, state: 'released', path, holder: existing };
  }
  return { ok: false, state: 'held-by-other', path, holder: existing };
}

// allow-comment: release-all selectors narrow one holder identity together. Treating them as alternatives let a stable owner override an explicit pid and sweep locks from other resumed sessions. Host-gated because pid/session ids carry no meaning across hosts.
function recordMatchesSelector(record, { pid, session, owner, agent }) {
  if (record.hostname !== hostname()) return false;
  if (pid != null && record.pid !== pid) return false;
  if (session != null && record.session !== session) return false;
  if (owner != null && agent != null && (record.owner !== owner || record.agent !== agent)) return false;
  return true;
}

export function releaseAll({ pid, session, owner, agent }) {
  const selector = { pid, session, owner, agent };
  const hasSelector = pid != null || session != null || (owner != null && agent != null);
  if (!hasSelector) throw new Error('release-all needs a --pid, --session, or --owner with --agent to identify the locks to release');
  const dir = locksDir();
  const released = [];
  if (!existsSync(dir)) return { ok: true, state: 'released-all', released, count: 0 };
  for (const entry of readdirSync(dir)) {
    if (!entry.endsWith('.lock')) continue;
    const path = join(dir, entry);
    const record = readRecordStable(path);
    if (!record || !recordMatchesSelector(record, selector)) continue;
    rmSync(path, { force: true });
    released.push({ path, realpath: record.realpath, holder: record });
  }
  return { ok: true, state: 'released-all', released, count: released.length };
}

// allow-comment: load-bearing contract. The single answer to "is this lock mine". A session id names one conversation and is checked first; an owner names the seat that conversation runs in, so it also recognises a resume with a fresh session id, but only for the same agent, since two agents can share a seat. Callers must not re-derive this from the holder record: a second opinion about identity is how a hook and the CLI came to disagree about who held a directory.
export function heldBySelf(holder, { session, owner, agent } = {}) {
  if (!holder) return { self: false, reason: 'no-holder' };
  if (!session && !owner) return { self: false, reason: 'no-identity' };
  if (session && holder.session && session === holder.session) return { self: true, reason: 'session' };
  if (owner && holder.owner && owner === holder.owner && agent === holder.agent) {
    return { self: true, reason: 'owner' };
  }
  return { self: false, reason: 'other-session' };
}

export function check({ dir, maxAgeHours, session, owner, agent }) {
  const realpath = occupancyRoot(dir);
  if (isExcluded(realpath)) return { state: 'excluded', path: null, realpath };
  const path = lockPathForRealpath(realpath);
  const existing = readRecordStable(path);
  if (!existing) {
    return existsSync(path)
      ? { state: 'corrupt', path, realpath }
      : { state: 'free', path, realpath };
  }
  const decision = classifyHolder(existing, maxAgeHours);
  const mine = heldBySelf(existing, { session, owner, agent });
  return {
    state: 'held',
    path,
    realpath,
    holder: existing,
    sameHost: existing.hostname === hostname(),
    alive: decision.alive,
    stale: decision.breakable,
    self: mine.self,
    selfReason: mine.reason,
  };
}
