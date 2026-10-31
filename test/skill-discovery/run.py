"""Native routing diagnostic using shipped metadata and inert skill bodies."""
import argparse
import json
import os
import re
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]


def read_source(path, revision):
    if revision:
        result = subprocess.run(['git', 'show', f'{revision}:{path}'], cwd=ROOT,
                                text=True, capture_output=True)
        return result.stdout if result.returncode == 0 else None
    source = ROOT / path
    return source.read_text() if source.exists() else None


def run(args):
    cases = json.loads(Path(__file__).with_name('cases.json').read_text())
    if args.case:
        cases = [case for case in cases if case['id'] == args.case]
        if not cases:
            raise ValueError('Unknown case: ' + args.case)
    marketplace = json.loads(read_source(Path('.agents/plugins/marketplace.json'), args.revision))
    codex_roots = {entry['name']: Path(entry['source']['path']) for entry in marketplace['plugins']}
    if args.revision:
        tracked = subprocess.check_output(['git', 'ls-tree', '-r', '--name-only', args.revision, 'packages'], cwd=ROOT, text=True)
        paths = {Path(path) for path in tracked.splitlines()}
    else:
        paths = {path.relative_to(ROOT) for path in (ROOT / 'packages').glob('*/skills/*/SKILL.*md')}
    directories = sorted({path.parent for path in paths if re.fullmatch(r'packages/[^/]+/skills/[^/]+/SKILL\.(?:claude\.|codex\.)?md', str(path))})
    sources = []
    for directory in directories:
        specific = directory / ('SKILL.' + args.host + '.md')
        if any(directory / ('SKILL.' + host + '.md') in paths for host in ('claude', 'codex')):
            if specific in paths:
                sources.append(ROOT / specific)
        elif directory / 'SKILL.md' in paths:
            sources.append(ROOT / directory / 'SKILL.md')
    names = [source.parent.name for source in sources]
    if len(names) != len(set(names)):
        raise ValueError('This local-skill diagnostic requires unique skill names')
    identities = {source.parent.name: source.relative_to(ROOT).parts[1] + ':' + source.parent.name
                  for source in sources}
    with tempfile.TemporaryDirectory(prefix='fieldkit-routing-') as temp:
        workspace = Path(temp)
        plugins = workspace / 'plugins'
        fixtures, skipped = {}, []
        for source in sources:
            relative = source.relative_to(ROOT)
            plugin, skill = relative.parts[1], relative.parts[3]
            if args.host == 'codex' and plugin not in codex_roots:
                skipped.append(identities[skill])
                continue
            runtime_path = codex_roots[plugin] / 'skills' / skill / 'SKILL.md' if args.host == 'codex' else relative
            text = read_source(runtime_path, args.revision)
            if text is None:
                skipped.append(identities[skill])
                continue
            frontmatter = text.split('---', 2)[1]
            target = (workspace / '.agents/skills' / skill / 'SKILL.md' if args.host == 'codex'
                      else plugins / plugin / 'skills' / skill / 'SKILL.md')
            target.parent.mkdir(parents=True, exist_ok=True)
            identity = identities[skill]
            target.write_text('---' + frontmatter + '\n---\n\nReply exactly ROUTING_LOADED:' + identity
                              + ' and stop. Do not use tools or perform the requested work.\n')
            fixtures[identity] = target
            if args.host == 'claude':
                manifest = plugins / plugin / '.claude-plugin/plugin.json'
                manifest.parent.mkdir(exist_ok=True)
                manifest.write_text(json.dumps({'name': plugin, 'version': '1.0.0'}))
            else:
                policy = read_source(runtime_path.parent / 'agents/openai.yaml', args.revision)
                if policy is not None:
                    policy_target = target.parent / 'agents/openai.yaml'
                    policy_target.parent.mkdir(exist_ok=True)
                    policy_target.write_text(policy)
        for case in cases:
            expected = case.get('expected_' + args.host, case['expected'])
            missing = (set(expected) | set(case.get('requires', []))) - set(fixtures)
            if missing:
                raise ValueError('Required fixtures missing: ' + ', '.join(sorted(missing)))
            command = ['claude', '-p', '--model', 'opus', '--setting-sources', '', '--tools', 'Skill',
                       '--strict-mcp-config', '--permission-mode', 'plan', '--no-session-persistence',
                       '--plugin-dir', str(plugins), '--output-format', 'stream-json', '--verbose',
                       '--max-turns', '3', '--system-prompt',
                       'You are a skill-routing diagnostic. For the user request, invoke the relevant available skill using Skill, then stop. If none applies, reply NONE. Never perform the underlying task.']
            prompt = case.get('prompt_' + args.host, case['prompt'])
            if args.host == 'codex':
                command = ['codex', 'exec', '--ignore-user-config', '--ephemeral', '--sandbox', 'read-only',
                           '--skip-git-repo-check', '--json', '-C', str(workspace), '-']
                prompt = ('Routing diagnostic only: read the relevant available SKILL.md for this request, then stop immediately. '
                          'Do not perform the task or change files. If no skill applies, reply NONE. Request: ' + prompt)
            completed = subprocess.run(command, input=prompt, cwd=workspace,
                                       env=dict(os.environ, DD_HEADLESS='1'), text=True, capture_output=True)
            events, parse_errors = [], []
            for line in completed.stdout.splitlines():
                if line.startswith('{'):
                    try:
                        events.append(json.loads(line))
                    except json.JSONDecodeError:
                        parse_errors.append(line)
            calls, commands, markers, outside = [], [], [], []
            successful_calls = {block.get('tool_use_id') for event in events
                                for block in event.get('message', {}).get('content', [])
                                if isinstance(block, dict) and block.get('type') == 'tool_result'
                                and not block.get('is_error', False)}
            for event in events:
                text = event.get('item', {}).get('text', '') if event.get('item', {}).get('type') == 'agent_message' else ''
                for block in event.get('message', {}).get('content', []):
                    if not isinstance(block, dict):
                        continue
                    if block.get('type') == 'tool_use' and block.get('name') == 'Skill' and block.get('id') in successful_calls:
                        name = block['input'].get('skill')
                        calls.append(identities.get(name, name))
                    if event.get('type') == 'assistant' and block.get('type') == 'text':
                        text += block.get('text', '')
                markers.extend(re.findall(r'ROUTING_LOADED:([a-z0-9-]+:[a-z0-9-]+)', text))
                item = event.get('item', {})
                if event.get('type') == 'item.completed' and item.get('type') == 'command_execution':
                    commands.append(item)
                    if 'SKILL.md' in item.get('command', ''):
                        matching = [identity for identity, target in fixtures.items()
                                    if str(target) in item['command'] or str(target.relative_to(workspace)) in item['command']]
                        if not matching:
                            outside.append(item['command'])
                        if item.get('exit_code') == 0:
                            calls.extend(identity for identity in matching
                                         if 'Reply exactly ROUTING_LOADED:' + identity in item.get('aggregated_output', ''))
            invoked = sorted(set(calls + markers) & set(fixtures))
            finished = any(event.get('type') == 'result' and event.get('subtype') == 'success'
                           and not event.get('is_error', False) for event in events) if args.host == 'claude' else any(
                               event.get('type') == 'turn.completed' for event in events)
            valid = completed.returncode == 0 and finished and not outside and not parse_errors
            result = {'host': args.host, 'case': case['id'], 'revision': args.revision or 'candidate',
                      'expected': expected, 'fixtures': sorted(fixtures), 'skipped': skipped, 'parse_errors': parse_errors, 'invoked': invoked, 'invoked_all': calls,
                      'markers': markers, 'outside_fixture_reads': outside, 'commands': commands,
                      'completed': finished, 'valid': valid,
                      'pass': valid and invoked == sorted(expected)
                              and set(expected).issubset(markers),
                      'returncode': completed.returncode, 'events': events, 'stderr': completed.stderr}
            print(json.dumps(result, ensure_ascii=False), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--host', choices=['claude', 'codex'], default='claude')
    parser.add_argument('--revision')
    parser.add_argument('--case')
    run(parser.parse_args())
