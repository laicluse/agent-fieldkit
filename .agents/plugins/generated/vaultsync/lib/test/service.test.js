import { it } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import * as runtime from '../runtime.mjs';

it('installs and reconciles the Linux daemon through the stable launcher', () => {
  const root = mkdtempSync(join(tmpdir(), 'vaultsync-service-'));
  try {
    const env = { HOME: root, LAICLUSE_HOME: join(root, 'state'), VAULTSYNC_BIN_DIR: join(root, 'bin'), PATH: '/usr/bin:/bin' };
    const calls = [];
    const run = (command, args) => { calls.push([command, ...args]); return { status: 0 }; };
    const result = runtime.installSystemdService(env, '2.0.36', run);
    const unit = readFileSync(result.unit, 'utf8');
    assert.match(unit, new RegExp(`ExecStart="${root}/bin/vaultsync" daemon`));
    assert.match(unit, /WantedBy=default.target/);
    assert.match(unit, /Restart=on-failure/);
    assert.match(unit, /Environment="LAICLUSE_HOME=/);
    assert.deepEqual(calls, [
      ['systemctl', '--user', 'daemon-reload'],
      ['systemctl', '--user', 'enable', 'vaultsync.service'],
      ['systemctl', '--user', 'restart', 'vaultsync.service'],
    ]);
    assert.equal(runtime.daemonServiceIsInstalled(env, 'linux'), true);
    assert.equal(runtime.daemonServiceNeedsReconciliation('2.0.36', env, 'linux'), false);
    assert.equal(runtime.daemonServiceNeedsReconciliation('2.0.37', env, 'linux'), true);
  } finally { rmSync(root, { recursive: true, force: true }); }
});

it('does not record a successful Linux upgrade when systemctl fails', () => {
  const root = mkdtempSync(join(tmpdir(), 'vaultsync-service-failure-'));
  const env = { HOME: root, LAICLUSE_HOME: join(root, 'state'), PATH: '/usr/bin:/bin' };
  try {
    assert.throws(() => runtime.installSystemdService(env, '2.0.36', () => ({ status: 1, stderr: 'No user bus' })), /No user bus/);
    assert.equal(runtime.daemonServiceNeedsReconciliation('2.0.36', env, 'linux'), true);
  } finally { rmSync(root, { recursive: true, force: true }); }
});

it('quotes spaces and systemd specifiers in service paths', () => {
  const unit = runtime.systemdUserUnit({ HOME: '/home/test space%user', PATH: '/usr/bin:/bin' });
  assert.match(unit, /ExecStart="\/home\/test space%%user\/\.local\/bin\/vaultsync" daemon/);
});
