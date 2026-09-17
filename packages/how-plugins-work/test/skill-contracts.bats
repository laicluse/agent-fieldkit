#!/usr/bin/env bats

setup() {
	PACKAGE_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
	REFERENCE="$PACKAGE_ROOT/skills/how-plugins-work/SKILL.md"
	CLOSEOUT="$PACKAGE_ROOT/skills/test-before-push/SKILL.md"
}

runtime_closeout_section() {
	awk '
		/^## Multi-agent runtime closeout$/ { active = 1; next }
		active && /^## / { exit }
		active { print }
	' "$REFERENCE"
}

@test "the general plugin workflow refreshes the version-keyed local Codex cache" {
	run runtime_closeout_section
	[ "$status" -eq 0 ]
	[[ "$output" == *"merge the candidate into that primary checkout"* ]]
	[[ "$output" == *"~/.codex/plugins/cache/<alias>/<plugin>/<version>"* ]]
	[[ "$output" != *"Do not run `codex plugin add`"* ]]
	[[ "$output" == *"explicit operator approval"* ]]
	[[ "$output" == *"codex plugin list --json"* ]]
}

@test "the runtime closeout verifies candidates without automatic shared-runtime mutation" {
	run ruby -ryaml -e '
		parts = File.read(ARGV.fetch(0)).split(/^---\s*$/)
		puts YAML.safe_load(parts.fetch(1)).fetch("description")
	' "$CLOSEOUT"
	[ "$status" -eq 0 ]
	[[ "$output" == *"without automatically mutating shared agent runtimes"* ]]
}

@test "the runtime closeout validates the staged candidate before integration" {
	grep -q 'git diff --cached --quiet' "$CLOSEOUT"
	grep -q 'plugins versions --staged .' "$CLOSEOUT"
	grep -q 'plugins build .' "$CLOSEOUT"
	grep -q 'plugins versions --check .' "$CLOSEOUT"
	grep -q 'rev-parse --path-format=absolute --git-common-dir' "$CLOSEOUT"
	grep -q 'marketplaceSource.sourceType == "local"' "$CLOSEOUT"
	grep -q 'explicit operator approval in the current turn' "$CLOSEOUT"
	! grep -q 'marketplace add ./' "$CLOSEOUT"
}
