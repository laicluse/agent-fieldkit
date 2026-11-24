#!/usr/bin/env bats

GATE="$BATS_TEST_DIRNAME/../hooks/first-surface.mjs"

setup() {
  mkdir -p "$BATS_TEST_TMPDIR/home/projects/gift-board" "$BATS_TEST_TMPDIR/scratch"
  WORK="$(cd "$BATS_TEST_TMPDIR/home/projects" && pwd -P)"
  SCRATCH="$(cd "$BATS_TEST_TMPDIR/scratch" && pwd -P)"
  export EOTB_TEMP_ROOTS="$SCRATCH"
  export LAICLUSE_HOME="$BATS_TEST_TMPDIR/laicluse"
}

write() {
  node -e '
    const [file, content, cwd] = process.argv.slice(1);
    process.stdout.write(JSON.stringify({tool_name: "Write", cwd, tool_input: {file_path: file, content}}));
  ' "$1" "$2" "${3:-$WORK}" | node "$GATE" claude
}

patch() {
  node -e '
    const [cwd, patch] = process.argv.slice(1);
    process.stdout.write(JSON.stringify({tool_name: "apply_patch", cwd, tool_input: {command: patch}}));
  ' "$1" "$2" | node "$GATE" codex
}

@test "the first stylesheet of a new surface is held until a look is recorded" {
  run write "$WORK/gift-board/style.css" ":root { --paper: #f6efe3; }"
  [ "$status" -eq 2 ]
  [[ "$output" == *"[eye-of-the-beholder/first-surface]"* ]]
  [[ "$output" == *"design-reasoning.md"* ]]
  [[ "$output" == *"$WORK/gift-board/visual-language.md"* ]]
  [[ "$output" == *"write down the look you were about to produce"* ]]
  [[ "$output" != *"surfaces.md"* ]]
  mkdir -p "$LAICLUSE_HOME/eye-of-the-beholder/references"
  printf '# Surfaces\n' > "$LAICLUSE_HOME/eye-of-the-beholder/references/surfaces.md"
  run write "$WORK/gift-board/style.css" "body {}"
  [[ "$output" == *"$LAICLUSE_HOME/eye-of-the-beholder/references/surfaces.md"* ]]
}

