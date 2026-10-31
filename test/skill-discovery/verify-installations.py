"""Compare existing host installations with their canonical generated payloads."""
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
ALIAS = json.loads((ROOT / '.claude-plugin/marketplace.json').read_text())['name']
before = json.loads(Path(__file__).with_name('installations-before.json').read_text())
expected = {(row['host'], row['plugin']): row for row in before}
rows = []
for host, command, identity in (
    ('claude', ['claude', 'plugin', 'list', '--json'], 'id'),
    ('codex', ['codex', 'plugin', 'list', '--json'], 'pluginId'),
):
    payload = json.loads(subprocess.check_output(command, text=True))
    entries = payload if isinstance(payload, list) else payload['installed']
    for entry in entries:
        if not entry[identity].endswith('@' + ALIAS):
            continue
        name = entry[identity].split('@')[0]
        assert (host, name) in expected, 'Unexpected new installation: ' + name
        assert entry['enabled'] == expected[host, name]['enabled'], name
        source = ROOT / 'packages' / name
        manifest = '.claude-plugin/plugin.json'
        cache = Path(entry['installPath']) if host == 'claude' else (
            Path.home() / '.codex/plugins/cache' / ALIAS / name / entry['version'])
        if host == 'codex':
            source = Path(entry['source']['path'])
            assert source.is_relative_to(ROOT), name
            assert entry['marketplaceSource']['source'] == str(ROOT), name
            assert entry['installed'], name
            manifest = '.codex-plugin/plugin.json'
        else:
            assert Path(entry['readFromFolder']) == source, name
        wanted = json.loads((source / manifest).read_text())
        actual = json.loads((cache / manifest).read_text())
        assert wanted == actual and entry['version'] == wanted['version'], name
        if host == 'codex':
            subtitle = json.loads((ROOT / 'packages' / name / 'interface.codex.json').read_text())
            assert actual['interface']['shortDescription'] == subtitle['shortDescription'], name
            assert actual['interface']['longDescription'] == actual['description'], name
        skills = sorted(source.glob('skills/*/SKILL.md'))
        assert {p.parent.name for p in cache.glob('skills/*/SKILL.md')} == {p.parent.name for p in skills}, name
        for skill in skills:
            assert skill.read_bytes() == (cache / skill.relative_to(source)).read_bytes(), str(skill)
        rows.append({'host': host, 'plugin': name, 'version': entry['version'],
                     'enabled': entry['enabled'], 'manifest_matches': True,
                     'matching_skill_files': len(skills)})
assert {(row['host'], row['plugin']) for row in rows} == set(expected)
print(json.dumps(rows, indent=2))
