---
description: Start a new recovery effort — create a dated, self-documenting recovery workspace and seed its docs before you change system, app, or config state. Use when the user says "back this up first", "set up a recovery folder", or is about to mutate state and wants reversibility plus a forensic record.
---

Start a recovery effort using the backup-before-troubleshooting discipline.

First, invoke the `backup-before-troubleshooting` skill and follow its "Start an effort"
workflow and safety rules. The skill is the single source of truth for those rules — do not
restate them here.

Steps:

1. Determine the **program** (short, path-stable, e.g. `Claude`, `UniFi`) and a short **goal**.
   If the user has not given both, ask.
2. Run the bundled seeding script, which touches no source artifacts. Prefer
   `"$CLAUDE_PLUGIN_ROOT"/scripts/new-recovery-effort.sh <Program> <goal words...>` when
   `$CLAUDE_PLUGIN_ROOT` is set; otherwise locate `scripts/new-recovery-effort.sh` inside the
   installed plugin and run it with the same arguments.
3. Confirm `RECOVERY_ROOT` if it matters (default `~/Recovery`; never `~/Downloads` or
   `~/Desktop` — see the skill's platform notes).
4. Help the user fill the seeded README incident line and the program version.
5. From here on, before each change: discover the real path first, then **copy (do not move)**
   it into the effort per the skill. Never back up from an assumed path.
