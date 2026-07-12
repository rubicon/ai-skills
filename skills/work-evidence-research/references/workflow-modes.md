# Workflow modes — passes, mode selection, corrections & conflicts

How `work-evidence-research` routes a request and runs its passes.  Read with
`taxonomies.md` (classification) and `output-formats.md` (deliverables).

---

## Mode selection (do this first)

Detect what the user actually wants before searching:

| Signal | Mode | Action |
|--------|------|--------|
| "build / find / what work…" with no prior research | **Fresh discovery** | run Pass 1 |
| "verify / confirm / close the gaps on…" existing finds | **Targeted verification** | run Pass 2 on the named items only |
| "assemble / finalize / package using what we have" | **Final assembly** | run Pass 3; do **not** re-discover |
| "source appendix / list the files used" | **Source appendix** | emit the quoted CSV (see `output-formats.md`) |

**Modes can combine.**  A single request may chain passes — e.g. discover then verify,
or find-by-type then filter by outcome.  Detect every mode the request implies and run
them in order; mode selection routes, it does not force a single exclusive choice.

When prior findings already exist, do **not** restart broad discovery unless the user
asks for it.

---

## Pass 1 — Discovery

1. Pick the entry dimension(s) and the project-type cluster(s).
2. **Lead with the format lane** to surface candidates cheaply (e.g. `.pptx` for
   decks, `.xlsx` / `.csv` for analytics), then open them to read genre and role — the
   format lane only surfaces candidates; tier is judged from content and artifact role
   after opening them, never from the format itself.
3. Classify each find into an evidence tier.
4. Produce a discovery inventory (see `output-formats.md`) and **flag gaps** — clients
   with only probable evidence, claims with no artifact, unresolved aliases.

## Pass 2 — Targeted verification / gap-closing

1. Take the probable / needs-verification items (and any user-supplied claims).
2. Search for the **specific missing artifact** that would confirm each.
3. **Upgrade a tier only on a direct artifact.**  Downgrade or quarantine when a claim
   fails to verify.
4. Report what changed and what remains unverified.

## Pass 3 — Final assembly

1. Use confirmed findings plus established prior context — **skip broad rediscovery**.
2. Build the requested deliverable (database, case-study ranking, bullet bank…).
3. Carry forward quarantine, aliases, and conflicts; do not quietly drop them.

---

## Correction precedence

- A later user correction **overrides** earlier assumptions and earlier drafts.
- **Record the override** — what changed, and that the user directed it.
- **Preserve the conflict** rather than collapsing it — note the prior reading and why
  it was superseded.

## Conflict preservation (keep both sides visible)

When sources disagree, surface the disagreement; never silently pick a winner.  Common
conflicts:

- The same company appears in **both** employer-side and agency/client-side contexts
  → two separate rows, metrics not merged.
- Two **award attributions** point to different entity names → list both, mark
  unresolved.
- A **strong resume mention** has **no direct artifact** → Probable, not Confirmed.
- A **probable alias** has an unresolved entity mapping → flag in the alias table.

---

## Scope discipline

Search only what the user asked about.  Do not expand into unrelated firms, eras, or
file trees, and do not re-run discovery the user did not request.

---

## Cross-reference

Tiers, genres, formats, metrics:  `taxonomies.md`.  Deliverable skeletons and CSV
rules:  `output-formats.md`.
