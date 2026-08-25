export const COMMANDS = [
  'install',
  'managed',
  'status',
  'pause',
  'resume',
  'now',
  'daemon',
  'doctor',
  'runtime',
];

const SUMMARIES = {
  install: 'register the current Git checkout and install the user-level daemon',
  managed: 'report whether a checkout is managed by vaultsync',
  status: 'show registered checkouts and sync state',
  pause: 'pause one checkout with an automatic resume deadline',
  resume: 'clear a pause for one checkout',
  now: 'run one immediate sync cycle for one checkout',
  daemon: 'run the long-lived debounce and remote-poll loop',
  doctor: 'run preflight checks for one checkout without registering it',
  runtime: 'install the stable machine-owned runtime',
};

export function parseInvocation(argv) {
  const [command, ...args] = argv;
  if (!command || command === 'help' || command === '--help' || command === '-h') {
    return { kind: 'help' };
  }
  if (!COMMANDS.includes(command)) {
    return { kind: 'unknown', command };
  }
  return { kind: 'command', command, args };
}

export function helpText() {
  const width = Math.max(...COMMANDS.map((c) => c.length));
  const lines = COMMANDS.map((c) => `  ${c.padEnd(width)}  ${SUMMARIES[c]}`);
  return `usage: vaultsync <command> [args]\n\n${lines.join('\n')}`;
}
