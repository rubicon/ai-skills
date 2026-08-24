---
description: Send a message to another Claude Code session by its address
---

Arguments: `$ARGUMENTS` — the first token is the target session's address
(`local_<uuid>`, from `/session-messaging:session-whoami` run in that session, or from
`mcp__ccd_session_mgmt__list_sessions`); the remainder is the message text.

Call `mcp__ccd_session_mgmt__send_message` with:
- `session_id`: the first token of `$ARGUMENTS`
- `message`: everything after it

If no address was supplied, don't guess one. Either ask the user to run
`/session-messaging:session-whoami` in the target session, or look it up by title/branch/PR via
`mcp__ccd_session_mgmt__list_sessions`. See the `session-messaging` skill for
why titles and `ListAgents` slugs aren't reliable substitutes.
