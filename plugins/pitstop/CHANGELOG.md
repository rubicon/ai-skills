# Changelog

All notable changes to this plugin are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versions use [Semantic Versioning](https://semver.org/).

## [0.3.3](https://github.com/rubicon/ai-skills/compare/pitstop-v0.3.2...pitstop-v0.3.3) (2026-10-14)


### Bug Fixes

* **pitstop:** count ref moves onto older commits as drift ([#142](https://github.com/rubicon/ai-skills/issues/142)) ([f3056f5](https://github.com/rubicon/ai-skills/commit/f3056f5e4d337f4b144ca50b8eddac7798b2b50c))
* **pitstop:** describe every drift form and what none means ([#143](https://github.com/rubicon/ai-skills/issues/143)) ([659d19f](https://github.com/rubicon/ai-skills/commit/659d19f98035f2f650a5b3b07094d1e0dd8b37d9))

## [0.3.2](https://github.com/rubicon/ai-skills/compare/pitstop-v0.3.1...pitstop-v0.3.2) (2026-10-12)


### Bug Fixes

* **pitstop:** make park mark user-stated claims, re-read files, and finish when nothing drifted ([#130](https://github.com/rubicon/ai-skills/issues/130)) ([972fd18](https://github.com/rubicon/ai-skills/commit/972fd187de0147583ab0d2f514d3c59c073546a4)), closes [#126](https://github.com/rubicon/ai-skills/issues/126)
* **pitstop:** scope park's re-derive rule and drop inherited labels when nothing drifted ([#137](https://github.com/rubicon/ai-skills/issues/137)) ([c695165](https://github.com/rubicon/ai-skills/commit/c6951650cbaf44126cc6d80d83b8ee4f57b5ad62)), closes [#134](https://github.com/rubicon/ai-skills/issues/134)
* **pitstop:** stop drift counting park's own files, same-second commits and earlier deletions ([#129](https://github.com/rubicon/ai-skills/issues/129)) ([41b1599](https://github.com/rubicon/ai-skills/commit/41b1599656423250f55f50b829b2783042cd0dee))

## [0.3.1](https://github.com/rubicon/ai-skills/compare/pitstop-v0.3.0...pitstop-v0.3.1) (2026-10-11)


### Bug Fixes

* **pitstop:** count only files newer than the handoff as drift ([#118](https://github.com/rubicon/ai-skills/issues/118)) ([e584f93](https://github.com/rubicon/ai-skills/commit/e584f930bfe523af160dca2bf7380433a3a3df0d))

## [0.3.0](https://github.com/rubicon/ai-skills/compare/pitstop-v0.2.0...pitstop-v0.3.0) (2026-10-10)


### Features

* **pitstop:** tell park how far the project moved since its own handoff ([#114](https://github.com/rubicon/ai-skills/issues/114)) ([4b32036](https://github.com/rubicon/ai-skills/commit/4b320365007f81394a9924c68d4481a5442ec46e)), closes [#102](https://github.com/rubicon/ai-skills/issues/102)

## [0.2.0](https://github.com/rubicon/ai-skills/compare/pitstop-v0.1.0...pitstop-v0.2.0) (2026-10-07)


### Features

* **pitstop:** add an optional Facts section so checkpoint keeps a fact store current ([#94](https://github.com/rubicon/ai-skills/issues/94)) ([220ea32](https://github.com/rubicon/ai-skills/commit/220ea32e98ab8cb3cf3d367aa2b7cba683cc480b)), closes [#92](https://github.com/rubicon/ai-skills/issues/92)
* **pitstop:** add catch-up, a short where-was-I on the current branch ([#84](https://github.com/rubicon/ai-skills/issues/84)) ([d7bb334](https://github.com/rubicon/ai-skills/commit/d7bb3340cefd14793c13be70fdc3559254414fff)), closes [#79](https://github.com/rubicon/ai-skills/issues/79)
* **pitstop:** add the pitstop plugin (park, sitrep, checkpoint, setup) ([#72](https://github.com/rubicon/ai-skills/issues/72)) ([5e22ff2](https://github.com/rubicon/ai-skills/commit/5e22ff24db83182cdcfb7e61c3f62dd1200a15ed)), closes [#71](https://github.com/rubicon/ai-skills/issues/71)
* **pitstop:** never overwrite another session's handoff ([#101](https://github.com/rubicon/ai-skills/issues/101)) ([c18375e](https://github.com/rubicon/ai-skills/commit/c18375e61d6690ee28b2649d6c85114acc040704))

## [0.1.0] - Unreleased

### Added

- `park`, `sitrep`, `checkpoint`, and `setup` skills.
- `handoff-verify.py`, which checks a handoff's paths, line ranges, commits, and drafts, and resolves every location pitstop uses.
