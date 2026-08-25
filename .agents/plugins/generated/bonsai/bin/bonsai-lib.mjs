import { existsSync, mkdirSync, writeFileSync, readFileSync, copyFileSync, readdirSync, statSync, realpathSync } from 'node:fs';
import { basename, join, resolve, dirname, sep } from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath, pathToFileURL } from 'node:url';

function parseVersionName(name) {
  const match = /^(\d+)\.(\d+)\.(\d+)(?:[-+].*)?$/.exec(name);
  if (!match) return null;
  return match.slice(1).map((part) => Number(part));
}

function compareVersionNames(left, right) {
  const leftParts = parseVersionName(left);
  const rightParts = parseVersionName(right);
  if (!leftParts || !rightParts) return left.localeCompare(right);
  for (let index = 0; index < leftParts.length; index += 1) {
    const diff = leftParts[index] - rightParts[index];
    if (diff) return diff;
  }
  return left.localeCompare(right);
}

function currentPluginRoot() {
  try {
    let dir = dirname(fileURLToPath(import.meta.url));
    while (true) {
      const hasManifest = existsSync(join(dir, '.claude-plugin', 'plugin.json')) || existsSync(join(dir, '.codex-plugin', 'plugin.json'));
      if (hasManifest) return dir;
      const parent = dirname(dir);
      if (parent === dir) return null;
      dir = parent;
    }
  } catch {
    return null;
  }
}

function sourcePeerFiles(peerName, relativeParts) {
  const pluginRoot = currentPluginRoot();
  if (!pluginRoot || parseVersionName(basename(pluginRoot))) return [];
  const file = join(dirname(pluginRoot), peerName, ...relativeParts);
  return existsSync(file) ? [file] : [];
}

function installedPeerFiles(peerName, relativeParts) {
  try {
    const pluginRoot = currentPluginRoot();
    if (!pluginRoot || !parseVersionName(basename(pluginRoot))) return [];
    const marketplaceDir = dirname(dirname(pluginRoot));
    const peerRoot = join(marketplaceDir, peerName);
    if (!existsSync(peerRoot)) return [];
    return readdirSync(peerRoot, { withFileTypes: true })
      .filter((entry) => entry.isDirectory() && parseVersionName(entry.name))
      .map((entry) => ({ version: entry.name, file: join(peerRoot, entry.name, ...relativeParts) }))
      .filter((candidate) => existsSync(candidate.file))
      .sort((left, right) => compareVersionNames(right.version, left.version))
      .map((candidate) => candidate.file);
  } catch {
    return [];
  }
}

function dibsLibCandidates() {
  if (process.env.DIBS_LIB) return [process.env.DIBS_LIB];
  return [
    ...sourcePeerFiles('dibs', ['bin', 'dibs-lib.mjs']),
    ...installedPeerFiles('dibs', ['bin', 'dibs-lib.mjs']),
  ];
}

async function loadDibs() {
  for (const candidate of dibsLibCandidates()) {
    if (!existsSync(candidate)) continue;
    try {
      return { mod: await import(pathToFileURL(candidate).href) };
    } catch (err) {
      return { mod: null, error: err };
    }
  }
  return { mod: null };
}

export async function claimWorktreeLock(dir, description) {
  const { mod: dibs, error } = await loadDibs();
  if (!dibs) {
    const warning = error
      ? `dibs present but failed to load (${error.message.split('\n')[0]}); worktree handed out without an occupancy lock`
      : 'dibs not available; worktree handed out without an occupancy lock';
    return { ok: false, state: error ? 'error' : 'unavailable', warning };
  }
  const pid = process.env.DIBS_HOLDER_PID ? Number(process.env.DIBS_HOLDER_PID) : process.ppid;
  try {
    // The branch name says which change this worktree exists for, so it beats
    // DIBS_DESCRIPTION, which a caller may have pinned session-wide and which
    // then labels every worktree alike. The env var stays the fallback for a
    // caller that hands out a worktree without naming its branch.
    const result = dibs.claim({ dir, pid, agent: process.env.DIBS_AGENT || 'bonsai', session: process.env.DIBS_SESSION, owner: process.env.DIBS_OWNER, description: description || process.env.DIBS_DESCRIPTION });
    if (!result.ok && result.holder) {
      return { ...result, warning: `worktree directory already ${dibs.formatHolder(result.holder)}` };
    }
    return result;
  } catch (err) {
    return { ok: false, state: 'error', warning: `dibs claim failed: ${err.message.split('\n')[0]}` };
  }
}

