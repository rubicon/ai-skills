# Changelog

All notable changes to the `outbound-review-gate` plugin are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versions use [Semantic Versioning](https://semver.org/).

## [0.2.0](https://github.com/rubicon/ai-skills/compare/outbound-review-gate-v0.1.0...outbound-review-gate-v0.2.0) (2026-10-19)


### Features

* add outbound-review-gate plugin ([#159](https://github.com/rubicon/ai-skills/issues/159)) ([763b87a](https://github.com/rubicon/ai-skills/commit/763b87a5a0b8ed1a564e61b78341256d503774c6))

## [0.1.0] - 2026-10-14

### Added
- Initial release. A PreToolUse hook that denies posts to third-party repositories unless a review receipt exists for the exact text, plus the `record`, `disposition` and `hash` helper subcommands.
