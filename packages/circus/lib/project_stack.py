#!/usr/bin/env python3
import difflib
import json
import os
import re
import subprocess
import sys

BANNER_MARK = "<!-- GENERATED "
BANNER_TAIL = " by 'circus project build'. Edit that original, never this file. -->"
SKILLS_SOURCE = os.path.join(".claude", "skills")
SKILLS_TARGET = os.path.join(".agents", "skills")
OVERRIDE = "AGENTS.override.md"
LOCAL_DIR = ".circus"

HOST_BOUND_TOOLS = ["Monitor", "ScheduleWakeup", "TaskStop", "CronCreate"]
HOST_BOUND_BODY = [
    ("ScheduleWakeup", r"\bScheduleWakeup\b"),
    ("TaskStop", r"\bTaskStop\b"),
    ("CronCreate", r"\bCronCreate\b"),
    ("CLAUDE_CODE_SESSION_ID", r"CLAUDE_CODE_SESSION_ID"),
    ("/loop", r"(?<![\w/.])/loop\b(?!/)"),
]
HOST_NOTES = [
    ("PushNotification", r"\bPushNotification\b"),
    ("AskUserQuestion", r"\bAskUserQuestion\b"),
    ("Skill tool", r"\bSkill\("),
]
ONLY_BLOCK = re.compile(
    r"^[ \t]*<!--\s*circus:only\s+(\w+)\s*-->[ \t]*\n(.*?)^[ \t]*<!--\s*circus:end\s*-->[ \t]*\n?",
    re.S | re.M,
)
TOP_KEY = re.compile(r"^([A-Za-z][\w-]*):[ \t]*(.*)$")
NESTED_KEY = re.compile(r"^[ \t]+([A-Za-z][\w-]*):[ \t]*(.+)$")
SKILL_NAME = re.compile(r"[A-Za-z0-9][A-Za-z0-9._-]*")
BLOCK_INDICATOR = re.compile(r"[>|][+-]?[ \t]*(#.*)?")


def die(message):
    sys.stderr.write("circus: %s\n" % message)
    sys.exit(1)


def banner(original):
    return BANNER_MARK + "from " + original + BANNER_TAIL


def is_ours(text):
    first = text.split("\n", 1)[0]
    return first.startswith(BANNER_MARK) and first.rstrip().endswith(BANNER_TAIL.strip())


def read_text(path):
    with open(path, encoding="utf-8") as handle:
        return handle.read()


def split_frontmatter(text):
    lines = text.split("\n")
    if not lines or lines[0].strip() != "---":
        return None, text
    for index in range(1, len(lines)):
        if lines[index].strip() == "---":
            return lines[1:index], "\n".join(lines[index + 1:])
    return None, text


def frontmatter_fields(lines):
    fields = {}
    key = None
    for line in lines:
        match = TOP_KEY.match(line)
        if match:
            key = match.group(1)
            fields[key] = [match.group(2)]
        elif key is not None:
            fields[key].append(line)
    return fields


def unquote(value):
    if len(value) >= 2 and value[0] == value[-1] == "'":
        return value[1:-1].replace("''", "'")
    if len(value) >= 2 and value[0] == value[-1] == '"':
        try:
            return json.loads(value)
        except ValueError:
            return re.sub(r"\\(.)", lambda match: match.group(1), value[1:-1])
    return re.sub(r"[ \t]+#.*$", "", value)


def scalar(parts):
    first = parts[0].strip()
    rest = [part.strip() for part in parts[1:]]
    if BLOCK_INDICATOR.fullmatch(first):
        return " ".join(" ".join(rest).split())
    return " ".join(unquote(" ".join([first] + rest).strip()).split())


def yaml_string(value):
    quoted = json.dumps(value, ensure_ascii=False)
    for character in ("\u0085", " ", " "):
        quoted = quoted.replace(character, "\\u%04x" % ord(character))
    return quoted


def metadata_pairs(parts):
    pairs = []
    for line in parts[1:]:
        match = NESTED_KEY.match(line)
        if match:
            pairs.append((match.group(1), unquote(match.group(2).strip())))
    return pairs


def host_bound_reason(fields, body):
    tools = scalar(fields.get("allowed-tools", [""]))
    tool_names = set(re.findall(r"\b[A-Z][A-Za-z]+\b", re.sub(r"\([^)]*\)", "", tools)))
    found = [name for name in HOST_BOUND_TOOLS if name in tool_names]
    for name, pattern in HOST_BOUND_BODY:
        if name not in found and re.search(pattern, body):
            found.append(name)
    return ", ".join(found)


def host_notes(body):
    return ", ".join(name for name, pattern in HOST_NOTES if re.search(pattern, body))


def render_skill(name, fields, body):
    out = ["---", "name: %s" % name, "description: %s" % yaml_string(scalar(fields["description"]))]
    for key in ("license", "compatibility"):
        if key in fields and scalar(fields[key]):
            out.append("%s: %s" % (key, yaml_string(scalar(fields[key]))))
    pairs = metadata_pairs(fields.get("metadata", [""]))
    if pairs:
        out.append("metadata:")
        out += ["  %s: %s" % (key, yaml_string(value)) for key, value in pairs]
    out.append("---")
    original = os.path.join(SKILLS_SOURCE, name, "SKILL.md")
    return "\n".join(out) + "\n" + banner(original) + "\n\n" + body.lstrip("\n")


