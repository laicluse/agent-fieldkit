# saysay

Speech mode via the macOS `say` command. Once enabled, the agent speaks every
response aloud, translating screen content into spoken language instead of
reading it out verbatim.

Use it for hands-busy or eyes-away sessions where the agent should keep the
operator informed audibly while still writing the normal text answer. It is a
local macOS feature; no speech output leaves the machine.

## Installation

```bash
claude plugins install saysay@laicluse-agent-fieldkit
codex plugin add saysay@laicluse-agent-fieldkit
```

In a Claude Code session, version 2.1.275 or later, one line installs it straight from the marketplace repository:

```
/plugin install saysay --marketplace laicluse/agent-fieldkit
```

## Commands

### `/saysay`

Enter speech mode. Subsequent responses are spoken aloud after rendering.

### `/saysay off`

Exit speech mode.

## Requirements

macOS, for the `say` binary. Node.js on `$PATH` for the post-update broadcast
check (`bin/check-broadcast`). The `saysay` and `say-phonetic` commands ship in
the plugin's `bin/` directory, which Claude Code and Codex add to `$PATH`
automatically, so there is no manual install step.

Optional: a "Saysay Duck" / "Saysay Unduck" pair of macOS Shortcuts lets
saysay lower other audio while it speaks. When the shortcuts are absent,
saysay simply skips ducking.

## Phonetic mappings

`say-phonetic` keeps a per-user pronunciation dictionary so that names,
acronyms, and code identifiers come out the way you want. Mappings live in
`${LAICLUSE_HOME:-$HOME/.laicluse}/saysay/phonetics.json`. A dictionary left
over from an earlier `~/.local/share/saysay/phonetics.json` install is migrated
into the new root automatically on first use.

```bash
say-phonetic add "laicluse" "lay-clue-zee"
say-phonetic remove "laicluse"
say-phonetic list
```
