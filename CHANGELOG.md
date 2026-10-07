# Changelog

All notable changes to this project will be documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versions use [Semantic Versioning](https://semver.org/).

## [1.3.0](https://github.com/rubicon/ai-skills/compare/v1.2.0...v1.3.0) (2026-10-07)


### Features

* add anger-translator, a skill that turns a heated draft into a firm, professional message ([#97](https://github.com/rubicon/ai-skills/issues/97)) ([1b40e81](https://github.com/rubicon/ai-skills/commit/1b40e8106ac3f8d6d42d055d9679aa35f9e35d95)), closes [#96](https://github.com/rubicon/ai-skills/issues/96)
* add goalpost, a skill that writes /goal conditions that are checkable and can finish ([#86](https://github.com/rubicon/ai-skills/issues/86)) ([323db2c](https://github.com/rubicon/ai-skills/commit/323db2ceec6fa966dc282428637c7b0fb962d26b)), closes [#81](https://github.com/rubicon/ai-skills/issues/81)
* add grand-tour, an onboarding-style tour of a codebase ([#87](https://github.com/rubicon/ai-skills/issues/87)) ([9bc01fa](https://github.com/rubicon/ai-skills/commit/9bc01fa1b19bdf57bd74370fa3c62e95d195f33c)), closes [#83](https://github.com/rubicon/ai-skills/issues/83)
* add loadout plugin for per-project plugin and skill audits ([#93](https://github.com/rubicon/ai-skills/issues/93)) ([7283d53](https://github.com/rubicon/ai-skills/commit/7283d53cd8ae2e768df80dcf945f8581fbd0d9e9)), closes [#78](https://github.com/rubicon/ai-skills/issues/78)
* add second-look, an intent-first review by a fresh agent ([#91](https://github.com/rubicon/ai-skills/issues/91)) ([e73995d](https://github.com/rubicon/ai-skills/commit/e73995dff6b15e4d67fbd9ec0b3096fbbd9086cf)), closes [#82](https://github.com/rubicon/ai-skills/issues/82)
* add showdown, a skill that compares approaches head to head and recommends one ([#85](https://github.com/rubicon/ai-skills/issues/85)) ([90da50c](https://github.com/rubicon/ai-skills/commit/90da50cce70733f72f501c0d9f7530f707cef518)), closes [#80](https://github.com/rubicon/ai-skills/issues/80)
* **pitstop:** add an optional Facts section so checkpoint keeps a fact store current ([#94](https://github.com/rubicon/ai-skills/issues/94)) ([220ea32](https://github.com/rubicon/ai-skills/commit/220ea32e98ab8cb3cf3d367aa2b7cba683cc480b)), closes [#92](https://github.com/rubicon/ai-skills/issues/92)
* **pitstop:** add catch-up, a short where-was-I on the current branch ([#84](https://github.com/rubicon/ai-skills/issues/84)) ([d7bb334](https://github.com/rubicon/ai-skills/commit/d7bb3340cefd14793c13be70fdc3559254414fff)), closes [#79](https://github.com/rubicon/ai-skills/issues/79)
* **pitstop:** add the pitstop plugin (park, sitrep, checkpoint, setup) ([#72](https://github.com/rubicon/ai-skills/issues/72)) ([5e22ff2](https://github.com/rubicon/ai-skills/commit/5e22ff24db83182cdcfb7e61c3f62dd1200a15ed)), closes [#71](https://github.com/rubicon/ai-skills/issues/71)
* **pitstop:** never overwrite another session's handoff ([#101](https://github.com/rubicon/ai-skills/issues/101)) ([c18375e](https://github.com/rubicon/ai-skills/commit/c18375e61d6690ee28b2649d6c85114acc040704))
* **salience:** give voice a situational axis and an expiring tell list ([#75](https://github.com/rubicon/ai-skills/issues/75)) ([60d38c5](https://github.com/rubicon/ai-skills/commit/60d38c5a4c286b8d242ba5546ad9f9ab25fa8bc1)), closes [#38](https://github.com/rubicon/ai-skills/issues/38) [#43](https://github.com/rubicon/ai-skills/issues/43) [#48](https://github.com/rubicon/ai-skills/issues/48) [#49](https://github.com/rubicon/ai-skills/issues/49) [#50](https://github.com/rubicon/ai-skills/issues/50) [#51](https://github.com/rubicon/ai-skills/issues/51) [#52](https://github.com/rubicon/ai-skills/issues/52) [#53](https://github.com/rubicon/ai-skills/issues/53) [#69](https://github.com/rubicon/ai-skills/issues/69) [#70](https://github.com/rubicon/ai-skills/issues/70)
* validate the SKILL.md files bundled inside plugins ([#99](https://github.com/rubicon/ai-skills/issues/99)) ([70dfef5](https://github.com/rubicon/ai-skills/commit/70dfef5ef71ca4f58961f723c2ba81fa98dce1b4)), closes [#90](https://github.com/rubicon/ai-skills/issues/90)


### Bug Fixes

* **backup-before-troubleshooting:** point homepage at the GitHub repo ([#98](https://github.com/rubicon/ai-skills/issues/98)) ([caaf32a](https://github.com/rubicon/ai-skills/commit/caaf32aa28ddde20831b8caaf93d1cae0b90466f)), closes [#89](https://github.com/rubicon/ai-skills/issues/89)

## [1.2.0](https://github.com/rubicon/ai-skills/compare/v1.1.1...v1.2.0) (2026-09-09)


### Features

* add codebase-memory skill ([#34](https://github.com/rubicon/ai-skills/issues/34)) ([fa88056](https://github.com/rubicon/ai-skills/commit/fa88056a161e6df6904192525ae2d90fa4c3c118)), closes [#33](https://github.com/rubicon/ai-skills/issues/33)
* add relocate-session skill ([#66](https://github.com/rubicon/ai-skills/issues/66)) ([1528bfd](https://github.com/rubicon/ai-skills/commit/1528bfd5ccd03795c606200b306155ef2f0a6e21)), closes [#65](https://github.com/rubicon/ai-skills/issues/65)
* add Salience, a unified LinkedIn executive presence plugin ([#29](https://github.com/rubicon/ai-skills/issues/29)) ([57415c0](https://github.com/rubicon/ai-skills/commit/57415c02f721de838ed20e45f1f20271cdfdd518))
* **salience:** add the worklist and engagement-roster paste path ([#64](https://github.com/rubicon/ai-skills/issues/64)) ([287b75a](https://github.com/rubicon/ai-skills/commit/287b75a0b0df2a29d6a86df3fc4a0f75dbea5171)), closes [#62](https://github.com/rubicon/ai-skills/issues/62)
* **salience:** close four governance gaps in the approval matrix and third-party rules ([#68](https://github.com/rubicon/ai-skills/issues/68)) ([94c66e9](https://github.com/rubicon/ai-skills/commit/94c66e96a094354651821a5eeadc70bbe156cf7f)), closes [#67](https://github.com/rubicon/ai-skills/issues/67)
* **salience:** close the advise-vs-execute refusal gap; record the corpus review ledger ([#63](https://github.com/rubicon/ai-skills/issues/63)) ([22601e6](https://github.com/rubicon/ai-skills/commit/22601e65429613557adab3bba8e69cdc312545be)), closes [#61](https://github.com/rubicon/ai-skills/issues/61)
* **salience:** read declared corpus authority; add fact subject and visibility ([#32](https://github.com/rubicon/ai-skills/issues/32)) ([bf7d6e3](https://github.com/rubicon/ai-skills/commit/bf7d6e31e6b5190885789cc01064595658c3fc19)), closes [#31](https://github.com/rubicon/ai-skills/issues/31)

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

- `anger-translator` skill (v0.1.0): rewrites a heated draft into a firm, professional message that keeps every fact, the ask, and any consequence the user stated, removes the heat, and flags political or legal risk. Inspired by the *Key & Peele* anger translator sketches, run in reverse
- `pitstop` Facts section: an optional fifth configuration section that lets `checkpoint` keep a fact store current, looking up each fact the session confirmed before replacing a changed value or adding a new one, and skipping unconfirmed, multi-valued, or conflicting facts. Off by default
- `loadout` plugin (v0.1.0): per-project plugin and skill audit with an approval stop, applied to `.claude/settings.local.json` and verified against fresh headless sessions by a tested script
- `second-look` skill (v0.1.0): an intent-first review by a fresh agent, driven by a required packet of the original ask, later changes, final requirements, and deferrals, with `/code-review` run alongside and findings tagged `[intent]` or `[bugs]`. Adapted from OpenChamber's `/handoff-review` and `/workspace-review` magic prompts (https://github.com/openchamber/openchamber, MIT)
- `grand-tour` skill (v0.1.0): a five-part onboarding tour of a codebase with one real flow traced through named files, using a code-graph index when one exists. Adapted from OpenChamber's `/explore` magic prompt (https://github.com/openchamber/openchamber, MIT)
- `goalpost` skill (v0.1.0): writes a Claude Code `/goal` line with an observable outcome, evidence shown in the conversation, constraints, and an escape clause, so an impossible goal stops instead of looping. Adapted from OpenChamber's `/craft-goal` magic prompt (https://github.com/openchamber/openchamber, MIT)
- `showdown` skill (v0.1.0): compares two or three genuinely distinct approaches to a known goal in one fixed-column table, picks one argued from the goal, and names the condition that would flip it; no plan, no code. Adapted from OpenChamber's `/weigh` magic prompt (https://github.com/openchamber/openchamber, MIT)
- `pitstop` `catch-up` skill: a two-to-three-sentence "where was I" on the current branch, read from the uncommitted diff, the branch's commits and PR, and the handoff checked against git. Inspired by OpenChamber's `/catch-up` magic prompt (https://github.com/openchamber/openchamber, MIT)
- `pitstop` plugin (v0.1.0): save what a compact or clear would destroy, then rebuild status after it. Four skills (`park`, `sitrep`, `checkpoint`, `setup`) and a tested verifier that fails a handoff naming a missing path, line, or commit, or a draft that was described but never saved
- `relocate-session` skill (v1.0.0) — relocate a Claude Code session, or a whole project
  directory, without silently orphaning auto-memory: memory is keyed to the git repository
  root, a copy/move disposition asked on every run and defaulting to copy, a bundled
  `scripts/carry-memory.sh` that copies with checksum verification and merges the `MEMORY.md`
  index without duplicating entries, and a report of what does and does not follow the move
- `codebase-memory` skill (v1.0.0) — query a codebase knowledge graph via MCP instead of grep: decision
  matrix, exploration/tracing workflows, tiered evidence standards, and the full tool/edge-type reference
- `scripts/check-no-personal-data.sh` and its test suite — CI now fails when installed content under
  `skills/` or `plugins/` carries a contributor's absolute home path or a real email address. Wired
  into the existing `validate-skills` job, so it is enforced on every PR. Root governance files stay
  out of scope, since a maintainer contact address in `CODE_OF_CONDUCT.md` is deliberate.

 `salience` plugin (v0.2.0) — unified LinkedIn executive presence system: 12 modules behind one entry point (profile intelligence, identity/fact ledger, positioning, voice, content, engagement, executive career, consulting, data import, analytics, governance), a private out-of-repo data store, 8 templates, 4 adapter docs, 5 commands, career-corpus directory ingestion, and a 33-case evaluation suite
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
