---
description: Delete a finished recovery effort's backups, with multiple confirmation gates. Destructive; USER-INVOCATION ONLY. Use only when the user explicitly runs this command to reclaim space from a recovery effort.
disable-model-invocation: true
---

Gated cleanup (janitor) for a recovery effort. This deletes **backups only**. It is destructive
and deliberate — run only what each gate confirms, and never skip a gate.

Invoke the `backup-before-troubleshooting` skill and honor its safety rules, especially
principle 6 (docs and evidence are never deletion targets) and principle 2 (copy, don't move).
Those rules live in the skill; this command enforces them rather than restating them.

**Protected set** (from skill principle 6): every `*.md` at all three README levels, the six
per-effort docs, and the entire `evidence/` folder. Cleanup may ONLY target `files/` contents
and the manifest's referenced-in-place external folders.

Procedure — confirm conversationally at each gate:

a. List efforts from the program's level-2 effort-index README. Ask the user to select one.
b. Read that effort's `MANIFEST.md`. Show the two deletable populations:
   - copied artifacts under `files/`
   - referenced-in-place external folders (the "Referenced in place" table)
c. Ask which tier to delete: **copied-only**, **in-place-only**, or **all**. Tiers are
   independently requestable.
d. Confirm after selection, after the tier choice, and again before deleting any external path.
   Offer batch-approve or per-path veto in plain language.
e. Before ANY external `rm`, verify the path:
   - appears **verbatim** in the manifest's "Referenced in place" table, AND
   - carries a backup marker in its name (`.bak-`, a dated `Claude.bak` / `.claude.bak`, or
     `claude-ext-disabled`).
   Refuse loudly anything that fails either test, and say which test failed (not in the record /
   no marker). This structurally prevents touching a live directory.
f. Janitor scope is the whole incident: with confirmation, you may delete the external
   in-place folders at their original locations (`~/Library/...`, `~/`), not only things under
   the workspace.
g. After deletion, append `backups deleted on <date>: <what>` to that effort's `CHANGELOG.md`
   and refresh `CURRENT-STATE.md` (roll its prior contents into the changelog first). The
   evidence of what happened must outlive the backups.

Never delete anything in the protected set. If asked to, refuse and explain why.
