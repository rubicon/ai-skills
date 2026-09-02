---
description: Build or correct the professional identity record and fact ledger
---

Arguments: `$ARGUMENTS` — optionally what to add or correct. Empty starts onboarding.

Load the `salience-identity` skill.

- **Empty, and no record exists** → run onboarding. Offer the import paths first; ask questions
  second. Target 15 minutes.
- **Empty, and a record exists** → summarize by category with counts and tiers, volunteer which
  items are inferences, and offer correct / remove / export / reset.
- **A fact to add** → assign a tier, record the source, check for contradictions, set `context` and
  `attribution`.
- **A correction** → supersede with history retained, then report every published surface in
  `used_in` that now repeats a stale claim.

Never treat your own parse of a document as verified. Show it back first.
