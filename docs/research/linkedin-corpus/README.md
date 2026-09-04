# LinkedIn corpus review ledger

What was reviewed while building the Salience plugin, what was decided about each source, and
why. The point of this directory is that the next review is a **differential**, not a re-run.

## Files

| File | What it holds |
|---|---|
| `repos.tsv` | One row per source repository, pinned to the commit that was actually read |
| `skills.tsv` | One row per judged skill: disposition, target module, one-line rationale |
| `refresh.sh` | Compares every pinned SHA against the current remote; prints only what moved |

## Using it

```bash
bash docs/research/linkedin-corpus/refresh.sh
```

Nothing printed means nothing to re-read. To pull the changed repos and see which skill files
moved:

```bash
bash docs/research/linkedin-corpus/refresh.sh --clone /tmp/corpus-refresh
```

Then judge only the changed `SKILL.md` files, and update the affected rows plus their
`commit_reviewed` SHA. A source whose SHA still matches does not get re-read, however tempting.

## Dispositions

| Value | Meaning |
|---|---|
| `MERGE` | The rule was adopted into Salience |
| `PARTIAL` | Something real here, scoped smaller than the source — a gap worth an issue, not a wholesale adoption |
| `CONFIRMATION` | Independently arrives at something Salience already does. No change, but corroboration that the rule is load-bearing |
| `REFUSED` | The technique is on Salience's refusal list. Recorded deliberately — see below |
| `NOT-TAKEN` | Read, judged, nothing to take. Out of scope, thinner than what Salience already has, or superseded |

### Why refused tools stay in the ledger

Twenty-one sources were refused — logged-in UI automation, session-cookie reuse, bulk connection
and messaging pipelines, detection-evasion pacing. They are recorded here **with the specific
mechanism named**, not filtered out, for three reasons:

1. Without the record, the next pass re-analyzes them from scratch and re-reaches the same answer.
2. Naming the mechanism (`li_at` cookie plus headless Chromium; PhantomBuster-triggered sequences;
   bezier-curve mouse jitter tuned to defeat bot detection) makes Salience's refusals concrete
   instead of abstract. "We do not automate LinkedIn" is weaker than naming the technique.
3. Several of them are otherwise well-engineered, and their non-refused parts were still judged
   on method. Deleting the row would lose that too.

## Scope

| Scope | Meaning |
|---|---|
| `in-scope` | LinkedIn presence, content, profile, engagement, career, or the reasoning method behind them |
| `adjacent` | Résumé/brand-adjacent; read for method, not for LinkedIn specifics |
| `aggregator` | Large vendored collections; LinkedIn-relevant skills extracted after content-hash and near-duplicate dedup, rather than reading every file |
| `sampled` | Very large repo; LinkedIn-relevant subset read |
| `mcp-server` | MCP server, not a skill collection |
| `out-of-scope` / `no-skills` | Read enough to determine it does not apply |

Aggregator repos carry large `skill_md_count` values (tens of thousands in one case) because they
vendor other people's collections wholesale. That number is a file count, not a count of distinct
skills, and it is not a measure of what was read.

## Method, and where it went wrong

Two passes ran. Recording both, including the failures, because the failures are the part that
would otherwise be repeated.

**Pass 1** dispositioned sources largely from their descriptions and frontmatter. It was wrong
twice in ways worth naming:

- **Excluding a source on subject matter meant never reading its method.** Twelve LinkedIn Ads
  skills were excluded wholesale as "paid campaign management, a different job." The domain
  judgment was right. But four of the strongest findings in the entire corpus came out of that
  block once it was actually read — how to refuse to conclude from thin data while still saying
  what would settle it, and how to attribute a change to a cause or admit the cause is unknown.
  A disposition made from a description string cannot tell a bad idea from a good idea in an
  unrelated domain.
- **Description-level reading missed rules buried in DO-NOT lists.** Seventeen skills in one repo
  were recorded as clean merges. Re-reading found six design rules in three of them that were
  not in Salience and should have been. Every one was inside a worked example or a prohibition
  list, invisible to a description-level pass.

**Pass 2** read the skills in full: mechanical extraction with verbatim quotes required, then
judgment against Salience as shipped.

Its own defect, recorded for the same reason: **the briefing describing Salience to the judging
agents was built with a line-range `sed` and was silently truncated.** All nine agents received a
governance section heading with no body, and never saw the content module's material gate. The
bias this introduces runs one direction — an agent with an incomplete picture of Salience
over-reports gaps it does not have, and cannot under-report material in the sources, which were
extracted separately and completely. Eight false-positive findings resulted out of roughly 110
substantive dispositions. All eight were caught by verifying each claim against the shipped files
and were downgraded to confirmations.

The lesson generalizes past this project: a truncated file reads exactly like a complete one.
Any extraction taken by line range needs its boundaries checked against the source length before
anything is built on it.

## Standing caveats

- **Platform mechanics quoted from a source are claims, not facts.** Character limits, reach
  penalties, and algorithm behavior asserted in these skills were recorded as stated by the
  source and are not independently verified. Anything acted on needs checking against LinkedIn's
  own documentation first.
- **Sources disagree with each other**, and disagreements were recorded rather than silently
  resolved — hashtag counts, for one, where sources split between 0–2 and 3–5.
- `skills.tsv` rows sourced from a batch summary rather than a per-skill judgment are attributed
  as such in the repo column.
