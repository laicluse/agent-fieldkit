#!/usr/bin/env python3
"""Exercise native plugin updates using a disposable home and local mock model."""
import http.server
import argparse
import json
import os
from pathlib import Path
import queue
import subprocess
import tempfile
import threading
import time


class Client:
    def __init__(self, env):
        self.p = subprocess.Popen(['codex', 'app-server'], env=env, text=True,
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
        self.events = queue.Queue()
        self.serial = 0
        self.deferred = []
        def read():
            for line in self.p.stdout:
                self.events.put(json.loads(line))
        threading.Thread(target=read, daemon=True).start()
        self.call('initialize', {'clientInfo': {'name': 'hook-probe', 'version': '1'},
            'capabilities': {'experimentalApi': True}})
        self.send({'method': 'initialized', 'params': {}})

    def send(self, item):
        self.p.stdin.write(json.dumps(item) + '\n')
        self.p.stdin.flush()

    def call(self, method, params):
        self.serial += 1
        self.send({'id': self.serial, 'method': method, 'params': params})
        while True:
            item = self.events.get(timeout=30)
            if item.get('id') == self.serial:
                if 'error' in item:
                    raise RuntimeError(item['error'])
                return item['result']
            self.deferred.append(item)

    def finish(self):
        result = []
        while True:
            item = self.deferred.pop(0) if self.deferred else self.events.get(timeout=30)
            if item.get('method') in ['hook/completed', 'error']:
                result.append(item)
            if item.get('method') == 'turn/completed':
                return result


def assert_user_stop_completed(events):
    runs = [e['params']['run'] for e in events if e.get('method') == 'hook/completed']
    stops = [r for r in runs if r['eventName'] == 'stop' and r['source'] == 'user']
    assert len(stops) == 1 and stops[0]['status'] == 'completed', events
    assert all(r['status'] != 'failed' for r in runs), events
    assert not any(entry['kind'] == 'error' for r in runs for entry in r['entries']), events
    assert not any(e.get('method') == 'error' for e in events), events


def probe(adapter_template, user_runtime=False, managed_runtime=False):
    version = subprocess.run(['codex', '--version'], capture_output=True, text=True, check=True).stdout.strip()
    if version != 'codex-cli 0.166.0':
        raise RuntimeError(f'This version-specific diagnostic requires codex-cli 0.166.0; found {version}')
    print(version, flush=True)
    requested, release = threading.Event(), threading.Event()
    request_tool, denial_received = threading.Event(), threading.Event()
    class Model(http.server.BaseHTTPRequestHandler):
        def log_message(self, *args):
            pass

        def do_POST(self):
            request = self.rfile.read(int(self.headers.get('Content-Length', 0)))
            if b'probe denies tool execution' in request:
                denial_received.set()
            requested.set()
            if not release.wait(30):
                return
            events = [
                {'type': 'response.created', 'response': {'id': 'r1'}},
                {'type': 'response.output_item.done', 'item': {'type': 'message',
                 'role': 'assistant', 'id': 'm1',
                 'content': [{'type': 'output_text', 'text': 'Done.'}]}},
                {'type': 'response.completed', 'response': {'id': 'r1',
                 'usage': {'input_tokens': 0, 'output_tokens': 0, 'total_tokens': 0}}}]
            if request_tool.is_set():
                request_tool.clear()
                events[1] = {'type': 'response.output_item.done', 'item': {
                    'type': 'function_call', 'name': 'exec_command',
                    'call_id': 'denied-call', 'id': 'denied-item',
                    'arguments': json.dumps({'cmd': f'touch "{tool_marker}"',
                                             'workdir': str(root)})}}
            body = ''.join('data: ' + json.dumps(e) + '\n\n' for e in events).encode()
            self.send_response(200)
            self.send_header('Content-Type', 'text/event-stream')
            self.send_header('Content-Length', str(len(body)))
            self.end_headers()
            self.wfile.write(body)

    server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Model)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    try:
        with tempfile.TemporaryDirectory(prefix='hook-lifecycle-') as temporary:
            root = Path(temporary)
            home, marketplace = root/'home', root/'marketplace'
            home.mkdir()
            plugin = marketplace/'probe'
            (plugin/'.codex-plugin').mkdir(parents=True)
            (plugin/'hooks').mkdir()
            (marketplace/'.agents/plugins').mkdir(parents=True)
            (marketplace/'.agents/plugins/marketplace.json').write_text(json.dumps({
                'name': 'lifecycle-probe', 'plugins': [{'name': 'probe', 'source': {
                    'source': 'local', 'path': './probe'},
                    'policy': {'installation': 'AVAILABLE'}}]}))
            log = root/'hooks.log'
            tool_marker = root/'tool-executed'
            command = '"${PLUGIN_ROOT}/hooks/dispatch.sh"'
            if adapter_template and not user_runtime:
                command = subprocess.run(['bash', '-c',
                    'source "$1" help >/dev/null; codex_hook_command probe Stop \'${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT}}/hooks/dispatch.sh\'',
                    'probe', str(adapter_template)], check=True, text=True,
                    capture_output=True).stdout.strip()
            guard = plugin/'hooks/deny.sh'
            guard.write_text('#!/bin/sh\necho "probe denies tool execution" >&2\nexit 2\n')
            guard.chmod(0o755)
            guard_command = '"${PLUGIN_ROOT}/hooks/deny.sh"'
            if adapter_template and not user_runtime:
                guard_command = subprocess.run(['bash', '-c',
                    'source "$1" help >/dev/null; codex_hook_command probe PreToolUse \'${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT}}/hooks/deny.sh\'',
                    'probe', str(adapter_template)], check=True, text=True,
                    capture_output=True).stdout.strip()
            (plugin/'hooks/hooks.json').write_text(json.dumps({'hooks': {
                'Stop': [{'hooks': [{'type': 'command', 'command': command}]}],
                'PreToolUse': [{'matcher': 'Bash', 'hooks': [
                    {'type': 'command', 'command': guard_command}]}]}}))
            runtime = root/'machine runtime'
            if user_runtime:
                runtime.mkdir()
                (runtime/'deny.sh').write_bytes(guard.read_bytes())
                (runtime/'deny.sh').chmod(0o755)
                (plugin/'hooks/hooks.json').write_text('{"hooks": {}}')
                (home/'hooks.json').write_text(json.dumps({'hooks': {
                    'Stop': [{'hooks': [{'type': 'command',
                                        'command': f'"{runtime}/dispatch.sh"'}]}],
                    'PreToolUse': [{'matcher': 'Bash', 'hooks': [
                        {'type': 'command', 'command': f'"{runtime}/deny.sh"'}]}]}}))
            def version(v):
                (plugin/'.codex-plugin/plugin.json').write_text(json.dumps({'name': 'probe', 'version': v}))
                entry = plugin/'hooks/dispatch.sh'
                entry.write_text(f'#!/bin/sh\nprintf "%s\\n" "{v}" >> "{log}"\n')
                entry.chmod(0o755)
                if user_runtime:
                    staged = runtime/'.dispatch-staging'
                    staged.write_bytes(entry.read_bytes())
                    staged.chmod(0o755)
                    staged.replace(runtime/'dispatch.sh')
            env = dict(os.environ, CODEX_HOME=str(home))
            for key in ['OPENAI_API_KEY', 'HC_TERMINAL_ID', 'CODEX_THREAD_ID']:
                env.pop(key, None)
            (home/'config.toml').write_text(f'''model = "mock-model"
model_provider = "fixture"
[model_providers.fixture]
name = "Local fixture"
base_url = "http://127.0.0.1:{server.server_port}/v1"
wire_api = "responses"
requires_openai_auth = false
[plugins."probe@lifecycle-probe"]
enabled = true
''')
            def cli(*args):
                p = subprocess.run(['codex', 'plugin', *args], env=env,
                    capture_output=True, text=True, timeout=30)
                assert p.returncode == 0, p.stderr
            version('1.0.0')
            cli('marketplace', 'add', str(marketplace))
            cli('add', 'probe@lifecycle-probe')
            client = Client(env)
            try:
                def trust():
                    listing = client.call('hooks/list', {'cwds': [str(root)]})
                    hooks = [h for d in listing['data'] for h in d['hooks']]
                    assert len(hooks) == 2, hooks
                    values = {}
                    for hook in hooks:
                        hashes = hook['currentHash'].split('/')
                        value = {'trusted_hash': hashes[0]}
                        if len(hashes) > 1:
                            value['trusted_content_hash'] = hashes[1]
                        values[hook['key']] = value
                    client.call('config/batchWrite', {'edits': [{'keyPath': 'hooks.state',
                        'value': values, 'mergeStrategy': 'upsert'}],
                        'reloadUserConfig': True})
                trust()
                thread = client.call('thread/start', {'cwd': str(root), 'model': 'mock-model',
                    'approvalPolicy': 'never', 'sandbox': 'danger-full-access'})['thread']['id']
                def turn():
                    client.call('turn/start', {'threadId': thread,
                        'input': [{'type': 'text', 'text': 'Reply done.'}]})
                release.set()
                turn()
                baseline = client.finish()
                assert log.read_text().splitlines() == ['1.0.0'], baseline
                log.unlink()
                request_tool.set()
                turn()
                denied = client.finish()
                assert denial_received.is_set(), denied
                assert not tool_marker.exists(), 'A denied tool was executed'
                assert log.read_text().splitlines() == ['1.0.0'], denied
                print('PASS: approved PreToolUse denial prevents actual command execution', flush=True)
                log.unlink()
                if managed_runtime:
                    managed = root/'managed runtime'
                    manager = Path(__file__).resolve().parents[1]/'lib/hook_runtime.py'
                    managed.mkdir()
                    (managed/'dispatch.py').write_bytes(manager.read_bytes())
                    def synchronize(approve=False, interrupt=False, pending=False):
                        command = ['/usr/bin/python3', str(manager), 'sync', '--codex-home', str(home),
                            '--runtime-root', str(managed), '--plugin', 'probe@lifecycle-probe']
                        if approve:
                            command.append('--approve-reviewed')
                        if interrupt:
                            injected = '''import importlib.util,sys
path=sys.argv[1]
spec=importlib.util.spec_from_file_location('publisher',path)
module=importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
original=module.Rpc.call
def call(self,method,params):
    result=original(self,method,params)
    if method=='config/batchWrite':
        raise RuntimeError('simulated interruption after config activation')
    return result
module.Rpc.call=call
sys.argv=[path]+sys.argv[2:]
module.main()
'''
                            command = ['/usr/bin/python3', '-c', injected, str(manager)] + command[2:]
                        result = subprocess.run(command, env=env, capture_output=True, text=True, timeout=30)
                        if pending:
                            assert result.returncode != 0 and 'await reviewed activation' in result.stderr, result.stderr
                            return
                        if interrupt:
                            assert result.returncode != 0 and 'simulated interruption' in result.stderr, result.stderr
                            pending = json.loads((managed/'managed.json').read_text())
                            assert len(pending['masks']) == 2 and pending['pendingEdits'], pending
                            return
                        assert result.returncode == 0, result.stdout + result.stderr
                    requested.clear()
                    release.clear()
                    turn()
                    assert requested.wait(20), 'mock model was not called'
                    synchronize(approve=True, interrupt=True)
                    synchronize()
                    assert 'pendingEdits' not in json.loads((managed/'managed.json').read_text())
                    print('PASS: interrupted native activation resumes with mask ownership intact', flush=True)
                    client.call('config/batchWrite', {'edits': [], 'reloadUserConfig': True})
                    version('1.0.1')
                    cli('add', 'probe@lifecycle-probe')
                    synchronize()
                    release.set()
                    migrated = client.finish()
                    assert_user_stop_completed(migrated)
                    assert log.read_text().splitlines() == ['1.0.1'], migrated
                    print('PASS: held turn migrates, shared bundle is removed, exactly one user hook completes', flush=True)
                    log.unlink()
                    request_tool.set()
                    denial_received.clear()
                    turn()
                    denied = client.finish()
                    assert denial_received.is_set() and not tool_marker.exists(), denied
                    assert log.read_text().splitlines() == ['1.0.1'], denied
                    print('PASS: published guard prevents actual command execution after migration', flush=True)
                    log.unlink()
                    requested.clear()
                    release.clear()
                    turn()
                    assert requested.wait(20), 'mock model was not called'
                    version('1.0.2')
                    observer = Client(env)
                    try:
                        observer.call('plugin/list', {'cwds': [str(root)]})
                        old = home/'plugins/cache/lifecycle-probe/probe/1.0.1'
                        deadline = time.monotonic() + 20
                        while old.exists() and time.monotonic() < deadline:
                            observer.call('plugin/list', {'cwds': [str(root)]})
                            time.sleep(0.05)
                        assert not old.exists(), 'Discovery did not replace the bundle'
                        synchronize()
                    finally:
                        observer.p.terminate()
                        observer.p.wait(timeout=10)
                    release.set()
                    updated = client.finish()
                    assert_user_stop_completed(updated)
                    assert log.read_text().splitlines() == ['1.0.2'], updated
                    print('PASS: native automatic update and complete runtime publication preserve one hook execution', flush=True)
                    client.p.terminate()
                    client.p.wait(timeout=10)
                    client = Client(env)
                    client.call('thread/resume', {'threadId': thread, 'cwd': str(root)})
                    log.unlink()
                    turn()
                    resumed = client.finish()
                    assert_user_stop_completed(resumed)
                    assert log.read_text().splitlines() == ['1.0.2'], resumed
                    print('PASS: resumed conversation uses the published runtime', flush=True)
                    installed_hooks = home/'plugins/cache/lifecycle-probe/probe/1.0.2/hooks/hooks.json'
                    declarations = json.loads(installed_hooks.read_text())
                    declarations['hooks']['Stop'][0]['hooks'].append({'type': 'command', 'command': 'echo pending'})
                    installed_hooks.write_text(json.dumps(declarations))
                    synchronize(pending=True)
                    masks = json.loads((managed/'managed.json').read_text())['masks']
                    assert len(masks) == 3, masks
                    log.unlink()
                    turn()
                    pending_turn = client.finish()
                    assert_user_stop_completed(pending_turn)
                    assert log.read_text().splitlines() == ['1.0.2'], pending_turn
                    print('PASS: pending new declaration stays masked while reviewed hook runs once', flush=True)
                    declarations['hooks']['PreToolUse'][0]['hooks'][0]['timeout'] = 24
                    installed_hooks.write_text(json.dumps(declarations))
                    synchronize(pending=True)
                    log.unlink()
                    request_tool.set()
                    denial_received.clear()
                    turn()
                    pending_guard = client.finish()
                    assert denial_received.is_set() and not tool_marker.exists(), pending_guard
                    assert log.read_text().splitlines() == ['1.0.2'], pending_guard
                    print('PASS: changed guard metadata keeps its approved implementation blocking during review', flush=True)
                    client.call('config/batchWrite', {'edits': [{'keyPath': 'plugins."probe@lifecycle-probe".enabled',
                        'value': False, 'mergeStrategy': 'replace'}], 'reloadUserConfig': True})
                    synchronize()
                    log.unlink()
                    turn()
                    disabled = client.finish()
                    assert not log.exists(), disabled
                    assert_user_stop_completed(disabled)
                    print('PASS: disabling the plugin stops its already registered callback without reapproval', flush=True)
                    return
                if user_runtime:
                    for v, automatic in [('1.0.1', False), ('1.0.2', True)]:
                        requested.clear()
                        release.clear()
                        turn()
                        assert requested.wait(20), 'mock model was not called'
                        version(v)
                        if automatic:
                            observer = Client(env)
                            try:
                                observer.call('plugin/list', {'cwds': [str(root)]})
                                old = home/'plugins/cache/lifecycle-probe/probe/1.0.1'
                                deadline = time.monotonic() + 20
                                while old.exists() and time.monotonic() < deadline:
                                    observer.call('plugin/list', {'cwds': [str(root)]})
                                    time.sleep(0.05)
                                assert not old.exists(), 'Discovery did not activate the local source version'
                            finally:
                                observer.p.terminate()
                                observer.p.wait(timeout=10)
                        else:
                            cli('add', 'probe@lifecycle-probe')
                        release.set()
                        result = client.finish()
                        assert log.read_text().splitlines() == [v], result
                        assert_user_stop_completed(result)
                        print(f'PASS: user hook executes {v} during {"automatic" if automatic else "explicit"} parallel plugin update', flush=True)
                        log.unlink()
                    client.p.terminate()
                    client.p.wait(timeout=10)
                    client = Client(env)
                    client.call('thread/resume', {'threadId': thread, 'cwd': str(root)})
                    turn()
                    resumed = client.finish()
                    assert log.read_text().splitlines() == ['1.0.2'], resumed
                    assert_user_stop_completed(resumed)
                    print('PASS: resumed user hook executes current runtime without renewed definition approval', flush=True)
                    return
                version('1.0.1')
                cli('add', 'probe@lifecycle-probe')
                turn()
                unapproved = client.finish()
                assert any('hook approval required' in json.dumps(e) for e in unapproved), unapproved
                assert not log.exists(), 'Changed bundle executed without reapproval'
                trust()
                turn()
                approved = client.finish()
                assert log.read_text().splitlines() == ['1.0.1'], approved
                print('PASS: between-turn update selects approved 1.0.1', flush=True)
                client.p.terminate()
                client.p.wait(timeout=10)
                client = Client(env)
                client.call('thread/resume', {'threadId': thread, 'cwd': str(root)})
                turn()
                resumed = client.finish()
                assert log.read_text().splitlines() == ['1.0.1', '1.0.1'], resumed
                print('PASS: fresh app-server resumes with approved 1.0.1', flush=True)
                log.unlink()
                requested.clear()
                release.clear()
                turn()
                assert requested.wait(20), 'mock model was not called'
                version('1.0.2')
                cli('add', 'probe@lifecycle-probe')
                old = home/'plugins/cache/lifecycle-probe/probe/1.0.1'
                print('old bundle exists:', old.exists(), flush=True)
                release.set()
                first = client.finish()
                turn()
                unapproved = client.finish()
                assert not any('No such file' in json.dumps(e) for e in unapproved), unapproved
                assert any('hook approval required' in json.dumps(e) for e in unapproved), unapproved
                assert not log.exists(), 'Changed bundle executed without reapproval'
                trust()
                turn()
                second = client.finish()
                print('hook log:', log.read_text() if log.exists() else '(empty)', flush=True)
                assert not old.exists()
                assert any('No such file' in json.dumps(e) for e in first), first
                assert log.read_text().splitlines() == ['1.0.2']
                assert not any('No such file' in json.dumps(e) for e in second), second
                print('PASS: active turn fails; reapproved next turn uses the new bundle')
                log.unlink()
                requested.clear()
                release.clear()
                turn()
                assert requested.wait(20), 'mock model was not called'
                version('1.0.3')
                observer = Client(env)
                try:
                    observer.call('plugin/list', {'cwds': [str(root)]})
                    old = home/'plugins/cache/lifecycle-probe/probe/1.0.2'
                    deadline = time.monotonic() + 20
                    while old.exists() and time.monotonic() < deadline:
                        observer.call('plugin/list', {'cwds': [str(root)]})
                        time.sleep(0.05)
                    assert not old.exists(), 'Discovery did not activate the local source version'
                finally:
                    observer.p.terminate()
                    observer.p.wait(timeout=10)
                release.set()
                discovered = client.finish()
                assert any('No such file' in json.dumps(e) for e in discovered), discovered
                assert not log.exists(), 'The removed bundle unexpectedly executed'
                print('PASS: parallel discovery auto-activates 1.0.3 and breaks the held turn', flush=True)
            finally:
                release.set()
                client.p.terminate()
                client.p.wait(timeout=10)
    finally:
        server.shutdown()
        server.server_close()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--adapter-template', type=Path,
        default=Path(__file__).resolve().parents[1]/'templates/plugin-adapters')
    parser.add_argument('--native', action='store_true', help='Use an unwrapped host-native command')
    parser.add_argument('--user-runtime', action='store_true', help='Probe an approved user hook with an atomically replaced standalone script')
    parser.add_argument('--managed-runtime', action='store_true', help='Verify real runtime publication and bundled-to-user migration during a held turn')
    args = parser.parse_args()
    probe(None if args.native else args.adapter_template.resolve(), args.user_runtime, args.managed_runtime)
