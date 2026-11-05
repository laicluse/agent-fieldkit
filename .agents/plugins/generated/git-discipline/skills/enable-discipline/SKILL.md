---
name: enable-discipline
description: >-
  Explicit $git-discipline:enable-discipline: operator-controlled Git discipline toggle.
---

Submit `$git-discipline:enable-discipline` as a standalone message. The UserPromptSubmit hook performs the toggle and reports its result before the model runs. Repo toggles use the submitted working directory; discipline toggles affect only the submitted session.

Prose, quoted examples, multiline messages, and unexpected arguments are ignored; ask for a standalone command in those cases.

If a standalone invocation reaches the model, the hook did not handle the command. Inspect the installed plugin version and UserPromptSubmit hook registration. Do not modify sentinels, replay hook payloads, or invoke the handler from an agent tool. Check whether the hook is missing, untrusted, or modified. Ask the operator to review and trust the installed hook in Codex `/hooks`, then retry in a fresh session. Never set hook trust or bypass it from an agent tool.
