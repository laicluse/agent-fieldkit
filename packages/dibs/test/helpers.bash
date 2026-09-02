#!/usr/bin/env bash
# allow-comment: load-bearing. The claim path falls back to the environment for identity and description, so a running agent session would answer the CLI's questions for the spec and hide the contracts under test. Every CLI spec clears them first.

dibs_clear_ambient_identity() {
  unset DIBS_DESCRIPTION DIBS_SESSION DIBS_OWNER DIBS_AGENT DIBS_HOLDER_PID
  unset CLAUDE_CODE_SESSION_ID CLAUDE_PID CLAUDECODE CODEX_THREAD_ID
}
