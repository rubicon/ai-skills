---
description: Inspect, correct, export, or reset what Salience has stored about you
---

Arguments: `$ARGUMENTS` — `show` (default), `export`, `reset`, or a correction in plain language.

Load the `salience-identity` skill and follow `skills/salience-identity/references/memory-controls.md`.

- `show` — summarize by category with counts and tiers. Volunteer the inferences. Do not print the
  whole record.
- `export` — run `scripts/salience-store.sh export` and say what the archive contains and where it is.
- `reset` — clear learned preferences (voice, experiments) while preserving verified career facts.
  These are different things; never conflate them. A full wipe requires explicit confirmation
  naming what is lost.
- Anything else — treat as a correction or a removal. Confirm exactly what changed, and for a
  removal say plainly that it does not unpublish copy that used the fact.

Store location: `${SALIENCE_HOME:-~/.claude/salience}` — outside this repository, never committed.
