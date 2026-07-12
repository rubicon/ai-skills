# Changelog

All notable changes to this project will be documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versions use [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- `identity-theft` skill (v0.1.0) — multi-personality text converter: rewrites text/Markdown/HTML in a fictional character's voice with a 51-personality roster, a fail-closed structural output gate, and a dossier roster validator
- `backup-before-troubleshooting` plugin (v0.1.0) — a recoverable, self-documenting troubleshooting discipline: a bundled skill (single source of truth for the safety rules), three lifecycle commands (`new-recovery-effort`, `recovery-status`, gated `cleanup`), and one seeding script; first plugin in the new `plugins/` tree
- Plugin hosting: the repo can now host Claude Code plugins under `plugins/` alongside `skills/`, with a root `.claude-plugin/marketplace.json` marketplace manifest (`rubicon`); `validate-skills.sh` and the GitHub-mirror allowlist now cover plugins and the marketplace
- `rubicon-wordpress-version-lab` skill — create/list/stop/remove Docker-only WordPress version labs on an SSH-reachable host; public and config-driven (no committed personal infrastructure)
- CI: validate skill structure, frontmatter, and PR/branch/commit policy on pull requests (Forgejo Actions)
- GitHub-mirror publish tooling: `scripts/sync-github-mirror.sh` (public snapshot publish) and an operations runbook

### Changed
- Set the repository display name to `Rubicon AI Skills` in the README
- Documented skillshare install commands in the README
- Simplified the GitHub-mirror tooling to a plain allowlist snapshot — this repo now publishes all of its skills, so per-skill privacy filtering is no longer needed
- CI: capped both jobs at `timeout-minutes: 5` so a hung Forgejo runner fails fast instead of after the ~15-minute default

### Removed
- Relocated a non-public skill into a new private repository (`ai-skills-private`); this repository now contains only publishable skills

### Fixed
- CI: resolved intermittent hangs on the self-hosted Forgejo Actions runner where trivial jobs could stall until the workflow timeout despite identical content passing on other runs; root cause was a runner-to-server connectivity issue in CI infrastructure, fixed at the runner level with no changes to any skill, workflow, or repo file

## [1.0.0] - 2026-06-18

### Added
- `secret-santa-generator` skill
- Skillshare-compatible directory-based skill structure (`skills/<name>/SKILL.md`)
- `AGENTS.md`, `CLAUDE.md`, `CHANGELOG.md` per general repository process policy
- `docs/process/ai-skills-repo-overlay.md` process overlay
- `work-evidence-research` skill — forensic, source-grounded work-history & client-proof research (see its CHANGELOG)

### Changed
- All skills: added per-skill `README.md` and `CHANGELOG.md`; normalized `version:` to SemVer (`MAJOR.MINOR.PATCH`)
- Documented the per-skill README/CHANGELOG, SemVer, and summary-root-changelog convention in `CLAUDE.md` and the process overlay

### Fixed
- Corrected the Forgejo owner (`dax` → `rubicon`) in install commands and the process overlay
