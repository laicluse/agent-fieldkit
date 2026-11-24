#!/usr/bin/env node
import { execFileSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const STYLESHEET = /\.(css|scss|sass|less|styl)$/i;
const MARKUP = /\.(html?|vue|svelte|astro)$/i;
const RECORD = /^visual-language.*\.md$/i;
const PROJECT_MARKER = /^(package\.json|index\.html?|readme(\..*)?|visual-language.*\.md|docs)$/i;
const PART_OF_A_PROJECT = new Set(["assets", "css", "styles", "stylesheets", "src", "public", "static", "web", "app", "site", "docs", "lib", "templates", "views"]);
const NOT_A_SURFACE = new Set(["node_modules", "vendor", "test", "tests", "spec", "fixtures", "__fixtures__", "dist", "build", "tmp", "worktrees"]);

function readPayload() {
  try {
    return JSON.parse(fs.readFileSync(0, "utf8"));
  } catch {
    return null;
  }
}

function writtenFiles(payload) {
  const input = payload.tool_input;
  if (input && typeof input === "object" && typeof input.file_path === "string" && typeof input.content === "string") {
    return [{ file: input.file_path, content: input.content }];
  }
  const patch = typeof input === "string" ? input : input?.command ?? input?.patch ?? input?.diff ?? input?.input;
  if (typeof patch !== "string") return [];
  const written = [];
  let current = null;
  for (const line of patch.split("\n")) {
    const header = line.match(/^\*\*\* (Add|Update|Delete) File: (.+)$/);
    if (header) {
      current = header[1] === "Delete" ? null : { file: header[2].trim(), content: "" };
      if (current) written.push(current);
    } else if (current && line.startsWith("+")) {
      current.content += `${line.slice(1)}\n`;
    }
  }
  return written;
}

function real(target) {
  let existing = target;
  const tail = [];
  while (!fs.existsSync(existing)) {
    const parent = path.dirname(existing);
    if (parent === existing) return target;
    tail.unshift(path.basename(existing));
    existing = parent;
  }
  return path.join(fs.realpathSync(existing), ...tail);
}

function inside(parent, child) {
  const relative = path.relative(parent, child);
  return relative === "" || (!relative.startsWith("..") && !path.isAbsolute(relative));
}

function temporaryRoots() {
  const configured = process.env.EOTB_TEMP_ROOTS;
  const roots = configured ? configured.split(path.delimiter) : [os.tmpdir(), "/tmp", "/var/folders"];
  return roots.filter(Boolean).map(real);
}

function existingDirectory(file) {
  let dir = path.dirname(file);
  while (!fs.existsSync(dir)) dir = path.dirname(dir);
  return dir;
}

function gitRoot(file) {
  try {
    const top = execFileSync("git", ["-C", existingDirectory(file), "rev-parse", "--show-toplevel"], { encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] }).trim();
    return top ? real(top) : null;
  } catch {
    return null;
  }
}

function isProject(dir) {
  try {
    return fs.readdirSync(dir).some(name => PROJECT_MARKER.test(name));
  } catch {
    return false;
  }
}

function surfaceRoot(file, cwd) {
  if (!inside(cwd, file)) return path.dirname(file);
  for (let dir = path.dirname(file); dir !== cwd; dir = path.dirname(dir)) {
    if (isProject(dir)) return dir;
  }
  const [first, ...rest] = path.relative(cwd, file).split(path.sep);
  return rest.length && !PART_OF_A_PROJECT.has(first) && !NOT_A_SURFACE.has(first) ? path.join(cwd, first) : cwd;
}

function hasStyles(file) {
  try {
    return /<style[\s>]/i.test(fs.readFileSync(file, "utf8"));
  } catch {
    return false;
  }
}

function find(root, matches, maxDepth) {
  let budget = 20000;
  const walk = (dir, depth) => {
    let entries;
    try {
      entries = fs.readdirSync(dir, { withFileTypes: true });
    } catch {
      return false;
    }
    for (const entry of entries) {
      if (--budget < 0) return false;
      if (entry.isFile() && matches(entry.name)) return true;
      if (entry.isDirectory() && depth < maxDepth && !entry.name.startsWith(".") && !NOT_A_SURFACE.has(entry.name) && walk(path.join(dir, entry.name), depth + 1)) return true;
    }
    return false;
  };
  return walk(root, 0);
}

const payload = readPayload();
if (!payload) process.exit(0);

const cwd = real(payload.cwd || process.cwd());
const temporary = temporaryRoots();
const written = writtenFiles(payload).map(({ file, content }) => {
  const resolved = real(path.resolve(cwd, file));
  const repository = gitRoot(resolved);
  return { file: resolved, content, repository, root: repository ?? surfaceRoot(resolved, cwd) };
});
const outsideSurface = (root, file) => path.relative(root, file).split(path.sep).some(segment => NOT_A_SURFACE.has(segment));
const recorded = new Set(written.filter(({ file, root }) => RECORD.test(path.basename(file)) && !outsideSurface(root, file)).map(({ root }) => root));

for (const { file, content, repository, root } of written) {
  const exists = fs.existsSync(file);
  const styled = STYLESHEET.test(file) ? !exists : MARKUP.test(file) && /<style[\s>]/i.test(content) && !(exists && hasStyles(file));
  if (!styled || recorded.has(root)) continue;
  if (!repository && temporary.some(dir => inside(dir, file))) continue;
  if (outsideSurface(root, file)) continue;
  if (find(root, name => RECORD.test(name), 3)) continue;
  if (find(root, name => STYLESHEET.test(name), 6)) continue;

  const reasoning = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../skills/eye-of-the-beholder/design-reasoning.md");
  const record = path.join(root, fs.existsSync(path.join(root, "docs")) ? "docs" : "", "visual-language.md");
  const log = path.join(process.env.LAICLUSE_HOME || path.join(os.homedir(), ".laicluse"), "eye-of-the-beholder", "references", "surfaces.md");
  const earlier = fs.existsSync(log) ? ` and the looks of earlier surfaces in ${log}` : "";
  process.stderr.write(
    `[eye-of-the-beholder/first-surface] ${path.relative(root, file)} gives ${root} its first styles, and nothing there records what this surface should look like. Styles written now come from model defaults, so the page will resemble every other generated page. Before writing them: write down the look you were about to produce; read "Starting a new surface" in ${reasoning}${earlier}; then choose a look that this surface's material calls for and that differs from both, and record it in ${record}. A look explained afterwards from the material is still the default. Styles nobody looks at, such as a fixture or a vendored copy, belong under a test, fixtures or vendor directory.\n`,
  );
  process.exit(2);
}
