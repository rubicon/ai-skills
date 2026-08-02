# Output formats — deliverable skeletons, quoted CSV, chunking

The structured outputs `work-evidence-research` produces.  Reproduce these shapes;
fill only with sourced facts and `[FILL IN]` placeholders.  Classification vocabulary
is in `taxonomies.md`.

---

## Client evidence database (markdown)

One block per client × context.  Required fields, plus optional lines that preserve
the messy edges:

```
### [CLIENT]  ·  [FIRM / ERA]  ·  Context: agency-client | employer-side
- Project type(s):   [cluster bucket(s)]
- Evidence tier:     Confirmed | Probable | Needs verification | Role/employer | Duplicate/alias
- Direct artifacts:  [source file name(s) — no invented paths]
- Outcome metrics:   [actual outcomes only, or "none found"]
- Scope metrics:     [budget / hours / scope — kept out of outcomes]
- Notes / ambiguity: [what is unresolved]
- Optional:          Evidence Notes · Needs Verification · Quarantined Claims Reference
```

Keep employer-side and agency/client-side as **separate blocks** even for the same
company.

**Cautious attribution.**  For any tier below Confirmed, hedge the wording (e.g.
"likely," "per internal roster — unconfirmed") and never state a probable relationship
or result as fact.

---

## Confirmed / probable watchlist

```
| Client   | Firm/Era | Context       | Project type | Tier      | Direct artifact? |
|----------|----------|---------------|--------------|-----------|------------------|
| [CLIENT] | [FIRM]   | agency-client | website      | Confirmed | signed SOW       |
| [CLIENT] | [FIRM]   | agency-client | analytics    | Probable  | roster mention   |
```

## Quarantined-claims table

Unsupported claims stay visible here — never upgraded, never dropped.

```
| Claim     | Where asserted | Why unsupported    | Artifact that would confirm |
|-----------|----------------|--------------------|-----------------------------|
| "[CLAIM]" | [source]       | no direct artifact | [e.g. campaign report]      |
```

## Alias-resolution table

```
| Name variant | Candidate canonical entity | Status                | Evidence |
|--------------|----------------------------|-----------------------|----------|
| [VARIANT]    | [ENTITY]                   | resolved / unresolved | [source] |
```

## Resume bullet bank

Confirmed-only.  Problem → action → result, ≤ 3 lines each, `[FILL IN]` for any
missing fact.  Do not invent metrics.

```
- [Action] for [CLIENT] that [result / outcome] — [source].
- [FILL IN owner / metric] …
```

## Case-study candidate ranking

Rank by outcome strength × artifact strength → readiness.

```
| Project   | Client   | Outcome strength  | Artifact strength        | Readiness |
|-----------|----------|-------------------|--------------------------|-----------|
| [PROJECT] | [CLIENT] | strong (conv +X%) | strong (campaign report) | High      |
```

---

## Quoted-CSV source appendix

A ledger of the files materially used.  **Hard rules:**

- **Quote every field** (as with `csv.QUOTE_ALL`) — fields contain commas.
- **Never invent or reconstruct URLs, file paths, dates, or metadata.**  If a value is
  unavailable, write an explicit placeholder:  `NO_URL` for a missing URL,
  `UNAVAILABLE` for other missing metadata.
- **Equal column counts on every row.**

Suggested columns:

```
"source_file","path_or_url","firm_era","client","project_type","evidence_type","evidence_tier","what_it_supports","status"
"[name]","NO_URL","[FIRM]","[CLIENT]","website","proposal","Confirmed","relationship + scope","UNAVAILABLE"
```

---

## Chunking

For large output, emit **one part at a time**, labelled `Part X of Y`, and wait for
the user to say "continue" before the next part.  Never truncate silently mid-table.

---

## Cross-reference

Classification vocabulary:  `taxonomies.md`.  Pass routing and conflicts:
`workflow-modes.md`.
