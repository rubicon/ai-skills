# Changelog

All notable changes to the `session-messaging` plugin are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versions use [Semantic Versioning](https://semver.org/).

## [0.2.0](https://github.com/rubicon/ai-skills/compare/session-messaging-v0.1.0...session-messaging-v0.2.0) (2026-10-22)


### Features

* **session-messaging:** output session-whoami address in a copyable code block ([#186](https://github.com/rubicon/ai-skills/issues/186)) ([683ae6f](https://github.com/rubicon/ai-skills/commit/683ae6fd09ceb0e6ac9bc52c837b86a43f3eb56f)), closes [#185](https://github.com/rubicon/ai-skills/issues/185)

## [0.1.0] - 2026-08-23

### Added
- Initial release. Cross-session messaging for Claude Code Desktop (CCD):
  - Bundled skill: how `mcp__ccd_session_mgmt__send_message` addressing works, and the
    `CLAUDE_CODE_HOST_SESSION_ID` self-identification rule (the single source of truth the
    commands defer to).
  - Commands: `session-whoami` (report this session's own address) and `session-send`
    (send a message to another session by address).
