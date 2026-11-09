#!/usr/bin/env bats

setup() {
  local source_root="${DRYDRY_PACKAGE_ROOT:-$BATS_TEST_DIRNAME/..}"
  PACKAGE="$BATS_TEST_TMPDIR/installed-plugin"
  cp -R "$source_root" "$PACKAGE"
}

@test "the installed package exposes only the two user workflows" {
  run python3 - "$PACKAGE" <<'PY'
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
names = sorted(
    re.search(r"(?m)^name:\s*(\S+)", path.read_text()).group(1)
    for path in (root / "skills").rglob("SKILL.md")
)
assert names == ["drydry", "parity-audit"], names
PY
  [ "$status" -eq 0 ]
}

@test "both installed workflows can load their linked task and storage documents" {
  run python3 - "$PACKAGE" <<'PY'
import re
import sys
from pathlib import Path
from urllib.parse import unquote

root = Path(sys.argv[1]).resolve()
pending = list((root / "skills").rglob("SKILL.md"))
visited = set()
while pending:
    path = pending.pop().resolve()
    if path in visited:
        continue
    visited.add(path)
    assert path.is_relative_to(root), path
    for target in re.findall(r"\[[^\]]*\]\(([^\s)]+)\)", path.read_text()):
        if "://" in target or target.startswith("#"):
            continue
        linked = (path.parent / unquote(target.split("#", 1)[0])).resolve()
        assert linked.is_relative_to(root) and linked.is_file(), (path, target)
        if linked.suffix == ".md":
            pending.append(linked)
tasks = root / "skills/drydry/references/tasks"
assert tasks.is_dir(), tasks
assert set(tasks.glob("*.md")).issubset(visited), "unreachable internal task"
PY
  [ "$status" -eq 0 ]
}
