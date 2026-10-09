# rover changelog

The post-update broadcast (see `bin/check-broadcast`) shows the topmost section
once per machine whenever the installed `version` in
`.claude-plugin/plugin.json` changes. Header version numbers are informational;
the broadcast is positional.

## [v2.0.30]

### Fixed

- Repair reviews retain the original scope and findings while reviewing the actual delta against a frozen revision. Repeated defects at one behavior boundary require a complete preservation comparison before another review, instead of restarting discovery with another full packet.

## [v2.0.24]

### Fixed

- **Pride review works without a remote.** Its default range now falls back from `origin/HEAD` to an existing local `init.defaultBranch` and uses the correct local ref in the diff range.

## [v2.0.23]

### Fixed

- **Pride review ranges no longer infer `main` or `master`.** The default
  branch snippet reads Git's `origin/HEAD` metadata and requires an explicit
  range when that metadata is absent.
- **No-repo setup no longer names `main`.** Rover's prelaunch recovery now uses
  plain `git init`, letting Git choose the repository's initial branch.

## [v2.0.22]

### Changed

- **Review range examples no longer assume `main`.** The pride and trim skills
  use default-branch wording for branch-vs-HEAD examples.

## [v2.0.20]

### Fixed

- **`rover` follows hook remediation during setup.** A setup hook that blocks a command while telling the rover how to proceed is now treated as recoverable setup friction, not a prelaunch question for the operator.

## [v2.0.9]

### Fixed

- **`rover` is multi-agent again.** It no longer depends directly on
  `autonomous:keepalive`; the active host or caller owns the continuation
  mechanism. Claude Code can still use `autonomous` as one keepalive
  implementation, while Codex receives the rover skills again.

## [v2.0.1]

### Breaking

- **`rover` is no longer advertised to Codex.** Its current phase machine
  depends on the Claude-only `autonomous` keepalive layer and Claude-style
  delegated review flows. The generated Codex marketplace now omits the plugin
  until a Codex-compatible rover path exists.

## [v2.0.0]

### Breaking

- Slash commands moved from `/autonomous:...` to `/rover:...`
  (`/rover:rover`, `/rover:stop`, `/rover:pride`, `/rover:trim`,
  `/rover:verify`, `/rover:decide`, `/rover:prepare`, `/rover:rover-help`).
  Waking a mission is now `/rover:rover .autonomous/<NAME>.md`. Install
  `rover@laicluse-agent-fieldkit` alongside `autonomous@laicluse-agent-fieldkit`;
  existing `.autonomous/` loop files stay compatible: the format is unchanged
  and waking them with the new command continues a mission exactly where it
  stopped.

### Added

- `rover` carries the decision framework (rover, rover-help, decide, prepare,
  pride, trim, verify, stop). The keep-alive machinery (cron heartbeat,
  wake/restore) lives in the `autonomous` plugin.
- At dispatch the rover asks `autonomous:keepalive` whether it is in a
  persistent process. The caller no longer instructs it to "skip the cron";
  the probe makes that call.
