# Fact Ledger Operations

Worked mechanics. Tier definitions live in `../../salience/references/evidence-contract.md`.

## Add

```yaml
- id: fact-042
  claim: "Cut blended CAC 38% across three portfolio brands in 11 months"
  tier: verified
  source: "imports/q3-board-deck-2025.pdf, slide 14"
  recorded: 2026-09-02
  period: "2024-08..2025-07"
  context: employer-side
  attribution: led-team
  used_in: []
```

Before writing:

1. **Assign a tier.** No untiered facts.
2. **Record the source.** `verified` with no source is a bug, not a shortcut.
3. **Search for a contradicting fact.** If one exists, do not append — go to *Conflict*.
4. **Set `context`** — `employer-side` or `client-side`. Work done as an employee and work done for
   that same company as an external client are different facts even with the same company name.
5. **Set `attribution`** — `personal` or `led-team`. At executive level, `led-team` is the accurate
   answer more often than users assume, and it is not a weaker claim.
6. **Preserve the metric's context** — unit, period, and scope. "38%" alone is not a fact.

## Conflict

Never resolve by choosing. Never append a second version silently.

```
[VERIFY]
Conflict — CAC improvement.

  fact-042  "38% over 11 months"     board deck, Q3 2025
  new       "nearly 40%"             pasted profile text, today

The profile is rounding a sourced figure upward. Recommend the profile match the deck.
Which is correct?
```

On resolution, record both the outcome and that a conflict occurred. A number that has already
appeared in two different forms publicly is worth remembering before a diligence conversation.

## Correct

The new value wins **when it is at least as well sourced as the one it replaces.** Check that first,
because the common case is the opposite.

| The old value is | The new value is | Do |
|---|---|---|
| `stated` | `stated` | Correct. New value wins, history retained |
| `stated` | `verified` | Correct, and promote |
| `verified` | `verified`, newer artifact | Correct. Note both artifacts in history |
| **`verified` with a source** | **`stated`, no artifact** | **Do not correct. This is a conflict** |

That last row is the one that matters, and it is not rare — a user recalling a different number than
the document says is a genuine disagreement between memory and record, not a typo being fixed.

Hold the new value at `stated`, **freeze the published copy at the sourced value**, and ask for the
artifact. Do not silently downgrade a sourced claim to an unsourced one, and do not update live
surfaces until one side wins. Changing a public number twice in three weeks costs more than the
delay does.

The old is retained in every case.

```yaml
- id: fact-042
  claim: "Cut blended CAC 34% across three portfolio brands in 11 months"
  tier: verified
  source: "imports/fy25-final-close.xlsx"
  recorded: 2026-09-02
  superseded_by: null
  history:
    - claim: "Cut blended CAC 38% ..."
      source: "imports/q3-board-deck-2025.pdf, slide 14"
      superseded: 2026-09-02
      reason: "Q3 deck was a projection; final close came in at 34%"
```

History is never deleted. A claim that changed is exactly the thing worth remembering.

## Propagate

A corrected fact used in published copy is only half fixed.

```
[VERIFY]
fact-042 corrected 38% → 34%. It currently appears in three published places:

  Headline (live)          "38% lower CAC"
  About, paragraph 3       "down 38% in 11 months"
  Post, 2026-07-14         "cut CAC 38%"

The first two are editable now. The post is public and dated — leaving it is defensible
since it reflected the figure you had at the time.

[NEXT]
Update the headline and About to 34%?
```

This is what `used_in` exists for. A ledger that cannot answer "where else does this appear" cannot
protect the user from a stale public claim.

## Promote

`inferred` → `verified` requires confirmation, and the confirmation becomes the source.

```yaml
tier: verified
source: "user confirmed 2026-09-02 — 'yes, 22 across all three units'"
```

Never promote silently, and never promote because a claim has been repeated often enough to feel
established.

## Gaps

Gaps are entries, not absences — otherwise they are forgotten between sessions.

```yaml
- id: gap-007
  wants: "A metric for the MarTech consolidation"
  why: "The consolidation is the strongest differentiator and currently has no number"
  blocks: [headline-v3, about-proof-line, case-study-hollis]
  asked: 2026-09-02
```

Surface the highest-leverage gap in `[VERIFY]`. Do not surface all of them every session — a list
of fourteen gaps gets ignored, which is how gaps become permanent.

## Closing a metric gap

The right way to close a gap is to **ask a question the user can answer from memory**, not to
compute an estimate. These questions reliably surface numbers people did not think they had:

**Scale** — How many people reported to you, directly and indirectly? What was the budget you
controlled? How many customers, accounts, markets, or business units?

**Change** — What was it like when you arrived? What was it like when you left? What would have
happened if nobody had done this?

**Comparison** — How did that compare to the year before? To the rest of the company? To what was
forecast?

**Derivation** — Is there a document that would have this? A board deck, a QBR, a performance
review, a final-close file, an offer letter.

Whatever the user answers is `stated` and usable. Whatever a *document* shows is `verified`.

**What is never done:** turning "I think it was about 100 hours" into "75+ hours saved" and
publishing it. Conservative estimation, range estimation, minimum bounds, and back-calculation from
frequency are all techniques for manufacturing a number that no artifact supports. They are common
in résumé advice and they fail the only test that matters — whether the person can defend the
figure when someone asks where it came from.

Two further limits, both from the same principle:

- **At most two or three numbers in a bullet.** Past that, none of them land and the line reads as
  padded.
- **Every number must be explicable in an interview.** If the user cannot say where a figure came
  from in one sentence, it does not ship.

## Never

- Estimate a metric into existence. Estimation is a *question for the user*, never a fact
- Round a user's number upward, or convert a range to its top end
- Merge employer-side and client-side work
- Upgrade `led-team` to `personal`
- Delete history on correction
- Let a gap vanish because the output read better without it
