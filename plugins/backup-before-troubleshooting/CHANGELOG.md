# Changelog

All notable changes to the `backup-before-troubleshooting` plugin are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versions use [Semantic Versioning](https://semver.org/).

## [0.1.0] - 2026-06-28

### Added
- Initial release. A recoverable, self-documenting troubleshooting discipline:
  - Bundled skill: the recovery-effort model, the path-preserving forensic workspace, and the
    battle-tested safety and scripting rules (the single source of truth the commands defer to).
  - Commands: `new-recovery-effort` (start), `recovery-status` (resume briefing), and
    `cleanup` (gated, user-invocation-only janitor).
  - One script: `new-recovery-effort.sh` (seeds the effort folder and docs only).
  - References: workspace layout, path preservation, workflows, restore runbook, platform notes.
