#!/usr/bin/env python3
"""Check checkout commands without changing Git state."""
import json
import os
from pathlib import Path
import shlex
import subprocess
import sys


def git(*args):
    result = subprocess.run(['git', *args], capture_output=True, text=True)
    return result.stdout.strip() if result.returncode == 0 else None


def reason(command):
    common = git('rev-parse', '--path-format=absolute', '--git-common-dir')
    current = git('rev-parse', '--absolute-git-dir')
    if not common or not current:
        return ''
    primary = Path(common).resolve() == Path(current).resolve()
    canonical_only = git('config', '--bool', 'laicluse.canonicalOnly') == 'true'
    try:
        lexer = shlex.shlex(command, posix=True, punctuation_chars=';&|\n')
        lexer.whitespace_split = True
        lexer.commenters = '#'
        tokens = list(lexer)
    except ValueError:
        return ''
    for index, token in enumerate(tokens):
        if os.path.basename(token) != 'git' or index + 1 >= len(tokens):
            continue
        args = tokens[index + 1:]
        for end, arg in enumerate(args):
            if arg and all(char in ';&|\n' for char in arg):
                args = args[:end]
                break
        if canonical_only and args[:2] == ['worktree', 'add']:
            return 'This repository requires its canonical checkout. Do not create another worktree; wait for its occupancy lock and use a named branch there.'
        if not primary or not args or args[0] not in ('checkout', 'switch'):
            continue
        flags = args[1:]
        if '--detach' in flags or '-d' in flags:
            return 'Keep the primary checkout on a named branch. Create or switch to a preview branch at the desired commit instead of detaching HEAD.'
        if args[0] == 'checkout' and not any(flag in flags for flag in ('-b', '-B', '--orphan')):
            target = next((arg for arg in flags if not arg.startswith('-')), None)
            if target and '--' not in flags and git('rev-parse', '--verify', target + '^{commit}') and git('show-ref', '--verify', 'refs/heads/' + target) is None:
                return 'Checking out a commit or tag detaches the primary checkout. Create a named branch at that revision instead.'
    return ''


if __name__ == '__main__':
    request = json.load(sys.stdin)
    print(reason(request.get('tool_input', {}).get('command', '')))
