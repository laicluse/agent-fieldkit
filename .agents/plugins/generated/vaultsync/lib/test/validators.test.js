import assert from 'node:assert/strict';
import { chmodSync, mkdirSync, mkdtempSync, readFileSync, realpathSync, rmSync, symlinkSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { execFileSync, spawn, spawnSync } from 'node:child_process';
import { after, before, it } from 'node:test';
import { fileURLToPath } from 'node:url';

import {
  configuredValidators,
  registrationPathForRoot,
  repoKey,
} from '../runtime.mjs';

let tmp;

before(() => {
  tmp = mkdtempSync(join(tmpdir(), 'vaultsync-validators-test-'));
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
  const root = join(tmp, name);
  mkdirSync(root);
  git(root, ['init', '-q']);
  writeFileSync(join(root, 'README.md'), '# Test\n');
  git(root, ['add', 'README.md']);
  git(root, ['commit', '-q', '-m', 'Initial commit']);
  return realpathSync(root);
}

function fakeDibs(name) {
  const path = join(tmp, `${name}-dibs.mjs`);
  writeFileSync(path, [
    '#!/usr/bin/env node',
    'const command = process.argv[2];',
    'if (command === "claim") process.stdout.write(JSON.stringify({ state: "claimed", holder: { nonce: "abc" } }));',
    'else if (command === "release") process.stdout.write(JSON.stringify({ state: "released" }));',
    'else if (command === "check") process.stdout.write(JSON.stringify({ state: "free" }));',
    'else process.exit(2);',
    '',
  ].join('\n'), { mode: 0o755 });
  return path;
}

function testEnv(name) {
  const home = join(tmp, `${name}-home`);
  mkdirSync(home, { recursive: true });
  return {
    ...process.env,
    HOME: home,
    LAICLUSE_HOME: join(tmp, `${name}-state`),
    VAULTSYNC_BIN_DIR: join(tmp, `${name}-bin`),
    DIBS_BIN: fakeDibs(name),
    GIT_AUTHOR_NAME: 'Vaultsync Test',
    GIT_AUTHOR_EMAIL: 'vaultsync@example.invalid',
    GIT_COMMITTER_NAME: 'Vaultsync Test',
    GIT_COMMITTER_EMAIL: 'vaultsync@example.invalid',
  };
}

function baseRegistration(root, overrides = {}) {
  return {
    version: 1,
    key: repoKey(root),
    requestedCwd: root,
    rootRealpath: root,
    gitCommonDir: join(root, '.git'),
    branchAtInstall: git(root, ['rev-parse', '--abbrev-ref', 'HEAD']),
    upstreamAtInstall: null,
    llmCommand: 'false',
    preSyncCommand: null,
    verifyCommand: null,
    debounceSeconds: 300,
    idlePollSeconds: 300,
    enabled: true,
    pausedUntil: null,
    pauseReason: null,
    lastSeenDirtyAt: null,
    lastCycleAt: null,
    lastPollAt: null,
    lastSuccessfulSyncAt: null,
    lastError: null,
    lastWarning: null,
    createdAt: '2026-08-28T00:00:00.000Z',
    updatedAt: '2026-08-28T00:00:00.000Z',
    ...overrides,
  };
}

function writeRegistration(root, env, registration) {
  const path = registrationPathForRoot(root, env);
  mkdirSync(join(env.LAICLUSE_HOME, 'vaultsync', 'registrations'), { recursive: true });
  writeFileSync(path, `${JSON.stringify(registration, null, 2)}\n`);
  return path;
}

function runVaultsync(args, env, expectFailure = false) {
  const cli = fileURLToPath(new URL('../../bin/vaultsync', import.meta.url));
  const result = spawnSync(process.execPath, [cli, ...args], { encoding: 'utf8', env });
  if (!expectFailure) assert.equal(result.status, 0, result.stderr || result.stdout);
  return result;
}

function spawnVaultsync(args, env) {
  const cli = fileURLToPath(new URL('../../bin/vaultsync', import.meta.url));
  return new Promise((resolve, reject) => {
    const child = spawn(process.execPath, [cli, ...args], { env, stdio: ['ignore', 'pipe', 'pipe'] });
    let stdout = '';
    let stderr = '';
    child.stdout.on('data', (chunk) => { stdout += chunk; });
    child.stderr.on('data', (chunk) => { stderr += chunk; });
    child.on('error', reject);
    child.on('exit', (status) => resolve({ status, stdout, stderr }));
  });
}

it('projects an unchanged verifyCommand registration as one legacy validator', () => {
  assert.deepEqual(configuredValidators({ verifyCommand: 'legacy-lint' }), [{
    name: 'legacy-verify',
    command: 'legacy-lint',
    repair: { mode: 'automatic', authority: 'diagnostics-and-changed' },
    legacy: true,
  }]);
});

it('combines legacy and named validators without changing their checkout identity', () => {
  assert.deepEqual(configuredValidators({
    verifyCommand: 'legacy-lint',
    validators: {
      cortex: { command: 'cortex validate .', repair: { mode: 'none', authority: 'none' } },
      tilt: { command: 'tilt lint', repair: { mode: 'none', authority: 'none' } },
    },
  }).map((validator) => validator.name), ['legacy-verify', 'cortex', 'tilt']);
});

it('adds, lists, replaces, and removes only one named validator idempotently', () => {
  const root = createRepo('validator-cli');
  const env = testEnv('validator-cli');
  const registrationPath = writeRegistration(root, env, baseRegistration(root, {
    validators: {
      cortex: { command: 'cortex validate .', repair: { mode: 'none', authority: 'none' } },
    },
  }));

  runVaultsync(['validator', 'add', 'tilt', root, '--command', 'tilt lint', '--repair', 'none', '--json'], env);
  const first = readFileSync(registrationPath, 'utf8');
  runVaultsync(['validator', 'add', 'tilt', root, '--command', 'tilt lint', '--repair', 'none', '--json'], env);
  const second = readFileSync(registrationPath, 'utf8');
  assert.equal(second, first);

  runVaultsync(['validator', 'add', 'tilt', root, '--command', 'tilt lint --strict', '--repair', 'none', '--json'], env);
  const replaced = JSON.parse(readFileSync(registrationPath, 'utf8'));
  assert.equal(replaced.validators.tilt.command, 'tilt lint --strict');
  assert.equal(replaced.validators.cortex.command, 'cortex validate .');

  const listed = JSON.parse(runVaultsync(['validator', 'list', root, '--json'], env).stdout);
  assert.deepEqual(listed.validators.map((validator) => validator.name), ['cortex', 'tilt']);

  const removed = JSON.parse(runVaultsync(['validator', 'remove', 'tilt', root, '--json'], env).stdout);
  assert.equal(removed.removed, true);
  const removedAgain = JSON.parse(runVaultsync(['validator', 'remove', 'tilt', root, '--json'], env).stdout);
  assert.equal(removedAgain.removed, false);
  assert.deepEqual(Object.keys(JSON.parse(readFileSync(registrationPath, 'utf8')).validators), ['cortex']);
});

it('requires explicit repair policy and bounded authority for named validators', () => {
  const root = createRepo('validator-policy');
  const env = testEnv('validator-policy');
  writeRegistration(root, env, baseRegistration(root));

  const missing = runVaultsync(['validator', 'add', 'tilt', root, '--command', 'tilt lint'], env, true);
  assert.notEqual(missing.status, 0);
  assert.match(missing.stderr, /--repair is required/);

  const unbounded = runVaultsync(['validator', 'add', 'tilt', root, '--command', 'tilt lint', '--repair', 'automatic'], env, true);
  assert.notEqual(unbounded.status, 0);
  assert.match(unbounded.stderr, /--repair-authority is required/);

  const contradictory = runVaultsync(['validator', 'add', 'tilt', root, '--command', 'tilt lint', '--repair', 'none', '--repair-authority', 'diagnostics'], env, true);
  assert.notEqual(contradictory.status, 0);
  assert.match(contradictory.stderr, /--repair-authority is not valid with --repair none/);

  const extraPath = runVaultsync(['validator', 'list', root, root, '--json'], env, true);
  assert.notEqual(extraPath.status, 0);
  assert.match(extraPath.stderr, /too many positional arguments/);

  const removeFlag = runVaultsync(['validator', 'remove', 'tilt', root, '--command', 'ignored'], env, true);
  assert.notEqual(removeFlag.status, 0);
  assert.match(removeFlag.stderr, /--command is only valid with validator add/);
});

it('keeps named validators when install updates the legacy verify command', () => {
  const root = createRepo('validator-reinstall');
  const env = testEnv('validator-reinstall');
  const registrationPath = writeRegistration(root, env, baseRegistration(root, {
    validators: {
      cortex: { command: 'cortex validate .', repair: { mode: 'none', authority: 'none' } },
    },
  }));
  const llm = join(tmp, 'validator-reinstall-llm.mjs');
  writeFileSync(llm, [
    '#!/usr/bin/env node',
    'let input = "";',
    'process.stdin.on("data", (chunk) => input += chunk);',
    'process.stdin.on("end", () => {',
    '  const payload = JSON.parse(input);',
    '  if (payload.task === "resolve_conflict") process.stdout.write(JSON.stringify({ resolved: "Remote truth line.\\n" }));',
    '  else process.exit(2);',
    '});',
    '',
  ].join('\n'), { mode: 0o755 });

  runVaultsync(['install', root, '--llm-command', `${process.execPath} ${llm}`, '--verify', 'true', '--no-launchd', '--json'], env);

  const registration = JSON.parse(readFileSync(registrationPath, 'utf8'));
  assert.equal(registration.verifyCommand, 'true');
  assert.deepEqual(registration.validators, {
    cortex: { command: 'cortex validate .', repair: { mode: 'none', authority: 'none' } },
  });
});

it('runs every validator and records aggregate failures separately', () => {
  const root = createRepo('aggregate-failures');
  const env = testEnv('aggregate-failures');
  const firstMarker = join(tmp, 'aggregate-first');
  const secondMarker = join(tmp, 'aggregate-second');
  const first = `${process.execPath} -e 'require("fs").writeFileSync(${JSON.stringify(firstMarker)}, "ran"); process.stderr.write("first diagnostic\\n"); process.exit(2)'`;
  const second = `${process.execPath} -e 'require("fs").writeFileSync(${JSON.stringify(secondMarker)}, "ran"); process.stderr.write("second diagnostic\\n"); process.exit(3)'`;
  const registrationPath = writeRegistration(root, env, baseRegistration(root, {
    validators: {
      first: { command: first, repair: { mode: 'none', authority: 'none' } },
      second: { command: second, repair: { mode: 'none', authority: 'none' } },
    },
  }));
  writeFileSync(join(root, 'README.md'), '# Test\n\nCheckpoint before validation.\n');

  const result = runVaultsync(['now', root, '--json'], env, true);
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /first diagnostic/);
  assert.match(result.stderr, /second diagnostic/);
  assert.equal(readFileSync(firstMarker, 'utf8'), 'ran');
  assert.equal(readFileSync(secondMarker, 'utf8'), 'ran');
  assert.equal(git(root, ['status', '--porcelain']), '');
  assert.equal(git(root, ['rev-list', '--count', 'HEAD']), '2');
  const registration = JSON.parse(readFileSync(registrationPath, 'utf8'));
  assert.deepEqual(registration.lastValidation.validators.map(({ name, state, exitCode }) => ({ name, state, exitCode })), [
    { name: 'first', state: 'failed', exitCode: 2 },
    { name: 'second', state: 'failed', exitCode: 3 },
  ]);
  assert.equal(registration.lastError.secondary.length, 1);

  const status = JSON.parse(runVaultsync(['status', root, '--json'], env).stdout).vaults[0];
  assert.deepEqual(status.validators.map(({ name, lastResult }) => ({ name, state: lastResult.state })), [
    { name: 'first', state: 'failed' },
    { name: 'second', state: 'failed' },
  ]);
});

it('reloads named validators inside the registration lock before writing', async () => {
  const root = createRepo('validator-concurrency');
  const env = testEnv('validator-concurrency');
  const registrationPath = writeRegistration(root, env, baseRegistration(root));
  const lockPath = `${registrationPath}.lock`;
  writeFileSync(lockPath, `${process.pid}:test-lock\n`);

  const addingTilt = spawnVaultsync(['validator', 'add', 'tilt', root, '--command', 'tilt lint', '--repair', 'none', '--json'], env);
  await new Promise((resolve) => setTimeout(resolve, 100));
  writeRegistration(root, env, baseRegistration(root, {
    validators: {
      cortex: { command: 'cortex validate .', repair: { mode: 'none', authority: 'none' } },
    },
  }));
  rmSync(lockPath);
  const result = await addingTilt;

  assert.equal(result.status, 0, result.stderr || result.stdout);
  assert.deepEqual(Object.keys(JSON.parse(readFileSync(registrationPath, 'utf8')).validators).sort(), ['cortex', 'tilt']);
});

it('clears stale outcomes when a validator is replaced, removed, or re-added', () => {
  const root = createRepo('validator-stale-outcome');
  const env = testEnv('validator-stale-outcome');
  writeRegistration(root, env, baseRegistration(root, {
    validators: {
      tilt: { command: 'old tilt lint', repair: { mode: 'none', authority: 'none' } },
    },
    lastValidation: {
      skipped: false,
      passed: true,
      validators: [{ name: 'tilt', state: 'passed', exitCode: 0, detail: null }],
    },
  }));

  runVaultsync(['validator', 'add', 'tilt', root, '--command', 'new tilt lint', '--repair', 'none', '--json'], env);
  let listed = JSON.parse(runVaultsync(['validator', 'list', root, '--json'], env).stdout);
  assert.equal(listed.validators[0].lastResult, null);

  runVaultsync(['validator', 'remove', 'tilt', root, '--json'], env);
  runVaultsync(['validator', 'add', 'tilt', root, '--command', 'new tilt lint', '--repair', 'none', '--json'], env);
  listed = JSON.parse(runVaultsync(['validator', 'list', root, '--json'], env).stdout);
  assert.equal(listed.validators[0].lastResult, null);
});

it('runs mixed legacy and named validator state without migrating the config', () => {
  const root = createRepo('mixed-runtime');
  const env = testEnv('mixed-runtime');
  const legacyMarker = join(tmp, 'mixed-legacy');
  const namedMarker = join(tmp, 'mixed-named');
  const registrationPath = writeRegistration(root, env, baseRegistration(root, {
    verifyCommand: `${process.execPath} -e 'require("fs").writeFileSync(${JSON.stringify(legacyMarker)}, "ran")'`,
    validators: {
      named: {
	command: `${process.execPath} -e 'require("fs").writeFileSync(${JSON.stringify(namedMarker)}, "ran")'`,
	repair: { mode: 'none', authority: 'none' },
      },
    },
  }));

  runVaultsync(['now', root, '--json'], env);

  assert.equal(readFileSync(legacyMarker, 'utf8'), 'ran');
  assert.equal(readFileSync(namedMarker, 'utf8'), 'ran');
  const registration = JSON.parse(readFileSync(registrationPath, 'utf8'));
  assert.equal(registration.verifyCommand.includes('mixed-legacy'), true);
  assert.deepEqual(Object.keys(registration.validators), ['named']);
  assert.deepEqual(registration.lastValidation.validators.map(({ name, state }) => ({ name, state })), [
    { name: 'legacy-verify', state: 'passed' },
    { name: 'named', state: 'passed' },
  ]);
});

it('keeps each validator repair inside its own diagnostics and authority', () => {
  const root = createRepo('repair-boundary');
  const env = testEnv('repair-boundary');
  writeFileSync(join(root, 'allowed.md'), '# Allowed\n');
  writeFileSync(join(root, 'forbidden.md'), '# Forbidden\n');
  git(root, ['add', 'allowed.md', 'forbidden.md']);
  git(root, ['commit', '-q', '--no-verify', '-m', 'Add validator fixtures']);
  const verifier = join(tmp, 'boundary-verifier.mjs');
  writeFileSync(verifier, `#!/usr/bin/env node\nprocess.stderr.write(${JSON.stringify(`${join(root, 'allowed.md')}: invalid\n`)});\nprocess.exit(1);\n`, { mode: 0o755 });
  const captured = join(tmp, 'boundary-payload.json');
  const llm = join(tmp, 'boundary-llm.mjs');
  writeFileSync(llm, [
    '#!/usr/bin/env node',
    'import { writeFileSync } from "node:fs";',
    'let input = "";',
    'process.stdin.on("data", (chunk) => input += chunk);',
    'process.stdin.on("end", () => {',
    `  writeFileSync(${JSON.stringify(captured)}, input);`,
    '  process.stdout.write(JSON.stringify({ repairs: [{ path: "forbidden.md", content: "changed\\n", reason: "cross boundary" }] }));',
    '});',
    '',
  ].join('\n'), { mode: 0o755 });
  const registrationPath = writeRegistration(root, env, baseRegistration(root, {
    llmCommand: `${process.execPath} ${llm}`,
    validators: {
      owner: {
	command: `${process.execPath} ${verifier}`,
	repair: { mode: 'automatic', authority: 'diagnostics' },
      },
      observer: { command: 'true', repair: { mode: 'none', authority: 'none' } },
    },
  }));

  const result = runVaultsync(['now', root, '--json'], env, true);
  assert.notEqual(result.status, 0);
  assert.equal(readFileSync(join(root, 'forbidden.md'), 'utf8'), '# Forbidden\n');
  const payload = JSON.parse(readFileSync(captured, 'utf8'));
  assert.equal(payload.verifier.name, 'owner');
  assert.deepEqual(payload.files.map((file) => file.path), ['allowed.md']);
  const registration = JSON.parse(readFileSync(registrationPath, 'utf8'));
  assert.equal(registration.lastValidation.validators.find((validator) => validator.name === 'observer').state, 'passed');
});

it('accepts safe relative diagnostic paths with spaces and rejects checkout escapes', () => {
  const root = createRepo('relative-diagnostics');
  const env = testEnv('relative-diagnostics');
  mkdirSync(join(root, 'notes'));
  writeFileSync(join(root, 'notes', 'allowed file.md'), '# Allowed\n');
  git(root, ['add', 'notes/allowed file.md']);
  git(root, ['commit', '-q', '--no-verify', '-m', 'Add relative diagnostic fixture']);
  const verifier = join(tmp, 'relative-verifier.mjs');
  writeFileSync(verifier, [
    '#!/usr/bin/env node',
    'process.stderr.write("notes/allowed file.md:12:3: invalid\\n");',
    'process.stderr.write("../outside.md:1: invalid\\n");',
    'process.exit(1);',
    '',
  ].join('\n'), { mode: 0o755 });
  const captured = join(tmp, 'relative-payload.json');
  const llm = join(tmp, 'relative-llm.mjs');
  writeFileSync(llm, [
    '#!/usr/bin/env node',
    'import { writeFileSync } from "node:fs";',
    'let input = "";',
    'process.stdin.on("data", (chunk) => input += chunk);',
    'process.stdin.on("end", () => {',
    `  writeFileSync(${JSON.stringify(captured)}, input);`,
    '  process.stdout.write(JSON.stringify({ repairs: [] }));',
    '});',
    '',
  ].join('\n'), { mode: 0o755 });
  writeRegistration(root, env, baseRegistration(root, {
    llmCommand: `${process.execPath} ${llm}`,
    validators: {
      relative: {
	command: `${process.execPath} ${verifier}`,
	repair: { mode: 'automatic', authority: 'diagnostics' },
      },
    },
  }));

  const result = runVaultsync(['now', root, '--json'], env, true);
  assert.notEqual(result.status, 0);
  const payload = JSON.parse(readFileSync(captured, 'utf8'));
  assert.deepEqual(payload.files.map((file) => file.path), ['notes/allowed file.md']);
});

it('never follows a repair candidate symlink outside the checkout', () => {
  const root = createRepo('repair-symlink');
  const env = testEnv('repair-symlink');
  const outside = join(tmp, 'outside-repair.md');
  writeFileSync(outside, '# Outside  \n');
  symlinkSync(outside, join(root, 'linked.md'));
  git(root, ['add', 'linked.md']);
  git(root, ['commit', '-q', '--no-verify', '-m', 'Add repair symlink fixture']);
  const verifier = join(tmp, 'symlink-verifier.mjs');
  writeFileSync(verifier, '#!/usr/bin/env node\nprocess.stderr.write("linked.md: trailing whitespace\\n");\nprocess.exit(1);\n', { mode: 0o755 });
  const llmMarker = join(tmp, 'symlink-llm-called');
  const llm = join(tmp, 'symlink-llm.mjs');
  writeFileSync(llm, `#!/usr/bin/env node\nrequire("fs").writeFileSync(${JSON.stringify(llmMarker)}, "called");\n`, { mode: 0o755 });
  writeRegistration(root, env, baseRegistration(root, {
    llmCommand: `${process.execPath} ${llm}`,
    validators: {
      symlink: {
	command: `${process.execPath} ${verifier}`,
	repair: { mode: 'automatic', authority: 'diagnostics' },
      },
    },
  }));

  const result = runVaultsync(['now', root, '--json'], env, true);
  assert.notEqual(result.status, 0);
  assert.equal(readFileSync(outside, 'utf8'), '# Outside  \n');
  assert.equal(spawnSync('test', ['-e', llmMarker]).status, 1);
});

it('publishes and executes the validator CLI through the stable machine launcher', () => {
  const root = createRepo('validator-machine-runtime');
  const env = testEnv('validator-machine-runtime');
  writeRegistration(root, env, baseRegistration(root, {
    validators: {
      stable: { command: 'true', repair: { mode: 'none', authority: 'none' } },
    },
  }));

  runVaultsync(['runtime', 'install'], env);
  const launcher = join(env.VAULTSYNC_BIN_DIR, 'vaultsync');
  const result = spawnSync(launcher, ['validator', 'list', root, '--json'], { encoding: 'utf8', env });

  assert.equal(result.status, 0, result.stderr);
  assert.equal(JSON.parse(result.stdout).validators[0].name, 'stable');
});

it('syncs an untouched legacy registration without adding validator config', () => {
  const root = createRepo('legacy-runtime');
  const env = testEnv('legacy-runtime');
  const marker = join(tmp, 'legacy-verified');
  const verifyCommand = `${process.execPath} -e 'require("fs").writeFileSync(${JSON.stringify(marker)}, "verified")'`;
  const registrationPath = writeRegistration(root, env, baseRegistration(root, { verifyCommand }));

  runVaultsync(['now', root, '--json'], env);

  assert.equal(readFileSync(marker, 'utf8'), 'verified');
  const registration = JSON.parse(readFileSync(registrationPath, 'utf8'));
  assert.equal(Object.hasOwn(registration, 'validators'), false);
  assert.equal(registration.lastValidation.validators[0].name, 'legacy-verify');
  assert.equal(registration.lastValidation.validators[0].state, 'passed');
});
