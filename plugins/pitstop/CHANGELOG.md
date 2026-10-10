# Changelog

All notable changes to this plugin are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versions use [Semantic Versioning](https://semver.org/).

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
