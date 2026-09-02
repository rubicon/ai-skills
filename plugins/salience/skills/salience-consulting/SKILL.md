---
name: salience-consulting
description: >-
  Develop consulting, fractional, advisory, and speaking opportunities — offer design and pricing
  posture, ideal-client definition, prospect and account research, outreach that does not read as
  outreach, proposal positioning, pipeline tracking, and the proof assets that convert inbound —
  case studies and testimonials. Triggers on "consulting positioning", "fractional CMO", "advisory
  work", "speaking opportunities", "research this prospect", "draft outreach to", "how should I
  price this", "my pipeline", "turn this connection into a client", "write up this client win",
  "ask for a testimonial".
  Not for employment search (use salience-career) or for writing marketing content (use
  salience-content).
version: 0.1.0
---

# Consulting and Advisory

Executive advisory work is sold through credibility and relationships, not through volume outreach.
The tactics that work for SaaS prospecting actively damage an executive brand, and this module will
not run them.

**Refused outright:** bulk connection requests, sequenced templated messaging to lists, automated
follow-up chains, pitching in a connection request, engagement farming, and any outreach that
misrepresents how the user found the recipient.

---

## Offer design

Vague availability produces no inbound. "Open to consulting opportunities" is not an offer.

Define, concretely:

1. **The problem** — as the buyer states it, not as the practice area
2. **The engagement shape** — fractional (ongoing, fractional time), advisory (periodic counsel),
   project (bounded scope and deliverable), or board/speaking
3. **Duration and commitment** — realistic. A fractional CMO at one day a week cannot own execution
4. **What is explicitly out of scope** — the most useful and most skipped element
5. **What the buyer gets** — outcomes, not activities

### Engagement shapes

| Shape | Buyer | Typical commitment | Sold on |
|---|---|---|---|
| Fractional executive | Company without budget or need for a full-time seat | 1–2 days/week, 6–12 months | Operating capability |
| Advisory | Founder or CEO needing periodic counsel | A few hours monthly | Judgment and access |
| Project | Specific bounded problem | Weeks, defined deliverable | A defined outcome |
| Board / committee | Governance need | Quarterly | Standing and experience |
| Speaking | Event or internal audience | One-off | Point of view |

Each has a different buyer, a different sales motion, and a different profile expression. Trying to
sell all five with one message sells none.

### Pricing posture

Salience does not set prices. It helps the user reason about posture:

- Price on the value of the problem, not on hours, wherever the shape allows
- A retainer that is uncomfortably low anchors every future engagement, including with other clients
- Discounting the first engagement to win it usually sets the ceiling permanently
- Name a range confidently and stop talking

Where market rate data is genuinely unknown, say so rather than inventing a benchmark.

---

## Ideal client

Specific enough to disqualify. Stage, size, model, ownership, the situation that creates the need,
who signs, and — critically — **who is not a fit.**

The disqualification list is what makes referral work: a network can only send the right people if
it knows which people are wrong.

---

## Prospect research

For a named company or person, assemble only what informs a real conversation:

- What the company actually does and its current situation
- Public signals of the relevant problem — hiring patterns, funding, leadership changes, product moves
- Who owns the problem and who signs
- Any genuine connection: shared contacts, prior context, something they published
- What the user could say that is useful before any engagement exists

Use public sources only. Do not attempt to access gated data, and do not compile personal
information beyond professional context.

**If there is no genuine reason to reach out, say so.** Manufacturing a pretext is what makes
outreach read as outreach.

---

## Outreach

The standard: it should be worth receiving even if it goes nowhere.

- **Lead with something useful or genuinely specific to them.** Not a compliment on their post —
  an observation about their situation that shows real attention.
- **Never open with the ask.** Establish relevance first.
- **Be explicit about why them, and why now.**
- **Make the ask small and easy to decline.** A conversation, not an engagement.
- **One follow-up, then stop.** Sequences of four and five messages are for products, not
  executives. The second message is the last one.

Every message requires approval before sending. No exceptions, and no batch approval — see
`salience-governance`.

### Warm paths first

Always check the relationship record before drafting cold outreach. A shared contact who will make
an introduction outperforms the best cold message by a wide margin, and this is the most common
missed move — the connection often already exists.

---

## Inbound

Most executive advisory work arrives inbound. The system that produces it:

- Profile positioned for the offer, with Featured carrying the diagnostic and the path
- Content demonstrating the judgment being bought
- Visible proof — case studies, testimonials, external validation
- A low-friction way to start a conversation

When the user asks how to get more consulting work, check this system before recommending outreach.
Outbound compensates for a weak inbound system; fixing the system is usually higher leverage and
almost always the honest answer.

---

## Pipeline

Track in `${SALIENCE_HOME:-~/.claude/salience}/relationships.yaml` with an opportunity view: who,
shape, the problem, stage, last contact, next step and when, and what is owed.

Stages: **signal** → **conversation** → **scoped** → **proposed** → **won / lost / dormant**

Record why opportunities are lost. Over a year that record is the most useful marketing input the
user has, and nobody keeps it.

## Proof

Case studies and testimonials are what convert an inbound visitor, and they are the assets
executives consistently fail to create while the engagement is fresh.

Two rules govern all of it. **The client is the hero and the user is the guide** — write what the
client experienced, not what was delivered. And **result strength governs language strength**: a
hard metric is stated flatly, a proxy is "contributed to", and a directional result never acquires
an invented magnitude.

See `references/proof-assets.md` for the drafting gate, the three formats, the testimonial ask, and
the confidentiality rules.

## References

- `references/offer-design.md` — shapes, scope boundaries, pricing posture
- `references/outreach.md` — research, message construction, worked examples, follow-up discipline
- `references/proof-assets.md` — case studies and testimonials, the hero principle, result-strength language
