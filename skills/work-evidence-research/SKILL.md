---
name: work-evidence-research
version: 1.0.0
author: Dax Davis
targets: [claude, cursor]
description: >-
  Forensic, source-grounded research workflow for reconstructing work history and
  client proof from connected files (Dropbox, Google Drive, and similar). Runs a
  three-pass workflow — discovery, targeted verification, final assembly — and
  classifies findings by client, firm/era, project type, evidence type, and outcome
  type, while keeping employer-side and agency/client-side work separate, quarantining
  unsupported claims, and never inventing details. Use when the user wants to build a
  client evidence database, find all projects of a given type, verify which projects
  have real outcome metrics, separate employer-side from agency/client work, assemble
  case-study candidates, or produce a fully-quoted CSV source appendix. Trigger
  phrases: "build a client evidence database," "find all website projects,"
  "reconstruct my work history," "which projects have real outcome metrics,"
  "separate employer-side from agency work," "source appendix CSV," "case-study
  candidates," "final assembly using prior findings."
---

# Work Evidence Research

A forensic research workflow for reconstructing work history and client proof from a
person's connected files (Dropbox, Google Drive, and similar).  It treats the file
corpus as evidence:  it discovers candidate work, classifies it by strength, keeps
employer-side and client-side work apart, quarantines what it cannot prove, and
assembles reusable deliverables (evidence databases, case-study shortlists, resume
bullets, source appendices).  It is a research method, not a summarizer — every claim
must trace to a found file.

## Evidence standards (read first)

These are non-negotiable.  They override any instinct to produce clean, polished, or
complete-looking output.

- **Accuracy over polish.**  A smaller, defensible result beats a fuller one that
  guesses.
- **Source-aware.**  Every factual claim must be traceable to an actual found file.
  If source linkage is uncertain, mark it explicitly — do not smooth it over.
- **No invented details.**  Never fabricate clients, dates, titles, metrics, or
  relationships.  Never invent or reconstruct URLs, file paths, dates, or metadata.
  Where a fact is missing, use a clearly-marked `[FILL IN]` placeholder.
- **Preserve ambiguity.**  Keep unresolved items visible (probable vs confirmed,
  alias conflicts, quarantined claims).  Do not force premature resolution.
- **Separate context.**  Keep employer-side work (done as an employee for the
  company) and agency/client-side work (done for an external client) separate, even
  when the same company appears in both — unless direct evidence justifies merging.
- **Quarantine, don't upgrade.**  Claims that lack a supporting artifact go in a
  visible quarantine; never silently upgrade or omit them.
- **Later corrections win.**  A user correction overrides earlier assumptions and
  earlier drafts.  Record the override; preserve the conflict rather than collapsing
  it.
- **Scope discipline.**  Search only what the user asked about.  Do not wander into
  unrelated files, and do not restart broad discovery when prior findings already
  exist.

## When to use

Use this skill when the user wants to:

- **Build a client/work evidence database** for a firm, era, or set of clients.
- **Find all projects of a given type** ("all website projects," "all analytics
  work") across one or more eras.
- **Verify** which projects have real outcome metrics, or close gaps on probable
  finds.
- **Separate employer-side from agency/client-side** work for a company.
- **Assemble** case-study candidates, a resume bullet bank, or portfolio-safe blurbs.
- **Produce a source appendix** — a fully-quoted CSV ledger of the files used.

## Entry dimensions

A request can enter from any of five dimensions; identify which one(s) apply:

1. **Client / brand** — a named client or a list (with aliases).
2. **Firm / era** — a company worked for and a time range.
3. **Project type** — treated as a **concept cluster**, never a single keyword
   ("website" → redesign, launch, CMS migration, sitemap, IA, UX/UI…).
4. **Evidence type** — the kind of source.  It spans document **genre** (proposal,
   SOW, deck, campaign report…), **artifact role** (primary proof / corroborating /
   mention), and **file format** (`.pdf`, `.docx`, `.pptx`, `.csv`…).  Format aids
   retrieval only; genre, role, and tier drive classification.
5. **Outcome type** — the result language sought (revenue, conversion, traffic,
   leads…), kept distinct from scope/operational, client-profile, and awards metrics
   (see the full metric taxonomy).

See `references/taxonomies.md` for the clusters, genres, formats, tiers, and metric
rules.

## The three-pass workflow

1. **Discovery** — broad inventory across the connected files for the chosen
   dimension(s); classify each find by evidence tier; flag gaps.
2. **Targeted verification** — for probable / needs-verification items, hunt the
   specific missing artifact; upgrade a tier only on a direct artifact, downgrade
   when a claim fails to verify.
3. **Final assembly** — produce the polished deliverable from confirmed findings plus
   prior context.

**Mode selection comes first:**  detect whether the user wants fresh discovery,
verification of prior findings, final assembly from established research, or a source
appendix — and route accordingly.  A request may **combine** passes (discover then
verify; find-by-type then filter by outcome) — run every pass it implies, in order.
Do **not** restart broad discovery when prior findings already exist.  See
`references/workflow-modes.md`.

## Classification & metrics

Classify every find into an evidence tier (Confirmed / Probable / Needs verification /
Role/employer / Duplicate/alias) and separate true outcome metrics from
scope, client-profile, awards, and quarantined claims.  Tier is set by artifact role
and content, never by file extension or genre label.  Full taxonomy in
`references/taxonomies.md`.

## Output modes

Deliverables (skeletons in `references/output-formats.md`):  client evidence database,
confirmed/probable watchlist, quarantined-claims table, alias-resolution table, resume
bullet bank, case-study candidate ranking, and a fully-quoted CSV source appendix.
For large output, chunk it (one labelled part at a time, wait for "continue").  When
emitting a CSV appendix, follow the hard no-invention rules in that file.

## How to handle a request

1. **Identify intent** — relationship proof, project discovery, case-study selection,
   metric verification, source-appendix generation, or final packaging.
2. **Identify the entry dimension(s) and pass**, and select the mode (fresh vs
   verify-prior vs assemble-from-prior).
3. **Open the relevant reference file(s)** and work from them.
4. **Gather inputs** — target firm/era, clients, aliases, project types,
   corrections/constraints, prior context, preferred output mode.  Ask concise
   questions only when missing information blocks progress (e.g. no file source is
   connected, or the target firm/era can't be identified); otherwise proceed on the
   most defensible interpretation and preserve the ambiguity rather than stalling.
   If no file source is connected, ask which to search rather than inventing.
5. **Run the pass(es)** and **produce the deliverable** in the requested output mode.
6. **Preserve the user's own facts and the messy edges** — quarantine, aliases,
   conflicts — rather than smoothing them away.

## Examples

- "Build a client evidence database for [FIRM], 2015–2019."  → discovery across the
  firm/era, tiered classification, employer-vs-client split, database output.
- "Find all website projects from [FIRM]."  → expand the website concept cluster (and
  the `.html` / `.pptx` / `.docx` format lane), classify confirmed vs probable.
- "Which [CLIENT] projects have real outcome metrics?"  → outcome-language search,
  separate outcomes from scope, shortlist case-study candidates.
- "Separate employer-side from agency-side work for [COMPANY]."  → two distinct
  context rows, no merged metrics, uncertainty preserved.
- "Make a fully-quoted CSV source appendix for everything used."  → source-appendix
  mode, every field quoted, `NO_URL` / `UNAVAILABLE` for missing data.
- "Final assembly from what we already found — don't re-discover."  → assembly mode
  only, no broad rediscovery.