def local_choices(repo):
    forced, skipped = set(), set()
    path = os.path.join(repo, LOCAL_DIR, "skills")
    if os.path.isfile(path):
        for line in read_text(path).splitlines():
            line = line.strip()
            if line.startswith("+"):
                forced.add(line[1:].strip())
            elif line.startswith("-"):
                skipped.add(line[1:].strip())
    return forced, skipped


def is_generated_skill(target_dir):
    skill_file = os.path.join(target_dir, "SKILL.md")
    if os.path.islink(target_dir) or not os.path.isfile(skill_file) or os.path.islink(skill_file):
        return False
    lines, body = split_frontmatter(read_text(skill_file))
    return lines is not None and is_ours(body.lstrip("\n"))


def refuse_symlinked_roots(repo):
    for relative in (".agents", SKILLS_TARGET):
        if os.path.islink(os.path.join(repo, relative)):
            die("%s is a symlink; a build would write into its target" % relative)


def plan_skills(repo, files, report):
    source_root = os.path.join(repo, SKILLS_SOURCE)
    forced, skipped = local_choices(repo)
    if not os.path.isdir(source_root):
        return
    for name in sorted(os.listdir(source_root)):
        skill_dir = os.path.join(source_root, name)
        skill_file = os.path.join(skill_dir, "SKILL.md")
        if not os.path.isfile(skill_file):
            continue
        if not SKILL_NAME.fullmatch(name):
            report.append(("skip", name, "directory name is not a skill name"))
            continue
        lines, body = split_frontmatter(read_text(skill_file))
        if lines is None:
            report.append(("skip", name, "no frontmatter"))
            continue
        fields = frontmatter_fields(lines)
        target_dir = os.path.join(repo, SKILLS_TARGET, name)
        if os.path.lexists(target_dir) and not is_generated_skill(target_dir):
            report.append(("keep", name, "handwritten %s" % os.path.join(SKILLS_TARGET, name)))
            continue
        if name in skipped:
            report.append(("skip", name, "listed in %s/skills" % LOCAL_DIR))
            continue
        if not scalar(fields.get("description", [""])):
            report.append(("skip", name, "no description"))
            continue
        reason = host_bound_reason(fields, body)
        if reason and name not in forced:
            report.append(("skip", name, "needs Claude Code: %s" % reason))
            continue
        for directory, _, names in os.walk(skill_dir):
            for file_name in names:
                source = os.path.join(directory, file_name)
                relative = os.path.relpath(source, skill_dir)
                target = os.path.join(SKILLS_TARGET, name, relative)
                if relative == "SKILL.md":
                    files[target] = (render_skill(name, fields, body).encode("utf-8"), 0o644)
                else:
                    with open(source, "rb") as handle:
                        files[target] = (handle.read(), os.stat(source).st_mode & 0o777)
        notes = host_notes(body)
        detail = "forced by %s/skills" % LOCAL_DIR if name in forced and reason else ""
        if notes:
            detail = (detail + "; " if detail else "") + "mentions %s" % notes
        report.append(("build", name, detail))


def repo_files(repo, file_name, ignored):
    command = ["git", "-C", repo, "ls-files", "--cached", "--others"]
    if not ignored:
        command.append("--exclude-standard")
    try:
        listed = subprocess.run(
            command + ["--", file_name, "**/" + file_name], check=True, capture_output=True, text=True,
        ).stdout.splitlines()
    except (subprocess.CalledProcessError, FileNotFoundError):
        listed = []
        for directory, _, names in os.walk(repo):
            if file_name in names:
                listed.append(os.path.relpath(os.path.join(directory, file_name), repo))
    return sorted(path for path in listed if os.path.lexists(os.path.join(repo, path)))


def instruction_sources(repo):
    return [path for path in repo_files(repo, "CLAUDE.md", False) if os.path.isfile(os.path.join(repo, path))]


def codex_view(text):
    return ONLY_BLOCK.sub(lambda match: match.group(2) if match.group(1) == "codex" else "", text)


def is_generated_override(path):
    return os.path.isfile(path) and not os.path.islink(path) and is_ours(read_text(path))


def plan_instructions(repo, files, report):
    overlay_path = os.path.join(repo, LOCAL_DIR, "codex.md")
    for source in instruction_sources(repo):
        directory = os.path.dirname(source)
        view = codex_view(read_text(os.path.join(repo, source)))
        if directory == "" and os.path.isfile(overlay_path):
            view = view.rstrip("\n") + "\n\n" + read_text(overlay_path)
        target = os.path.join(directory, OVERRIDE)
        target_path = os.path.join(repo, target)
        if os.path.lexists(target_path) and not is_generated_override(target_path):
            report.append(("keep", target, "handwritten"))
            continue
        agents = os.path.join(repo, directory, "AGENTS.md")
        if os.path.isfile(agents) and read_text(agents) == view:
            report.append(("same", source, "AGENTS.md already carries this text"))
            continue
        files[target] = ((banner(source) + "\n\n" + view).encode("utf-8"), 0o644)
        report.append(("build", target, "from %s" % source))


