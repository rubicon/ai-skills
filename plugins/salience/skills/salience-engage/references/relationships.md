# Relationship Records

## Schema

`${SALIENCE_HOME:-~/.claude/salience}/relationships.yaml`

```yaml
- id: rel-014
  name: "Priya Raman"
  role: "Partner, executive search - CMO practice"
  organization: "Kestrel Partners"
  relevance: "Places CMOs in PE-backed B2B SaaS. Ran the Hollis search that hired my predecessor."
  first_contact: 2025-11-03
  last_contact: 2026-07-18
  channel: linkedin
  context: |
    Introduced by Tom Alvarez. Two calls. She asked me to flag anyone strong in
    lifecycle marketing; I sent her two names in March, one got placed.
  owed:
    - who: me
      what: "Send the attribution teardown I mentioned"
      since: 2026-07-18
  owed_to_me: []
  next_touch: "When the teardown is written, or Q4 either way"
  tags: [search-firm, warm, priority]
```

The `owed` field is the one that matters most. Owing someone something and going quiet is the most
damaging pattern in professional relationships and the easiest to fix.

## Follow-up ranking

When asked who to follow up with:

1. **Unfulfilled commitments the user made.** Always first
2. **Live threads** — a recent exchange that stopped mid-conversation
3. **Warm but decaying** — a real relationship, no contact in 6-12 months
4. **Situational** — someone whose circumstances just changed relevantly (new role, funding,
   a public move)

Never surface someone with nothing to say. A follow-up needs a reason: something useful, a genuine
question, a relevant introduction, or an honest reconnection with no ask attached.

```
Three worth your time this week.

Priya Raman (Kestrel) - you promised her the attribution teardown in July and it hasn't
gone. That's the only overdue commitment on the list.

Tom Alvarez - introduced you to Priya, hasn't heard from you since. Nothing owed; worth a
note because he's the reason that relationship exists.

Dana Whitfield - just moved to a VP Growth seat at a Series C. You worked together at
Northbay. Congratulations note, no ask.
```

## What not to record

- Personal details they would be uncomfortable seeing written down
- Contents of private messages beyond what is needed to track a commitment
- Speculation about their situation, employment, or intentions
- Assessments of them as a person
- Anything about their family, health, or finances

**The test: if this person read their record, would the relationship survive it?**

If the answer is no, do not write it. This is not merely an ethical constraint — records leak,
export, and get read over shoulders.

## Third-party data

Never export or share relationship data without explicit, scoped approval. "Export my contacts" is
a gated action — see `../../salience-governance/SKILL.md`.

Do not compile personal information about a private individual across sources. Professional context
the user recorded from their own interactions is legitimate; assembled dossiers are not.

## Networking plans

Sustainable, not aspirational:

- 5-10 relationships to deepen, named, with a reason each
- A realistic weekly rhythm — for most executives, 15-20 minutes on three days
- 3-5 people worth following consistently
- One re-engagement per month from the dormant list

Refuse volume targets. "50 connection requests a week" is not a networking plan; it is a way to be
ignored fifty times, and it damages the profile it claims to build.
