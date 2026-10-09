# Changelog

All notable changes to the `session-messaging` plugin are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versions use [Semantic Versioning](https://semver.org/).

## [0.2.0](https://github.com/rubicon/ai-skills/compare/session-messaging-v0.1.0...session-messaging-v0.2.0) (2026-10-09)


### Features

* add session-messaging plugin for CCD cross-session messaging ([#24](https://github.com/rubicon/ai-skills/issues/24)) ([6cfd326](https://github.com/rubicon/ai-skills/commit/6cfd32688dff5706db9d8d84b7f158021222ec59)), closes [#23](https://github.com/rubicon/ai-skills/issues/23)

## [0.1.0] - 2026-08-23

### Added
- Initial release. Cross-session messaging for Claude Code Desktop (CCD):
  - Bundled skill: how `mcp__ccd_session_mgmt__send_message` addressing works, and the
    `CLAUDE_CODE_HOST_SESSION_ID` self-identification rule (the single source of truth the
    commands defer to).
  - Commands: `session-whoami` (report this session's own address) and `session-send`
    (send a message to another session by address).
