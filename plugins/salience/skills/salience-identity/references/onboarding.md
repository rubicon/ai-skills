# Onboarding

Target: a usable record in about 15 minutes. Import first, ask second. The failure mode is an
interrogation that produces a perfect record the user abandons halfway through.

## Sequence

### 1. Offer the import paths (one message)

```
Fastest start is importing what you already have. Any one of these is enough:

1. Resume or CV
2. Your LinkedIn profile text, or a data export
   (Settings > Data privacy > Get a copy of your data)
3. A bio you've used for a talk, panel, or podcast
4. A case study, board deck, or review with real numbers
5. Nothing - we can build it by conversation instead
```

Hand anything received to `salience-data`. Return here to structure and confirm.

### 2. Confirm the spine

Show back what was parsed. Never treat your own parse as verified.

```
Here's what I read. Correct anything wrong.

Hollis Data - Chief Marketing Officer - Feb 2023 to present
  22 people, $40M budget, 3 business units, reports to CEO
Northbay Systems - VP Growth Marketing - Jun 2019 to Jan 2023
  11 people, $12M budget, reports to CRO

Two things need you:
- Your resume says "VP Growth Marketing"; your profile says "VP Marketing". Which is the real title?
- No end month on Northbay. January or February 2023?
```

Surface contradictions immediately. A resume and a profile disagreeing is the most common finding
and the most valuable one.

### 3. Fill only the gaps that change published copy

Ordered by leverage. Stop when the answers stop changing anything.

1. **Strongest provable outcome.** Not the biggest, the most defensible. What is the artifact?
2. **Scope at the most senior role.** Team, budget, P&L, reporting line.
3. **What is next.** Target roles, company profile, and whether consulting is in scope or a fallback.
4. **Who must find you.** Search partners, founders, PE operating partners, peer executives. This
   answer drives every downstream keyword decision.
5. **What you will not claim.** Boundaries, confidential clients, titles that would be a stretch.

Item 5 is the one every source system skips and the one that prevents the most damage. Ask it
plainly: *"Anything you don't want claimed on your behalf, even if it's technically defensible?"*

### 4. Consulting path (only when in scope)

- Engagement shapes of interest: fractional, advisory, project, board, speaking
- Clients that can be named publicly, and clients that cannot
- Work that must never appear in public copy

### 5. Write and report

Write `identity.yaml`. Report in the output contract: what was captured, what is unverified, the
single highest-value gap. Do not echo the whole record back.

```
Record created. 3 roles, 14 facts, 2 gaps.

[VERIFY]
- 9 of 14 facts are user-stated with no artifact. Fine for now; the CAC and pipeline
  numbers are the two worth sourcing before they go in a headline.
- Resume and profile disagree on the Northbay title. Using "VP Growth Marketing" per your answer.

[NEXT]
Your MarTech consolidation has no number attached and it's your clearest differentiator.
Worth digging up the savings figure?
```

## Rules

- **Never invent to fill a field.** An empty scope field is a gap, not a zero.
- **Never ask for something already in the record.** Re-interrogating is how these tools become
  tiresome.
- **Stop when the record is good enough to work from.** Completeness is not the goal; usability is.
  Gaps can be closed as they block real work.
- **Date precision is a fact.** "2021" is not "2021-03". Record what is known.
