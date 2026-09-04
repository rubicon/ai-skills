# Changelog

All notable changes to this project will be documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versions use [Semantic Versioning](https://semver.org/).

## [1.1.1](https://github.com/rubicon/ai-skills/compare/v1.1.0...v1.1.1) (2026-09-02)


### Bug Fixes

* **ci:** pin release-please 1Password reference by item UUID ([#26](https://github.com/rubicon/ai-skills/issues/26)) ([6acdef7](https://github.com/rubicon/ai-skills/commit/6acdef759482bd1f13f766c0e73a64319508aa2f)), closes [#25](https://github.com/rubicon/ai-skills/issues/25)

## [1.1.0](https://github.com/rubicon/ai-skills/compare/v1.0.0...v1.1.0) (2026-08-31)


### Features

* add session-messaging plugin for CCD cross-session messaging ([#24](https://github.com/rubicon/ai-skills/issues/24)) ([6cfd326](https://github.com/rubicon/ai-skills/commit/6cfd32688dff5706db9d8d84b7f158021222ec59)), closes [#23](https://github.com/rubicon/ai-skills/issues/23)
* list rubicon-marketing-board as an external plugin source ([#13](https://github.com/rubicon/ai-skills/issues/13)) ([b397afb](https://github.com/rubicon/ai-skills/commit/b397afb1d2916834de8b4389cc8f8be26653b134)), closes [#12](https://github.com/rubicon/ai-skills/issues/12)


### Bug Fixes

* correct 1Password item reference in release-please workflow ([#15](https://github.com/rubicon/ai-skills/issues/15)) ([eda7184](https://github.com/rubicon/ai-skills/commit/eda71841a219dd39875f43841c18583ab1e365e0))
* parse SKILL.md frontmatter as YAML, pin actions, polish docs ([#10](https://github.com/rubicon/ai-skills/issues/10)) ([3408699](https://github.com/rubicon/ai-skills/commit/34086995ae1e44b147eb112aab99d045af84d2a1))
* restore canonical contents overwritten by mirror snapshot, port cache-money ([#7](https://github.com/rubicon/ai-skills/issues/7)) ([4c32275](https://github.com/rubicon/ai-skills/commit/4c32275c02459353e56f7ee365e7f1f166284b97)), closes [#6](https://github.com/rubicon/ai-skills/issues/6)

## [Unreleased]

### Added

- `codebase-memory` skill (v1.0.0) — query a codebase knowledge graph via MCP instead of grep: decision
  matrix, exploration/tracing workflows, tiered evidence standards, and the full tool/edge-type reference
- `scripts/check-no-personal-data.sh` and its test suite — CI now fails when installed content under
  `skills/` or `plugins/` carries a contributor's absolute home path or a real email address. Wired
  into the existing `validate-skills` job, so it is enforced on every PR. Root governance files stay
  out of scope, since a maintainer contact address in `CODE_OF_CONDUCT.md` is deliberate.

### Added
- `salience` plugin (v0.2.0) — unified LinkedIn executive presence system: 12 modules behind one entry point (profile intelligence, identity/fact ledger, positioning, voice, content, engagement, executive career, consulting, data import, analytics, governance), a private out-of-repo data store, 8 templates, 4 adapter docs, 5 commands, career-corpus directory ingestion, and a 33-case evaluation suite
- `session-messaging` plugin (v0.1.0) — cross-session messaging for Claude Code Desktop (CCD): a bundled skill covering `mcp__ccd_session_mgmt__send_message` addressing and session self-identification, plus two commands (`session-whoami`, `session-send`)
- `rubicon-marketing-board` plugin listed as an external GitHub source (pinned to `v0.1.1`) — first marketplace entry sourced from a separate repo rather than vendored under `plugins/`
- `cache-money` skill (v1.1.0) — Claude Code token/context-management practices for cheaper, sharper sessions
- `identity-theft` skill (v0.1.0) — multi-personality text converter that rewrites text in a fictional character's voice
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
