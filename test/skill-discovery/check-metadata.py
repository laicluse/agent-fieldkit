"""Verify that the discovery audit preserves names, flags and skill bodies."""
from pathlib import Path
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[2]
BASELINE = json.loads(Path(__file__).with_name('metadata.json').read_text())['baseline']
NEEDLE = 'Exercise the generated host metadata rather than reconstructing it by hand.'
LESSON = " Inventory skills per host: when a directory has agent-specific sources, use only the matching `SKILL.<host>.md`; a lone source for another host does not imply support. Do not enumerate only shared `SKILL.md` files, which can omit host-only skills and retain another host's materialized copy."


def without_description(frontmatter):
    return re.sub(r'(?m)^description:.*(?:\n[ \t]+[^\n]*)*', 'description:', frontmatter, count=1)


sources = sorted((ROOT / 'packages').glob('*/skills/*/SKILL.*md'))
tracked = subprocess.check_output(['git', 'ls-tree', '-r', '--name-only', BASELINE, 'packages'], cwd=ROOT, text=True)
baseline_sources = {Path(path) for path in tracked.splitlines() if Path(path).match('packages/*/skills/*/SKILL.*md')}
assert {path.relative_to(ROOT) for path in sources} == baseline_sources, 'Skill source inventory changed'

for path in sources:
    relative = path.relative_to(ROOT)
    before = subprocess.check_output(['git', 'show', f'{BASELINE}:{relative}'], cwd=ROOT, text=True)
    _, old_frontmatter, old_body = before.split('---', 2)
    _, new_frontmatter, new_body = path.read_text().split('---', 2)
    assert without_description(old_frontmatter) == without_description(new_frontmatter), str(relative)
    expected_body = old_body
    if str(relative) == 'packages/how-plugins-work/skills/how-plugins-work/SKILL.md':
        assert old_body.count(NEEDLE) == 1
        expected_body = old_body.replace(NEEDLE, NEEDLE + LESSON, 1)
    assert expected_body == new_body, 'Unexpected instruction-body change: ' + str(relative)
print('Names, non-description frontmatter, and bodies match the audit baseline; only the exact inventory lesson is added.')