function executableOnPath(name, env = process.env) {
  const pathValue = env.PATH || '';
  for (const dir of pathValue.split(sep === '\\' ? ';' : ':')) {
    if (!dir) continue;
    const candidate = join(dir, name);
    if (existsSync(candidate)) return candidate;
  }
  return null;
}

function vaultsyncCliCandidates(env = process.env) {
  return [
    env.VAULTSYNC_BIN,
    ...sourcePeerFiles('vaultsync', ['bin', 'vaultsync']),
    ...installedPeerFiles('vaultsync', ['bin', 'vaultsync']),
    executableOnPath('vaultsync', env),
  ].filter(Boolean);
}

export function vaultsyncManagedStatus(root, env = process.env) {
  for (const candidate of vaultsyncCliCandidates(env)) {
    if (!existsSync(candidate)) continue;
    try {
      const output = execFileSync(candidate, ['managed', root, '--json'], {
		encoding: 'utf8',
		env: { ...process.env, ...env },
		stdio: ['ignore', 'pipe', 'pipe'],
      });
      return JSON.parse(output);
    } catch {}
  }
  return { managed: false, root, unavailable: true };
}

export function git(repo, args) {
  return execFileSync('git', args, { cwd: repo, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] });
}

export function isGitRepo(repo) {
  try {
    git(repo, ['rev-parse', '--is-inside-work-tree']);
    return true;
  } catch {
    return false;
  }
}

