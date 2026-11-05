#!/usr/bin/env python3
"""Publish independently executable Codex hooks and their user registrations."""
import argparse
import copy
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import queue
import shlex
import shutil
import subprocess
import sys
import tempfile
import threading
import time


def atomic_write(path, content):
    path = Path(path)
    if path.exists() and path.read_text() == content:
        return
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    fd, temporary = tempfile.mkstemp(prefix='.publish-', dir=path.parent)
    try:
        with os.fdopen(fd, 'w') as stream:
            stream.write(content)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def read_json(path, default=None):
    try:
        return json.loads(Path(path).read_text())
    except FileNotFoundError:
        return copy.deepcopy(default)


def bundle_hash(root):
    digest = hashlib.sha256()
    for path in sorted(root.rglob('*')):
        if path.is_symlink():
            raise ValueError('hook runtime bundles must not contain symlinks')
        if path.is_file():
            digest.update(str(path.relative_to(root)).encode() + b'\0')
            digest.update(str(path.stat().st_mode & 0o777).encode() + b'\0')
            digest.update(path.read_bytes())
    return digest.hexdigest()


def load_hooks(root):
    manifest = read_json(root / '.codex-plugin/plugin.json', {})
    sources = manifest.get('hooks', './hooks/hooks.json')
    if isinstance(sources, (str, dict)):
        sources = [sources]
    result = []
    for source in sources:
        if isinstance(source, dict):
            raise ValueError('inline hook sources require explicit migration support')
        path = (root / source).resolve()
        if not path.is_relative_to(root.resolve()):
            raise ValueError('hook source escapes its bundle')
        if path.is_file():
            result.append({'path': str(path.relative_to(root.resolve())), 'hooks': read_json(path)['hooks']})
    return result


def binding_key(plugin_id, source, event, group_index, hook_index, group, hook):
    metadata = {key: value for key, value in group.items() if key != 'hooks'}
    metadata['handler'] = {key: value for key, value in hook.items() if key not in ('command', 'commandWindows')}
    metadata['identity'] = [plugin_id, source, event, group_index, hook_index]
    return hashlib.sha256(json.dumps(metadata, sort_keys=True).encode()).hexdigest()


