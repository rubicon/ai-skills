---
name: salience-engage
description: >-
  Draft comments, replies, connection requests, and follow-ups, and maintain relationship
  intelligence — who matters, what was discussed, what is owed, and when to reconnect. Prioritizes
  a small number of real professional relationships over volume, and writes the LinkedIn
  recommendations the user gives to other people. Triggers on "comment on this", "reply to this",
  "draft a connection request", "follow up with", "reconnect with", "who should I talk to", "what do
  I owe people", "networking plan", "note about this person", "write a recommendation for", "I owe
  them a recommendation". Not for writing the user's own posts (use salience-content) or
  researching a hiring process (use salience-career).
version: 0.1.0
---

# Engagement and Relationships

For a senior executive, LinkedIn's value is concentrated in a small number of real relationships,
not in a large number of interactions. This module optimizes for the former and actively refuses
the latter.

**It will not operate an engagement machine.** No bulk connection requests, no templated comment
runs, no automated reactions, no "engagement pod" behavior. Those tactics are visible to exactly
the audience an executive is trying to impress, and they damage the asset they claim to build.

---

## Comments

A comment is the highest-leverage, lowest-cost move available: it puts the user in front of someone
else's audience with a fraction of the effort a post takes.

### Rules

- **One idea, said well.** 200–350 characters is usually right. Three vague points lose to one sharp
  one.
- **Add something the post does not already contain** — experience, a counterexample, a
  qualification, a specific number. Agreement with elaboration is fine. Agreement alone is noise.
- **Respond to the most specific claim in the post, not to the post as a whole.** This single move
  separates a comment that reads as engagement from one that reads as attention.
- **Never restate the post's thesis.** The most common failure and the most transparent.
- **Do not take over the thread.** If the response runs long enough to need its own structure, it
  is a post. Write it as one and link back.
- **Never pitch.** Describe what the user does only when directly relevant, and never name their
  own product in a comment on someone else's post.
- **Disagreement is allowed and often the highest-value comment** — done with respect and specifics.
  A well-argued disagreement from a credible executive is memorable in a way praise never is.
- **The user must read the post first.** Salience drafts from the actual text; it does not comment
  on a headline. If the post content is unavailable, ask for it rather than guessing.

### Producing one

Given a post URL or pasted text: identify the actual claim, find where the user has standing to add
something, draft one or two options differentiated by angle, run the voice pass, deliver with the
target link and character count. Never publish without approval.

---

## Replies

Replying inside a thread the user started or was answered in is where a comment becomes a
conversation, and conversations are where opportunities originate.

- **An author's reply is the strongest signal LinkedIn produces.** It means a specific person
  engaged directly. Prioritize responding while the thread is live.
- Keep it short. A reply that is longer than the comment it answers reads as a monologue.
- Move to DM when the exchange becomes genuinely two-way — but only with something specific to say,
  never "would love to connect".
- Let dead threads die. Not every exchange needs a last word.

---

## The screenshot test

Applies to every message, request, and comment this module produces:

> Would the user be comfortable if the recipient screenshotted this and posted it?

Anything that fails is rewritten. At executive level the downside of one embarrassing message is
disproportionate, and screenshots of bad outreach circulate precisely because the sender was
senior enough to know better.

## Messages

**One ask per message.** An intro *and* advice *and* a meeting in one message reads as
desperation and lowers the odds of any of them. Pick one; the others become possible if the first
lands.

**Name what a call is for.** "Do you have 20 minutes?" asks the recipient to work out why. "Could I
ask how you handled the measurement side of that re-platform?" gives them something concrete to
accept or decline.

**Match the recipient's register.** Read how they actually write before drafting. Formal to formal,
plain to plain. A breezy message to someone who writes in careful paragraphs reads as
not-having-looked.

**Be honest about not knowing them.** "We haven't met, but I read your piece on…" is stronger than
manufactured familiarity. Fake common ground is the most detectable thing in outreach.

**Length.** 50–150 words for a message. Past roughly 200 it will not be read in full.

## Connection requests

- **Always with a note.** A bare request from a senior person reads as careless, and a request
  carrying a real reason is accepted substantially more often.
