import { it } from 'node:test';
import assert from 'node:assert/strict';
import { COMMANDS, helpText, parseInvocation } from '../cli.mjs';

it('exposes the vaultsync command surface', () => {
  assert.deepEqual(COMMANDS, ['install', 'managed', 'status', 'pause', 'resume', 'now', 'daemon', 'doctor', 'validator', 'runtime']);
});

it('routes known subcommands and forwards arguments', () => {
  assert.deepEqual(parseInvocation(['pause', '--minutes', '30']), {
    kind: 'command',
    command: 'pause',
    args: ['--minutes', '30'],
  });
});

it('treats help forms as help', () => {
  for (const argv of [[], ['help'], ['--help'], ['-h']]) {
    assert.equal(parseInvocation(argv).kind, 'help');
  }
});

it('reports unknown subcommands explicitly', () => {
  assert.deepEqual(parseInvocation(['sync']), { kind: 'unknown', command: 'sync' });
});

it('help text names every subcommand', () => {
  const text = helpText();
  for (const command of COMMANDS) assert.match(text, new RegExp(`\\b${command}\\b`));
});
