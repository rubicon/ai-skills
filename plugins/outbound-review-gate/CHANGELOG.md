# Changelog

All notable changes to the `outbound-review-gate` plugin are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versions use [Semantic Versioning](https://semver.org/).

## [0.1.0] - 2026-10-14

### Added
- Initial release. A PreToolUse hook that denies posts to third-party repositories unless a review receipt exists for the exact text, plus the `record`, `disposition` and `hash` helper subcommands.
