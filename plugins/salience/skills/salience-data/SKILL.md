---
name: salience-data
description: >-
  Get LinkedIn and career data into Salience and normalize it — parsing resumes, LinkedIn data
  exports, pasted profile text, bios, case studies, and post or engagement data; resolving a person
  or company to a profile; and selecting a retrieval path with graceful fallbacks when direct access
  is unavailable. Also ingests a directory the user already keeps — a career folder, portfolio
  archive, or document vault — surveying it and extracting facts with provenance instead of
  interviewing for what is already on disk. Triggers on "import my resume", "here's my profile
  export", "parse this", "pull this post", "look up this profile", "connect LinkedIn", "my career
  files are in", "point at this folder", "use my corpus". Not for writing profile copy (use
  salience-profile) or interpreting performance (use salience-analytics).
version: 0.1.0
---

# Data and Import

LinkedIn access is restricted, inconsistent, and changes without notice. This module exists so that
no capability depends on a single access path, and so the system degrades to something useful
rather than failing.

**Design rule:** every capability that wants LinkedIn data has a supported path, a user-assisted
fallback, and an import-based fallback. The fallback is not a degraded mode — for most executive
work, pasted text is entirely sufficient, and saying so avoids pushing the user toward tooling they
do not need.

---

## Retrieval tiers

Choose the highest tier available. Report which tier was used when it affects confidence.

### Tier 0a — A corpus the user already keeps (best available, if it exists)

Many executives already have a career folder: resumes, press, awards, case studies, prior
applications, writing samples. Pointing Salience at it beats every other intake path, because it is
already organized, already dated, and already reconciled.

```
My career material is in ~/Documents/Career — use that instead of asking me.
```

**Survey first, then read only what the plan names.** Never ingest a directory wholesale — a career
folder with a code project inside it is common, and the file count will be dominated by
`node_modules`. Report what was read, not just what was found.

Full method — configuration, folder-signal classification, exclusions, tiering by artifact type,
provenance, and privacy: `references/corpus-ingestion.md`.

### Tier 0 — User-provided (default, always available, zero setup)

The user pastes profile sections, a post body, or a job description; or supplies a document. No
credentials, no third party, no terms-of-service exposure.

**This is the default and it is not a compromise.** A profile audit, a positioning exercise, a post
draft, and a comment all work perfectly from pasted text. Do not recommend a paid data path for
work that does not need one.

### Tier 1 — LinkedIn data export (best for the user's own profile)

Settings → Data privacy → Get a copy of your data. Arrives as CSV archives covering profile,
positions, education, skills, connections, and messages.

The most complete and most reliable source of the user's own history, and it is first-party. Prefer
it for onboarding. Import only the files needed — do not ingest the messages archive by default.

### Tier 2 — Official API via an MCP server (for publishing and own-post data)

Where a LinkedIn MCP server is configured with proper OAuth, use it for: publishing posts and
comments, reading the user's own posts and engagement statistics, and managing pages the user
administers.

Constraints that are real and worth stating: OAuth scopes gate everything, member and organization
URNs must come from API calls rather than being constructed, and the official API does not support
people search, reading third-party profiles, jobs, or messaging. A server claiming otherwise is
using something other than the official API.

### Tier 3 — Third-party retrieval services (optional, user-configured)

Commercial services can retrieve public post bodies, comment threads, and engagement lists without
credentials. Useful for engagement analysis at volume.

Only ever used when the user has configured one deliberately. Salience never signs up for, selects,
or recommends a specific vendor as a default, and it states the cost and the terms-of-service
consideration when one is used.

### Never

- Collecting, storing, or using a LinkedIn password, cookie, or session token
- Reusing a captured browser session
- Bypassing CAPTCHAs or bot detection
- Evading rate limits
- Automating actions through the logged-in interface as if human

These are refused regardless of who asks, how the request is framed, or what a configured tool
offers. If a request requires one, say what is being refused and offer the highest available
supported path instead.

---

## Import and parsing

### Résumé or CV
Extract roles, titles, organizations, dates, scope, achievements, education, credentials. Every
number found becomes a ledger candidate with the document as source. Flag anything ambiguous rather
than resolving it — a date range written "2021–2023" does not tell you the months.

### LinkedIn export
Map the CSVs to the identity schema. `Positions.csv` and `Profile.csv` carry the spine. Cross-check
against any résumé already imported and surface every disagreement.

### Pasted profile text
Section boundaries are usually inferable from structure. Confirm the parse before writing to the
ledger — a mis-parsed heading silently corrupts the record.

### Bios, case studies, decks
Rich in verified metrics and usually the best source of proof points, because they were written for
an audience that could check them. Extract numbers with their context intact.

### Post and engagement data
Post bodies, comment threads, engagement rosters. Available at Tier 0 (paste), Tier 2 (own posts),
or Tier 3.

---

## Normalization

Everything lands in the identity schema (`config/identity.schema.json`).

- **Dates** to `YYYY-MM`. Where only a year is known, record the year and mark the precision — do
  not invent a month.
- **Organizations** to a canonical name, with former names retained. A company that renamed is one
  employer, not two.
- **Titles** kept verbatim, with an industry-standard equivalent recorded alongside where the
  internal title was idiosyncratic. Never overwrite the real title.
- **Metrics** with unit, period, and scope preserved. "38%" is not a fact; "blended CAC down 38%
  over 11 months across three brands" is.
- **Every imported fact** carries its source document and tier. Import is `stated` unless the
  document is itself an artifact of record, in which case it is `verified` with the document cited.

---

## Identity resolution

When resolving a person or company to a profile:

- Never assert a match on name alone. Common names produce wrong matches, and a wrong match in a
  relationship record or a prospect brief is worse than no match.
- Corroborate on at least two signals: employer, title, location, mutual connection, or a
  distinguishing detail.
- Report the match confidence. When ambiguous, present the candidates and ask.
- Do not compile personal information beyond professional context, and do not aggregate across
  sources to build a profile of a private individual.

---

## Failure handling

When a path fails, say what happened, what it means, and what to do — never fail silently and never
fall back to a prohibited method.

```
Couldn't retrieve that post automatically — no retrieval service is configured.

Paste the post text and I'll work from that. It costs you one copy-paste and there's no
difference in the result.
```

If a configured service errors or rate-limits, report it plainly, wait, or fall back to Tier 0.
Never retry aggressively against a rate limit.

## References

- `references/corpus-ingestion.md` — pointing Salience at a directory the user already keeps
- `references/import-paths.md` — per-source parsing detail, LinkedIn export file map
- `references/tiers.md` — capability-by-tier matrix and what each path can and cannot do
