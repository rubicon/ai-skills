# Changelog

All notable changes to the `session-messaging` plugin are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versions use [Semantic Versioning](https://semver.org/).

## [0.1.0] - 2026-08-23

### Added
- Initial release. Cross-session messaging for Claude Code Desktop (CCD):
  - Bundled skill: how `mcp__ccd_session_mgmt__send_message` addressing works, and the
    `CLAUDE_CODE_HOST_SESSION_ID` self-identification rule (the single source of truth the
    commands defer to).
  - Commands: `session-whoami` (report this session's own address) and `session-send`
    (send a message to another session by address).
