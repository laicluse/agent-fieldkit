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
  local mac_open='([[:alnum:]_.\/-]+\/)?open([[:space:]]|$)'

  if grep -Eq "${prefix}${assignments}${wrappers}(${target}|${mac_open})" <<< "$cmd"; then
    dd_emit_deny no-shell-ui-control "Shell-driven host UI control blocked: do not activate apps, send host mouse/keyboard input, or capture the host screen from shell commands, and do not substitute an equivalent after one route is denied. Use the host's explicit UI/browser capability; use project-native commands only when they do not touch user-facing desktop state."
  fi
}
