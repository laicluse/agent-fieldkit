import importlib.util
from pathlib import Path
import os
import subprocess
import tempfile
import unittest
import sys
sys.dont_write_bytecode = True

spec = importlib.util.spec_from_file_location('policy', Path(__file__).resolve().parents[2] / 'hooks/lib/checkout-policy.py')
policy = importlib.util.module_from_spec(spec)
spec.loader.exec_module(policy)

class CheckoutPolicyTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.before = os.getcwd()
        self.root = Path(self.tmp.name) / 'repo'
        self.root.mkdir()
        os.chdir(self.root)
        self.git('init', '-q')
        self.git('-c', 'user.name=Test', '-c', 'user.email=test@example.invalid', 'commit', '-q', '--allow-empty', '-m', 'Initial')

    def tearDown(self):
        os.chdir(self.before)
        self.tmp.cleanup()

    def git(self, *args):
        return subprocess.check_output(['git', *args], text=True).strip()

    def test_primary_detach_is_blocked(self):
        for command in ('git checkout --detach HEAD', 'git switch -d HEAD', 'git checkout HEAD', 'git checkout ' + self.git('rev-parse', 'HEAD')):
            self.assertTrue(policy.reason(command), command)

    def test_named_branch_and_file_checkout_are_allowed(self):
        branch = self.git('branch', '--show-current')
        for command in ('git switch ' + branch, 'git checkout ' + branch, 'git checkout -b preview HEAD', 'git checkout -- README.md', 'git switch -c preview HEAD'):
            self.assertEqual(policy.reason(command), '', command)

    def test_linked_worktree_detach_is_allowed(self):
        linked = Path(self.tmp.name) / 'linked'
        self.git('worktree', 'add', '--detach', str(linked), 'HEAD')
        os.chdir(linked)
        self.assertEqual(policy.reason('git checkout --detach HEAD'), '')

    def test_canonical_only_blocks_worktree_add(self):
        self.git('config', 'laicluse.canonicalOnly', 'true')
        self.assertTrue(policy.reason('git worktree add ../another -b feature'))
        self.assertEqual(policy.reason('git worktree list'), '')

if __name__ == '__main__':
    unittest.main()
