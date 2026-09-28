#!/bin/bash
# PreToolUse:Bash guard for the plugin commands that change which code a machine loads. allow-comment: load-bearing contract. Only the set that adds, removes or disables is gated: install, uninstall, disable, and marketplace add or remove. Updating or enabling an already installed plugin, including a Codex `plugin add` of one, is ordinary agent work and passes untouched, because activating merged work is the job, not a hazard. A gated command goes to the host's permission prompt where the operator sees one, and is refused elsewhere with the DD_PLUGIN_MUTATION=asked escape named in the denial, so an agent whose operator did ask is never stuck handing the command back. The guard never reads the operator's wording to infer consent: a keyword-and-verb match refuses real approvals phrased outside its vocabulary, accepts sentences that merely mention plugins, and turns every new phrasing into another regex.

dd_plugin_mutation_escaped() {
  local head="${1#"${1%%[![:space:]]*}"}"
  while [[ "$head" =~ ^(env|command|exec|nohup|sudo|doas|arch)[[:space:]]+(.*)$ ]]; do
    head="${BASH_REMATCH[2]}"
  done
  while [[ "$head" =~ ^([A-Za-z_][A-Za-z0-9_]*)=([^[:space:]]*)[[:space:]]+(.*)$ ]]; do
    if [ "${BASH_REMATCH[1]}" = "DD_PLUGIN_MUTATION" ] && [ "${BASH_REMATCH[2]}" = "asked" ]; then
      return 0
    fi
    head="${BASH_REMATCH[3]}"
  done
  return 1
}

# Codex has no update verb: `codex plugin add` of an installed plugin is how an installed plugin refreshes, and `codex plugin remove` deletes its cache, so an existing cache directory marks it installed.
dd_codex_add_refreshes_installed() {
  local plugin marketplace
  [[ "$1" =~ codex[[:space:]]+plugin[[:space:]]+add[[:space:]]+([A-Za-z0-9_.-]+)@([A-Za-z0-9_.-]+)([[:space:]]|$) ]] || return 1
  plugin="${BASH_REMATCH[1]}"
  marketplace="${BASH_REMATCH[2]}"
  [ -d "${CODEX_HOME:-$HOME/.codex}/plugins/cache/$marketplace/$plugin" ]
}

guard_plugin_mutation() {
  local input="$1" cmd prefix assignments wrappers codex_mutation claude_mutation
  cmd=$(jq -r '.tool_input.command // .tool_input.cmd // empty' <<< "$input" 2>/dev/null)
  [ -n "$cmd" ] || return 0

  prefix='(^|[;&|({]|[$][(])[[:space:]]*'
  assignments='([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]+[[:space:]]+)*'
  wrappers='((command|exec|nohup|sudo|doas|arch)([[:space:]]+-[^[:space:]]+)*[[:space:]]+|env([[:space:]]+-[^[:space:]]+|[[:space:]]+[A-Za-z_][A-Za-z0-9_]*=[^[:space:]]+)*[[:space:]]+)*'
  codex_mutation='([[:alnum:]_.\/-]+\/)?codex[[:space:]]+plugin[[:space:]]+((add|remove|disable)([[:space:]]|$)|marketplace[[:space:]]+(add|remove)([[:space:]]|$))'
  claude_mutation='([[:alnum:]_.\/-]+\/)?claude[[:space:]]+plugins?[[:space:]]+((install|uninstall|disable)([[:space:]]|$)|marketplace[[:space:]]+(add|remove)([[:space:]]|$))'

  local segment gated=""
  while IFS= read -r segment; do
    grep -Eq "${prefix}${assignments}${wrappers}(${codex_mutation}|${claude_mutation})" <<< "$(dd_command_unquoted "$segment")" || continue
    dd_plugin_mutation_escaped "$segment" && continue
    dd_codex_add_refreshes_installed "$(dd_command_unquoted "$segment")" && continue
    gated="$segment"
    break
  done < <(dd_command_segments "$cmd")
  [ -n "$gated" ] || return 0

  dd_emit_ask plugin-mutation "this adds, removes or disables machine-wide plugin code, so it changes which hooks and runtime every live coding session on this machine loads. Updating or enabling an already installed plugin is not gated; this is the set that changes what exists. Re-run with DD_PLUGIN_MUTATION=asked in front once the operator has asked for this exact change." "$input"
}
