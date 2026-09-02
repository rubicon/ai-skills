# Changelog

All notable changes to the Salience plugin are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-09-02

Initial release. One unified LinkedIn executive presence system, synthesized from 33 in-scope
source skills, plugins, and MCP servers, read in full rather than by summary.

### Added

- **Orchestrator** (`salience`) — single entry point with intent routing, the five-tier evidence
  contract, and a shared output contract (result → verify → one next action) that every module
  inherits.
- **Identity Engine** (`salience-identity`) — professional identity record, verified-fact ledger
  with provenance and supersession history, 15-minute onboarding, and full memory controls
  (inspect, correct, remove, export, reset).
- **Profile Intelligence** (`salience-profile`) — nine-component audit with executive weighting by
  goal, honest 1–10 scoring, evidence gate, language scan, three strategically distinct headline
  variants, seven-step About with character budgets, experience rewriting with scope lines and
  attribution discipline, goal-matched Featured selection, recruiter and executive-search
  visibility, AI-search visibility, and résumé-to-profile consistency auditing.
- **Positioning** (`salience-positioning`) — five-question framework, five differentiation tests,
  audience variants, competitive mapping, executive narrative for moves, pivots, gaps, and the
  employed-and-exploring case.
- **Voice** (`salience-voice`) — voice capture from writing samples or interview (preferring the
  user's own past posts from a data export), mandatory validation before saving, and tiered AI-tell
  enforcement where the captured profile outranks general style rules. Hooks engineered by another
  module are exempt from naturalness editing, which would otherwise destroy them.
- **Content and Authority** (`salience-content`) — pillar design with an executive mix, a material
  gate that refuses to draft without a quantified fact, a non-obvious claim, a mechanism, and a
  decided close; format and hook selection, video scripts, post scoring, long-form and newsletters,
  repurposing, media briefs, and client confidentiality handling.
- **Engagement and Relationships** (`salience-engage`) — comment and reply drafting, connection
  requests, follow-up ranking led by unfulfilled commitments, relationship records with a privacy
  test, sustainable networking plans, and writing the recommendations the user gives to other
  people (distinct from the refused case of authoring testimony for someone else to paste).
- **Executive Career** (`salience-career`) — target definition, requirement extraction separating
  real from boilerplate, match and scope scoring, retained-search relationships, story banking,
  the hard interview questions, and compensation preparation.
- **Consulting and Advisory** (`salience-consulting`) — offer design with explicit scope
  boundaries, engagement shapes, pricing posture, ideal-client definition with disqualification,
  warm-path-first outreach, and pipeline tracking.
- **Data and Import** (`salience-data`) — four retrieval tiers with graceful fallbacks, résumé and
  LinkedIn-export parsing, normalization rules, and identity resolution requiring corroboration.
- **Career corpus ingestion** (`salience-data/references/corpus-ingestion.md`) — Salience can be
  pointed at a directory the user already keeps rather than interviewing them for facts that are
  already on disk. It surveys the structure and proposes a read plan before opening anything,
  classifies by folder signal, tiers by artifact type, records `corpus:`-relative provenance on
  every extracted fact, and reports the files it opened. Read-only: it never writes, moves,
  renames, or deletes anything in a corpus. Offered first in onboarding, ahead of the résumé path.
- **Analytics and Learning** (`salience-analytics`) — four-tier outcome hierarchy led by
  opportunity rather than volume, experiment tracking, attribution honesty rules, a named list of
  false patterns to refuse (survivorship, format-versus-content, volume-as-engagement, four weeks
  called a trend, "post more"), a required limits block on every review, and an ordered diagnosis
  for "it isn't working".
- **Governance** (`salience-governance`) — per-item approval matrix with no batch or standing
  approval, approval card format, refused-action list, third-party data rules, and the
  instruction-boundary rule for content Salience reads.
- Private local store outside the repository, with `scripts/salience-store.sh` for init, status,
  export, and a preferences-only reset that preserves verified career facts.
- `config/identity.schema.json` and a fully fictional worked example that exercises correction
  history, every evidence tier, client-side separation, boundaries, and gaps.
- Eight output templates, four adapter documents, five commands.
- 31-case evaluation suite with blocking acceptance criteria for fabrication, unapproved action,
  prohibited methods, prompt injection, fabricated social proof, third-party profile critique, and
  manufactured audit findings.

### Merge notes

Several sources disagreed with each other or with an earlier decision here. The resolutions worth
recording:

- **Voice sources.** One source ranks raw writing (Slack, unedited email, transcripts) as most
  authentic; another ranks the user's own past LinkedIn posts highest. Both are right about
  different things — raw sources carry truer voice, published posts carry the correct register.
  Salience uses both and says which is which.
- **Profile scoring.** One source forbids composite scores as unactionable. Scoring is retained
  because it ranks fixes and makes change measurable across audits, but paired with a
  `critical`/`important`/`polish` severity, delivered after the rewrites, and guarded against the
  two opposite failures — softening to encourage, and manufacturing findings to justify the audit.
- **Résumé metric estimation.** Several sources teach conservative estimation, ranges, minimum
  bounds, and back-calculation to manufacture numbers. Salience refuses all of it for published
  claims, and instead adopts the legitimate half — the discovery questions that surface numbers the
  user already knows.
- **Skills count.** An earlier draft here advised filling all 50 skill slots. That was wrong:
  padding dilutes the strong skills and adds unendorsed noise. Corrected to 15–25 genuine ones.
- **AI-tell removal.** A ban list without false-positive guards flattens good writing. Added the
  cluster rule (one tell is not evidence), an explicit do-not-flag list, the human signals to
  preserve, and the distinction between clean and lifeless.

### Fixed before release, from the evaluation suite

Five defects the eval subset surfaced against the design itself, each fixed in the module that
caused it:

- **Contradiction handling disagreed with itself** across three files — the evidence contract said
  stop, the output contract said flag and deliver, and the router said ask one question. Added an
  explicit stop-versus-deliver test in the evidence contract, which the other two now defer to.
- **A user-stated correction to a document-verified fact was treated as a correction**, not a
  conflict. The fact ledger now compares tiers before deciding which it is.
- **The governance override clause could be read as reaching the approval gate.** Scoped explicitly
  to cautions about content and judgment; the gate is a mechanism and does not bend.
- **"General patterns" was a loophole around the third-party critique refusal** — enumerating the
  failures in someone's pasted profile under a general heading is the same critique with a
  disclaimer attached. Closed.
- **Two worked examples contradicted the shipped fixture**, using a `$1.1M` MarTech savings figure
  while `gap-001` in the same fixture states that no dollar figure exists for that consolidation.
  An example that fabricates against its own record teaches fabrication. Rewritten to claim the
  change rather than the savings, with the gap left open and explained.

### Notes

- The plugin is public; all personal data is written outside the repository and is never committed.
- Original implementation throughout. No third-party code was copied.
- Source set resolved to canonical repositories rather than marketplace listings; several supplied
  URLs proved to be mirrors of the same upstream (notably one profile optimizer vendored into a
  second repository with only its description string changed).
- Excluded from the source set as out of scope, each recorded with a reason: general-purpose design
  tooling, browser cookie-persistence login tooling, paid-ads campaign management, a multi-platform
  content reader, and an unverifiable video reference.
- Profile scoring pairs each component score with a `critical` / `important` / `polish` severity,
  and carries explicit guards against the two opposite failures — softening scores to encourage, and
  manufacturing findings to justify the audit. Scores rank fixes; they are never the deliverable,
  and no fix is described in terms of an outcome it will produce.
- Video scripts with a spoken-word budget added to the content formats; name-field checks
  (pronunciation, former name) added to the profile components.
- Profile: the searchable role noun belongs in roughly the first 50 characters of the headline;
  audit posture states facts rather than verdicts and notes what works; an `audit-only` mode for
  users who want diagnosis without rewrites.
- Career: overqualification treated as a real rejection risk; posting red flags including the
  executive-specific ones (no stated mandate, hedged reporting line, an absent seat history, a
  reposted listing); a walk-away number decided before any compensation conversation; résumé
  formatting and ATS optimization explicitly out of scope, with the reason.
- Voice: confidence zones per topic (full authority / earned perspective / active exploration), an
  exclusion check so platform conventions are not mistaken for voice, A/B validation, and an
  exemption protecting deliberately engineered hooks from naturalness editing.
- Content: a material gate that refuses to draft without a quantified fact, a non-obvious claim, a
  mechanism and a decided close; pillars defined as topic plus arguable angle; repurposing reframed
  as mining one source for several anchored seeds; five distinct long-form shapes.
- Engagement: the screenshot test, one ask per message, and recommendations the user gives to others.
- Consulting: proof assets — the hero principle, and result strength governing language strength.
- Analytics: single-post review with the comment-quality diagnostic, and a named list of false
  patterns to refuse.
- System-wide: a 48-hour actionability test before any advice ships, and an inversion line on
  anything hard to reverse.
- Auditing or critiquing a third party's profile is refused, with the two legitimate exceptions
  named: reading it as research, and auditing one the user was asked to help with.

[Unreleased]: https://github.com/rubicon/ai-skills/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/rubicon/ai-skills/releases/tag/v0.1.0
