---
name: session-messaging
description: Use when sending a message to another Claude Code Desktop (CCD) session, or when a session needs to report its own address so another session can message it — covers cross-session send_message and session self-identification.
version: 0.1.0
---

# Session Messaging

## Overview

CCD sessions message each other via `mcp__ccd_session_mgmt__send_message`, addressed by
a `sessionId` in the form `local_<uuid>`. A session cannot look up its own `sessionId`
through `list_sessions` or `get_session` — both tools explicitly exclude the calling
session from their results. The title shown in the app UI is not a valid address either;
passing a title into `send_message` fails.

## Self-identification

A session's own address is the env var `CLAUDE_CODE_HOST_SESSION_ID` — already in
`local_<uuid>` form, ready to hand to another session.

`CLAUDE_CODE_SESSION_ID` (no prefix) is a *different* ID — the bare transcript/CLI
session UUID — and does not work as a `send_message` target. Concatenating `local_`
onto it produces a plausible-looking but wrong address.

Verified 2026-08-23: calling `get_session` with the correct `CLAUDE_CODE_HOST_SESSION_ID`
value returns `"Refusing to return the current session"` — proof it's a real, recognized
ID that's simply self-excluded. Calling it with the wrong (`CLAUDE_CODE_SESSION_ID`-based)
guess returns a generic `"... not found"` — indistinguishable from a typo. **Don't treat
"not found" as proof an ID's format is wrong; it's also what a correct-but-self-excluded
ID looks like from certain angles, and what a genuinely wrong ID looks like.** If a "not
found" result matters, disambiguate it against a different session rather than concluding
from the message alone.

## Quick reference

| Need | Do |
|---|---|
| Get a session's own address | In that session: `echo $CLAUDE_CODE_HOST_SESSION_ID` |
| Send to a known address | `mcp__ccd_session_mgmt__send_message(session_id, message)` |
| Find an address by title/PR/branch | `mcp__ccd_session_mgmt__list_sessions` — excludes the caller, but works for any *other* session, running or not |

## Common mistakes

- **Using the app UI title as `session_id`.** Titles aren't addresses; `send_message`
  will fail even though the title is real and visible.
- **Using `ListAgents`/`SendMessage`'s short slug for a session that might go idle.**
  That roster only covers currently-*running* peers and the slug isn't guaranteed
  stable across restarts. Fine for live in-process subagents; wrong tool when the
  target might be idle or closed by the time the other session sends.
- **Assuming a session can self-report via `list_sessions`.** It's excluded from its
  own results by design — use the env var instead.

Related commands: `/session-messaging:session-whoami`, `/session-messaging:session-send`
