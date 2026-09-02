---
name: salience-analytics
description: >-
  Track what actually produces opportunity — profile changes, content performance, experiment
  history, and the outcomes that matter (recruiter contact, qualified conversations, interviews,
  consulting inquiries, advisory and speaking invitations). Learns from what the user accepts,
  rejects, and corrects. Triggers on "how did my posts do", "what's working", "did that change
  help", "review my performance", "my profile isn't getting views", "was that worth it", "why did
  this post flop", "postmortem on this post". Not for producing content (use salience-content) or
  auditing the profile (use salience-profile).
version: 0.1.0
---

# Analytics and Learning

The question this module answers is **"is this producing anything?"** — not "how many impressions
did that get."

For an executive, LinkedIn success is a small number of high-quality conversations. A post seen by
40,000 people that produces nothing is worse than a post seen by 900 that produces one call with the
right person, because the first teaches the wrong lesson and is easy to repeat.

---

## Outcome hierarchy

Rank every result by this. Report in this order, always.

| Tier | Signal |
|---|---|
| **1 — Opportunity** | An interview, a search-firm conversation about a live mandate, a consulting inquiry, an advisory or board approach, a speaking invitation |
| **2 — Qualified conversation** | A real exchange with someone in the target audience — a peer executive, a founder, an operating partner, a search partner |
| **3 — Qualified attention** | Profile views from target-audience people, an author reply from someone who matters, a saved or shared post from the right reader |
| **4 — Volume** | Impressions, likes, followers, connection count |

**Tier 4 is diagnostic only.** It explains distribution; it never justifies an activity on its own.
When a user asks how a post did, lead with tiers 1–3 and mention tier 4 only as explanation.

Say plainly when the honest answer is "this produced nothing yet." Executive content compounds
slowly, and a system that manufactures encouragement from impression counts trains the wrong
behavior.

---

## What to track

`${SALIENCE_HOME:-~/.claude/salience}/content-log.yaml` and `experiments.yaml`:

**Per published item:** date, pillar, format, hook type, the claim made, the goal, and outcomes at
7 and 30 days across all four tiers.

**Per profile change:** what changed, when, and the before/after on search appearances, view volume,
**viewer composition**, and inbound quality.

Viewer composition is the most informative and least reported metric available. Views rising while
the audience shifts away from the target is a keyword problem presenting as success.

**Per experiment:** the hypothesis, what changed, the window, what happened, and what was concluded.

**Learning signals:** which drafts the user accepted unchanged, which they rewrote and how, phrasings
they consistently reject, and corrections to the fact ledger. These feed `salience-voice` and
`salience-identity`.

---

## Attribution honesty

Most of what matters here cannot be cleanly attributed, and pretending otherwise is the failure mode
of every analytics tool.

- A recruiter call rarely traces to one post
- Profile views lag content by days and cluster unpredictably
- The highest-value outcomes have the longest and least visible paths
- Sample sizes are small enough that most differences are noise

Rules:

1. **Report correlation as correlation.** "The three posts before that inquiry were all in the
   MarTech pillar" — not "that pillar generated the inquiry."
2. **Refuse to draw conclusions from too little data.** Two posts is not a trend. Say "not enough
   yet" rather than inventing a pattern.
3. **Prefer the boring explanation.** Cadence, timing, and audience size explain more variance than
   hook selection.
4. **Never invent a metric.** If the number is not available, say what would be needed to know.

---

## Reviews

### 30-day
What was published, outcomes by tier, what changed on the profile, what the viewer composition did,
one thing to keep, one to stop, one to try. That is the whole review — an executive does not need a
dashboard.

### Quarterly
Whether the strategy is producing opportunity, whether the audience is the intended one, whether the
positioning still fits, and whether the effort is worth the return.

**Be willing to conclude it is not working.** If two quarters of consistent effort produced no
tier-1 or tier-2 outcomes, the honest recommendation may be that the positioning is wrong, the
audience is not here, or effort belongs elsewhere. A tool that always recommends more content is not
analyzing anything.

---

## Wrong patterns to refuse

The most damaging output of content analytics is a false pattern the user then optimizes for. Name
these when they appear rather than reporting the pattern:

- **Survivorship.** One contrarian post went wide. That is not evidence contrarian posts work. Look
  across posts before calling anything a pattern.
- **Format confused with content.** "Carousels outperform text" may mean the carousel *topics* were
  stronger. Disentangle before recommending a format.
- **Volume read as engagement.** 10,000 impressions with 12 reactions is a worse post than 1,500
  with 30 substantive comments from the right people. Impressions are the easiest number to move
  and the least informative.
- **Four weeks called a trend.** Most claimed LinkedIn trends are sampling noise. A pattern needs
  8-12 weeks before it is durable.
- **"Post more" as the answer.** Almost never correct above roughly one post a week. It is the
  recommendation that sounds like analysis and requires none.

## Required output section

Every review ends with an explicit limits block. It is not optional and it is not a hedge — it is
the part that keeps the user from over-fitting.

```
What I can't conclude from this
- Four posts is not enough to separate pillar from format. Both changed at once.
- No dwell-time data, so a "read" and a "scrolled past" look identical here.
- The Kestrel conversation may have come from the comment thread, not the post. I can't tell.
```

## Reviewing a single post

Distinct from the periodic review. Use it when one post clearly beat or missed the user's own
median, and only after **at least 48 hours, ideally five to seven days.**

**Ask the user's read before giving yours.** *"Before I look — what's your gut on what worked or
didn't?"* Their instinct is usually partly right, and starting there makes the review a
conversation rather than a verdict. It also surfaces context no metric contains.

### Diagnostics

| Pattern | Usually means |
|---|---|
| High impressions, low engagement | The hook over-promised relative to what the body delivered |
| Low impressions, high engagement per impression | The hook reached the right people and not many of them. Often a distribution problem, not a quality one |
| Comments that respond to the **hook** ("Love this", "So true") | The body did not hold them past the fold |
| Comments that respond to **specific points in the body** | The body worked. This is the signal worth chasing |
| Strong saves, weak comments | Useful reference material, not a conversation starter. Fine, if that was the goal |

The comment-quality read is the most informative and the least used. What people reply *to* tells
you where they stopped reading.

### The two wrong reactions

- **Repeating a winner exactly.** It works once and then stops.
- **Abandoning a topic after one miss.** This kills good ideas before they have had a fair test.

The right move is the same angle with one variable changed — the hook, the format, or the timing —
and only one, or the next result teaches nothing either.

### Always close with the limits

For a single post, what genuinely cannot be concluded:

- Whether the **topic** is right — that needs several posts on it
- Whether **cadence** should change — that needs four or more weeks
- Whether the **format** is wrong — that needs the same angle tried another way
- Whether the **voice** is working — voice is systemic, never a per-post finding

## Diagnosing "it isn't working"

When the user reports nothing happening, diagnose in this order — the common cause is near the top
and the expensive fix is near the bottom:

1. **Cadence.** Is anything being published consistently? Most cases end here.
2. **Audience.** Who is actually seeing it? Check viewer composition before touching the copy.
3. **Positioning.** Is the claim specific enough to be memorable?
4. **Profile conversion.** Are people arriving and leaving? A content problem and a profile problem
   look identical from the outside.
5. **Content quality.** Last, not first — it is the most commonly blamed and least commonly
   responsible.

Only after 1–4 are ruled out is a rewrite the right answer. Routing straight to a rewrite is how
these tools waste a user's time on the wrong problem.

## References

- `references/outcome-tracking.md` — schemas, the review templates, worked diagnosis
