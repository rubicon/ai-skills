# Corpus Ingestion

Pointing Salience at a directory the user already keeps — a career folder, a portfolio archive, a
document vault — instead of interviewing them for facts that are sitting on disk.

**The principle: never ask for something the corpus already contains.** Re-asking is the fastest way
to make an onboarding feel like a form, and a user with an organized career folder has already done
the work once.

## Configure

```yaml
# $SALIENCE_HOME/config.yaml
corpus:
  - path: "~/Documents/Career"
    role: primary          # the main career corpus
  - path: "~/Documents/Writing"
    role: voice            # writing samples only
    read_only: true
  - path: "~/Archive/Press"
    role: evidence
```

Or in conversation: *"My career stuff is in ~/Documents/Career — use that."*

Salience reads these paths. It never writes to them, never moves or renames anything, and never
deletes. The corpus is a source, not a workspace.

## Survey before ingesting

**Do not read 1,500 files.** Survey the structure, propose a plan, get agreement, then read only
what the plan names.

```
Surveying ~/Documents/Career — 1,502 files, 216 MB.

Worth reading now
  Resume (Current)/          a resume, a career corpus doc, an evidence database, an awards ledger
  Press & Evidence/          13 dated press PDFs, 1999-2002 and 2019
  Voice and Persona/         6 files including a brand and writing style guide
  Applications/              8 role folders, each with a resume, cover letter, and fit notes

Skipping
  Resume (Current)/Build/    node_modules and build output — 1,240 files, not career material
  Archive/                   ask me if you want it; large and undated

Plan: start with the resume and the career corpus doc for the role spine, cross-check against
the evidence database, then pull dated press as verified artifacts. About four files to start.

Sound right?
```

The survey is cheap and the read is not. A corpus with a code project inside it is common and will
otherwise dominate the file count.

## What to skip, always

`node_modules` · `.git` · `dist`, `build`, `out`, `target` · `.venv`, `__pycache__` · `.DS_Store` ·
lock files · minified assets · anything over ~20 MB unless specifically named · images, except when
the user asks about a banner or headshot · **anything under a path segment the user flagged
private**.

## Folder signals

Directory names are strong classification evidence. Read them before opening anything.

| Folder or filename suggests | Feeds | Treat as |
|---|---|---|
| `Resume`, `CV` | Role spine, scope, achievements | `stated` — the user's own assertion |
| `Career Corpus`, `Source of Truth`, `Evidence Database` | The spine, preferentially | Read **first** — see below |
| `Press`, `Coverage`, `Media`, dated PDFs | Proof points, external corroboration | `verified` — third-party publication |
| `Awards`, `Recognition` | Credentials | `verified` when the artifact is present |
| `Voice`, `Writing`, `Style Guide`, `Persona` | `salience-voice` | Voice samples and any existing profile |
| `Applications/<company>/` | `salience-career` | Prior positioning per target, and what was claimed |
| `Case Studies`, `Portfolio`, `Client` | `salience-consulting` proof assets | Check confidentiality before any public use |
| `Coaching`, `Workshops` | Career method and prior advice | Context, not fact |
| `Board`, `Advisory` | Governance roles | Role entries |
| `Archive`, `Old`, dated back-folders | Deep history | Ask before reading; often superseded |

## Authority is declared, never inferred

A maintained corpus usually states its own precedence — a README, a `CLAUDE.md`, or a header block
saying which file wins when two disagree. **Find that statement and follow it.** Where none exists,
ask which file is canonical. Do not decide from evidence the filesystem happens to offer.

**Never infer authority from a filename.** A file called *Source of Truth* is as likely to be a
navigation guide pointing at the real spine as it is to be the spine. Read enough of it to find out
which.

**Never infer authority from size or completeness.** This is the failure mode that looks most like
diligence. Observed on a real corpus: the largest file by a factor of six, matching every
name heuristic, carrying a complete duplicate of two other files — and explicitly disclaimed in the
README as a non-authoritative recovery dump that was still being edited. A "most complete file wins"
rule lands on exactly the wrong document, and lands there confidently.

What actually separates a maintained file from a dump is **maintenance evidence**, not volume:
conflict markers, reconciliation blocks naming a canonical value and the date it was settled, and
dated corrections. A dump has quarantine markers copied in with everything else and no reconciliation
blocks at all, because nobody has been resolving anything in it.

Once the canonical spine is identified, **read it first and build the career spine from it.** It
represents work the user already did to reconcile their own history, and rebuilding that from
scattered files resurfaces contradictions they already settled. Use everything else to
**corroborate and date** it, not to replace it.

### When two authority orders disagree

A corpus can declare precedence in more than one place, and the orders can differ — a README naming
one order and a `CLAUDE.md` in the same tree naming another. **That is a contradiction, and it is
surfaced, not resolved by picking.** It is also the most consequential contradiction in a corpus,
because it silently changes the answer to every later question.

### Named exclusions belong in the config

Any file the corpus itself disclaims — a recovery dump, a superseded planning artifact left in a
live folder, an "alternative" variant explicitly marked as not the default — is excluded by name,
recorded with the reason, and re-confirmed on a later run. Do not rely on catching it again by
inference.

## Generated companion views

A canonical structured file often ships alongside a generated prose view of the same data:
`awards-ledger.yaml` and `awards-ledger.md`, a database and its exported summary. **Import one.**
Ingesting both double-counts every entry, and the duplicates look like corroboration.

