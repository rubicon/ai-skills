# session-messaging

A Claude Code plugin for cross-session messaging between Claude Code Desktop (CCD) sessions:
how to address another session's `mcp__ccd_session_mgmt__send_message` call, and how a session
reports its own address. See the bundled skill
[skills/session-messaging/SKILL.md](skills/session-messaging/SKILL.md) for the full reference,
including the self-identification env var and the common mistakes it exists to prevent.

## Commands

- `/session-messaging:session-whoami` — report this session's own address
- `/session-messaging:session-send` — send a message to another session by its address

## Install

```bash
/plugin marketplace add rubicon/ai-skills
/plugin install session-messaging@rubicon
```

## Changelog

See [CHANGELOG.md](CHANGELOG.md).
