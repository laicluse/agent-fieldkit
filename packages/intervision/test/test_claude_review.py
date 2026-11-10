import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest


RUNNER = Path(__file__).parents[1] / 'bin/claude-review'
SUCCESS = {'type': 'result', 'subtype': 'success', 'is_error': False,
           'num_turns': 1, 'terminal_reason': 'completed', 'stop_reason': 'end_turn',
           'result': 'No findings.', 'modelUsage': {'claude-opus-5-5': {}}}


class ReviewRunnerTest(unittest.TestCase):
    def run_peer(self, records, *, stall=False, model='opus', exit_code=0):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            fake = root / 'claude'
            marker = root / 'continued'
            script = '#!' + sys.executable + '\nimport json,os,sys,time\nfrom pathlib import Path\n'
            script += 'sys.stdin.read()\n'
            script += "assert '--safe-mode' in sys.argv and '--system-prompt' in sys.argv\n"
            script += "assert '--bare' not in sys.argv and '--fallback-model' not in sys.argv\n"
            script += "assert sys.argv[sys.argv.index('--tools')+1] == ''\n"
            script += "assert sys.argv[sys.argv.index('--max-turns')+1] == '1'\n"
            script += "assert sys.argv[sys.argv.index('--setting-sources')+1] == ''\n"
            script += f"assert sys.argv[sys.argv.index('--model')+1] == {model.lower()!r}\n"
            script += "assert 'CLAUDE_CODE_MAX_OUTPUT_TOKENS' not in os.environ\n"
            script += f'records=json.loads({json.dumps(json.dumps(records))})\n'
            script += 'for record in records: print(json.dumps(record),flush=True)\n'
            if stall:
                script += f'time.sleep(2)\nPath({str(marker)!r}).touch()\n'
            script += f'sys.exit({exit_code})\n'
            fake.write_text(script)
            fake.chmod(0o755)
            environment = {**os.environ, 'PATH': str(root) + os.pathsep + os.environ['PATH'],
                           'CLAUDE_CODE_MAX_OUTPUT_TOKENS': '512'}
            output = root / 'review.json'
            completed = subprocess.run([sys.executable, str(RUNNER), '--model', model, '--output', str(output)],
                                       input='Review this complete artifact.', text=True,
                                       capture_output=True, env=environment, timeout=5)
            return completed.returncode, json.loads(output.read_text()), marker.exists()

    def test_complete_single_turn_is_preserved(self):
        code, result, _ = self.run_peer([SUCCESS])
        self.assertEqual(code, 0)
        self.assertEqual(result, SUCCESS)

    def test_overflow_stops_the_owned_peer(self):
        event = {'type': 'stream_event', 'event': {'type': 'message_delta',
                  'delta': {'stop_reason': 'max_tokens'}}}
        code, result, continued = self.run_peer([event], stall=True)
        self.assertEqual(code, 1)
        self.assertEqual(result['terminal_reason'], 'max_tokens')
        self.assertFalse(continued)

    def test_fragmented_fake_tool_call_stops_without_execution(self):
        records = [{'type': 'stream_event', 'event': {'type': 'content_block_delta',
                    'index': 0, 'delta': {'type': 'text_delta', 'text': text}}}
                   for text in ['<inv', 'oke name="Bash">']]
        code, result, continued = self.run_peer(records, stall=True)
        self.assertEqual(code, 1)
        self.assertEqual(result['terminal_reason'], 'textual_tool_call')
        self.assertFalse(continued)

    def test_blank_loop_across_chunks_stops(self):
        records = [{'type': 'stream_event', 'event': {'type': 'content_block_delta',
                    'index': 0, 'delta': {'type': 'text_delta', 'text': '\n' * 128}}}] * 2
        code, result, continued = self.run_peer(records, stall=True)
        self.assertEqual(code, 1)
        self.assertEqual(result['terminal_reason'], 'blank_output_loop')
        self.assertFalse(continued)

    def test_refusal_stops_without_fallback(self):
        event = {'type': 'stream_event', 'event': {'type': 'message_delta',
                  'delta': {'stop_reason': 'refusal'}}}
        code, result, continued = self.run_peer([event], stall=True)
        self.assertEqual(code, 1)
        self.assertEqual(result['terminal_reason'], 'refusal')
        self.assertFalse(continued)

    def test_multi_turn_and_wrong_model_are_rejected(self):
        for broken in [{**SUCCESS, 'num_turns': 3},
                       {**SUCCESS, 'modelUsage': {'claude-sonnet-5-5': {}}},
                       {**SUCCESS, 'is_error': True},
                       {**SUCCESS, 'result': '  '},
                       {**SUCCESS, 'terminal_reason': 'api_error'}]:
            with self.subTest(result=broken):
                code, _, _ = self.run_peer([broken])
                self.assertEqual(code, 1)

    def test_explicit_model_version_is_not_substituted(self):
        code, result, _ = self.run_peer([SUCCESS], model='claude-opus-5-4')
        self.assertEqual(code, 1)
        self.assertTrue(result['is_error'])
        self.assertEqual(result['provider_result'], SUCCESS)

    def test_invalid_stream_shape_is_a_failed_artifact(self):
        code, result, _ = self.run_peer([[]])
        self.assertEqual(code, 1)
        self.assertEqual(result['terminal_reason'], 'invalid_stream_record')

    def test_existing_evidence_is_never_overwritten(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / 'review.json'
            output.write_text('original evidence')
            result = subprocess.run([sys.executable, str(RUNNER), '--output', str(output)],
                                    input='Review this.', text=True, capture_output=True,
                                    env={**os.environ, 'PATH': ''}, timeout=5)
            self.assertEqual(result.returncode, 2)
            self.assertEqual(output.read_text(), 'original evidence')

    def test_missing_verdict_is_not_success(self):
        code, result, _ = self.run_peer([{'type': 'system', 'subtype': 'init'}])
        self.assertEqual(code, 1)
        self.assertIn('missing_result', result['terminal_reason'])

    def test_case_insensitive_alias_is_accepted(self):
        code, result, _ = self.run_peer([SUCCESS], model='Opus')
        self.assertEqual(code, 0)
        self.assertEqual(result, SUCCESS)

    def test_preamble_and_namespaced_tool_markup_stop(self):
        for text in ['A review preamble.\n<invoke name="Bash">',
                     'A review preamble.\n<x:invoke name="Bash">',
                     'x' * 800 + '\n<antml:function_calls>']:
            code, result, continued = self.run_peer([{'type': 'assistant', 'message': {
                'content': [{'type': 'text', 'text': text}]}}], stall=True)
            self.assertEqual(code, 1)
            self.assertEqual(result['terminal_reason'], 'textual_tool_call')
            self.assertFalse(continued)

    def test_quoted_tool_markup_is_review_data(self):
        quoted = 'Evidence:\n```xml\n<invoke name="Bash">\n```\nNo findings.'
        code, _, _ = self.run_peer([{'type': 'assistant', 'message': {
            'content': [{'type': 'text', 'text': quoted}]}}, SUCCESS])
        self.assertEqual(code, 0)

    def test_whitespace_only_lines_are_a_blank_loop(self):
        code, result, _ = self.run_peer([{'type': 'assistant', 'message': {
            'content': [{'type': 'text', 'text': ' \t\n' * 256}]}}])
        self.assertEqual(code, 1)
        self.assertEqual(result['terminal_reason'], 'blank_output_loop')

    def test_nested_malformed_shapes_and_missing_model_fail(self):
        records = [
            {'type': 'stream_event', 'event': {'type': 'content_block_start', 'content_block': []}},
            {'type': 'stream_event', 'event': {'type': 'content_block_delta', 'delta': []}},
            {'type': 'stream_event', 'event': {'type': 'content_block_delta', 'index': [], 'delta': {}}},
            {'type': 'stream_event', 'event': {'type': 'content_block_delta',
             'delta': {'type': 'text_delta', 'text': None}}},
            {**SUCCESS, 'modelUsage': None}, {**SUCCESS, 'modelUsage': {}},
        ]
        for record in records:
            with self.subTest(record=record):
                code, result, _ = self.run_peer([record])
                self.assertEqual(code, 1)
                self.assertTrue(result['is_error'])

    def test_nonzero_exit_never_looks_like_approval(self):
        code, result, _ = self.run_peer([SUCCESS], exit_code=3)
        self.assertEqual(code, 1)
        self.assertTrue(result['is_error'])
        self.assertEqual(result['provider_result'], SUCCESS)

    def test_final_text_is_checked_without_partial_events(self):
        code, result, _ = self.run_peer([{**SUCCESS, 'result': '<invoke name="Bash">'}])
        self.assertEqual(code, 1)
        self.assertEqual(result['terminal_reason'], 'textual_tool_call')

    def test_unicode_review_is_preserved(self):
        unicode_result = {**SUCCESS, 'result': 'No findings: résumé 日本語.'}
        code, result, _ = self.run_peer([unicode_result])
        self.assertEqual(code, 0)
        self.assertEqual(result, unicode_result)

    def test_account_expiry_is_not_written_to_review_artifacts(self):
        code, result, _ = self.run_peer([{**SUCCESS, 'credential_expires_at': '2099-01-01'}])
        self.assertEqual(code, 0)
        self.assertEqual(result, SUCCESS)

    def test_unexpected_tool_use_stops(self):
        for record in [
            {'type': 'stream_event', 'event': {'type': 'content_block_start',
             'content_block': {'type': 'tool_use'}}},
            {'type': 'assistant', 'message': {'content': [{'type': 'tool_use'}]}},
            {'type': 'assistant', 'message': {'stop_reason': 'max_tokens', 'content': []}},
        ]:
            code, result, continued = self.run_peer([record], stall=True)
            self.assertEqual(code, 1)
            self.assertTrue(result['is_error'])
            self.assertFalse(continued)

    @unittest.skipUnless(os.name == 'posix', 'POSIX signal semantics')
    def test_termination_cleans_up_the_owned_peer(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            child_pid = root / 'peer.pid'
            fake = root / 'claude'
            fake.write_text('#!' + sys.executable + '\nimport os,sys,time\nfrom pathlib import Path\n'
                            + f'sys.stdin.read()\nPath({str(child_pid)!r}).write_text(str(os.getpid()))\ntime.sleep(30)\n')
            fake.chmod(0o755)
            output = root / 'review.json'
            process = subprocess.Popen([sys.executable, str(RUNNER), '--output', str(output)],
                                       stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                       text=True, env={**os.environ, 'PATH': str(root) + os.pathsep + os.environ['PATH']})
            try:
                process.stdin.write('Review this.')
                process.stdin.close()
                deadline = time.monotonic() + 5
                while not child_pid.exists() and time.monotonic() < deadline:
                    time.sleep(0.01)
                self.assertTrue(child_pid.exists())
                pid = int(child_pid.read_text())
                process.terminate()
                process.wait(timeout=5)
                with self.assertRaises(ProcessLookupError):
                    os.kill(pid, 0)
                self.assertTrue(json.loads(output.read_text())['is_error'])
            finally:
                if process.poll() is None:
                    process.kill()
                    process.wait()
                process.stdout.close()
                process.stderr.close()


if __name__ == '__main__':
    unittest.main()
