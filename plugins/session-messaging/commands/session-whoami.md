---
description: Report this session's own address for cross-session messaging (CLAUDE_CODE_HOST_SESSION_ID)
---

Run in Bash: `echo $CLAUDE_CODE_HOST_SESSION_ID`

Report back exactly that value and nothing else, inside a fenced code block (no
language tag) so the user can copy it with the block's copy icon. Always use the
code block, even though the value is a single line. It's this session's address for
another session's `mcp__ccd_session_mgmt__send_message` call — hand it to whoever
needs to message this session.

Do not use `CLAUDE_CODE_SESSION_ID` (no `local_` prefix) or attempt to build the
address by concatenating a prefix onto it — see the `session-messaging` skill for why.
