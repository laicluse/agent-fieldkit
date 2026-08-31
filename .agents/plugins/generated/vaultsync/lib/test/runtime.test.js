import { after, before, it } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, readFileSync, realpathSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { tmpdir } from 'node:os';
import { execFileSync, spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import {
  DEFAULT_PAUSE_MINUTES,
  acquireDaemonLease,
  commitNarrative,
  fallbackCommitMessage,
  findDibsBin,
  launchAgentNeedsReconciliation,
  launchAgentPlist,
  preflightRepository,
  probeLlmCommand,
  registrationPathForRoot,
  repoKey,
  resolveGitRoot,
  vaultsyncDaemonPids,
} from '../runtime.mjs';

let tmp;

before(() => {
  tmp = mkdtempSync(join(tmpdir(), 'vaultsync-test-'));
});

after(() => {
  rmSync(tmp, { recursive: true, force: true });
});

function git(cwd, args) {
  return execFileSync('git', args, {
    cwd,
    encoding: 'utf8',
    env: {
      ...process.env,
      GIT_AUTHOR_NAME: 'Vaultsync Test',
      GIT_AUTHOR_EMAIL: 'vaultsync@example.invalid',
      GIT_COMMITTER_NAME: 'Vaultsync Test',
      GIT_COMMITTER_EMAIL: 'vaultsync@example.invalid',
    },
  }).trim();
}

function createRepo(name) {
  const dir = join(tmp, name);
  mkdirSync(dir);
  git(dir, ['init', '-q']);
  writeFileSync(join(dir, 'README.md'), '# Test\n');
  git(dir, ['add', 'README.md']);
  git(dir, ['commit', '-q', '-m', 'Initial commit']);
  return dir;
}

function runNode(args, options = {}) {
  const result = spawnSync(process.execPath, args, {
    encoding: 'utf8',
    env: { ...process.env, ...(options.env || {}) },
    cwd: options.cwd || tmp,
  });
  if (result.status !== 0) {
    throw new Error([result.stdout, result.stderr].filter(Boolean).join('\n'));
  }
  return result;
}

function syncFixture(name) {
  const remote = join(tmp, `${name}-remote.git`);
  const local = join(tmp, `${name}-local`);
  git(tmp, ['init', '--bare', '-q', remote]);
  git(tmp, ['clone', '-q', remote, local]);
  writeFileSync(join(local, 'note.md'), '# Note\n');
  git(local, ['add', 'note.md']);
  git(local, ['commit', '-q', '-m', 'Initial commit']);
  git(local, ['push', '-q', '-u', 'origin', 'HEAD']);

  const fakeDibs = join(tmp, `${name}-dibs.mjs`);
  writeFileSync(fakeDibs, [
    '#!/usr/bin/env node',
    'const command = process.argv[2];',
    'if (command === "claim") process.stdout.write(JSON.stringify({ state: "claimed", holder: { nonce: "abc" } }));',
    'else if (command === "release") process.stdout.write(JSON.stringify({ state: "released" }));',
    'else if (command === "check") process.stdout.write(JSON.stringify({ state: "free" }));',
    'else process.exit(2);',
    '',
  ].join('\n'), { mode: 0o755 });

  const llm = join(tmp, `${name}-llm.mjs`);
  writeFileSync(llm, [
    '#!/usr/bin/env node',
    'let input = "";',
    'process.stdin.on("data", (chunk) => input += chunk);',
    'process.stdin.on("end", () => {',
    '  const payload = JSON.parse(input);',
    '  if (payload.task === "commit_message") process.stdout.write(JSON.stringify({ message: "Update vault note\\n\\nRecord the portable vault content.\\n\\nSlice: docs-only" }));',
    '  else if (payload.task === "resolve_conflict") process.stdout.write(JSON.stringify({ resolved: "Remote truth line.\\n" }));',
    '  else process.exit(2);',
    '});',
    '',
  ].join('\n'), { mode: 0o755 });

  const env = {
    LAICLUSE_HOME: join(tmp, `${name}-state`),
    DIBS_BIN: fakeDibs,
    HOME: join(tmp, `${name}-home`),
    GIT_AUTHOR_NAME: 'Vaultsync Test',
    GIT_AUTHOR_EMAIL: 'vaultsync@example.invalid',
    GIT_COMMITTER_NAME: 'Vaultsync Test',
    GIT_COMMITTER_EMAIL: 'vaultsync@example.invalid',
  };
  mkdirSync(env.HOME);
  const cli = fileURLToPath(new URL('../../bin/vaultsync', import.meta.url));
  runNode([cli, 'install', local, '--llm-command', `${process.execPath} ${llm}`, '--no-launchd'], { env });
  return { cli, env, local, remote };
}

it('provides Node on PATH to LaunchAgent child executables', () => {
  const child = join(tmp, 'launchd-child.mjs');
  writeFileSync(child, '#!/usr/bin/env node\nprocess.stdout.write("child-ready\\n");\n', { mode: 0o755 });
  const plist = launchAgentPlist({
    HOME: tmp,
    LAICLUSE_HOME: join(tmp, 'launchd-home'),
    PATH: '/usr/bin:/bin:/usr/sbin:/sbin',
  });
  const pathValue = plist.match(/<key>PATH<\/key>\s*<string>([^<]+)<\/string>/)?.[1];

  assert.ok(pathValue, 'LaunchAgent plist must define PATH for child executables');
  assert.ok(pathValue.split(':').includes(dirname(process.execPath)));

  const result = spawnSync(child, [], {
    encoding: 'utf8',
    env: { HOME: tmp, PATH: pathValue },
  });
  assert.equal(result.status, 0, result.stderr);
  assert.equal(result.stdout, 'child-ready\n');
});

it('launches the daemon through the stable machine entrypoint', () => {
  const env = {
    HOME: join(tmp, 'stable-launcher-home'),
    LAICLUSE_HOME: join(tmp, 'stable-launcher-state'),
    VAULTSYNC_BIN_DIR: join(tmp, 'stable-launcher-bin'),
    PATH: '/usr/bin:/bin:/usr/sbin:/sbin',
  };
  const plist = launchAgentPlist(env);

  assert.match(plist, new RegExp(`<string>${join(env.VAULTSYNC_BIN_DIR, 'vaultsync')}</string>\\s*<string>daemon</string>`));
  assert.doesNotMatch(plist, /plugins\/cache/);
  assert.doesNotMatch(plist, new RegExp(`<string>${process.execPath}</string>`));
});

it('reconciles a published runtime until the LaunchAgent records that version', () => {
  const env = {
    HOME: join(tmp, 'launch-agent-version-home'),
    LAICLUSE_HOME: join(tmp, 'launch-agent-version-state'),
  };
  assert.equal(launchAgentNeedsReconciliation('2.0.21', env), true);
  const stateDir = join(env.LAICLUSE_HOME, 'vaultsync');
  mkdirSync(stateDir, { recursive: true });
  writeFileSync(join(stateDir, 'launch-agent.json'), '{"version":"2.0.21"}\n');
  assert.equal(launchAgentNeedsReconciliation('2.0.21', env), false);
  assert.equal(launchAgentNeedsReconciliation('2.0.22', env), true);
});

it('allows only one long-lived daemon to own a machine runtime', () => {
  const env = {
    HOME: join(tmp, 'daemon-lease-home'),
    LAICLUSE_HOME: join(tmp, 'daemon-lease-state'),
  };
  const first = acquireDaemonLease(env);
  assert.ok(first);
  assert.equal(acquireDaemonLease(env), null);
  first.release();
  const replacement = acquireDaemonLease(env);
  assert.ok(replacement);
  replacement.release();
});

it('identifies stale stable and versioned daemon processes without touching one-shot commands', () => {
  const env = {
    HOME: join(tmp, 'daemon-process-home'),
    LAICLUSE_HOME: join(tmp, 'daemon-process-state'),
    VAULTSYNC_BIN_DIR: join(tmp, 'daemon-process-bin'),
  };
  const stable = join(env.VAULTSYNC_BIN_DIR, 'vaultsync');
  const release = join(env.LAICLUSE_HOME, 'vaultsync', 'runtime', 'releases', '2.0.20', 'bin', 'vaultsync');
  const rows = [
    `101 node ${stable} daemon`,
    `102 node ${release} daemon`,
    `103 node ${release} daemon --once`,
    `104 node ${join(tmp, 'unrelated', 'vaultsync')} daemon`,
    `105 node ${stable} status`,
  ].join('\n');

  assert.deepEqual(vaultsyncDaemonPids(rows, env, 101), [102]);
});

it('keys registrations by the resolved Git worktree root', () => {
  const repo = createRepo('identity-main');
  mkdirSync(join(repo, 'notes'));
  const root = resolveGitRoot(join(repo, 'notes'), { PWD: repo, HOME: tmp, LAICLUSE_HOME: join(tmp, 'home') });
  assert.equal(root, realpathSync(repo));
  assert.equal(repoKey(root), repoKey(realpathSync(repo)));
  assert.equal(registrationPathForRoot(root, { HOME: tmp, LAICLUSE_HOME: join(tmp, 'home') }), join(tmp, 'home', 'vaultsync', 'registrations', `${repoKey(root)}.json`));
});

it('keeps linked worktrees isolated from the main checkout', () => {
  const repo = createRepo('identity-worktree-main');
  const linked = join(tmp, 'identity-worktree-linked');
  git(repo, ['worktree', 'add', '-q', linked, '-b', 'linked']);
  assert.notEqual(repoKey(resolveGitRoot(repo)), repoKey(resolveGitRoot(linked)));
});

it('allows repository preflight without a branch upstream', () => {
  const repo = createRepo('no-upstream');
  const preflight = preflightRepository(repo);
  assert.equal(preflight.branch, git(repo, ['rev-parse', '--abbrev-ref', 'HEAD']));
  assert.equal(preflight.upstream, null);
});

it('reports whether a checkout is managed through the public CLI', () => {
  const managed = createRepo('managed-query-managed');
  const unmanaged = createRepo('managed-query-unmanaged');
  const fakeDibs = join(tmp, 'managed-query-dibs.mjs');
  writeFileSync(fakeDibs, [
    '#!/usr/bin/env node',
    'const command = process.argv[2];',
    'if (command === "claim") process.stdout.write(JSON.stringify({ state: "claimed", holder: { nonce: "abc" } }));',
    'else if (command === "release") process.stdout.write(JSON.stringify({ state: "released" }));',
    'else if (command === "check") process.stdout.write(JSON.stringify({ state: "free" }));',
    'else process.exit(2);',
    '',
  ].join('\n'), { mode: 0o755 });
  const llm = join(tmp, 'managed-query-llm.mjs');
  writeFileSync(llm, [
    '#!/usr/bin/env node',
    'let input = "";',
    'process.stdin.on("data", (chunk) => input += chunk);',
    'process.stdin.on("end", () => {',
    '  const payload = JSON.parse(input);',
    '  if (payload.task === "resolve_conflict") process.stdout.write(JSON.stringify({ resolved: "Remote truth line.\\n" }));',
    '  else if (payload.task === "commit_message") process.stdout.write(JSON.stringify({ message: "Record managed query\\n\\nExercise the managed query contract.\\n\\nSlice: docs-only" }));',
    '  else process.exit(2);',
    '});',
    '',
  ].join('\n'), { mode: 0o755 });
  const cli = fileURLToPath(new URL('../../bin/vaultsync', import.meta.url));
  const env = {
    LAICLUSE_HOME: join(tmp, 'managed-query-home'),
    DIBS_BIN: fakeDibs,
    HOME: tmp,
  };
  runNode([cli, 'install', managed, '--llm-command', `${process.execPath} ${llm}`, '--no-launchd'], { env });

  const managedResult = JSON.parse(runNode([cli, 'managed', managed, '--json'], { env }).stdout);
  const unmanagedResult = JSON.parse(runNode([cli, 'managed', unmanaged, '--json'], { env }).stdout);

  assert.equal(managedResult.managed, true);
  assert.equal(managedResult.root, realpathSync(managed));
  assert.equal(unmanagedResult.managed, false);
  assert.equal(unmanagedResult.root, realpathSync(unmanaged));
});

it('checkpoints locally but waits to sync an SSH remote until its agent has identities', () => {
  const fixture = syncFixture('locked-ssh-agent');
  const fakeBin = join(tmp, 'locked-ssh-agent-bin');
  mkdirSync(fakeBin);
  writeFileSync(join(fakeBin, 'ssh'), [
    '#!/usr/bin/env node',
    'if (process.argv[2] === "-G") {',
    '  process.stdout.write("hostname locked-host\\nidentityagent /tmp/locked-agent.sock\\n");',
    '  process.exit(0);',
    '}',
    'process.exit(99);',
    '',
  ].join('\n'), { mode: 0o755 });
  writeFileSync(join(fakeBin, 'ssh-add'), '#!/usr/bin/env node\nprocess.exit(1);\n', { mode: 0o755 });
  git(fixture.local, ['remote', 'set-url', 'origin', 'vault@locked-host:notes.git']);
  const env = { ...fixture.env, PATH: `${fakeBin}:${process.env.PATH}` };
  const registrationPath = registrationPathForRoot(realpathSync(fixture.local), env);
  const registration = JSON.parse(readFileSync(registrationPath, 'utf8'));
  writeFileSync(registrationPath, `${JSON.stringify({ ...registration, debounceSeconds: 1, lastSeenDirtyAt: '2026-01-01T00:00:00Z' }, null, 2)}\n`);
  writeFileSync(join(fixture.local, 'note.md'), '# Note\n\nDurable while credentials are locked.\n');

  const daemonResult = JSON.parse(runNode([fixture.cli, 'daemon', '--once', '--json'], { env }).stdout);
  assert.equal(daemonResult[0].state, 'waiting-for-authentication');
  assert.equal(git(fixture.local, ['status', '--porcelain']), '');
  assert.equal(git(fixture.local, ['rev-list', '--left-right', '--count', 'HEAD...@{u}']), '1\t0');
  assert.throws(() => runNode([fixture.cli, 'now', fixture.local, '--json'], { env }), /fetch|remote|repository/i);
});

it('stores the registered pre-sync command during installation', () => {
  const local = createRepo('pre-sync-install');
  const fakeDibs = join(tmp, 'pre-sync-install-dibs.mjs');
  writeFileSync(fakeDibs, [
    '#!/usr/bin/env node',
    'const command = process.argv[2];',
    'if (command === "check") process.stdout.write(JSON.stringify({ state: "free" }));',
    'else process.stdout.write(JSON.stringify({ state: "released" }));',
    '',
  ].join('\n'), { mode: 0o755 });
  const llm = join(tmp, 'pre-sync-install-llm.mjs');
  writeFileSync(llm, [
    '#!/usr/bin/env node',
    'let input = "";',
    'process.stdin.on("data", (chunk) => input += chunk);',
    'process.stdin.on("end", () => {',
    '  const payload = JSON.parse(input);',
    '  if (payload.task === "resolve_conflict") process.stdout.write(JSON.stringify({ resolved: "Resolved.\\n" }));',
    '  else process.exit(2);',
    '});',
    '',
  ].join('\n'), { mode: 0o755 });
  const cli = fileURLToPath(new URL('../../bin/vaultsync', import.meta.url));
  const env = { LAICLUSE_HOME: join(tmp, 'pre-sync-install-state'), DIBS_BIN: fakeDibs, HOME: tmp };

  runNode([cli, 'install', local, '--llm-command', `${process.execPath} ${llm}`, '--pre-sync', 'tilt site', '--no-launchd'], { env });

  const registration = JSON.parse(readFileSync(registrationPathForRoot(realpathSync(local), env), 'utf8'));
  assert.equal(registration.preSyncCommand, 'tilt site');
});

it('formats a git-discipline-friendly fallback commit message', () => {
  const message = fallbackCommitMessage('debounce');
  assert.match(message, /^Sync vault content\n\n/);
  assert.match(message, /Tests: n\/a \(docs-only\)/);
  assert.match(message, /Slice: docs-only/);
  assert.match(message, /Red-then-green: n\/a \(no executable behaviour changed\)/);
  assert.match(message, /Vaultsync-Reason: debounce/);
});

it('records a changed HTML viewer as visual commit evidence', () => {
  const message = fallbackCommitMessage('manual', ['0 System/viewer.html']);
  assert.match(message, /^Visual: 0 System\/viewer\.html$/m);
});

it('makes fallback commit reasoning specific to the staged content', () => {
  const first = fallbackCommitMessage('debounce', ['note.md'], '+first revision\n');
  const second = fallbackCommitMessage('debounce', ['note.md'], '+second revision\n');

  assert.notEqual(first, second);
  assert.match(first, /1 changed vault path/);
  assert.ok(first.split('\n').every((line) => line.length <= 72));
});

it('falls back when an LLM repeats a recent commit narrative', () => {
  const fixture = syncFixture('repeated-commit-narrative');
  const llm = join(tmp, 'repeated-commit-narrative-llm.mjs');
  writeFileSync(llm, [
    '#!/usr/bin/env node',
    'let input = "";',
    'process.stdin.on("data", (chunk) => input += chunk);',
    'process.stdin.on("end", () => {',
    '  const payload = JSON.parse(input);',
    '  if (payload.task === "commit_message") process.stdout.write(JSON.stringify({ message: "Record vault changes" }));',
    '  else if (payload.task === "resolve_conflict") process.stdout.write(JSON.stringify({ resolved: "Remote truth line.\\n" }));',
    '  else process.exit(2);',
    '});',
    '',
  ].join('\n'), { mode: 0o755 });
  const registrationPath = registrationPathForRoot(realpathSync(fixture.local), fixture.env);
  const registration = JSON.parse(readFileSync(registrationPath, 'utf8'));
  writeFileSync(registrationPath, `${JSON.stringify({ ...registration, llmCommand: `${process.execPath} ${llm}` }, null, 2)}\n`);
  writeFileSync(join(fixture.local, '.git', 'hooks', 'commit-msg'), [
    '#!/bin/sh',
    'narrative="This sync records the local vault changes before reconciling with the remote truth."',
    'if grep -Fq "$narrative" "$1" && git log -5 --format=%B | grep -Fq "$narrative"; then',
    '  echo "git-discipline: duplicate-why: commit narrative duplicates the previous sync" >&2',
    '  exit 1',
    'fi',
    '',
  ].join('\n'), { mode: 0o755 });

  writeFileSync(join(fixture.local, 'first.md'), '# First\n\nFirst generated change.\n');
  runNode([fixture.cli, 'now', fixture.local, '--json'], { env: fixture.env });
  for (const [name, body] of [['middle-a.md', 'First intervening change.'], ['middle-b.md', 'Second intervening change.']]) {
    writeFileSync(join(fixture.local, name), `# Intervening\n\n${body}\n`);
    git(fixture.local, ['add', name]);
    git(fixture.local, [
      'commit', '-q',
      '-m', `Add ${name}`,
      '-m', body,
      '-m', 'Tests: n/a (test fixture)',
      '-m', 'Slice: docs-only',
    ]);
  }
  git(fixture.local, ['push', '-q']);
  writeFileSync(join(fixture.local, 'second.md'), '# Second\n\nSecond generated change.\n');
  runNode([fixture.cli, 'now', fixture.local, '--json'], { env: fixture.env });

  assert.equal(git(fixture.local, ['log', '-1', '--format=%s']), 'Sync vault content');
  assert.equal(git(fixture.local, ['rev-list', '--left-right', '--count', 'HEAD...@{u}']), '0\t0');
});

it('excludes the complete Git trailer block from commit narratives', () => {
  const first = [
    'Record vault changes',
    '',
    'Preserve the same substantive reason.',
    '',
    'Verified: first verifier',
    ' continuation detail',
  ].join('\n');
  const second = [
    'Use another subject',
    '',
    'Preserve the same substantive reason.',
    '',
    'Verified-how:second verifier',
    'Visual: viewer.html',
  ].join('\n');

  assert.equal(commitNarrative(first), commitNarrative(second));
});

it('finds dibs through DIBS_BIN first', () => {
  const fake = join(tmp, 'fake-dibs');
  writeFileSync(fake, '#!/bin/sh\nexit 0\n', { mode: 0o755 });
  assert.equal(findDibsBin({ DIBS_BIN: fake, PATH: '' }), fake);
});

it('finds the newest dibs executable in the local plugin cache', () => {
  const home = join(tmp, 'plugin-cache-home');
  const oldDibs = join(home, '.codex', 'plugins', 'cache', 'laicluse-agent-fieldkit', 'dibs', '2.0.30', 'bin', 'dibs');
  const currentDibs = join(home, '.codex', 'plugins', 'cache', 'laicluse-agent-fieldkit', 'dibs', '2.0.31', 'bin', 'dibs');
  mkdirSync(dirname(oldDibs), { recursive: true });
  mkdirSync(dirname(currentDibs), { recursive: true });
  writeFileSync(oldDibs, '#!/bin/sh\nexit 0\n', { mode: 0o755 });
  writeFileSync(currentDibs, '#!/bin/sh\nexit 0\n', { mode: 0o755 });

  assert.equal(findDibsBin({ HOME: home, PATH: '' }), currentDibs);
});

it('probes the mandatory conflict resolver contract', () => {
  const helper = join(tmp, 'llm-helper.mjs');
  writeFileSync(helper, [
    '#!/usr/bin/env node',
    'let input = "";',
    'process.stdin.on("data", (chunk) => input += chunk);',
    'process.stdin.on("end", () => {',
    '  const payload = JSON.parse(input);',
    '  if (payload.task !== "resolve_conflict") process.exit(2);',
    '  process.stdout.write(JSON.stringify({ resolved: "Remote truth line.\\n" }));',
    '});',
    '',
  ].join('\n'), { mode: 0o755 });
  assert.equal(probeLlmCommand(`node ${helper}`, tmp), true);
});

it('keeps the default pause window at two hours', () => {
  assert.equal(DEFAULT_PAUSE_MINUTES, 120);
});

it('ignores a stale registered dibs path when a current dibs is discoverable', () => {
  const local = createRepo('stale-dibs');

  const installDibs = join(tmp, 'stale-install-dibs.mjs');
  writeFileSync(installDibs, [
    '#!/usr/bin/env node',
    'const command = process.argv[2];',
    'if (command === "claim") process.stdout.write(JSON.stringify({ state: "claimed", holder: { nonce: "abc" } }));',
    'else if (command === "release") process.stdout.write(JSON.stringify({ state: "released" }));',
    'else if (command === "check") process.stdout.write(JSON.stringify({ state: "free" }));',
    'else process.exit(2);',
    '',
  ].join('\n'), { mode: 0o755 });
  const pathDibsDir = join(tmp, 'stale-path-bin');
  mkdirSync(pathDibsDir);
  const pathDibs = join(pathDibsDir, 'dibs');
  writeFileSync(pathDibs, readFileSync(installDibs, 'utf8'), { mode: 0o755 });
  const llm = join(tmp, 'stale-llm.mjs');
  writeFileSync(llm, [
    '#!/usr/bin/env node',
    'let input = "";',
    'process.stdin.on("data", (chunk) => input += chunk);',
    'process.stdin.on("end", () => {',
    '  const payload = JSON.parse(input);',
    '  if (payload.task === "commit_message") process.stdout.write(JSON.stringify({ message: "Record stale dibs recovery\\n\\nCapture the vault edit after resolving dibs dynamically.\\n\\nSlice: docs-only" }));',
    '  else if (payload.task === "resolve_conflict") process.stdout.write(JSON.stringify({ resolved: "Remote truth line.\\n" }));',
    '  else process.exit(2);',
    '});',
    '',
  ].join('\n'), { mode: 0o755 });
  const cli = fileURLToPath(new URL('../../bin/vaultsync', import.meta.url));
  const env = {
    LAICLUSE_HOME: join(tmp, 'stale-home'),
    DIBS_BIN: installDibs,
    HOME: tmp,
    GIT_AUTHOR_NAME: 'Vaultsync Test',
    GIT_AUTHOR_EMAIL: 'vaultsync@example.invalid',
    GIT_COMMITTER_NAME: 'Vaultsync Test',
    GIT_COMMITTER_EMAIL: 'vaultsync@example.invalid',
  };
  runNode([cli, 'install', local, '--llm-command', `${process.execPath} ${llm}`, '--no-launchd'], { env });

  const registrationPath = registrationPathForRoot(realpathSync(local), env);
  const registration = JSON.parse(readFileSync(registrationPath, 'utf8'));
  writeFileSync(registrationPath, JSON.stringify({ ...registration, dibsBin: join(tmp, 'missing-dibs') }, null, 2));
  writeFileSync(join(local, 'README.md'), '# Test\n\nChanged with stale dibs registration.\n');

  runNode([cli, 'now', local, '--json'], {
    env: {
      ...env,
      DIBS_BIN: '',
      PATH: `${pathDibsDir}:${process.env.PATH}`,
    },
  });

  const saved = JSON.parse(readFileSync(registrationPath, 'utf8'));
  assert.equal(git(local, ['status', '--porcelain']), '');
  assert.equal(saved.lastError, null);
  assert.match(git(local, ['log', '-1', '--pretty=%s']), /Record stale dibs recovery/);
});

it('installs and runs one dirty checkout sync cycle against a bare remote', () => {
  const remote = join(tmp, 'sync-remote.git');
  const local = join(tmp, 'sync-local');
  git(tmp, ['init', '--bare', '-q', remote]);
  git(tmp, ['clone', '-q', remote, local]);
  writeFileSync(join(local, 'note.md'), '# Note\n');
  git(local, ['add', 'note.md']);
  git(local, ['commit', '-q', '-m', 'Initial commit']);
  git(local, ['push', '-q', '-u', 'origin', 'HEAD']);

  const fakeDibs = join(tmp, 'sync-dibs.mjs');
  writeFileSync(fakeDibs, [
    '#!/usr/bin/env node',
    'const command = process.argv[2];',
    'if (command === "claim") process.stdout.write(JSON.stringify({ state: "claimed", holder: { nonce: "abc" } }));',
    'else if (command === "release") process.stdout.write(JSON.stringify({ state: "released" }));',
    'else if (command === "check") process.stdout.write(JSON.stringify({ state: "free" }));',
    'else process.exit(2);',
    '',
  ].join('\n'), { mode: 0o755 });
  const llm = join(tmp, 'sync-llm.mjs');
  writeFileSync(llm, [
    '#!/usr/bin/env node',
    'let input = "";',
    'process.stdin.on("data", (chunk) => input += chunk);',
    'process.stdin.on("end", () => {',
    '  const payload = JSON.parse(input);',
    '  if (payload.task === "commit_message") {',
    '    process.stdout.write(JSON.stringify({ message: "Update vault note\\n\\nThis sync records the changed vault note before remote reconciliation.\\n\\nSlice: docs-only" }));',
    '  } else if (payload.task === "resolve_conflict") {',
    '    process.stdout.write(JSON.stringify({ resolved: "Remote truth line.\\n" }));',
    '  } else process.exit(2);',
    '});',
    '',
  ].join('\n'), { mode: 0o755 });
  const cli = fileURLToPath(new URL('../../bin/vaultsync', import.meta.url));
  const env = {
    LAICLUSE_HOME: join(tmp, 'sync-home'),
    DIBS_BIN: fakeDibs,
    HOME: tmp,
    GIT_AUTHOR_NAME: 'Vaultsync Test',
    GIT_AUTHOR_EMAIL: 'vaultsync@example.invalid',
    GIT_COMMITTER_NAME: 'Vaultsync Test',
    GIT_COMMITTER_EMAIL: 'vaultsync@example.invalid',
  };
  runNode([cli, 'install', local, '--llm-command', `${process.execPath} ${llm}`, '--no-launchd'], { env });
  writeFileSync(join(local, '.git', 'hooks', 'pre-commit'), [
    '#!/bin/sh',
    "echo \"managed-git: deze vault wordt via 'vault sync' beheerd, niet via plain git.\" >&2",
    "echo \"Draai 'vault sync', of voeg '--no-verify' toe om dit bewust te omzeilen.\" >&2",
    'exit 1',
    '',
  ].join('\n'), { mode: 0o755 });
  writeFileSync(join(local, '.git', 'hooks', 'pre-push'), [
    '#!/bin/sh',
    "echo \"managed-git: deze vault wordt via 'vault sync' beheerd, niet via plain git.\" >&2",
    "echo \"Draai 'vault sync', of voeg '--no-verify' toe om dit bewust te omzeilen.\" >&2",
    'exit 1',
    '',
  ].join('\n'), { mode: 0o755 });
  writeFileSync(join(local, 'note.md'), '# Note\n\nChanged locally.\n');
  runNode([cli, 'now', local, '--json'], { env });

  assert.equal(git(local, ['status', '--porcelain']), '');
  assert.match(git(local, ['log', '-1', '--pretty=%s']), /Update vault note/);
  assert.match(git(tmp, ['--git-dir', remote, 'log', '-1', '--pretty=%s']), /Update vault note/);
});

it('commits generated files before publication', () => {
  const fixture = syncFixture('pre-sync-generated-file');
  const generator = join(tmp, 'pre-sync-generated-file.mjs');
  writeFileSync(generator, [
    '#!/usr/bin/env node',
    'import { readFileSync, writeFileSync } from "node:fs";',
    'const note = readFileSync("note.md", "utf8");',
    'writeFileSync("viewer.html", `<main>${note.trim()}</main>\\n`);',
    '',
  ].join('\n'), { mode: 0o755 });
  const registrationPath = registrationPathForRoot(realpathSync(fixture.local), fixture.env);
  const installed = JSON.parse(readFileSync(registrationPath, 'utf8'));
  writeFileSync(registrationPath, `${JSON.stringify({ ...installed, preSyncCommand: `${process.execPath} ${generator}` }, null, 2)}\n`);
  writeFileSync(join(fixture.local, 'note.md'), '# Note\n\nGenerated before commit.\n');

  runNode([fixture.cli, 'now', fixture.local, '--json'], { env: fixture.env });

  assert.equal(readFileSync(join(fixture.local, 'viewer.html'), 'utf8'), '<main># Note\n\nGenerated before commit.</main>\n');
  assert.match(git(fixture.local, ['log', '-2', '--pretty=', '--name-only']), /note\.md/);
  assert.match(git(fixture.local, ['log', '-2', '--pretty=', '--name-only']), /viewer\.html/);
  assert.equal(git(fixture.local, ['rev-list', '--left-right', '--count', 'HEAD...@{u}']), '0\t0');
});

it('continues publication when another cycle checkpoints the same staged state', () => {
  const fixture = syncFixture('concurrent-checkpoint');
  const hook = join(fixture.local, '.git', 'hooks', 'pre-commit');
  writeFileSync(hook, [
    '#!/bin/sh',
    'tree=$(git write-tree)',
    'parent=$(git rev-parse HEAD)',
    'commit=$(printf "Concurrent checkpoint\\n" | git commit-tree "$tree" -p "$parent")',
    'git update-ref HEAD "$commit" "$parent"',
    'printf "On branch main\\nnothing to commit, working tree clean\\n" >&2',
    'exit 1',
    '',
  ].join('\n'), { mode: 0o755 });
  writeFileSync(join(fixture.local, 'note.md'), '# Note\n\nCheckpointed by the daemon.\n');

  const cycle = JSON.parse(runNode([fixture.cli, 'now', fixture.local, '--json'], { env: fixture.env }).stdout);

  assert.equal(cycle.state, 'synced');
  assert.equal(git(fixture.local, ['status', '--porcelain']), '');
  assert.equal(git(fixture.local, ['rev-list', '--left-right', '--count', 'HEAD...@{u}']), '0\t0');
});

it('blocks commit and push when the pre-sync command fails', () => {
  const fixture = syncFixture('pre-sync-failure');
  const generator = join(tmp, 'pre-sync-failure.mjs');
  writeFileSync(generator, [
    '#!/usr/bin/env node',
    'import { writeFileSync } from "node:fs";',
    'writeFileSync("viewer.html", "partial viewer\\n");',
    'process.stderr.write("viewer generation failed\\n");',
    'process.exit(17);',
    '',
  ].join('\n'), { mode: 0o755 });
  const registrationPath = registrationPathForRoot(realpathSync(fixture.local), fixture.env);
  const installed = JSON.parse(readFileSync(registrationPath, 'utf8'));
  writeFileSync(registrationPath, `${JSON.stringify({ ...installed, preSyncCommand: `${process.execPath} ${generator}` }, null, 2)}\n`);
  writeFileSync(join(fixture.local, 'note.md'), '# Note\n\nMust not publish.\n');

  assert.throws(
    () => runNode([fixture.cli, 'now', fixture.local, '--json'], { env: fixture.env }),
    /pre-sync command failed/,
  );

  const registration = JSON.parse(readFileSync(registrationPath, 'utf8'));
  assert.equal(registration.lastError.phase, 'pre-sync');
  assert.match(registration.lastError.detail, /viewer generation failed/);
  assert.equal(git(fixture.local, ['rev-list', '--left-right', '--count', 'HEAD...@{u}']), '1\t0');
  assert.match(git(fixture.local, ['show', '--pretty=', '--name-only', 'HEAD']), /note\.md/);
  assert.doesNotMatch(git(fixture.local, ['status', '--porcelain']), /viewer\.html/);

  const peer = join(tmp, 'pre-sync-failure-peer');
  git(tmp, ['clone', '-q', fixture.remote, peer]);
  git(peer, ['config', 'core.hooksPath', '/dev/null']);
  writeFileSync(join(peer, 'remote.md'), '# Remote\n');
  writeFileSync(join(peer, 'viewer.html'), '<main># Remote</main>\n');
  git(peer, ['add', 'remote.md', 'viewer.html']);
  git(peer, ['commit', '-q', '-m', 'Refresh remote viewer']);
  git(peer, ['push', '-q']);
  const llm = join(tmp, 'pre-sync-failure-retry-llm.mjs');
  writeFileSync(llm, [
    '#!/usr/bin/env node',
    'let input = "";',
    'process.stdin.on("data", (chunk) => input += chunk);',
    'process.stdin.on("end", () => {',
    '  const payload = JSON.parse(input);',
    '  if (payload.task === "commit_message") process.stdout.write(JSON.stringify({ message: "Recover generated viewer\\n\\nPublish only the successful generated state.\\n\\nSlice: docs-only" }));',
    '  else if (payload.task === "resolve_conflict") process.exit(19);',
    '  else process.exit(2);',
    '});',
    '',
  ].join('\n'), { mode: 0o755 });
  writeFileSync(registrationPath, `${JSON.stringify({
    ...JSON.parse(readFileSync(registrationPath, 'utf8')),
    llmCommand: `${process.execPath} ${llm}`,
  }, null, 2)}\n`);

  writeFileSync(generator, [
    '#!/usr/bin/env node',
    'import { readFileSync, writeFileSync } from "node:fs";',
    'const note = readFileSync("note.md", "utf8").trim();',
    'const remote = readFileSync("remote.md", "utf8").trim();',
    'writeFileSync("viewer.html", `<main>${note} | ${remote}</main>\\n`);',
    '',
  ].join('\n'), { mode: 0o755 });
  runNode([fixture.cli, 'now', fixture.local, '--json'], { env: fixture.env });

  assert.equal(readFileSync(join(fixture.local, 'viewer.html'), 'utf8'), '<main># Note\n\nMust not publish. | # Remote</main>\n');
  assert.doesNotMatch(git(tmp, ['--git-dir', fixture.remote, 'log', '-p', '--all']), /partial viewer/);
  assert.equal(git(fixture.local, ['rev-list', '--left-right', '--count', 'HEAD...@{u}']), '0\t0');
});

it('rolls back generated output when the pre-sync process times out', () => {
  const fixture = syncFixture('pre-sync-timeout');
  const generator = join(tmp, 'pre-sync-timeout.mjs');
  writeFileSync(generator, [
    '#!/usr/bin/env node',
    'import { writeFileSync } from "node:fs";',
    'writeFileSync("viewer.html", "partial timeout viewer\\n");',
    'setTimeout(() => {}, 1000);',
    '',
  ].join('\n'), { mode: 0o755 });
  const registrationPath = registrationPathForRoot(realpathSync(fixture.local), fixture.env);
  const installed = JSON.parse(readFileSync(registrationPath, 'utf8'));
  writeFileSync(registrationPath, `${JSON.stringify({
    ...installed,
    preSyncCommand: `${process.execPath} ${generator}`,
    preSyncTimeoutMs: 50,
  }, null, 2)}\n`);
  writeFileSync(join(fixture.local, 'note.md'), '# Note\n\nMust survive a timed-out generator.\n');

  assert.throws(
    () => runNode([fixture.cli, 'now', fixture.local, '--json'], { env: fixture.env }),
    /pre-sync command failed/,
  );

  assert.doesNotMatch(git(fixture.local, ['status', '--porcelain']), /viewer\.html/);
  assert.equal(git(fixture.local, ['rev-list', '--left-right', '--count', 'HEAD...@{u}']), '1\t0');
});

it('reruns pre-sync after integrating remote changes', () => {
  const fixture = syncFixture('pre-sync-post-rebase');
  const generator = join(tmp, 'pre-sync-post-rebase.mjs');
  writeFileSync(generator, [
    '#!/usr/bin/env node',
    'import { existsSync, readFileSync, writeFileSync } from "node:fs";',
    'const remote = existsSync("remote.md") ? readFileSync("remote.md", "utf8").trim() : "missing";',
    'writeFileSync("viewer.html", `<main>${remote}</main>\\n`);',
    '',
  ].join('\n'), { mode: 0o755 });
  const registrationPath = registrationPathForRoot(realpathSync(fixture.local), fixture.env);
  const installed = JSON.parse(readFileSync(registrationPath, 'utf8'));
  writeFileSync(registrationPath, `${JSON.stringify({ ...installed, preSyncCommand: `${process.execPath} ${generator}` }, null, 2)}\n`);
  const peer = join(tmp, 'pre-sync-post-rebase-peer');
  git(tmp, ['clone', '-q', fixture.remote, peer]);
  writeFileSync(join(peer, 'remote.md'), '# Remote input\n');
  git(peer, ['add', 'remote.md']);
  git(peer, ['commit', '-q', '-m', 'Add remote input']);
  git(peer, ['push', '-q']);

  const cycle = JSON.parse(runNode([fixture.cli, 'now', fixture.local, '--json'], { env: fixture.env }).stdout);

  assert.equal(readFileSync(join(fixture.local, 'viewer.html'), 'utf8'), '<main># Remote input</main>\n');
  assert.equal(cycle.result.preSyncRuns, 1);
  assert.equal(git(fixture.local, ['rev-list', '--left-right', '--count', 'HEAD...@{u}']), '0\t0');
});

it('generates after rebasing when both peers changed the generated file', () => {
  const fixture = syncFixture('pre-sync-two-writers');
  writeFileSync(join(fixture.local, 'viewer.html'), '<main>baseline</main>\n');
  git(fixture.local, ['add', 'viewer.html']);
  git(fixture.local, ['commit', '-q', '-m', 'Seed generated viewer']);
  git(fixture.local, ['push', '-q']);
  const peer = join(tmp, 'pre-sync-two-writers-peer');
  git(tmp, ['clone', '-q', fixture.remote, peer]);
  git(peer, ['config', 'core.hooksPath', '/dev/null']);
  writeFileSync(join(peer, 'remote.md'), '# Remote\n');
  writeFileSync(join(peer, 'viewer.html'), '<main># Remote</main>\n');
  git(peer, ['add', 'remote.md', 'viewer.html']);
  git(peer, [
    'commit', '-q',
    '-m', 'Refresh remote viewer',
    '-m', 'Change remote source and its generated projection together so the local cycle must integrate both before regenerating.',
    '-m', 'Slice: docs-only',
  ]);
  git(peer, ['push', '-q']);
  const generator = join(tmp, 'pre-sync-two-writers-generator.mjs');
  writeFileSync(generator, [
    '#!/usr/bin/env node',
    'import { existsSync, readFileSync, writeFileSync } from "node:fs";',
    'const read = (path) => existsSync(path) ? readFileSync(path, "utf8").trim() : "";',
    'writeFileSync("viewer.html", `<main>${[read("local.md"), read("remote.md")].filter(Boolean).join(" | ")}</main>\\n`);',
    '',
  ].join('\n'), { mode: 0o755 });
  const llm = join(tmp, 'pre-sync-two-writers-llm.mjs');
  writeFileSync(llm, [
    '#!/usr/bin/env node',
    'let input = "";',
    'process.stdin.on("data", (chunk) => input += chunk);',
    'process.stdin.on("end", () => {',
    '  const payload = JSON.parse(input);',
    '  if (payload.task === "commit_message") process.stdout.write(JSON.stringify({ message: "Refresh generated viewer\\n\\nRecord the combined viewer after remote integration.\\n\\nSlice: docs-only" }));',
    '  else if (payload.task === "resolve_conflict") process.exit(19);',
    '  else process.exit(2);',
    '});',
    '',
  ].join('\n'), { mode: 0o755 });
  const registrationPath = registrationPathForRoot(realpathSync(fixture.local), fixture.env);
  const installed = JSON.parse(readFileSync(registrationPath, 'utf8'));
  writeFileSync(registrationPath, `${JSON.stringify({
    ...installed,
    llmCommand: `${process.execPath} ${llm}`,
    preSyncCommand: `${process.execPath} ${generator}`,
  }, null, 2)}\n`);
  writeFileSync(join(fixture.local, 'local.md'), '# Local\n');

  runNode([fixture.cli, 'now', fixture.local, '--json'], { env: fixture.env });

  assert.equal(readFileSync(join(fixture.local, 'viewer.html'), 'utf8'), '<main># Local | # Remote</main>\n');
  assert.equal(git(fixture.local, ['rev-list', '--left-right', '--count', 'HEAD...@{u}']), '0\t0');
});

it('reruns pre-sync after verifier repairs', () => {
  const fixture = syncFixture('pre-sync-post-verification');
  const generator = join(tmp, 'pre-sync-post-verification.mjs');
  writeFileSync(generator, [
    '#!/usr/bin/env node',
    'import { readFileSync, writeFileSync } from "node:fs";',
    'writeFileSync("viewer.html", `<main>${readFileSync("note.md", "utf8")}</main>`);',
    '',
  ].join('\n'), { mode: 0o755 });
  const verifier = join(tmp, 'pre-sync-post-verification-verifier.mjs');
  writeFileSync(verifier, [
    '#!/usr/bin/env node',
    'import { readFileSync } from "node:fs";',
    'const note = readFileSync("note.md", "utf8");',
    'if (/ +$/m.test(note)) {',
    '  process.stdout.write(`${process.cwd()}/note.md: trailing whitespace\\n`);',
    '  process.exit(1);',
    '}',
    '',
  ].join('\n'), { mode: 0o755 });
  const registrationPath = registrationPathForRoot(realpathSync(fixture.local), fixture.env);
  const installed = JSON.parse(readFileSync(registrationPath, 'utf8'));
  writeFileSync(registrationPath, `${JSON.stringify({
    ...installed,
    preSyncCommand: `${process.execPath} ${generator}`,
    verifyCommand: `${process.execPath} ${verifier}`,
  }, null, 2)}\n`);
  writeFileSync(join(fixture.local, 'note.md'), '# Note  \n');

  const cycle = JSON.parse(runNode([fixture.cli, 'now', fixture.local, '--json'], { env: fixture.env }).stdout);

  assert.equal(readFileSync(join(fixture.local, 'note.md'), 'utf8'), '# Note\n');
  assert.equal(readFileSync(join(fixture.local, 'viewer.html'), 'utf8'), '<main># Note\n</main>');
  assert.equal(cycle.result.preSyncRuns, 2);
  assert.equal(git(fixture.local, ['rev-list', '--left-right', '--count', 'HEAD...@{u}']), '0\t0');
});

it('preserves a failed commit-message generator as the primary blocked sync cause and retries staged changes', () => {
  const fixture = syncFixture('commit-message-auth-failure');
  writeFileSync(join(fixture.local, 'note.md'), '# Note\n\nSuccessful sync before OAuth expires.\n');
  runNode([fixture.cli, 'now', fixture.local, '--json'], { env: fixture.env });
  const generator = join(tmp, 'commit-message-auth-failure-llm.mjs');
  writeFileSync(generator, [
    '#!/usr/bin/env node',
    'let input = "";',
    'process.stdin.on("data", (chunk) => input += chunk);',
    'process.stdin.on("end", () => {',
    '  const payload = JSON.parse(input);',
    '  if (payload.task === "resolve_conflict") {',
    '    process.stdout.write(JSON.stringify({ resolved: "Remote truth line.\\n" }));',
    '    return;',
    '  }',
    '  if (payload.task === "commit_message") {',
    '    process.stderr.write("Failed to authenticate: OAuth session expired and could not be refreshed\\nBearer secret-access-token\\nOAUTH_TOKEN=secret-refresh-token\\n");',
    '    process.exit(17);',
    '  }',
    '  process.exit(2);',
    '});',
    '',
  ].join('\n'), { mode: 0o755 });
  const registrationPath = registrationPathForRoot(realpathSync(fixture.local), fixture.env);
  const installed = JSON.parse(readFileSync(registrationPath, 'utf8'));
  writeFileSync(registrationPath, `${JSON.stringify({ ...installed, llmCommand: `${process.execPath} ${generator}` }, null, 2)}\n`);
  writeFileSync(join(fixture.local, '.git', 'hooks', 'commit-msg'), [
    '#!/bin/sh',
    'echo "git-discipline: duplicate-why: fallback reasoning duplicates the previous sync" >&2',
    'exit 1',
    '',
  ].join('\n'), { mode: 0o755 });
  writeFileSync(join(fixture.local, 'note.md'), `# Note\n\nChanged while OAuth is expired.\n\n${'large staged viewer content\n'.repeat(50000)}`);

  assert.throws(
    () => runNode([fixture.cli, 'now', fixture.local, '--json'], { env: fixture.env }),
    /OAuth session expired/,
  );

  const afterManualFailure = JSON.parse(readFileSync(registrationPath, 'utf8'));
  writeFileSync(registrationPath, `${JSON.stringify({ ...afterManualFailure, debounceSeconds: 1, lastSeenDirtyAt: '2026-01-01T00:00:00Z' }, null, 2)}\n`);
  const daemonResult = JSON.parse(runNode([fixture.cli, 'daemon', '--once', '--json'], { env: fixture.env }).stdout);
  assert.equal(daemonResult[0].state, 'error', JSON.stringify(daemonResult[0]));

  const blocked = JSON.parse(readFileSync(registrationPath, 'utf8'));
  assert.equal(blocked.lastError.phase, 'commit-message-generation', JSON.stringify(blocked.lastError));
  assert.equal(blocked.lastError.message, 'OAuth session expired.');
  assert.match(blocked.lastError.detail, /Failed to authenticate/);
  assert.doesNotMatch(JSON.stringify(blocked.lastError), /secret-access-token|secret-refresh-token/);
  assert.equal(blocked.lastError.recovery, 'Re-authenticate the configured provider and retry sync.');
  assert.equal(blocked.lastError.secondary.length, 1);
  assert.equal(blocked.lastError.secondary[0].phase, 'commit');
  assert.match(blocked.lastError.secondary[0].message, /duplicate-why/);
  assert.match(git(fixture.local, ['status', '--porcelain']), /^M  note\.md$/m);

  const status = JSON.parse(runNode([fixture.cli, 'status', fixture.local, '--json'], { env: fixture.env }).stdout);
  assert.equal(status.protocol, 'vaultsync.status.v1');
  assert.equal(status.vaults[0].state, 'blocked');
  assert.equal(status.vaults[0].failure.phase, 'commit-message-generation');
  assert.match(status.vaults[0].lastSuccessfulSyncAt, /^\d{4}-/);
  assert.equal(status.vaults[0].pending.uncommitted.staged[0], 'note.md');
  assert.equal(status.vaults[0].pending.unpushed.commits, 0);
  const textStatus = runNode([fixture.cli, 'status', fixture.local], { env: fixture.env }).stdout;
  assert.match(textStatus, /blocked during commit-message-generation: OAuth session expired\./);
  assert.match(textStatus, /secondary commit failure: git-discipline: duplicate-why/);
  assert.match(textStatus, /last successful sync:/);
  assert.match(textStatus, /local changes: 1 uncommitted \(1 staged\), 0 unpushed commits/);
  assert.match(textStatus, /recovery: Re-authenticate the configured provider and retry sync\./);

  writeFileSync(join(fixture.local, '.git', 'hooks', 'commit-msg'), '#!/bin/sh\nexit 0\n', { mode: 0o755 });
  writeFileSync(generator, [
    '#!/usr/bin/env node',
    'let input = "";',
    'process.stdin.on("data", (chunk) => input += chunk);',
    'process.stdin.on("end", () => {',
    '  const payload = JSON.parse(input);',
    '  if (payload.task === "commit_message") process.stdout.write(JSON.stringify({ message: "Record recovered vault note\\n\\nCommit the staged note after restoring provider authentication.\\n\\nSlice: docs-only" }));',
    '  else if (payload.task === "resolve_conflict") process.stdout.write(JSON.stringify({ resolved: "Remote truth line.\\n" }));',
    '  else process.exit(2);',
    '});',
    '',
  ].join('\n'), { mode: 0o755 });

  runNode([fixture.cli, 'now', fixture.local, '--json'], { env: fixture.env });

  const recovered = JSON.parse(readFileSync(registrationPath, 'utf8'));
  assert.equal(recovered.lastError, null);
  assert.equal(git(fixture.local, ['status', '--porcelain']), '');
  assert.equal(git(fixture.local, ['rev-list', '--left-right', '--count', 'HEAD...@{u}']), '0\t0');
  assert.match(git(fixture.local, ['log', '-1', '--pretty=%s']), /Record recovered vault note/);
});

it('refuses to commit dirty content containing the current home path', () => {
  const fixture = syncFixture('shareability-dirty');
  writeFileSync(join(fixture.local, 'note.md'), `# Note\n\nRun ${fixture.env.HOME}/bin/tilt.\n`);

  assert.throws(
    () => runNode([fixture.cli, 'now', fixture.local, '--json'], { env: fixture.env }),
    /machine-local home path/,
  );
  assert.equal(git(fixture.local, ['rev-list', '--left-right', '--count', 'HEAD...@{u}']), '0\t0');
  assert.match(git(fixture.local, ['status', '--porcelain']), /note\.md/);
});

it('refuses to push an existing ahead commit containing the current home path', () => {
  const fixture = syncFixture('shareability-ahead');
  writeFileSync(join(fixture.local, 'note.md'), `# Note\n\nRun ${fixture.env.HOME}/bin/tilt.\n`);
  git(fixture.local, ['add', 'note.md']);
  git(fixture.local, ['commit', '-q', '-m', 'Record machine-local command']);

  assert.throws(
    () => runNode([fixture.cli, 'now', fixture.local, '--json'], { env: fixture.env }),
    /machine-local home path/,
  );
  assert.equal(git(fixture.local, ['rev-list', '--left-right', '--count', 'HEAD...@{u}']), '1\t0');
  assert.equal(git(tmp, ['--git-dir', fixture.remote, 'log', '-1', '--pretty=%s']), 'Initial commit');
});

it('allows a corrective commit that removes a machine-local home path', () => {
  const fixture = syncFixture('shareability-cleanup');
  writeFileSync(join(fixture.local, 'note.md'), `# Note\n\nRun ${fixture.env.HOME}/bin/tilt.\n`);
  git(fixture.local, ['add', 'note.md']);
  git(fixture.local, ['commit', '-q', '-m', 'Seed legacy machine-local command']);
  git(fixture.local, ['push', '-q']);
  writeFileSync(join(fixture.local, 'note.md'), '# Note\n\nRun tilt from PATH.\n');
  git(fixture.local, ['add', 'note.md']);
  git(fixture.local, ['commit', '-q', '-m', 'Use portable command resolution']);

  runNode([fixture.cli, 'now', fixture.local, '--json'], { env: fixture.env });

  assert.equal(git(fixture.local, ['rev-list', '--left-right', '--count', 'HEAD...@{u}']), '0\t0');
  assert.equal(git(tmp, ['--git-dir', fixture.remote, 'show', 'HEAD:note.md']), '# Note\n\nRun tilt from PATH.');
});

it('evaluates corrected outgoing content from the final tree', () => {
  const fixture = syncFixture('shareability-outgoing-cleanup');
  writeFileSync(join(fixture.local, 'note.md'), `# Note\n\nRun ${fixture.env.HOME}/bin/tilt.\n`);
  git(fixture.local, ['add', 'note.md']);
  git(fixture.local, ['commit', '-q', '-m', 'Capture legacy machine-local command']);
  writeFileSync(join(fixture.local, 'note.md'), '# Note\n\nRun tilt from PATH.\n');
  git(fixture.local, ['add', 'note.md']);
  git(fixture.local, ['commit', '-q', '-m', 'Use portable command resolution']);

  runNode([fixture.cli, 'now', fixture.local, '--json'], { env: fixture.env });

  assert.equal(git(fixture.local, ['rev-list', '--left-right', '--count', 'HEAD...@{u}']), '0\t0');
  assert.equal(git(tmp, ['--git-dir', fixture.remote, 'show', 'HEAD:note.md']), '# Note\n\nRun tilt from PATH.');
});

it('syncs a staged transcript batch larger than the default subprocess buffer', () => {
  const fixture = syncFixture('large-transcript-batch');
  writeFileSync(join(fixture.local, 'large-transcript.md'), `# Transcript\n\n${'spoken words '.repeat(2_000_000)}\n`);

  runNode([fixture.cli, 'now', fixture.local, '--json'], { env: fixture.env });

  assert.equal(git(fixture.local, ['status', '--porcelain']), '');
  assert.equal(git(fixture.local, ['rev-list', '--left-right', '--count', 'HEAD...@{u}']), '0\t0');
});

it('installs and auto-commits a local-only checkout without an upstream', () => {
  const local = createRepo('local-only');

  const fakeDibs = join(tmp, 'local-only-dibs.mjs');
  writeFileSync(fakeDibs, [
    '#!/usr/bin/env node',
    'const command = process.argv[2];',
    'if (command === "claim") process.stdout.write(JSON.stringify({ state: "claimed", holder: { nonce: "abc" } }));',
    'else if (command === "release") process.stdout.write(JSON.stringify({ state: "released" }));',
    'else if (command === "check") process.stdout.write(JSON.stringify({ state: "free" }));',
    'else process.exit(2);',
    '',
  ].join('\n'), { mode: 0o755 });
  const llm = join(tmp, 'local-only-llm.mjs');
  writeFileSync(llm, [
    '#!/usr/bin/env node',
    'let input = "";',
    'process.stdin.on("data", (chunk) => input += chunk);',
    'process.stdin.on("end", () => {',
    '  const payload = JSON.parse(input);',
    '  if (payload.task === "commit_message") {',
    '    process.stdout.write(JSON.stringify({ message: "Record local vault note\\n\\nCapture the local-only vault edit without requiring remote synchronization.\\n\\nSlice: docs-only" }));',
    '  } else if (payload.task === "resolve_conflict") {',
    '    process.stdout.write(JSON.stringify({ resolved: "Remote truth line.\\n" }));',
    '  } else process.exit(2);',
    '});',
    '',
  ].join('\n'), { mode: 0o755 });
  const cli = fileURLToPath(new URL('../../bin/vaultsync', import.meta.url));
  const home = join(tmp, 'local-only-home');
  const env = {
    LAICLUSE_HOME: home,
    DIBS_BIN: fakeDibs,
    HOME: tmp,
    GIT_AUTHOR_NAME: 'Vaultsync Test',
    GIT_AUTHOR_EMAIL: 'vaultsync@example.invalid',
    GIT_COMMITTER_NAME: 'Vaultsync Test',
    GIT_COMMITTER_EMAIL: 'vaultsync@example.invalid',
  };
  runNode([cli, 'install', local, '--llm-command', `${process.execPath} ${llm}`, '--no-launchd'], { env });
  writeFileSync(join(local, '.git', 'hooks', 'commit-msg'), [
    '#!/bin/sh',
    'grep -q "^Tests:" "$1" || { echo "missing Tests trailer" >&2; exit 1; }',
    'grep -q "^Slice: docs-only$" "$1" || { echo "invalid Slice trailer" >&2; exit 1; }',
    'grep -q "^Red-then-green:" "$1" || { echo "missing Red-then-green trailer" >&2; exit 1; }',
    '',
  ].join('\n'), { mode: 0o755 });
  writeFileSync(join(local, 'README.md'), '# Test\n\nChanged locally.\n');
  runNode([cli, 'now', local, '--json'], { env });

  const registration = JSON.parse(readFileSync(registrationPathForRoot(realpathSync(local), env), 'utf8'));
  const upstream = spawnSync('git', ['rev-parse', '--abbrev-ref', '--symbolic-full-name', '@{u}'], {
    cwd: local,
    encoding: 'utf8',
  });
  assert.equal(git(local, ['status', '--porcelain']), '');
  assert.notEqual(upstream.status, 0);
  assert.match(git(local, ['log', '-1', '--pretty=%s']), /Record local vault note/);
  assert.equal(registration.upstreamAtInstall, null);
  assert.equal(registration.lastError, null);
  assert.equal(registration.lastResult.upstream, null);
  assert.equal(registration.lastResult.committed, true);
});

it('records a poll timestamp when verification fails after committing', () => {
  const remote = join(tmp, 'verify-remote.git');
  const local = join(tmp, 'verify-local');
  git(tmp, ['init', '--bare', '-q', remote]);
  git(tmp, ['clone', '-q', remote, local]);
  writeFileSync(join(local, 'note.md'), '# Note\n');
  git(local, ['add', 'note.md']);
  git(local, ['commit', '-q', '-m', 'Initial commit']);
  git(local, ['push', '-q', '-u', 'origin', 'HEAD']);

  const fakeDibs = join(tmp, 'verify-dibs.mjs');
  writeFileSync(fakeDibs, [
    '#!/usr/bin/env node',
    'const command = process.argv[2];',
    'if (command === "claim") process.stdout.write(JSON.stringify({ state: "claimed", holder: { nonce: "abc" } }));',
    'else if (command === "release") process.stdout.write(JSON.stringify({ state: "released" }));',
    'else if (command === "check") process.stdout.write(JSON.stringify({ state: "free" }));',
    'else process.exit(2);',
    '',
  ].join('\n'), { mode: 0o755 });
  const llm = join(tmp, 'verify-llm.mjs');
  writeFileSync(llm, [
    '#!/usr/bin/env node',
    'let input = "";',
    'process.stdin.on("data", (chunk) => input += chunk);',
    'process.stdin.on("end", () => {',
    '  const payload = JSON.parse(input);',
    '  if (payload.task === "commit_message") process.stdout.write(JSON.stringify({ message: "Update vault note\\n\\nRecord a note change before verifier failure handling.\\n\\nSlice: docs-only" }));',
    '  else if (payload.task === "resolve_conflict") process.stdout.write(JSON.stringify({ resolved: "Remote truth line.\\n" }));',
    '  else if (payload.task === "repair_verifier") process.stdout.write(JSON.stringify({ repairs: [] }));',
    '  else process.exit(2);',
    '});',
    '',
  ].join('\n'), { mode: 0o755 });
  const cli = fileURLToPath(new URL('../../bin/vaultsync', import.meta.url));
  const home = join(tmp, 'verify-home');
  const env = {
    LAICLUSE_HOME: home,
    DIBS_BIN: fakeDibs,
    HOME: tmp,
    GIT_AUTHOR_NAME: 'Vaultsync Test',
    GIT_AUTHOR_EMAIL: 'vaultsync@example.invalid',
    GIT_COMMITTER_NAME: 'Vaultsync Test',
    GIT_COMMITTER_EMAIL: 'vaultsync@example.invalid',
  };
  runNode([cli, 'install', local, '--llm-command', `${process.execPath} ${llm}`, '--verify', 'false', '--no-launchd'], { env });
  writeFileSync(join(local, 'note.md'), '# Note\n\nChanged locally.\n');
  assert.throws(() => runNode([cli, 'now', local, '--json'], { env }), /verification command failed/);

  const registration = JSON.parse(readFileSync(registrationPathForRoot(realpathSync(local), env), 'utf8'));
  assert.equal(git(local, ['status', '--porcelain']), '');
  assert.equal(git(local, ['rev-list', '--left-right', '--count', 'HEAD...@{u}']), '1\t0');
  assert.equal(registration.lastSeenDirtyAt, null);
  assert.match(registration.lastPollAt, /^\d{4}-/);
  assert.match(registration.lastError.message, /verification command failed/);
});

it('asks the LLM command to repair verifier failures before pushing', () => {
  const remote = join(tmp, 'repair-remote.git');
  const local = join(tmp, 'repair-local');
  git(tmp, ['init', '--bare', '-q', remote]);
  git(tmp, ['clone', '-q', remote, local]);
  writeFileSync(join(local, 'note.md'), '# Note\n');
  writeFileSync(join(local, 'legacy.md'), '# Legacy\n\nMentions E-Flux.\n');
  writeFileSync(join(local, 'other.md'), '# Other\n\nMentions Zaptec.\n');
  git(local, ['add', 'note.md', 'legacy.md', 'other.md']);
  git(local, [
    'commit',
    '-q',
    '-m', 'Seed repair fixture',
    '-m', 'Seed the test repository with a clean current note and one legacy lint issue. This gives the verifier repair test a pre-existing warning outside the current sync commit.',
    '-m', 'Tests: n/a (test fixture)',
    '-m', 'Slice: docs-only',
  ]);
  git(local, ['push', '-q', '-u', 'origin', 'HEAD']);

  const fakeDibs = join(tmp, 'repair-dibs.mjs');
  writeFileSync(fakeDibs, [
    '#!/usr/bin/env node',
    'const command = process.argv[2];',
    'if (command === "claim") process.stdout.write(JSON.stringify({ state: "claimed", holder: { nonce: "abc" } }));',
    'else if (command === "release") process.stdout.write(JSON.stringify({ state: "released" }));',
    'else if (command === "check") process.stdout.write(JSON.stringify({ state: "free" }));',
    'else process.exit(2);',
    '',
  ].join('\n'), { mode: 0o755 });
  const verifier = join(tmp, 'repair-verifier.mjs');
  writeFileSync(verifier, [
    '#!/usr/bin/env node',
    'import { readFileSync } from "node:fs";',
    'import { join } from "node:path";',
    'let failed = false;',
    'const checks = [["legacy.md", "E-Flux"], ["other.md", "Zaptec"]];',
    'for (const [name, topic] of checks) {',
    '  const path = join(process.cwd(), name);',
    '  const text = readFileSync(path, "utf8");',
    '  if (text.includes(topic) && !text.includes(`[[${topic}]]`)) {',
    '    process.stdout.write(`${path}: topic ${JSON.stringify(topic)} matcht een bestaande note maar is niet gelinkt\\n`);',
    '    failed = true;',
    '  }',
    '}',
    'if (failed) process.exit(1);',
    '',
  ].join('\n'), { mode: 0o755 });
  const llm = join(tmp, 'repair-llm.mjs');
  writeFileSync(llm, [
    '#!/usr/bin/env node',
    'let input = "";',
    'process.stdin.on("data", (chunk) => input += chunk);',
    'process.stdin.on("end", () => {',
    '  const payload = JSON.parse(input);',
    '  if (payload.task === "commit_message") {',
    '    process.stdout.write(JSON.stringify({ message: "Update vault note\\n\\nRecord and repair the note change before remote reconciliation.\\n\\nSlice: docs-only" }));',
    '  } else if (payload.task === "resolve_conflict") {',
    '    process.stdout.write(JSON.stringify({ resolved: "Remote truth line.\\n" }));',
    '  } else if (payload.task === "repair_verifier") {',
    '    if (payload.files.length !== 1) process.exit(3);',
    '    if (!payload.verifier.detail.includes(payload.files[0].path)) process.exit(4);',
    '    if (payload.files[0].path !== "other.md" && payload.verifier.detail.includes("other.md")) process.exit(5);',
    '    const repairs = payload.files.map((file) => ({ path: file.path, content: file.content.replace(/E-Flux/g, "[[E-Flux]]").replace(/Zaptec/g, "[[Zaptec]]"), reason: "link verifier topic" }));',
    '    process.stdout.write(JSON.stringify({ repairs }));',
    '  } else process.exit(2);',
    '});',
    '',
  ].join('\n'), { mode: 0o755 });
  const cli = fileURLToPath(new URL('../../bin/vaultsync', import.meta.url));
  const env = {
    LAICLUSE_HOME: join(tmp, 'repair-home'),
    DIBS_BIN: fakeDibs,
    HOME: tmp,
    GIT_AUTHOR_NAME: 'Vaultsync Test',
    GIT_AUTHOR_EMAIL: 'vaultsync@example.invalid',
    GIT_COMMITTER_NAME: 'Vaultsync Test',
    GIT_COMMITTER_EMAIL: 'vaultsync@example.invalid',
  };
  runNode([cli, 'install', local, '--llm-command', `${process.execPath} ${llm}`, '--verify', `${process.execPath} ${verifier}`, '--no-launchd'], { env });
  writeFileSync(join(local, 'note.md'), '# Note\n\nChanged locally.\n');
  runNode([cli, 'now', local, '--json'], { env });

  assert.equal(git(local, ['status', '--porcelain']), '');
  assert.equal(git(local, ['rev-list', '--left-right', '--count', 'HEAD...@{u}']), '0\t0');
  assert.equal(readFileSync(join(local, 'note.md'), 'utf8'), '# Note\n\nChanged locally.\n');
  assert.equal(readFileSync(join(local, 'legacy.md'), 'utf8'), '# Legacy\n\nMentions [[E-Flux]].\n');
  assert.equal(readFileSync(join(local, 'other.md'), 'utf8'), '# Other\n\nMentions [[Zaptec]].\n');
  const repairCommit = git(tmp, ['--git-dir', remote, 'log', '-1', '--pretty=%B']);
  assert.match(repairCommit, /^Sync vault content/);
  assert.match(repairCommit, /Vaultsync-Reason: manual-verifier-repair/);
});