@test "a recorded look lets the first stylesheet through" {
  printf '# Visual language\n' > "$WORK/gift-board/visual-language.md"
  run write "$WORK/gift-board/style.css" "body {}"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "a record under docs counts, and the gate asks for it there when docs exists" {
  mkdir -p "$WORK/gift-board/docs"
  run write "$WORK/gift-board/style.css" "body {}"
  [ "$status" -eq 2 ]
  [[ "$output" == *"$WORK/gift-board/docs/visual-language.md"* ]]
  printf '# Visual language\n' > "$WORK/gift-board/docs/visual-language.md"
  run write "$WORK/gift-board/style.css" "body {}"
  [ "$status" -eq 0 ]
}

@test "a surface that already has a stylesheet is not a new surface" {
  mkdir -p "$WORK/gift-board/css"
  printf 'body {}\n' > "$WORK/gift-board/css/base.css"
  run write "$WORK/gift-board/css/board.css" "main {}"
  [ "$status" -eq 0 ]
}

@test "a sibling project's record or stylesheet does not excuse this one" {
  mkdir -p "$WORK/camp-planner"
  printf '# Visual language\n' > "$WORK/camp-planner/visual-language.md"
  printf 'body {}\n' > "$WORK/camp-planner/style.css"
  run write "$WORK/gift-board/style.css" "body {}"
  [ "$status" -eq 2 ]
}

@test "a git repository is one surface from its root" {
  git -C "$WORK/gift-board" init -q
  mkdir -p "$WORK/gift-board/web"
  run write "$WORK/gift-board/web/style.css" "body {}" "$WORK/gift-board/web"
  [ "$status" -eq 2 ]
  [[ "$output" == *"gift-board/visual-language.md"* ]]
  [[ "$output" != *"web/visual-language.md"* ]]
}

@test "a new page with inline styles counts as a first stylesheet" {
  run write "$WORK/gift-board/index.html" "<html><style>body{}</style></html>"
  [ "$status" -eq 2 ]
}

@test "a page without styles passes" {
  run write "$WORK/gift-board/index.html" "<html><link rel=stylesheet href=style.css></html>"
  [ "$status" -eq 0 ]
}

@test "a fixture stylesheet passes" {
  run write "$WORK/gift-board/test/fixtures/a.css" "body {}"
  [ "$status" -eq 0 ]
}

@test "a stylesheet in a temporary directory passes" {
  run write "$SCRATCH/page/style.css" "body {}" "$SCRATCH"
  [ "$status" -eq 0 ]
}

@test "overwriting an existing stylesheet passes" {
  printf 'body {}\n' > "$WORK/gift-board/style.css"
  run write "$WORK/gift-board/style.css" "main {}"
  [ "$status" -eq 0 ]
}

@test "a patch that adds a stylesheet is held the same way" {
  run patch "$WORK" $'*** Begin Patch\n*** Add File: gift-board/style.css\n+body { margin: 0; }\n*** End Patch\n'
  [ "$status" -eq 2 ]
  [[ "$output" == *"gift-board/visual-language.md"* ]]
}

@test "a patch that adds the record together with the stylesheet passes" {
  run patch "$WORK" $'*** Begin Patch\n*** Add File: gift-board/visual-language.md\n+# Visual language\n*** Add File: gift-board/style.css\n+body { margin: 0; }\n*** End Patch\n'
  [ "$status" -eq 0 ]
}

@test "a record for another project in the same patch excuses nothing" {
  git -C "$WORK/gift-board" init -q
  run patch "$WORK/gift-board" $'*** Begin Patch\n*** Add File: fixtures/visual-language.md\n+# Visual language\n*** Add File: style.css\n+body { margin: 0; }\n*** End Patch\n'
  [ "$status" -eq 2 ]
  run patch "$WORK" $'*** Begin Patch\n*** Add File: camp-planner/visual-language.md\n+# Visual language\n*** Add File: gift-board/style.css\n+body { margin: 0; }\n*** End Patch\n'
  [ "$status" -eq 2 ]
}

@test "the first inline styles added to an existing page are held" {
  printf '<html><body></body></html>\n' > "$WORK/gift-board/index.html"
  run patch "$WORK" $'*** Begin Patch\n*** Update File: gift-board/index.html\n@@\n-<html><body></body></html>\n+<html><style>body { margin: 0; }</style><body></body></html>\n*** End Patch\n'
  [ "$status" -eq 2 ]
  run write "$WORK/gift-board/index.html" "<html><style>body{}</style></html>"
  [ "$status" -eq 2 ]
  printf '<html><style>body{}</style></html>\n' > "$WORK/gift-board/index.html"
  run write "$WORK/gift-board/index.html" "<html><style>main{}</style></html>"
  [ "$status" -eq 0 ]
}

@test "from inside a project without git, the project is the working directory" {
  mkdir -p "$WORK/gift-board/docs" "$WORK/camp-planner"
  printf '# Visual language\n' > "$WORK/gift-board/docs/visual-language.md"
  run write "$WORK/gift-board/assets/css/site.css" "body {}" "$WORK/gift-board"
  [ "$status" -eq 0 ]
  run write "$WORK/camp-planner/assets/css/site.css" "body {}" "$WORK/camp-planner"
  [ "$status" -eq 2 ]
  [[ "$output" == *"camp-planner/visual-language.md"* ]]
  run write "$WORK/camp-planner/fixtures/site.css" "body {}" "$WORK/camp-planner"
  [ "$status" -eq 0 ]
}

@test "a git repository in a temporary directory is still a surface" {
  mkdir -p "$SCRATCH/repo"
  git -C "$SCRATCH/repo" init -q
  run write "$SCRATCH/repo/style.css" "body {}" "$SCRATCH/repo"
  [ "$status" -eq 2 ]
}

@test "the generated Codex hook command reaches the gate" {
  root="$(git -C "$BATS_TEST_DIRNAME" rev-parse --show-toplevel)/.agents/plugins/generated/eye-of-the-beholder"
  command="$(jq -r '.hooks.PreToolUse[0].hooks[0].command' "$root/hooks/hooks.json")"
  payload="$(node -e 'process.stdout.write(JSON.stringify({tool_name: "apply_patch", cwd: process.argv[1], tool_input: {command: "*** Begin Patch\n*** Add File: gift-board/style.css\n+body {}\n*** End Patch\n"}}))' "$WORK")"
  run env PLUGIN_ROOT="$root" PAYLOAD="$payload" sh -c "printf '%s' \"\$PAYLOAD\" | { $command; }"
  [ "$status" -eq 2 ]
  [[ "$output" == *"[eye-of-the-beholder/first-surface]"* ]]
}

@test "unreadable input never blocks a tool call" {
  run bash -c "printf 'not json' | node '$GATE' claude"
  [ "$status" -eq 0 ]
  run bash -c "printf '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"ls\"}}' | node '$GATE' claude"
  [ "$status" -eq 0 ]
}

@test "both hosts register the gate on their file-writing tools" {
  run node - "$BATS_TEST_DIRNAME/../hooks" <<'NODE'
const fs = require("fs");
const path = require("path");
const dir = process.argv[2];
const claude = JSON.parse(fs.readFileSync(path.join(dir, "hooks.json"), "utf8"));
const codex = JSON.parse(fs.readFileSync(path.join(dir, "hooks.codex.json"), "utf8"));
for (const [name, config, tool] of [["claude", claude, "Write"], ["codex", codex, "apply_patch"]]) {
  if (Object.keys(config).join() !== "hooks") throw new Error(`${name}: only a top-level hooks key is portable`);
  const entry = config.hooks.PreToolUse[0];
  if (!new RegExp(`^(${entry.matcher})$`).test(tool)) throw new Error(`${name}: matcher misses ${tool}`);
  if (!entry.hooks[0].command.includes("first-surface.mjs")) throw new Error(`${name}: gate not registered`);
}
NODE
  [ "$status" -eq 0 ]
}

@test "design reasoning tells a new surface how to start" {
  run node - "$BATS_TEST_DIRNAME/../skills" <<'NODE'
const fs = require("fs");
const path = require("path");
const skills = process.argv[2];
const reasoning = fs.readFileSync(path.join(skills, "eye-of-the-beholder/design-reasoning.md"), "utf8");
const router = fs.readFileSync(path.join(skills, "eye-of-the-beholder/SKILL.md"), "utf8");
const library = fs.readFileSync(path.join(skills, "explore/reference-library.md"), "utf8");
for (const rule of [/## Starting a new surface/, /Name your default/, /surfaces\.md/, /agent decision/, /beside the most recent surfaces/]) {
  if (!rule.test(reasoning)) throw new Error(`design reasoning lacks: ${rule}`);
}
if (!/surfaces\.md/.test(library)) throw new Error("the library does not define the surfaces log");
const description = router.match(/^description: >-\n([\s\S]*?)\n---/m)[1];
if (!/new page, app or site/.test(description)) throw new Error("the entry point does not trigger on building a new surface");
if (!/Starting a new surface/.test(router)) throw new Error("the router does not send a new build to the starting procedure");
NODE
  [ "$status" -eq 0 ]
}
