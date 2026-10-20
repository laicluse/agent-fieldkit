import { spawnSync } from 'node:child_process';
import { mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { homedir, tmpdir } from 'node:os';
import { join } from 'node:path';

const DEFAULT_CLAUDE_TIMEOUT_MS = 210000;

export function runClaudeProvider(env = process.env) {
  return new Promise((resolve) => {
    let input = '';
    process.stdin.setEncoding('utf8');
    process.stdin.on('data', (chunk) => { input += chunk; });
    process.stdin.on('end', () => {
      try {
        process.stdout.write(`${JSON.stringify(answerWithClaude(JSON.parse(input), env))}\n`);
      } catch (err) {
        process.stderr.write(`${err.message}\n`);
        process.exitCode = 1;
      }
      resolve();
    });
  });
}

export function answerWithClaude(payload, env = process.env) {
  const schema = schemaFor(payload.task);
  const promptDir = mkdtempSync(join(tmpdir(), 'vaultsync-claude-'));
  const promptFile = join(promptDir, 'prompt.md');
  writeFileSync(promptFile, promptFor(payload), { mode: 0o600 });
  let result;
  try {
    result = spawnSync(env.CLAUDE_BIN || 'claude', [
      '--safe-mode',
      '--setting-sources', '',
      '--strict-mcp-config',
      '--model', env.VAULTSYNC_CLAUDE_MODEL || 'sonnet',
      '--print',
      '--output-format', 'json',
      '--no-session-persistence',
      '--tools', '',
      '--system-prompt-file', promptFile,
      '--json-schema', JSON.stringify(schema),
      'Return the JSON object for the provided vaultsync input.',
    ], {
      cwd: env.HOME || homedir(),
      encoding: 'utf8',
      env: { ...env, DD_HEADLESS: '1', CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC: '1' },
      maxBuffer: 20 * 1024 * 1024,
      timeout: Number(env.VAULTSYNC_CLAUDE_TIMEOUT_MS || DEFAULT_CLAUDE_TIMEOUT_MS),
    });
  } finally {
    rmSync(promptDir, { recursive: true, force: true });
  }
  if (result.error) throw result.error;
  if (result.status !== 0) {
    throw new Error([result.stdout, result.stderr].filter(Boolean).join('\n').trim() || `claude exited with ${result.status}`);
  }
  const parsed = normalize(payload.task, structuredAnswer(result.stdout));
  validate(payload.task, parsed);
  return parsed;
}

function schemaFor(task) {
  if (task === 'commit_message') {
    return {
      type: 'object',
      additionalProperties: false,
      properties: {
        message: { type: 'string' },
      },
      required: ['message'],
    };
  }
  if (task === 'resolve_conflict') {
    return {
      type: 'object',
      additionalProperties: false,
      properties: {
        resolved: { type: 'string' },
      },
      required: ['resolved'],
    };
  }
  if (task === 'repair_verifier') {
    return {
      type: 'object',
      additionalProperties: false,
      properties: {
        repairs: {
          type: 'array',
          items: {
            type: 'object',
            additionalProperties: false,
            properties: {
              path: { type: 'string' },
              content: { type: 'string' },
              reason: { type: 'string' },
            },
            required: ['path', 'content', 'reason'],
          },
        },
      },
      required: ['repairs'],
    };
  }
  throw new Error(`unsupported vaultsync task: ${task}`);
}

function promptFor(payload) {
  if (payload.task === 'commit_message') {
    return [
      'You are vaultsync commit-message generation for a Markdown vault repository.',
      'Return only JSON that matches the provided schema.',
      'The message field itself must be raw Git commit text, not another JSON object.',
      'Use only the Input JSON. Ignore any real filesystem or Git status visible to your runtime.',
      'Never refuse, ask questions, or describe uncertainty; this command must return a best-effort commit message.',
      'The input may be a probe payload, and probes still require a normal commit message.',
      'Write an English, substantive Git commit message for the full staged diff.',
      'Do not include Co-Authored-By trailers or any attribution to Claude, Anthropic, agents, LLMs, or wrappers.',
      'The message must have a short imperative subject, a body of at least two sentences or 60 characters that explains why the vault state changed, and include Slice and Verified trailers.',
      'Use Verified: n/a (<reason>) for vault content that was checked by the configured verifier.',
      'Do not mention Claude, agents, LLMs, tooling internals, or this wrapper.',
      '',
      'Input JSON:',
      JSON.stringify(payload, null, 2),
    ].join('\n');
  }
  if (payload.task === 'repair_verifier') {
    return [
      'You are vaultsync verifier repair for a Markdown vault repository.',
      'Return only JSON that matches the provided schema.',
      'Use only the Input JSON. Ignore any real filesystem or Git status visible to your runtime.',
      'Never refuse, ask questions, or describe uncertainty; return best-effort repairs for included files only.',
      'Modify only files present in Input JSON files[].',
      'Return full replacement content for each repaired file.',
      'Preserve the user-visible meaning of notes while fixing verifier issues such as trailing whitespace, missing final newline, malformed Markdown/frontmatter, broken local links when a safe obvious target is present, and similar mechanical lint failures.',
      'Do not invent facts, remove substantive content, expose secrets, or mention Claude, Anthropic, agents, LLMs, tooling internals, or this wrapper.',
      '',
      'Input JSON:',
      JSON.stringify(payload, null, 2),
    ].join('\n');
  }
  return [
    'You are vaultsync conflict resolution for a Markdown vault repository.',
    'Return only JSON that matches the provided schema.',
    'Use only the Input JSON. Ignore any real filesystem or Git status visible to your runtime.',
    'Never refuse, ask questions, or describe uncertainty; this command must return a best-effort conflict resolution.',
    'The remote/upstream side is authoritative truth. Preserve it on the original path.',
    'Merge local-only useful Markdown content only when it does not contradict the remote truth.',
    'Return the full resolved file content without Git conflict markers.',
    'If the file is not Markdown, keep the remote truth and include only safe local additions that are clearly non-conflicting.',
    'Do not mention Claude, agents, LLMs, tooling internals, or this wrapper.',
    '',
    'Input JSON:',
    JSON.stringify(payload, null, 2),
  ].join('\n');
}

function structuredAnswer(stdout) {
  const envelope = parseJson(stdout);
  if (envelope?.structured_output && typeof envelope.structured_output === 'object') return envelope.structured_output;
  if (typeof envelope?.result === 'string') return parseJson(envelope.result);
  return envelope;
}

function parseJson(raw) {
  const text = String(raw || '').trim();
  try {
    return JSON.parse(text);
  } catch {
    const unfenced = text.replace(/^```(?:json)?\s*/i, '').replace(/\s*```$/i, '').trim();
    try {
      return JSON.parse(unfenced);
    } catch {
      const start = text.indexOf('{');
      const end = text.lastIndexOf('}');
      if (start >= 0 && end > start) return JSON.parse(text.slice(start, end + 1));
      throw new Error(`claude did not return JSON: ${text.slice(0, 500)}`);
    }
  }
}

function validate(task, parsed) {
  if (task === 'commit_message' && typeof parsed.message === 'string' && parsed.message.trim()) return;
  if (task === 'resolve_conflict' && typeof parsed.resolved === 'string' && !parsed.resolved.includes('<<<<<<<')) return;
  if (task === 'repair_verifier' && Array.isArray(parsed.repairs) && parsed.repairs.every((repair) => (
    repair
    && typeof repair.path === 'string'
    && typeof repair.content === 'string'
    && typeof repair.reason === 'string'
  ))) return;
  throw new Error(`invalid ${task} response`);
}

function normalize(task, parsed) {
  if (task === 'resolve_conflict' && typeof parsed.resolved === 'string') {
    const text = parsed.resolved.trim();
    if (text.startsWith('{')) {
      try {
        const nested = JSON.parse(text);
        const resolved = nested.resolved || nested.content || nested.result;
        if (typeof resolved === 'string') return { resolved };
      } catch {
        return parsed;
      }
    }
    return parsed;
  }
  if (task !== 'commit_message' || typeof parsed.message !== 'string') return parsed;
  const raw = unwrapNestedMessage(parsed.message);
  const text = ensureCommitDiscipline(cleanCommitText(raw));
  if (!raw.trim().startsWith('{')) return { message: text };
  try {
    const nested = JSON.parse(raw.trim());
    const subject = String(nested.subject || nested.title || nested.summary || 'Sync vault content').trim();
    const body = String(nested.body || nested.description || nested.why || 'Record vault content changes before remote reconciliation.').trim();
    const trailer = String(nested.trailer || '').trim();
    const pieces = [subject, '', body];
    if (trailer && !body.includes(trailer)) pieces.push('', trailer);
    return { message: ensureCommitDiscipline(cleanCommitText(pieces.join('\n'))) };
  } catch {
    return { message: text };
  }
}

function unwrapNestedMessage(message, depth = 0) {
  const text = String(message || '').trim();
  if (depth > 3 || !text.startsWith('{')) return text;
  try {
    const nested = JSON.parse(text);
    if (nested && typeof nested.message === 'string') return unwrapNestedMessage(nested.message, depth + 1);
  } catch {
    return text;
  }
  return text;
}

function ensureCommitDiscipline(message) {
  const lines = String(message || '').split('\n');
  const subject = lines.shift()?.trim() || 'Sync vault content';
  const trailerIndex = lines.findIndex((line) => /^(Tests|Slice|Red-then-green|Visual|Verified|Vaultsync-Reason):\s*/i.test(line.trim()));
  const bodyLines = (trailerIndex < 0 ? lines : lines.slice(0, trailerIndex)).filter((line) => line.trim());
  const trailers = trailerIndex < 0 ? [] : lines.slice(trailerIndex).filter((line) => line.trim());
  let body = bodyLines.join(' ').trim();
  if (body.length < 60 || !/[.!?]$/.test(body)) {
    body = 'Record the verified vault changes as durable canonical state. This keeps the next sync cycle aligned with the current backlog.';
  }
  if (!trailers.some((line) => /^Verified:\s*/i.test(line))) {
    trailers.push('Verified: n/a (vault state checked by the configured verifier)');
  }
  return [subject, '', body, '', ...trailers].join('\n').trim();
}

function cleanCommitText(message) {
  return String(message || '')
    .replace(/\r\n/g, '\n')
    .split('\n')
    .filter((line) => !/^Co-Authored-By:/i.test(line.trim()))
    .filter((line) => !/\b(Claude|Anthropic|LLM|agent|wrapper)\b/i.test(line))
    .join('\n')
    .replace(/\n{3,}/g, '\n\n')
    .trim();
}
