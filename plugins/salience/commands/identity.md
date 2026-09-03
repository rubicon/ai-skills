---
description: Build or correct the professional identity record and fact ledger
---

Arguments: `$ARGUMENTS` — one or more paths to read from, or what to add or correct. Empty starts
onboarding.

Load the `salience-identity` skill.

- **One or more paths** → register each as a source with a role, then ingest. A directory is
  surveyed before anything is read; a single file is read directly; a git repository is surveyed
  with `.git/` excluded. Persist them to `$SALIENCE_HOME/config.yaml` so they are not re-asked.
  Report which files were opened, not only what was found. Read-only, always.
- **Empty, and no record exists** → run onboarding. Offer a folder first, then the other import
  paths; ask questions second. Target 15 minutes.
- **Empty, and a record exists** → summarize by category with counts and tiers, volunteer which
  items are inferences, and offer correct / remove / export / reset.
- **A fact to add** → assign a tier, record the source, check for contradictions, set `context` and
  `attribution`.
- **A correction** → supersede with history retained, then report every published surface in
  `used_in` that now repeats a stale claim.

Never treat your own parse of a document as verified. Show it back first.
