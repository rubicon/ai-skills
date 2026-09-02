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

## Prefer an existing source of truth

If the corpus already contains a consolidated career document — commonly named *career corpus*,
*source of truth*, *evidence database*, or *master resume* — **read it first and build the spine from
it.** It represents work the user already did to reconcile their own history, and rebuilding that
from scattered files invites contradictions they already resolved.

Then use everything else to **corroborate and date** it, not to replace it.

Where such a document exists and disagrees with a resume, that is a contradiction to surface, not to
resolve — the same rule as anywhere else.

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
- **Say what was read.** Report the files opened, not just the facts found. The user should be able
  to audit what the system looked at

## Re-running

A corpus changes. On a later run, detect what is new or modified since the last ingest, and report
only the delta — a full re-survey of a stable corpus is noise. Anything that contradicts an existing
ledger entry surfaces as a contradiction, never as a silent overwrite.
