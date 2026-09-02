---
description: Audit and rewrite a LinkedIn profile against verified facts
---

Arguments: `$ARGUMENTS` — optionally the goal (`executive search`, `consulting`, `authority`) and
the mode (`quick`, `standard`, `deep`). Infer from context when absent.

Load the `salience-profile` skill.

Required before scoring: the goal, the audience, and the current profile content (pasted sections,
a LinkedIn export, or screenshots). Pull everything else from the identity record — do not re-ask
for career facts already stored.

If no identity record exists, stop and run `salience-identity` onboarding first. Auditing without a
fact ledger means rewriting claims you cannot check.

Run in order: evidence gate → language scan → score the nine components → rank by leverage →
rewrite → visibility layers if `deep` → deliver.

Rewrites come before the scorecard in the output.