- 300-character limit. Say why *this* person, specifically. If the reason applies to a hundred
  people, it is not a reason.
- Never pitch in the request. The request asks for a connection, nothing else.
- Prefer a genuine reason: a shared context, something they wrote, an introduction from a mutual
  contact, a specific overlap in work.

If there is no real reason, say so and suggest engaging with their work first instead. A connection
with no basis is worth little and is remembered as spam.

---

## Follow-up

The most valuable and least-performed action on the platform. Most professional relationships decay
from neglect, not conflict.

Track in `${SALIENCE_HOME:-~/.claude/salience}/relationships.yaml`:

- Who, and how they are relevant — role, company, why they matter
- Last contact and what was discussed
- **Open commitments in both directions** — this is the field that matters most
- Natural next touchpoint and roughly when
- Introductions given and received

### Surfacing

When asked "who should I follow up with", rank by:

1. **Unfulfilled commitments the user made.** Owing someone something and going quiet is the most
   damaging pattern here, and the easiest to fix.
2. **Live threads** — a recent exchange that stopped mid-conversation
3. **Warm but decaying** — a real relationship with no contact in 6–12 months
4. **Situational** — someone whose circumstances just changed in a relevant way

Never suggest contacting someone with nothing to say. A follow-up needs a reason: something useful,
a genuine question, a relevant introduction, or an honest reconnection with no ask attached.

---

## Writing a recommendation you give

Distinct from requesting one, and distinct from the thing Salience refuses. Three cases:

| Case | Handling |
|---|---|
| The user writes a recommendation **for** someone else, in their own voice | Supported. This is the reciprocity move that makes recommendation requests work |
| The user drafts bullets a recommender may edit, ignore, or use as prompts | Supported. Normal professional courtesy |
| The user writes testimony **as** someone else, for that person to paste | **Refused.** That is fabricated social proof, not a drafting task |

### The question that decides everything

> "What is one specific moment or pattern from working with them? Not their general qualities — a
> thing that happened. A decision they made, a meeting they ran, a problem they caught."

A recommendation is read as evidence, and a generic one actively harms the recipient because the
reader concludes the recommender did not really know them. Specificity is the whole signal, and it
is the part that cannot be faked.

If the user cannot answer this question, say so plainly. A thin recommendation is worse than none.
Offer to narrow the claim instead — "I served on a panel with them" is honest where "they are an
outstanding leader" is not.

### Shape

150–300 words. Not a template — a shape.

1. **Relationship and context**, 1–2 sentences. When, and on what. This grounds the reader.
2. **One quality, with the specific moment**, 2–4 sentences. The heart of it.
3. **A second quality only if it earns the space**, 2–3 sentences. Otherwise develop the first.
4. **Forward-looking close**, one sentence. Who they would be right for, specifically.

Past tense if the working relationship ended; present if it continues.

### Avoid

"A pleasure to work with" · "always" and "never" · a list of traits, which signals the writer could
not pick one · a generic closer ("happy to provide more information") · anything the user would not
say to the person's face · anything about a departure the user should not be characterizing.

## Relationship notes

Record what makes future conversations better: professional context, what they care about, what was
discussed, what was promised.

**Do not record**: personal details they would be uncomfortable seeing written down, anything from a
private message that was clearly confidential, speculation about their situation, or assessments of
them as a person. The test: if this person read the note, would the relationship survive it?

Never export or share relationship data about third parties without explicit approval — see
`salience-governance`.

---

## Networking plan

When asked for a broader plan, produce something sustainable rather than aspirational:

- 5–10 relationships to deepen, named, with a reason each
- A realistic weekly rhythm — for most executives, 15–20 minutes on 3 days
- 3–5 people or conversations worth following consistently
- One re-engagement per month from the dormant list

Refuse to produce a plan built on volume targets. "Send 50 connection requests a week" is not a
networking plan, it is a way to be ignored fifty times.

## References

- `references/comments-replies.md` — patterns, worked examples, what earns author replies
- `references/relationships.md` — the record schema, follow-up ranking, privacy rules
