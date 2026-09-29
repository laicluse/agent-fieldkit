#!/bin/bash

guard_no_shell_ui_control() {
  local input="$1"
  local cmd
  cmd=$(jq -r '.tool_input.command // empty' <<< "$input" 2>/dev/null)
  [ -z "$cmd" ] && return 0

  local prefix='(^|[;&|({]|[$][(])[[:space:]]*'
  local assignments='([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]+[[:space:]]+)*'
  local wrappers='((command|exec|nohup|sudo|doas|arch)([[:space:]]+-[^[:space:]]+)*[[:space:]]+|env([[:space:]]+-[^[:space:]]+|[[:space:]]+[A-Za-z_][A-Za-z0-9_]*=[^[:space:]]+)*[[:space:]]+)*'
  local target='([[:alnum:]_.\/-]+\/)?(osascript|cliclick|xdotool|ydotool|wtype|screencapture|gnome-screenshot|scrot)([[:space:]]|$)'
  if grep -Eq "${prefix}${assignments}${wrappers}${target}" <<< "$cmd"; then
    dd_emit_deny no-shell-ui-control "Shell-driven host UI automation blocked: do not script apps, send host mouse/keyboard input, or capture the host screen from shell commands. Use the host's explicit UI/browser capability for those operations. Opening files with open is allowed; it does not authorize a chained automation command."
  fi
}
