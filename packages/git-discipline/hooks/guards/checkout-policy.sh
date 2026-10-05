#!/bin/bash

guard_checkout_policy() {
  local message
  message=$(python3 "$DIR/lib/checkout-policy.py" <<< "$1") || return 0
  [ -n "$message" ] && dd_emit_deny "checkout-policy" "$message"
  return 0
}
