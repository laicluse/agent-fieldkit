#!/usr/bin/env python3
"""Exercise native plugin updates using a disposable home and local mock model."""
import http.server
import json
import os
from pathlib import Path
import queue
import subprocess
import tempfile
import threading


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


def probe():
    version = subprocess.run(['codex', '--version'], capture_output=True, text=True, check=True).stdout.strip()
    if version != 'codex-cli 0.166.0':
        raise RuntimeError(f'This version-specific diagnostic requires codex-cli 0.166.0; found {version}')
    print(version, flush=True)
    requested, release = threading.Event(), threading.Event()
    class Model(http.server.BaseHTTPRequestHandler):
        def log_message(self, *args):
            pass

        def do_POST(self):
            self.rfile.read(int(self.headers.get('Content-Length', 0)))
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
            command = '"${PLUGIN_ROOT}/hooks/dispatch.sh"'
            (plugin/'hooks/hooks.json').write_text(json.dumps({'hooks': {'Stop': [
                {'hooks': [{'type': 'command', 'command': command}]}]}}))
            def version(v):
                (plugin/'.codex-plugin/plugin.json').write_text(json.dumps({'name': 'probe', 'version': v}))
                entry = plugin/'hooks/dispatch.sh'
                entry.write_text(f'#!/bin/sh\nprintf "%s\\n" "{v}" >> "{log}"\n')
                entry.chmod(0o755)
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
                    hooks = [h for d in listing['data'] for h in d['hooks'] if h.get('pluginId')]
                    assert len(hooks) == 1, hooks
                    hook = hooks[0]
                    hashes = hook['currentHash'].split('/')
                    value = {'trusted_hash': hashes[0]}
                    if len(hashes) > 1:
                        value['trusted_content_hash'] = hashes[1]
                    client.call('config/batchWrite', {'edits': [{'keyPath': 'hooks.state',
                        'value': {hook['key']: value}, 'mergeStrategy': 'upsert'}],
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
                requested.clear()
                release.clear()
                turn()
                assert requested.wait(20), 'mock model was not called'
                version('1.0.1')
                cli('add', 'probe@lifecycle-probe')
                old = home/'plugins/cache/lifecycle-probe/probe/1.0.0'
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
                assert log.read_text().splitlines() == ['1.0.1']
                assert not any('No such file' in json.dumps(e) for e in second), second
                print('PASS: active turn fails; reapproved next turn uses the new bundle')
            finally:
                release.set()
                client.p.terminate()
                client.p.wait(timeout=10)
    finally:
        server.shutdown()
        server.server_close()


if __name__ == '__main__':
    probe()
