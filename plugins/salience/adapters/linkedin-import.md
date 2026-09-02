# LinkedIn Data Export

**Free, first-party, no third party involved, and the best onboarding input available.**

## Requesting

Settings → Data privacy → Get a copy of your data.

Choose **"Want something in particular?"** and select the specific files rather than "The works" —
it arrives faster and avoids importing things Salience should not hold.

Recommended selection: Profile · Positions · Education · Skills · Recommendations · Endorsements ·
Shares.

**Leave Messages unselected.** It contains other people's words and confidential exchanges, and
Salience will not import it by default. If a specific message is needed later, paste that one.

Basic archives typically arrive within minutes; the full archive can take up to 24 hours.

## Importing

Unzip and point Salience at the folder, or hand it individual CSVs.

```
Here's my LinkedIn export: ~/Downloads/Basic_LinkedInDataExport_2026-09-02/
```

Salience reads what it needs, shows the parse back for confirmation, and writes to the identity
record only after you confirm.

## What each file gives

| File | Feeds |
|---|---|
| `Profile.csv` | Current headline and About — the baseline for the audit |
| `Positions.csv` | The role spine. Titles, companies, dates, descriptions |
| `Education.csv` | Credentials |
| `Skills.csv` | Current skills state for the search-visibility audit |
| `Endorsement_Received_Info.csv` | Which skills carry search weight |
| `Recommendations_Received.csv` | Proof points, and useful voice samples |
| `Shares.csv` | Content history and voice samples |
| `Connections.csv` | Relationship seeding — large, imported selectively |

## Limits

- A point-in-time snapshot. It does not update
- It contains nothing about anyone else's profile
- Descriptions are whatever you wrote, so they are `stated`, not `verified` — the export proves
  what your profile says, not that it is accurate

## Privacy

The export lands in `$SALIENCE_HOME/imports/`, outside the repository, in a directory the store
script marks git-ignored. It is included in `salience-store.sh export` and removed by deleting the
file. Nothing is uploaded anywhere.
