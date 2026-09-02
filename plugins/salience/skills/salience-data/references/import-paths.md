# Import Paths

## LinkedIn data export

Settings > Data privacy > Get a copy of your data. Arrives as a ZIP of CSVs, typically within
minutes for the basic archive.

| File | Carries | Use |
|---|---|---|
| `Profile.csv` | Headline, summary, industry, location | Current profile state for the audit |
| `Positions.csv` | Title, company, dates, description | The role spine. Most reliable source available |
| `Education.csv` | Institutions, degrees, dates | Credentials |
| `Skills.csv` | Listed skills | Current skills state |
| `Recommendations_Received.csv` | Text, author, date | Proof points and voice samples |
| `Connections.csv` | Name, company, position, connected date | Relationship seeding. Large — import selectively |
| `Endorsement_Received_Info.csv` | Skill endorsements | Which skills carry search weight |
| `Shares.csv` | Posts and articles | Voice samples and content history |
| `messages.csv` | Full message history | **Do not import by default.** Ask first, import narrowly |

**Never ingest the messages archive by default.** It contains other people's words and confidential
exchanges. Import only when the user asks for something specific from it, and only the portion
needed.

Roughly the first import wins the date fight: `Positions.csv` dates are what LinkedIn displays, so
a disagreement with a résumé means the résumé is likely right and the profile is what the world sees
— surface both.

## Résumé or CV

Extract roles, titles, organizations, dates, scope, achievements, education, credentials.

- Every number becomes a ledger candidate with the document as source
- Date ranges written as years only stay years. Do not infer months
- Bullet text is a claim, not a verified fact — the résumé is the user's own assertion unless it
  cites something
- Scope statements ("team of 12", "$40M budget") are the most valuable extraction and the most
  commonly absent

## Pasted profile text

Section boundaries are usually inferable from structure, but confirm the parse before writing. A
mis-parsed heading silently corrupts the record and is hard to detect later.

## Bios, case studies, board decks

The best source of verified proof points, because they were written for an audience that could check
them. Extract numbers with their context intact — unit, period, and scope.

A board deck figure may be a projection. Note which, and prefer a final-close document where one
exists. This is exactly the situation the ledger's `history` field exists for.

## Post and engagement data

Post bodies, comment threads, engagement rosters. Tier 0 (paste), Tier 2 (own posts via official
API), or Tier 3 (third-party retrieval). See `tiers.md`.

## Normalization rules

- **Dates** to `YYYY-MM`; record `date_precision: year` when the month is unknown
- **Organizations** to a canonical name with former names retained. A renamed company is one
  employer, not two
- **Titles** kept verbatim; `title_standard` records the industry equivalent without overwriting
- **Metrics** keep unit, period, and scope. "38%" is not a fact
- **Every imported fact** carries its source document and a tier. Import is `stated` unless the
  document is an artifact of record, in which case `verified` with the document cited

## Confirmation

Always show the parse back before writing. Never treat your own extraction as verified — a parse is
an inference about a document, and inference is a tier.
