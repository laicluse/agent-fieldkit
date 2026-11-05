import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

MODULE = Path(__file__).resolve().parents[1] / 'lib/hook_runtime.py'


class HookRuntimeTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='hook-runtime-')
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name)
        self.root = self.base / 'runtime with spaces'
        self.bundle = self.base / 'cache/market/probe/1.0.0'
        (self.bundle / 'hooks').mkdir(parents=True)
        (self.bundle / '.codex-plugin').mkdir()
        (self.bundle / '.codex-plugin/plugin.json').write_text(json.dumps({'name': 'probe', 'version': '1.0.0'}))
        self.write_hook('first')
        self.spec = {'id': 'probe@market', 'root': str(self.bundle), 'data': str(self.base / 'plugin data')}
        spec = importlib.util.spec_from_file_location('hook_runtime', MODULE)
        self.module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.module)

    def write_hook(self, text):
        entry = self.bundle / 'hooks/dispatch.sh'
        entry.write_text('#!/bin/sh\n. "$PLUGIN_ROOT/hooks/message.sh"\nprintf "%s|%s|%s|" "$MESSAGE" "$PROBE_PREFIX" "$1"\ncat\nexit 7\n')
        entry.chmod(0o755)
        (self.bundle / 'hooks/message.sh').write_text(f'MESSAGE={text}\n')
        (self.bundle / 'hooks/hooks.json').write_text(json.dumps({'hooks': {'Stop': [
            {'matcher': '.*', 'hooks': [{'type': 'command', 'timeout': 12,
             'command': 'PROBE_PREFIX=preserved "${PLUGIN_ROOT}/hooks/dispatch.sh" argument'}]}]}}))

    def publish(self):
        return self.module.publish([self.spec], self.root)

    def invoke(self, registry):
        return subprocess.run(['python3', str(MODULE), 'dispatch', '--runtime-root', str(self.root),
                               'probe@market', 'Stop', '0', '0'], input='payload', text=True,
                              capture_output=True, env={**os.environ, 'SHELL': '/bin/sh'})

    def test_missing_pretool_runtime_blocks_execution(self):
        result = subprocess.run(['python3', str(MODULE), 'dispatch', '--runtime-root', str(self.root),
            'probe@market', 'PreToolUse', '0', '0'], text=True, capture_output=True)
        self.assertEqual(result.returncode, 2, result.stderr)

    def test_pretool_preserves_original_hook_exit_status(self):
        hooks_file = self.bundle/'hooks/hooks.json'
        hooks = json.loads(hooks_file.read_text())
        hooks['hooks']['PreToolUse'] = hooks['hooks']['Stop']
        hooks_file.write_text(json.dumps(hooks))
        self.publish()
        result = subprocess.run(['python3', str(MODULE), 'dispatch', '--runtime-root', str(self.root),
            'probe@market', 'PreToolUse', '0', '0'], input='payload', text=True, capture_output=True)
        self.assertEqual(result.returncode, 7, result.stderr)

    def test_dispatch_retains_full_bundle_after_native_cache_removal(self):
        self.publish()
        shutil.rmtree(self.bundle)
        result = self.invoke(None)
        self.assertEqual((result.returncode, result.stdout), (7, 'first|preserved|argument|payload'))

    def test_publication_switches_to_complete_new_release(self):
        first = self.publish()
        self.write_hook('second')
        second = self.publish()
        self.assertNotEqual(first['plugins']['probe@market']['release'], second['plugins']['probe@market']['release'])
        self.assertEqual(self.invoke(None).stdout, 'second|preserved|argument|payload')
        self.assertTrue(Path(first['plugins']['probe@market']['release']).exists())

    def test_removed_declaration_stops_execution_after_publication(self):
        first = self.publish()
        original = next(iter(first['bindings']))
        hooks_path = self.bundle / 'hooks/hooks.json'
        hooks = json.loads(hooks_path.read_text())
        hooks['hooks']['Stop'][0]['matcher'] = 'changed'
        hooks_path.write_text(json.dumps(hooks))
        self.write_hook('second')
        hooks_path.write_text(json.dumps(hooks))
        second = self.publish()
        result = subprocess.run(['python3', str(MODULE), 'dispatch', '--runtime-root', str(self.root),
            'probe@market', 'Stop', '0', '0', '--binding', original], capture_output=True, text=True)
        self.assertEqual((result.returncode, result.stdout), (0, ''))

    def test_disabled_plugin_stops_its_registered_callback(self):
        self.publish()
        self.module.publish([], self.root)
        result = self.invoke(None)
        self.assertEqual((result.returncode, result.stdout), (0, ''))

    def test_pending_review_updates_existing_and_stops_withdrawn_bindings(self):
        first = self.publish()
        original, _ = self.module.registrations(first, {'hooks': {}}, self.root, set())
        self.write_hook('second')
        path = self.bundle / 'hooks/hooks.json'
        hooks = json.loads(path.read_text())
        hooks['hooks']['Stop'][0]['hooks'].append({'type': 'command', 'command': 'echo new'})
        path.write_text(json.dumps(hooks))
        candidate = self.module.publish([self.spec], self.root, activate=False)
        safe = self.module.reviewed_registry(candidate, first, original, self.root)
        self.assertEqual(set(safe['bindings']), set(first['bindings']))
        self.assertNotEqual(next(iter(safe['bindings'].values()))['release'], next(iter(first['bindings'].values()))['release'])
        hooks['hooks']['Stop'][0]['hooks'][0]['timeout'] = 24
        path.write_text(json.dumps(hooks))
        changed = self.module.publish([self.spec], self.root, activate=False)
        waiting = self.module.reviewed_registry(changed, first, original, self.root)
        self.assertEqual(waiting['bindings'], first['bindings'])
        self.assertFalse(set(first['bindings']) & set(waiting['retiredBindings']))
        withdrawn = self.module.publish([], self.root, activate=False)
        stopped = self.module.reviewed_registry(withdrawn, first, original, self.root)
        self.assertFalse(stopped['bindings'])
        self.assertTrue(set(first['bindings']).issubset(stopped['retiredBindings']))

    def test_preparing_new_definitions_keeps_the_current_registry(self):
        self.publish()
        before = (self.root / 'current.json').read_bytes()
        self.write_hook('second')
        self.module.publish([self.spec], self.root, activate=False)
        self.assertEqual((self.root / 'current.json').read_bytes(), before)
        self.assertEqual(self.invoke(None).stdout, 'first|preserved|argument|payload')

    def test_concurrent_publications_converge_on_a_complete_release(self):
        worker = ('import importlib.util,json,sys,pathlib; '
                  's=importlib.util.spec_from_file_location("hooks",sys.argv[1]); '
                  'm=importlib.util.module_from_spec(s); s.loader.exec_module(m); '
                  'm.publish(json.loads(sys.argv[2]),pathlib.Path(sys.argv[3]))')
        processes = [subprocess.Popen(['python3', '-c', worker, str(MODULE),
            json.dumps([self.spec]), str(self.root)]) for _ in range(2)]
        for process in processes:
            self.assertEqual(process.wait(timeout=15), 0)
        self.assertEqual(self.invoke(None).stdout, 'first|preserved|argument|payload')

    def test_failed_copy_keeps_previous_registry_and_behavior(self):
        self.publish()
        before = (self.root / 'current.json').read_bytes()
        original = self.module.shutil.copytree
        def fail(*args, **kwargs):
            raise OSError('source disappeared')
        self.write_hook('second')
        self.module.shutil.copytree = fail
        try:
            with self.assertRaises(OSError):
                self.publish()
        finally:
            self.module.shutil.copytree = original
        self.assertEqual((self.root / 'current.json').read_bytes(), before)
        self.assertEqual(self.invoke(None).stdout, 'first|preserved|argument|payload')

    def test_missing_bundle_keeps_working_release(self):
        self.publish()
        shutil.rmtree(self.bundle)
        with self.assertRaises(FileNotFoundError):
            self.publish()
        self.assertEqual(self.invoke(None).stdout, 'first|preserved|argument|payload')

    def test_user_registrations_preserve_other_sources_and_options(self):
        registry = self.publish()
        original = {'hooks': {'SessionEnd': [{'hooks': [{'type': 'command', 'command': 'existing-user-hook'}]}]}}
        generated, masks = self.module.registrations(registry, original, self.root, set())
        self.assertEqual(generated['hooks']['SessionEnd'], original['hooks']['SessionEnd'])
        hook = generated['hooks']['Stop'][0]['hooks'][0]
        self.assertEqual(hook['timeout'], 12)
        self.assertEqual(generated['hooks']['Stop'][0]['matcher'], '.*')
        self.assertIn('probe@market:hooks/hooks.json:stop:0:0', masks)
        repeat, _ = self.module.registrations(registry, generated, self.root, set())
        self.assertEqual(repeat, generated)

    def test_user_hook_appended_after_managed_hook_keeps_its_position(self):
        registry = self.publish()
        initial, _ = self.module.registrations(registry, {'hooks': {}}, self.root, set())
        initial['hooks']['Stop'].append({'hooks': [{'type': 'command', 'command': 'later-user-hook'}]})
        repeat, _ = self.module.registrations(registry, initial, self.root, set())
        self.assertEqual(repeat, initial)

    def test_only_provisioning_installs_the_dispatcher(self):
        self.root.mkdir()
        dispatcher = self.root/'dispatch.py'
        dispatcher.write_text('installed version')
        with self.assertRaisesRegex(ValueError, 'provision'):
            self.module.installed_dispatcher(self.root)
        self.assertEqual(dispatcher.read_text(), 'installed version')

    def test_unresponsive_rpc_has_a_deadline(self):
        fake = self.base/'unresponsive-codex'
        fake.write_text('#!/usr/bin/python3\nimport time\ntime.sleep(30)\n')
        fake.chmod(0o755)
        with self.assertRaises(TimeoutError):
            self.module.Rpc(str(fake), self.base, timeout=0.1)

    def test_operator_disabled_hook_stays_disabled(self):
        registry = self.publish()
        key = 'probe@market:hooks/hooks.json:stop:0:0'
        generated, masks = self.module.registrations(registry, {'hooks': {}}, self.root, {key})
        self.assertEqual(generated, {'hooks': {}})
        self.assertEqual(masks, [])

    def test_circus_exposes_the_hook_publisher(self):
        circus = MODULE.parent.parent / 'bin/circus'
        result = subprocess.run([str(circus), 'plugins', 'hooks', '--help'], text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('sync', result.stdout)

    def test_unmanaged_symlink_cannot_import_code_from_cache(self):
        outside = self.base / 'outside.sh'
        outside.write_text('MESSAGE=outside\n')
        (self.bundle / 'hooks/link.sh').symlink_to(outside)
        with self.assertRaisesRegex(ValueError, 'symlink'):
            self.publish()


if __name__ == '__main__':
    unittest.main()
