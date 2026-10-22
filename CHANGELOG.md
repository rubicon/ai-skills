# Changelog

All notable changes to this project will be documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versions use [Semantic Versioning](https://semver.org/).

## [2.3.0](https://github.com/rubicon/ai-skills/compare/v2.2.1...v2.3.0) (2026-10-22)


### Features

* **session-messaging:** output session-whoami address in a copyable code block ([#186](https://github.com/rubicon/ai-skills/issues/186)) ([683ae6f](https://github.com/rubicon/ai-skills/commit/683ae6fd09ceb0e6ac9bc52c837b86a43f3eb56f)), closes [#185](https://github.com/rubicon/ai-skills/issues/185)

## [2.2.1](https://github.com/rubicon/ai-skills/compare/v2.2.0...v2.2.1) (2026-10-19)


### Bug Fixes

* bump rubicon-marketing-board marketplace pin to v0.1.3 ([#183](https://github.com/rubicon/ai-skills/issues/183)) ([50a9dfd](https://github.com/rubicon/ai-skills/commit/50a9dfd4b713025f4c6b529ac7b132430465e30c)), closes [#182](https://github.com/rubicon/ai-skills/issues/182)

## [2.2.0](https://github.com/rubicon/ai-skills/compare/v2.1.0...v2.2.0) (2026-10-19)


### Features

* add outbound-review-gate plugin ([#159](https://github.com/rubicon/ai-skills/issues/159)) ([763b87a](https://github.com/rubicon/ai-skills/commit/763b87a5a0b8ed1a564e61b78341256d503774c6))


### Bug Fixes

* bump rubicon-marketing-board marketplace pin to v0.1.2 ([#166](https://github.com/rubicon/ai-skills/issues/166)) ([58a878b](https://github.com/rubicon/ai-skills/commit/58a878b592d4861a3109c4c111e036ad7bf5bdbb)), closes [#165](https://github.com/rubicon/ai-skills/issues/165)
* **salience:** give the Liang citation its figures, source and scope ([#177](https://github.com/rubicon/ai-skills/issues/177)) ([94fcff2](https://github.com/rubicon/ai-skills/commit/94fcff2b472e767164c35db0392e54ee3d11c269))
* **salience:** point follow-first guidance at the setting that still exists ([#175](https://github.com/rubicon/ai-skills/issues/175)) ([b614ff9](https://github.com/rubicon/ai-skills/commit/b614ff9e3fd417ad62b8cc6340d9c2b4e94e4855))

## [2.1.0](https://github.com/rubicon/ai-skills/compare/v2.0.0...v2.1.0) (2026-10-14)


### Features

* add right-stuff-guard, a hook that denies malformed AskUserQuestion markers ([#157](https://github.com/rubicon/ai-skills/issues/157)) ([8c80f7b](https://github.com/rubicon/ai-skills/commit/8c80f7bb3a2c20844addb23bc6240684b363f6ae))

## [2.0.0](https://github.com/rubicon/ai-skills/compare/v1.4.2...v2.0.0) (2026-10-14)


### ⚠ BREAKING CHANGES

* the codebase-memory skill is removed. Install codebase-memoir with skillshare -s codebase-memoir instead of -s codebase-memory.

### Features

* add codex-review, an independent review with the Codex CLI ([#140](https://github.com/rubicon/ai-skills/issues/140)) ([154794a](https://github.com/rubicon/ai-skills/commit/154794a2583a7afcf2769cf4384326b9f6758240))
* add right-stuff, pop-up questions that mark a recommendation and the right thing ([#144](https://github.com/rubicon/ai-skills/issues/144)) ([bd9e03b](https://github.com/rubicon/ai-skills/commit/bd9e03b776e05ab5a80f580326158dd5553c293c))
* replace codebase-memory with codebase-memoir, the maintained version ([#127](https://github.com/rubicon/ai-skills/issues/127)) ([b0ce643](https://github.com/rubicon/ai-skills/commit/b0ce6439db36d8cd8323bd3d26f8fed992b6bd9f))


### Bug Fixes

* **codebase-memoir:** correct nine accuracy gaps ([#153](https://github.com/rubicon/ai-skills/issues/153)) ([975a9b1](https://github.com/rubicon/ai-skills/commit/975a9b1b0d88a61a874bb6a96f75f172c9073982))
* **pitstop:** count ref moves onto older commits as drift ([#142](https://github.com/rubicon/ai-skills/issues/142)) ([f3056f5](https://github.com/rubicon/ai-skills/commit/f3056f5e4d337f4b144ca50b8eddac7798b2b50c))
* **pitstop:** describe every drift form and what none means ([#143](https://github.com/rubicon/ai-skills/issues/143)) ([659d19f](https://github.com/rubicon/ai-skills/commit/659d19f98035f2f650a5b3b07094d1e0dd8b37d9))

## [1.4.2](https://github.com/rubicon/ai-skills/compare/v1.4.1...v1.4.2) (2026-10-12)


### Bug Fixes

* **pitstop:** make park mark user-stated claims, re-read files, and finish when nothing drifted ([#130](https://github.com/rubicon/ai-skills/issues/130)) ([972fd18](https://github.com/rubicon/ai-skills/commit/972fd187de0147583ab0d2f514d3c59c073546a4)), closes [#126](https://github.com/rubicon/ai-skills/issues/126)
* **pitstop:** scope park's re-derive rule and drop inherited labels when nothing drifted ([#137](https://github.com/rubicon/ai-skills/issues/137)) ([c695165](https://github.com/rubicon/ai-skills/commit/c6951650cbaf44126cc6d80d83b8ee4f57b5ad62)), closes [#134](https://github.com/rubicon/ai-skills/issues/134)
* **pitstop:** stop drift counting park's own files, same-second commits and earlier deletions ([#129](https://github.com/rubicon/ai-skills/issues/129)) ([41b1599](https://github.com/rubicon/ai-skills/commit/41b1599656423250f55f50b829b2783042cd0dee))

## [1.4.1](https://github.com/rubicon/ai-skills/compare/v1.4.0...v1.4.1) (2026-10-11)


### Bug Fixes

* **pitstop:** count only files newer than the handoff as drift ([#118](https://github.com/rubicon/ai-skills/issues/118)) ([e584f93](https://github.com/rubicon/ai-skills/commit/e584f930bfe523af160dca2bf7380433a3a3df0d))

## [1.4.0](https://github.com/rubicon/ai-skills/compare/v1.3.0...v1.4.0) (2026-10-10)


### Features

* **pitstop:** tell park how far the project moved since its own handoff ([#114](https://github.com/rubicon/ai-skills/issues/114)) ([4b32036](https://github.com/rubicon/ai-skills/commit/4b320365007f81394a9924c68d4481a5442ec46e)), closes [#102](https://github.com/rubicon/ai-skills/issues/102)

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

### Added

- `scripts/check-no-personal-data.sh` and its test suite — CI now fails when installed content under
  `skills/` or `plugins/` carries a contributor's absolute home path or a real email address. Wired
  into the existing `validate-skills` job, so it is enforced on every PR. Root governance files stay
  out of scope, since a maintainer contact address in `CODE_OF_CONDUCT.md` is deliberate.

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

### Added

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
