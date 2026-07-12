<!-- Thanks for contributing. Fill in what applies; delete the rest. -->

## What & why

<!-- What does this change and why? Link the issue: -->
Closes #

## Type

- [ ] New personality (identity-theft)
- [ ] New skill / plugin
- [ ] Fix
- [ ] Docs

## Adding a personality? Checklist

- [ ] Dossier at `skills/identity-theft/references/personalities/<id>.md`
- [ ] Follows `references/dossier-contract.md` (header fields, required sections)
- [ ] Unique `id`, `suffix`, and `aliases` across the roster
- [ ] One `### Example (…)` per mode, each with **Before:** / **After:**
- [ ] **No copyrighted dialogue** anywhere; examples are newly written
- [ ] Signature tics have explicit per-document caps
- [ ] `python3 skills/identity-theft/scripts/validate_dossier.py skills/identity-theft/references/personalities/` passes

## General

- [ ] Conventional Commits title (`feat:`, `fix:`, `docs:`, …)
- [ ] Branch named `dev/<issue>-<slug>`
- [ ] CI is green
