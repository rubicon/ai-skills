---
name: salience-positioning
description: >-
  Establish what the user stands for in the market and why a specific audience should choose them —
  executive narrative, differentiation, value propositions per audience, and the proof points that
  make each defensible. Covers CMO/VP-level positioning, fractional and advisory positioning, and
  the career-narrative work behind a move or a pivot. Triggers on "what do I stand for", "how do I
  differentiate", "my value proposition", "position me for CMO roles", "how do I explain the move",
  "what's my story", "make me sound more senior". Not for writing the profile copy that expresses
  it (use salience-profile) or capturing writing style (use salience-voice).
version: 0.1.0
---

# Positioning

Positioning decides what every other module writes. A profile rewritten without it produces
competent copy pointed nowhere, which is why "rewrite my headline" so often has to start here.

Positioning is a **choice about who to lose.** An executive positioned for everything is positioned
for nothing, and at senior level the cost of vagueness is not fewer opportunities — it is worse
ones.

## Inputs

From `salience-identity`: career record, proof points, target roles, target audiences, and the
explicit "will not claim" boundaries. Ask only for what is genuinely missing.

## The five questions

All five, answered concretely. Do not proceed on abstractions — a vague answer here produces vague
output everywhere downstream, and the user will blame the copy.

### 1. Who, specifically?
Not "B2B companies". Company stage, size, model, and the situation they are in.
*Good:* "B2B SaaS, $20M–$200M ARR, PE-backed or post-Series-C, where growth has flattened and the
board is asking why spend stopped converting."

### 2. What problem?
The problem as the buyer experiences it, in their words — not the practice area name.
*Good:* "We're spending more and getting less, and nobody can tell us whether it's the market, the
product, or the marketing."

### 3. How do you solve it?
The method, and specifically what makes it repeatable rather than personal talent.
*Good:* "Fix the measurement layer first, because most stalled funnels are a measurement problem
presenting as a creative problem. Then rebuild demand against what the data actually says."

### 4. Why is that better than the alternatives?
Name the real alternatives: the agency, the internal hire, the other fractional, doing nothing.
Doing nothing is usually the most common competitor and the one most analyses skip.

### 5. So what?
The consequence for the buyer if this works. Business outcome, not activity.

## Differentiation test

Run every draft position through this. Failing any one sends it back.

| Test | Fails when |
|---|---|
| **Substitution** | Swapping in a peer's name leaves it equally true. Then it describes a category, not a person |
| **Negation** | The opposite is absurd ("I deliver *poor* results"). Then it is not a position, it is table stakes |
| **Evidence** | No verified fact supports it. It may still be right — but it is `proposed`, and the gap is now the priority |
| **Exclusion** | It repels nobody. A position that offends no one attracts no one |
| **Defensibility** | It cannot survive "say more about that" from a skeptical board member |
| **Memorability** | Someone who heard it once cannot repeat it a week later without notes. A position nobody can relay is a position that never travels through a network |

The substitution test is the one that kills the most drafts, and it should.

### Check your own work

Before delivering, answer honestly:

- Is the differentiator something a peer could also claim? If yes, it is a category description.
- Does the audience describe a real person, or a demographic segment?
- **If the user already had positioning, does this genuinely differ — or did I polish their old
  framing and present it as new?** This is the most common failure and the hardest to notice from
  inside.

A useful question when differentiation is thin: *"What have you done that a peer or an agency told
you they don't do?"* The answer is usually the real position.

## Outputs

Written to `${SALIENCE_HOME:-~/.claude/salience}/positioning.yaml` once approved.

1. **Positioning statement** — internal, one paragraph, not copy
2. **One-liner** — ten words or fewer, sayable out loud
3. **Short version** — roughly 30 seconds, for the "what do you do" question
4. **Differentiators** — three at most, each with the proof point behind it and its tier
5. **Audience variants** — the same position expressed for each audience that matters
6. **Proof map** — which fact supports which claim, and where the gaps are

## Audience variants

One position, several expressions. The claim does not change; the emphasis does.

| Audience | Leads with |
|---|---|
| Board / search committee | Scope, judgment, track record at comparable scale |
| Founder / CEO | The problem and the speed of the fix |
| PE operating partner | Repeatability, measurement, time to value |
| Peer executive | Point of view and method |
| Prospective team | What it is like to work for this person |

Changing the *claim* per audience is not variation, it is inconsistency, and it is visible to
anyone who reads two of them.

## The employed-and-exploring case

An executive positioning for their next role while holding a current one has real constraints:
discretion, loyalty, and the fact that current colleagues read the profile. Handle explicitly.

- Position around **capability and point of view**, never availability
- Never imply dissatisfaction with the current employer
- Signal direction through what is discussed, not through declared intent
- Keep availability in the recruiter-only setting, not in public copy

## Career narrative

For a move, a pivot, or a gap, produce a narrative that is **true, brief, and forward-facing.**
Three sentences: what the arc was, what the move is toward, why now. Never defensive, never
over-explained. A long explanation signals a problem the short version did not have.

Where there is a genuine gap — a sabbatical, a layoff, a caretaking period — state it plainly in
one clause and move to what came of it. The evasive version is always more damaging than the fact.

## Anti-patterns

- Positioning on a claim with no proof and no plan to build any
- Positioning that describes the whole function ("full-stack marketing leader") — that is a job
  description, not a position
- Positioning for a role the user has not decided they want, to keep options open
- Adopting a "category of one" claim because it sounds strong. It has the highest ceiling and
  fails hardest under scrutiny; write it only when the proof exists

## References

- `references/frameworks.md` — the five questions expanded, competitive mapping, worked examples
- `references/executive-narrative.md` — moves, pivots, gaps, and the employed-and-exploring case