export function branchToDir(branch) {
  return branch.replace(/\//g, '-');
}

// allow-comment: documents the git contract this relies on. `git worktree list` always lists the main worktree first, so a linked-worktree --repo still anchors new worktrees under <main>/worktrees/ instead of nesting them.
export function mainWorktree(repo) {
  try {
    const out = git(repo, ['worktree', 'list', '--porcelain']);
    const first = out.split('\n').find((l) => l.startsWith('worktree '));
    if (first) return first.slice('worktree '.length);
  } catch {}
  return resolve(repo);
}

// Deterministic dev-server port hint in [3100, 3999]. Cross-platform and
// dependency-free; the value is a hint, not a guarantee of freeness.
export function computePort(name) {
  let h = 5381;
  for (let i = 0; i < name.length; i++) h = ((h << 5) + h + name.charCodeAt(i)) >>> 0;
  return 3100 + (h % 900);
}

function refExists(repo, ref) {
  try {
    git(repo, ['rev-parse', '--verify', '--quiet', ref]);
    return true;
  } catch {
    return false;
  }
}

function remoteDefaultBranch(repo, remote = 'origin') {
  try {
    const ref = git(repo, ['symbolic-ref', '--quiet', '--short', `refs/remotes/${remote}/HEAD`]).trim();
    const prefix = `${remote}/`;
    return ref.startsWith(prefix) ? ref.slice(prefix.length) : ref || null;
  } catch {
    return null;
  }
}

function configuredDefaultBranch(repo) {
  let configured;
  try {
    configured = git(repo, ['config', '--get', 'init.defaultBranch']).trim();
  } catch {
    return null;
  }
  return configured && refExists(repo, `refs/heads/${configured}`) ? configured : null;
}

export function defaultBranch(repo) {
  const remoteDefault = remoteDefaultBranch(repo);
  if (remoteDefault) return remoteDefault;
  return configuredDefaultBranch(repo);
}

export function resolveBase(repo) {
  const def = defaultBranch(repo);
  if (!def) throw new Error(`cannot determine the default branch for ${repo} from origin/HEAD or init.defaultBranch`);
  const localRef = `refs/heads/${def}`;
  const remoteRef = `refs/remotes/origin/${def}`;
  const hasLocal = refExists(repo, localRef);
  const hasRemote = refExists(repo, remoteRef);
  if (!hasLocal && hasRemote) return `origin/${def}`;
  if (!hasLocal) return 'HEAD';
  if (!hasRemote) return def;
  try {
    const counts = git(repo, ['rev-list', '--left-right', '--count', `${localRef}...${remoteRef}`]).trim();
    const [ahead, behind] = counts.split(/\s+/).map((n) => parseInt(n, 10));
    return ahead === 0 && behind > 0 ? `origin/${def}` : def;
  } catch {
    return def;
  }
}

export async function createWorktree({ repo, branch, base, dir }) {
  if (!isGitRepo(repo)) {
    throw new Error(`${repo} is not a git repository`);
  }
  if (!branch || !branch.trim() || branch.includes('..') || /\s/.test(branch)) {
    throw new Error(`invalid branch name ${JSON.stringify(branch)}`);
  }
  const dirName = dir ? branchToDir(dir) : branchToDir(branch);
  if (!dirName || dirName.includes('..') || /\s/.test(dirName)) {
    throw new Error(`invalid worktree dir name ${JSON.stringify(dir)}`);
  }
  const root = mainWorktree(repo);
  const vaultsyncStatus = vaultsyncManagedStatus(root);
  if (vaultsyncStatus.managed) {
    throw new Error(`vaultsync manages ${root}; bonsai does not create worktrees for vaultsync checkouts`);
  }
  const resolvedBase = base || resolveBase(root);
  const baseSha = git(root, ['rev-parse', resolvedBase]).trim();
  const worktreesDir = join(root, 'worktrees');
  mkdirSync(worktreesDir, { recursive: true });
  const gitignore = join(worktreesDir, '.gitignore');
  if (!existsSync(gitignore)) writeFileSync(gitignore, '*\n');
  const worktree = join(worktreesDir, dirName);
  if (refExists(root, `refs/heads/${branch}`)) {
    throw new Error(`branch ${branch} already exists in ${root}; wrap and tear down that work first, never a numbered branch`);
  }
  git(root, ['worktree', 'add', '-b', branch, worktree, resolvedBase]);
  const lock = await claimWorktreeLock(worktree, branch);
  return { worktree, branch, base: resolvedBase, baseSha, port: computePort(dirName), lock };
}

const INSTALL_COMMANDS = {
  yarn: ['yarn', ['install', '--frozen-lockfile']],
  pnpm: ['pnpm', ['install', '--frozen-lockfile']],
  bun: ['bun', ['install']],
  npm: ['npm', ['install']],
  bundler: ['bundle', ['install']],
};

function readBonsaiList(repo) {
  const file = join(repo, '.bonsai');
  if (!existsSync(file)) return [];
  return readFileSync(file, 'utf8')
    .split(/\r?\n/)
    .map((l) => l.trim())
    .filter((l) => l && !l.startsWith('#'));
}

export function detectInstalls(worktree) {
  const dirs = [worktree];
  for (const name of readdirSync(worktree)) {
    if (name === 'node_modules') continue;
    const p = join(worktree, name);
    try {
      if (statSync(p).isDirectory()) dirs.push(p);
    } catch {}
  }
  const installs = [];
  for (const dir of dirs) {
    if (existsSync(join(dir, 'package.json'))) {
      const manager = existsSync(join(dir, 'yarn.lock')) ? 'yarn'
        : existsSync(join(dir, 'pnpm-lock.yaml')) ? 'pnpm'
        : (existsSync(join(dir, 'bun.lock')) || existsSync(join(dir, 'bun.lockb'))) ? 'bun'
        : 'npm';
      installs.push({ dir, manager });
    }
    if (existsSync(join(dir, 'Gemfile'))) installs.push({ dir, manager: 'bundler' });
  }
  return installs;
}

export function setupWorktree({ repo, worktree, install = true, exec = execFileSync }) {
  if (!existsSync(worktree)) throw new Error(`worktree ${worktree} does not exist`);
  const copied = [];
  const warnings = [];
  const worktreeAbs = resolve(worktree);
  for (const rel of readBonsaiList(repo)) {
    const to = resolve(worktree, rel);
    if (to !== worktreeAbs && !to.startsWith(worktreeAbs + sep)) {
      warnings.push(`skipped ${rel}: escapes the worktree`);
      continue;
    }
    const from = join(repo, rel);
    if (!existsSync(from)) continue;
    try {
      mkdirSync(dirname(to), { recursive: true });
      copyFileSync(from, to);
      copied.push(rel);
    } catch (err) {
      warnings.push(`copy ${rel} failed: ${err.message.split('\n')[0]}`);
    }
  }
  const installs = detectInstalls(worktree);
  if (install) {
    for (const { dir, manager } of installs) {
      const [cmd, args] = INSTALL_COMMANDS[manager];
      try {
        exec(cmd, args, { cwd: dir, stdio: ['ignore', 'pipe', 'pipe'] });
      } catch (err) {
        warnings.push(`install in ${dir} via ${manager} failed: ${err.message.split('\n')[0]}`);
      }
    }
  }
  return { worktree, copied, installs, warnings };
}

// allow-comment: deliberately NOT resolveBase; resolveBase keeps the local ref unless origin is strictly ahead, which a stray local-ahead commit defeats, letting an already-merged branch read as unmerged at teardown.
function integrationBase(repo, def) {
  if (!def) return null;
  if (refExists(repo, `refs/remotes/origin/${def}`)) return `origin/${def}`;
  return refExists(repo, `refs/heads/${def}`) ? def : null;
}

function parseWorktrees(repo) {
  const out = git(repo, ['worktree', 'list', '--porcelain']);
  const entries = [];
  let cur = {};
  for (const line of out.split('\n')) {
    if (line.startsWith('worktree ')) {
      if (cur.path) entries.push(cur);
      cur = { path: line.slice('worktree '.length) };
    } else if (line.startsWith('branch ')) {
      cur.branch = line.slice('branch '.length).replace('refs/heads/', '');
    } else if (line === '' && cur.path) {
      entries.push(cur);
      cur = {};
    }
  }
  if (cur.path) entries.push(cur);
  return entries;
}

function isAncestor(repo, a, b) {
  try {
    git(repo, ['merge-base', '--is-ancestor', a, b]);
    return true;
  } catch {
    return false;
  }
}

function countRange(repo, range) {
  try {
    return parseInt(git(repo, ['rev-list', '--count', range]).trim(), 10) || 0;
  } catch {
    return 0;
  }
}

function branchPushed(repo, branch) {
  try {
    const up = git(repo, ['rev-parse', '--abbrev-ref', `${branch}@{upstream}`]).trim();
    if (!up) return false;
    return countRange(repo, `${up}..${branch}`) === 0;
  } catch {
    return false;
  }
}

function canonPath(p) {
  try {
    return realpathSync(p);
  } catch {
    return resolve(p);
  }
}

export function classifyTeardown({ repo, target }) {
  const worktrees = parseWorktrees(repo);
  const abs = canonPath(target);
  const guess = canonPath(join(repo, 'worktrees', target));
  let entry = worktrees.find((w) => canonPath(w.path) === abs)
    || worktrees.find((w) => w.branch === target)
    || worktrees.find((w) => canonPath(w.path) === guess);
  if (!entry) throw new Error(`no worktree or branch matching ${target} in ${repo}`);
  const { path: worktree, branch } = entry;
  const def = defaultBranch(repo);
  if (!def) throw new Error(`cannot determine the default branch for ${repo} from origin/HEAD or init.defaultBranch`);
  const base = integrationBase(repo, def);
  const dirty = git(worktree, ['status', '--porcelain']).trim().length > 0;
  const mergedIntoBase = base && branch ? isAncestor(repo, branch, base) : false;
  const mergedIntoLocalDefault = base !== def && branch && def && refExists(repo, `refs/heads/${def}`) ? isAncestor(repo, branch, def) : false;
  const integrated = mergedIntoBase || mergedIntoLocalDefault;
  const ahead = base && branch ? countRange(repo, `${base}..${branch}`) : 0;
  const behind = base && branch ? countRange(repo, `${branch}..${base}`) : 0;
  const pushed = branch ? branchPushed(repo, branch) : false;
  const removable = integrated || (!dirty && ahead === 0);
  const warnings = [];
  if (!integrated && ahead > 0 && !pushed) warnings.push(`${ahead} unpushed commit(s) ahead of ${base} would be orphaned by removal`);
  if (!integrated && behind > 0) warnings.push(`${base} advanced by ${behind} commit(s) since this branch; rebase before wrap`);
  if (dirty) warnings.push('worktree has uncommitted changes');
  if (branch && worktrees.filter((w) => w.branch === branch).length > 1) {
    warnings.push(`branch ${branch} is checked out in more than one worktree`);
  }
  return { worktree, branch, integrated, dirty, ahead, behind, pushed, removable, warnings };
}

function keptReasonFor(c) {
  if (c.dirty) return 'worktree has uncommitted changes; commit them or pass --force';
  if (!c.integrated && c.ahead > 0) return `branch has ${c.ahead} unmerged commit(s); wrap them or pass --force`;
  return 'not integrated and not safe to drop; pass --force to override';
}

export function teardownWorktree({ repo, target, force = false, dryRun = false }) {
  const c = classifyTeardown({ repo, target });
  const base = { worktree: c.worktree, branch: c.branch, removable: c.removable, warnings: c.warnings };
  if (dryRun) return { ...base, removed: false, keptReason: c.removable ? null : keptReasonFor(c) };
  if (!c.removable && !force) return { ...base, removed: false, keptReason: keptReasonFor(c) };
  git(repo, ['worktree', 'remove', ...(force ? ['--force'] : []), c.worktree]);
  if (c.branch) {
    try {
      git(repo, ['branch', (force || c.integrated) ? '-D' : '-d', c.branch]);
    } catch (err) {
      base.warnings.push(`worktree removed but branch ${c.branch} was not deleted: ${err.message.split('\n')[0]}`);
    }
  }
  return { ...base, removed: true, keptReason: null };
}