The structured file is canonical unless the corpus says otherwise. Where the prose view contains
material the structured file does not, that is drift worth reporting, not extra facts to merge.

## Provenance

Every fact extracted from the corpus carries its file path and location, exactly as any other
source:

```yaml
- id: fact-088
  claim: "Led the acquisition of two services firms during the 2000 rollup"
  tier: verified
  source: "corpus:Press & Evidence/2000 - TechWeb Today - Acquires Two Services Firms.pdf"
  recorded: 2026-09-02
```

Use a `corpus:` prefix and a path relative to the configured root. Absolute paths leak the user's
directory layout into the record for no benefit, and break if the folder moves.

### Provenance is usually prose

A disciplined corpus carries provenance inline rather than in fields, and these markers hold exactly
what the evidence contract needs. Read them:

| Marker in the corpus | What it means | Where it lands |
|---|---|---|
| A dated source tag — `(2023-08; also 2024-06, 2025-01)` | The claim was attested on those dates, more than once | `recorded`, and corroboration strength |
| `⚠️ CONFLICT`, or the same figure differing between files | An open disagreement | Surface it. Never pick |
| `✓ Conflicts reconciled by <person> on <date>` | A settled question, with a canonical value named | Take the canonical value; put the loser in `history` with the reconciliation date as `superseded` |
| A cited source filename | The artifact behind the claim | `source`, and a candidate for `verified` |
| `COMPANY-CONTEXT ONLY`, or similar | The fact belongs to the organization | `subject: organization` |
| A quarantine note | Not publishable, whatever its sourcing | `visibility: private`, with the note as `visibility_reason` |

A reconciled conflict is **not** a contradiction to re-surface. The user already settled it, and
raising it again reads as not having read their work.

### Confidence vocabularies must be mapped, and the mapping recorded

A corpus may carry more than one confidence scale — `Confirmed / Probable / Needs Verification` in
one file and `High / Medium / Low` in another, with no mapping defined between them. Both must land
on Salience's five tiers, and **the mapping chosen is reported to the user**, because it is a
judgment call that changes what gets published.

A defensible default, stated as a proposal rather than applied silently:

| Corpus says | Salience tier |
|---|---|
| `Confirmed` with a cited artifact · `High` with a cited artifact | `verified` |
| `Confirmed (per <user>)` · `Confirmed` with no artifact | `stated` |
| `Probable` · `Medium` | `inferred` |
| `Needs Verification` · `Low` | `gap`, not a fact |

Note the asymmetry: a confidence label is not a source. `Confirmed` with nothing cited is still the
user's own assertion, and it is `stated`.

## Tiering by artifact type

The corpus makes real tiering possible, which an interview cannot:

| Artifact | Tier | Why |
|---|---|---|
| Dated press coverage, a published article | `verified` | Third-party publication, independently checkable |
| A board deck, QBR, final-close file | `verified` | A record of the time, though check projection versus actual |
| An award certificate or announcement | `verified` | |
| A resume or bio the user wrote | `stated` | Their own assertion, not corroboration |
| A cover letter or application answer | `stated`, and dated | Useful for what was claimed *when* |
| A consolidated evidence document | Inherits per entry | Only as good as what it cites |
| A draft, a note, an outline | `stated` at best | Often thinking, not record |

**A resume in the corpus does not make its claims verified.** It is the same assertion in a file.
Verification needs a document produced by someone other than the user, or a record produced at the
time.

## Dates from filenames

Corpora are commonly dated in filenames — `2000-06-15 - ...`, `2025-08-14-...`. Use these for
`recorded` and period context, and say the date came from the filename rather than from the content.
Filenames are usually right and occasionally are the date the file was saved rather than written.

**Frontmatter `updated:` is not a staleness signal on its own.** It is hand-maintained and drifts
from filesystem mtime routinely — a file edited last week can still claim it was updated months ago.
Where the two disagree, say so rather than trusting either; a dated reconciliation block inside the
content beats both.

## Voice

A corpus is the best voice source available, and better than asking. Route writing samples to
`salience-voice`, preferring:

1. An existing voice or style guide, if one is present — read it as a **starting hypothesis to
   validate**, not as settled fact. It was written for a purpose that may not be this one
2. Unedited writing — emails, notes, drafts
3. Published pieces, for register

Apply the exclusion check: material written for a specific audience carries that audience's
conventions, not the person's voice.

## Privacy

- **Read only.** Never write, move, rename, or delete anything in a configured corpus
- **Nothing personal enters the repository.** Extracted facts go to `$SALIENCE_HOME`, never to the
  plugin directory
- **Skip anything under a path the user flagged private**, without needing a reason
- **Third-party material** — references, other people's reviews, private correspondence — is subject
  to the same third-party rules as anywhere else. Professional context only, and never exported
- **Quarantine markers are load-bearing.** A figure can be verified, well sourced, and still barred
  from a sent resume or a public profile. Sourcing answers a different question than permission
  does. Any quarantine note in the corpus becomes `visibility: private` with the note preserved as
  `visibility_reason`, so the restriction outlives whoever set it
- **Say what was read.** Report the files opened, not just the facts found. The user should be able
  to audit what the system looked at

## Re-running

A corpus changes. On a later run, detect what is new or modified since the last ingest, and report
only the delta — a full re-survey of a stable corpus is noise. Anything that contradicts an existing
ledger entry surfaces as a contradiction, never as a silent overwrite.
