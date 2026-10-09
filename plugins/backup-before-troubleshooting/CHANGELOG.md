# Changelog

All notable changes to the `backup-before-troubleshooting` plugin are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versions use [Semantic Versioning](https://semver.org/).

## [0.1.1](https://github.com/rubicon/ai-skills/compare/backup-before-troubleshooting-v0.1.0...backup-before-troubleshooting-v0.1.1) (2026-10-09)


### Bug Fixes

* **backup-before-troubleshooting:** point homepage at the GitHub repo ([#98](https://github.com/rubicon/ai-skills/issues/98)) ([caaf32a](https://github.com/rubicon/ai-skills/commit/caaf32aa28ddde20831b8caaf93d1cae0b90466f)), closes [#89](https://github.com/rubicon/ai-skills/issues/89)

## [0.1.0] - 2026-06-28

### Added
- Initial release. A recoverable, self-documenting troubleshooting discipline:
  - Bundled skill: the recovery-effort model, the path-preserving forensic workspace, and the
    battle-tested safety and scripting rules (the single source of truth the commands defer to).
  - Commands: `new-recovery-effort` (start), `recovery-status` (resume briefing), and
    `cleanup` (gated, user-invocation-only janitor).
  - One script: `new-recovery-effort.sh` (seeds the effort folder and docs only).
  - References: workspace layout, path preservation, workflows, restore runbook, platform notes.
