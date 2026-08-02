---
description: Resume an in-flight recovery effort — read its CURRENT-STATE, open DECISIONS, and gotcha warnings and brief where it left off. Use when the user asks "where did I leave this", "what's the status of the recovery", or returns to a tracked troubleshooting effort.
---

Brief the user on an in-flight recovery effort. This is read-only — change nothing.

Invoke the `backup-before-troubleshooting` skill for the workspace layout.

Steps:

1. Find the effort. If the user named a program, list efforts from the level-2 effort-index
   README under `${RECOVERY_ROOT:-~/Recovery}/<Program>/`. If which effort is ambiguous, ask.
2. Read these from the chosen effort and summarize, in this order:
   - The **Gotchas** line at the top of `CURRENT-STATE.md` — surface it loudly, first.
   - `CURRENT-STATE.md` — what is true on disk now, what is backed up.
   - `DECISIONS.md` — open hypotheses and what has been ruled out.
   - The latest `CHANGELOG.md` entries — recent actions.
3. Give a short "where this left off / what's next" briefing. Do not modify any file.