def publish(specs, runtime_root, activate=True):
    runtime_root = Path(runtime_root).resolve()
    runtime_root.mkdir(parents=True, exist_ok=True, mode=0o700)
    with (runtime_root / '.publish.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        plugins = {}
        for spec in specs:
            root = Path(spec['root']).resolve()
            before = bundle_hash(root)
            releases = runtime_root / 'releases'
            releases.mkdir(exist_ok=True, mode=0o700)
            release = releases / before
            if not release.exists():
                stage = Path(tempfile.mkdtemp(prefix='.staging-', dir=releases))
                try:
                    shutil.copytree(root, stage / 'bundle', symlinks=True)
                    if bundle_hash(stage / 'bundle') != before or bundle_hash(root) != before:
                        raise ValueError('plugin source changed while publishing')
                    load_hooks(stage / 'bundle')
                    os.replace(stage / 'bundle', release)
                finally:
                    shutil.rmtree(stage)
            plugins[spec['id']] = {'release': str(release), 'data': spec['data'], 'sources': load_hooks(release)}
        bindings = {}
        for plugin_id, plugin in plugins.items():
            for source in plugin['sources']:
                for event, groups in source['hooks'].items():
                    for gi, group in enumerate(groups):
                        for hi, hook in enumerate(group['hooks']):
                            key = binding_key(plugin_id, source['path'], event, gi, hi, group, hook)
                            bindings[key] = {'plugin': plugin_id, 'release': plugin['release'], 'data': plugin['data'], 'hook': hook}
        previous = read_json(runtime_root / 'current.json', {})
        retired = (set(previous.get('retiredBindings', [])) | (set(previous.get('bindings', {})) - set(bindings))) - set(bindings)
        registry = {'plugins': plugins, 'bindings': bindings, 'retiredBindings': sorted(retired)}
        if activate:
            atomic_write(runtime_root / 'current.json', json.dumps(registry, indent=2) + '\n')
        return registry


def event_key(event):
    return re.sub(r'(?<!^)(?=[A-Z])', '_', event).lower()


def registrations(registry, original, runtime_root, disabled):
    runtime_root = Path(runtime_root).resolve()
    dispatcher = runtime_root / 'dispatch.py'
    result = {'hooks': {}}
    hooks = result['hooks']
    marker = shlex.quote(str(dispatcher)) + ' dispatch '
    masks = []
    for plugin_id, plugin in sorted(registry['plugins'].items()):
        for source in plugin['sources']:
            for event, groups in source['hooks'].items():
                for group_index, group in enumerate(groups):
                    generated = copy.deepcopy(group)
                    generated['hooks'] = []
                    for hook_index, hook in enumerate(group['hooks']):
                        key = f"{plugin_id}:{source['path']}:{event_key(event)}:{group_index}:{hook_index}"
                        if key in disabled:
                            continue
                        if hook.get('type') != 'command':
                            raise ValueError(f'{key}: only command hooks are supported')
                        exported = copy.deepcopy(hook)
                        binding = binding_key(plugin_id, source['path'], event, group_index, hook_index, group, hook)
                        exported['command'] = shlex.join(['/usr/bin/python3', str(dispatcher), 'dispatch',
                            '--runtime-root', str(runtime_root), plugin_id, event,
                            str(group_index), str(hook_index), '--source', source['path'], '--binding', binding])
                        generated['hooks'].append(exported)
                        masks.append(key)
                    if generated['hooks']:
                        hooks.setdefault(event, []).append(generated)
    generated = hooks
    result = copy.deepcopy(original)
    hooks = result.setdefault('hooks', {})
    def identity(command):
        return command.rsplit(' --binding ', 1)[0]
    for event in set(hooks) | set(generated):
        pending = list(generated.get(event, []))
        ordered = []
        for old in hooks.get(event, []):
            owned = [h for h in old['hooks'] if marker in h.get('command', '')]
            if not owned:
                ordered.append(old)
                continue
            keys = {identity(h['command']) for h in owned}
            match = next((g for g in pending if any(identity(h['command']) in keys for h in g['hooks'])), None)
            if match is not None:
                pending.remove(match)
                replacement = copy.deepcopy(match)
                replacement['hooks'].extend(h for h in old['hooks'] if marker not in h.get('command', ''))
                ordered.append(replacement)
            else:
                remainder = copy.deepcopy(old)
                remainder['hooks'] = [h for h in old['hooks'] if marker not in h.get('command', '')]
                if remainder['hooks']:
                    ordered.append(remainder)
        ordered.extend(pending)
        if ordered:
            hooks[event] = ordered
        else:
            hooks.pop(event, None)
    return result, masks


def dispatch(args):
    registry = read_json(args.runtime_root / 'current.json')
    if args.binding:
        if args.binding not in registry['bindings']:
            if args.binding in registry.get('retiredBindings', []):
                return
            raise KeyError('published hook binding is unavailable')
        plugin = registry['bindings'][args.binding]
        hook = plugin['hook']
    else:
        if args.plugin not in registry['plugins']:
            return
        plugin = registry['plugins'][args.plugin]
        source = next(s for s in plugin['sources'] if s['path'] == args.source)
        hook = source['hooks'][args.event][args.group]['hooks'][args.hook]
    env = dict(os.environ, PLUGIN_ROOT=plugin['release'], CLAUDE_PLUGIN_ROOT=plugin['release'],
               PLUGIN_DATA=plugin['data'], CLAUDE_PLUGIN_DATA=plugin['data'])
    if not Path(plugin['release']).is_dir():
        raise FileNotFoundError('published hook release is unavailable')
    command = hook['command']
    os.execve('/bin/sh', ['/bin/sh', '-c', command], env)


class Rpc:
    def __init__(self, codex, home, timeout=30):
        env = dict(os.environ, CODEX_HOME=str(home))
        self.process = subprocess.Popen([codex, '-c', 'features.plugins=false', 'app-server'], env=env,
            text=True, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
        self.serial = 0
        self.timeout = timeout
        self.messages = queue.Queue()
        def read():
            try:
                for line in self.process.stdout:
                    self.messages.put(json.loads(line))
            except Exception as error:
                self.messages.put(error)
            finally:
                self.messages.put(EOFError('app-server exited'))
        threading.Thread(target=read, daemon=True).start()
        try:
            self.call('initialize', {'clientInfo': {'name': 'hook-runtime', 'version': '1'},
                                'capabilities': {'experimentalApi': True}})
            self.send({'method': 'initialized', 'params': {}})
        except Exception:
            self.close()
            raise

    def send(self, value):
        self.process.stdin.write(json.dumps(value) + '\n')
        self.process.stdin.flush()

    def call(self, method, params):
        self.serial += 1
        self.send({'id': self.serial, 'method': method, 'params': params})
        deadline = time.monotonic() + self.timeout
        while True:
            try:
                message = self.messages.get(timeout=max(0, deadline - time.monotonic()))
            except queue.Empty:
                raise TimeoutError(f'app-server did not answer {method}')
            if isinstance(message, Exception):
                raise message
            if message.get('id') == self.serial:
                if 'error' in message:
                    raise RuntimeError(message['error'])
                return message['result']

    def close(self):
        self.process.terminate()
        try:
            self.process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            self.process.kill()
            self.process.wait(timeout=5)
        self.process.stdin.close()
        self.process.stdout.close()


def specs_from_cache(home, selected, config):
    specs = []
    for plugin_id in selected:
        if not config.get('plugins', {}).get(plugin_id, {}).get('enabled', False):
            continue
        name, marketplace = plugin_id.split('@', 1)
        base = home / 'plugins/cache' / marketplace / name
        versions = [p for p in base.iterdir() if p.is_dir() and (p / '.codex-plugin/plugin.json').is_file()]
        if len(versions) != 1:
            raise ValueError(f'{plugin_id}: expected one native installed version, found {len(versions)}')
        specs.append({'id': plugin_id, 'root': str(versions[0]),
                      'data': str(home / 'plugins/data' / f'{name}-{marketplace}')})
    return specs


def definition_records(document):
    records = set()
    for event, groups in document.get('hooks', {}).items():
        for group in groups:
            metadata = {key: value for key, value in group.items() if key != 'hooks'}
            for hook in group['hooks']:
                records.add(json.dumps([event, metadata, hook], sort_keys=True))
    return records


def emitted_hook_matches(metadata, definitions, hooks_file):
    if metadata.get('source') != 'user' or Path(metadata.get('sourcePath', '')).resolve() != hooks_file.resolve():
        return False
    for event, groups in definitions['hooks'].items():
        for group in groups:
            for hook in group['hooks']:
                if metadata.get('command') != hook.get('command') or metadata.get('matcher') != group.get('matcher'):
                    continue
                if event_key(metadata['eventName']) != event_key(event):
                    continue
                if metadata.get('async', False) != hook.get('async', False):
                    continue
                if metadata.get('statusMessage') != hook.get('statusMessage'):
                    continue
                if 'timeout' in hook and metadata.get('timeoutSec') != hook['timeout']:
                    continue
                if 'additionalContextLimit' in hook and metadata.get('additionalContextLimit') != hook['additionalContextLimit']:
                    continue
                return True
    return False


def reviewed_registry(registry, previous, registrations_document, runtime_root):
    marker = shlex.quote(str(runtime_root.resolve() / 'dispatch.py')) + ' dispatch '
    allowed = set()
    for groups in registrations_document.get('hooks', {}).values():
        for group in groups:
            for hook in group['hooks']:
                command = hook.get('command', '')
                if marker in command and ' --binding ' in command:
                    allowed.add(command.rsplit(' --binding ', 1)[1])
    result = copy.deepcopy(registry)
    result['bindings'] = {key: value for key, value in registry['bindings'].items() if key in allowed}
    for key, binding in previous.get('bindings', {}).items():
        if key in allowed and key not in result['bindings'] and binding['plugin'] in registry['plugins']:
            result['bindings'][key] = binding
    result['retiredBindings'] = sorted((set(registry['retiredBindings']) |
        set(previous.get('bindings', {}))) - set(result['bindings']))
    return result


def installed_dispatcher(runtime_root):
    dispatcher = runtime_root / 'dispatch.py'
    if not dispatcher.is_file() or dispatcher.read_bytes() != Path(__file__).read_bytes():
        raise ValueError('dispatcher differs from this source; deploy through its Ansible provisioning')
    return dispatcher


def sync(args):
    dispatcher = installed_dispatcher(args.runtime_root)
    rpc = Rpc(args.codex, args.codex_home)
    try:
        config = rpc.call('config/read', {'includeLayers': False})['config']
        state = config.get('hooks', {}).get('state', {})
        previous = read_json(args.runtime_root / 'managed.json', {'masks': []})
        disabled = {key for key, value in state.items()
                    if value.get('enabled') is False and key not in previous['masks']}
        specs = specs_from_cache(args.codex_home, args.plugin, config)
        previous_registry = read_json(args.runtime_root / 'current.json', {})
        registry = publish(specs, args.runtime_root, activate=False)
        runtime_changed = registry != previous_registry
        hooks_file = args.codex_home / 'hooks.json'
        original = read_json(hooks_file, {'hooks': {}})
        desired, masks = registrations(registry, original, args.runtime_root, disabled)
        changed = original != desired
        requires_approval = bool(definition_records(desired) - definition_records(original))
        if changed and requires_approval and not args.approve_reviewed:
            safe = reviewed_registry(registry, previous_registry, original, args.runtime_root)
            atomic_write(args.runtime_root / 'current.json', json.dumps(safe, indent=2) + '\n')
            owned_masks = sorted(set(previous['masks']) | set(masks))
            previous['masks'] = owned_masks
            atomic_write(args.runtime_root / 'managed.json', json.dumps(previous, indent=2) + '\n')
            rpc.call('config/batchWrite', {'edits': [
                {'keyPath': 'hooks.state.' + json.dumps(key) + '.enabled', 'value': False,
                 'mergeStrategy': 'replace'} for key in masks], 'reloadUserConfig': True})
            raise ValueError('new user hook definitions await reviewed activation; reviewed bindings updated and withdrawn bindings stopped')
        if changed and not requires_approval and not args.approve_reviewed:
            desired = original
            changed = False
        if changed:
            atomic_write(hooks_file, json.dumps(desired, indent=2) + '\n')
        atomic_write(args.runtime_root / 'current.json', json.dumps(registry, indent=2) + '\n')
        if args.approve_reviewed or previous.get('pendingEdits'):
            listing = rpc.call('hooks/list', {'cwds': [str(args.runtime_root)]})
            edits = []
            canonical, _ = registrations(registry, {'hooks': {}}, args.runtime_root, disabled)
            expected_count = sum(len(group['hooks']) for groups in canonical['hooks'].values() for group in groups)
            approved_count = 0
            for directory in listing['data']:
                for hook in directory['hooks']:
                    if not emitted_hook_matches(hook, canonical, hooks_file):
                        continue
                    hashes = hook['currentHash'].split('/')
                    if len(hashes) != 1:
                        raise ValueError('user hook unexpectedly carries a plugin content hash')
                    edits.append({'keyPath': 'hooks.state.' + json.dumps(hook['key']) + '.trusted_hash',
                                  'value': hashes[0], 'mergeStrategy': 'replace'})
                    approved_count += 1
            if approved_count != expected_count:
                raise ValueError(f'activation expected {expected_count} exact user definitions; matched {approved_count}')
            for key in masks:
                edits.append({'keyPath': 'hooks.state.' + json.dumps(key) + '.enabled',
                              'value': False, 'mergeStrategy': 'replace'})
            if not edits:
                raise ValueError('no managed hook definitions were found for reviewed activation')
            if not args.approve_reviewed:
                pending = previous['pendingEdits']
                expected = {e['keyPath']: e['value'] for e in pending if e['keyPath'].endswith('.trusted_hash')}
                actual = {e['keyPath']: e['value'] for e in edits if e['keyPath'].endswith('.trusted_hash')}
                if expected != actual:
                    raise ValueError('interrupted activation definitions changed; reviewed activation is required')
                edits = pending
            owned_masks = sorted(set(previous['masks']) | set(masks))
            activation = {'masks': owned_masks, 'plugins': args.plugin, 'pendingEdits': edits}
            atomic_write(args.runtime_root / 'managed.json', json.dumps(activation, indent=2) + '\n')
            rpc.call('config/batchWrite', {'edits': edits, 'reloadUserConfig': True})
            activation.pop('pendingEdits')
            atomic_write(args.runtime_root / 'managed.json', json.dumps(activation, indent=2) + '\n')
        print(json.dumps({'plugins': list(registry['plugins']), 'definitionsChanged': changed,
                          'runtimeChanged': runtime_changed, 'masked': len(masks)}))
    finally:
        rpc.close()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='action', required=True)
    run = commands.add_parser('dispatch')
    run.add_argument('--runtime-root', type=Path, required=True)
    run.add_argument('plugin')
    run.add_argument('event')
    run.add_argument('group', type=int)
    run.add_argument('hook', type=int)
    run.add_argument('--source', default='hooks/hooks.json')
    run.add_argument('--binding')
    setup = commands.add_parser('sync')
    setup.add_argument('--codex-home', type=Path, default=Path.home()/'.codex')
    setup.add_argument('--runtime-root', type=Path, default=Path(os.environ.get('LAICLUSE_HOME', Path.home()/'.laicluse'))/'hooks/runtime')
    setup.add_argument('--codex', default='codex')
    setup.add_argument('--plugin', action='append', required=True)
    setup.add_argument('--approve-reviewed', action='store_true')
    args = parser.parse_args()
    args.runtime_root = args.runtime_root.resolve()
    if args.action == 'dispatch':
        try:
            dispatch(args)
        except Exception as error:
            message = f'Independent hook runtime is unavailable: {error}'
            if args.event == 'PreToolUse':
                print(message, file=sys.stderr)
                raise SystemExit(2)
            print(json.dumps({'systemMessage': message}))
    else:
        args.runtime_root.mkdir(parents=True, exist_ok=True, mode=0o700)
        with (args.runtime_root / '.sync.lock').open('a') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            sync(args)


if __name__ == '__main__':
    main()