def stale_paths(repo, files):
    stale = []
    target_root = os.path.join(repo, SKILLS_TARGET)
    if os.path.isdir(target_root):
        for name in sorted(os.listdir(target_root)):
            target_dir = os.path.join(target_root, name)
            if not is_generated_skill(target_dir):
                continue
            for directory, _, names in os.walk(target_dir):
                for file_name in names:
                    relative = os.path.relpath(os.path.join(directory, file_name), repo)
                    if relative not in files:
                        stale.append(relative)
    for relative in repo_files(repo, OVERRIDE, True):
        if relative not in files and is_generated_override(os.path.join(repo, relative)):
            stale.append(relative)
    return stale


def plan(repo):
    refuse_symlinked_roots(repo)
    files, report = {}, []
    plan_skills(repo, files, report)
    plan_instructions(repo, files, report)
    return files, stale_paths(repo, files), report


def on_disk(repo, relative):
    path = os.path.join(repo, relative)
    if not os.path.isfile(path) or os.path.islink(path):
        return None
    with open(path, "rb") as handle:
        return handle.read()


def drift(repo, files, stale):
    return [relative for relative, (content, _) in sorted(files.items()) if on_disk(repo, relative) != content], stale


def print_report(report):
    for status, name, detail in report:
        print(("%-6s %-28s %s" % (status, name, detail)).rstrip())


def prune_empty(repo, relative):
    directory = os.path.dirname(os.path.join(repo, relative))
    root = os.path.join(repo, SKILLS_TARGET)
    while directory.startswith(root + os.sep) and os.path.isdir(directory) and not os.listdir(directory):
        os.rmdir(directory)
        directory = os.path.dirname(directory)


def unlink_symlinked_parents(repo, relative):
    parts = relative.split(os.sep)
    if parts[:2] != SKILLS_TARGET.split(os.sep):
        return
    for depth in range(4, len(parts)):
        directory = os.path.join(repo, *parts[:depth])
        if os.path.islink(directory):
            os.remove(directory)


def cmd_build(repo):
    files, stale, report = plan(repo)
    for relative in stale:
        os.remove(os.path.join(repo, relative))
        prune_empty(repo, relative)
    for relative, (content, mode) in files.items():
        path = os.path.join(repo, relative)
        unlink_symlinked_parents(repo, relative)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        if os.path.islink(path):
            os.remove(path)
        with open(path, "wb") as handle:
            handle.write(content)
        os.chmod(path, mode)
    print_report(report)
    counts = {}
    for status, _, _ in report:
        counts[status] = counts.get(status, 0) + 1
    print("circus: project stack built in %s (%s)" % (repo, ", ".join("%s %d" % item for item in sorted(counts.items()))))
    return 0


def cmd_check(repo):
    files, stale, _ = plan(repo)
    changed, leftover = drift(repo, files, stale)
    for relative in changed:
        print("DRIFT  %s" % relative)
    for relative in leftover:
        print("STALE  %s" % relative)
    if changed or leftover:
        return 1
    print("circus: project stack in sync (%s)" % repo)
    return 0


def cmd_diff(repo):
    files, stale, _ = plan(repo)
    changed, leftover = drift(repo, files, stale)
    for relative in changed:
        before = on_disk(repo, relative)
        old = before.decode("utf-8", "replace").splitlines(keepends=True) if before else []
        new = files[relative][0].decode("utf-8", "replace").splitlines(keepends=True)
        sys.stdout.writelines(difflib.unified_diff(old, new, "a/" + relative, "b/" + relative))
    for relative in leftover:
        print("remove %s" % relative)
    return 0


def main(argv):
    if not argv or argv[0] in ("-h", "--help", "help"):
        print(
            "circus project - derive a Codex project stack from the Claude project source\n\n"
            "  circus project build [repo]  write .agents/skills and AGENTS.override.md\n"
            "  circus project check [repo]  exit 1 when the stack drifts from the originals\n"
            "  circus project diff [repo]   show what build would change\n\n"
            "Originals: CLAUDE.md files and .claude/skills/. Each generated file carries a banner\n"
            "naming its original. Skills that mention Claude Code facilities for waiting, resuming\n"
            "or session state are skipped. Whether the output is tracked is up to .gitignore.\n"
            "Local choices: .circus/skills (+name builds, -name skips), .circus/codex.md (Codex-only text)."
        )
        return 0
    command, paths = argv[0], argv[1:]
    if len(paths) > 1 or any(arg.startswith("-") for arg in paths):
        die("usage: circus project %s [repo]" % command)
    repo = os.path.abspath(paths[0] if paths else os.getcwd())
    if not os.path.isdir(repo):
        die("directory does not exist: %s" % repo)
    if command == "build":
        return cmd_build(repo)
    if command == "check":
        return cmd_check(repo)
    if command == "diff":
        return cmd_diff(repo)
    die("unknown project command: %s" % command)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
