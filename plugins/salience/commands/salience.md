---
description: Route a LinkedIn request to the right Salience module
---

Arguments: `$ARGUMENTS` — what you want, in plain language. Optional; ask if empty.

Load the `salience` skill and follow its router.

1. If no identity record exists at `${SALIENCE_HOME:-~/.claude/salience}/identity.yaml`, run
   `salience-identity` onboarding first — unless the request needs no personal context at all.
2. Identify the intent and load **only** that module. Consult the router map for near-misses
   (`/salience:profile-audit` for "my profile isn't getting views" is wrong — that routes to
   analytics).
3. If the intent is ambiguous, ask exactly one question with two or three concrete options. Do not
   default to a profile audit.
4. Deliver in the output contract: result, then `[VERIFY]` if anything needs it, then at most one
   `[NEXT]`.

Never publish, send, or edit anything live without an explicit per-item approval.
