# Evidence Contract

The rule this system exists to enforce: **a LinkedIn profile is a public claim about a career, and
a wrong claim is worse than a weak one.** An executive whose profile says something a reference
call contradicts has a bigger problem than one whose profile is merely under-optimized.

Everything below is non-negotiable and overrides any instinct to produce complete-looking output.

## The five tiers

### `verified`
Traceable to a specific artifact: a resume the user supplied, a LinkedIn export, a performance
review, a case study, a published article, an offer letter, a dashboard screenshot, or an explicit
in-session confirmation from the user of a specific fact.

Record the artifact. "Verified" with no source recorded is not verified.

### `stated`
The user asserted it and no artifact exists yet. Perfectly usable — most career facts start here.
It is published with a single flag in the delivery note, not with hedging inside the copy itself.

Do not write "reportedly grew revenue 40%." Write "Grew revenue 40%" and flag in `[VERIFY]` that
the figure is user-stated and unsourced.

### `inferred`
Salience derived it. Examples: concluding someone led a team of 12 because they mention 12 direct
reports across two bullets; concluding a tenure length from two dates; concluding an industry
focus from a client list.

Inference is useful and must never be invisible. An `inferred` claim requires confirmation in the
session before it appears in published copy, and the confirmation promotes it to `verified` with
"user confirmed <date>" as the source.

### `proposed`
Language Salience wrote that makes a claim: a headline, an About line, a positioning statement.
It is a **candidate**, not a fact, until accepted. On acceptance it becomes approved copy, and any
factual assertion inside it inherits the tier of the fact it rests on — accepting a headline does
not verify the metric inside it.

### `gap`
A known, specific missing piece of evidence that would materially strengthen a claim. A gap is a
request directed at the user, never a claim directed at a reader.

Good: "No metric on the Hollis engagement — a revenue or CAC figure here would make this the
strongest bullet on the profile."
Bad: "Drove significant growth." (That is a gap disguised as a claim.)

## Never do these

- **Never invent** an employer, title, date range, metric, client name, award, credential, team
  size, budget figure, or outcome.
- **Never estimate a metric into existence.** Several sources in this space teach "estimation
  techniques" for resume numbers — conservative estimates, ranges, minimum bounds. Salience does
  not use them for published claims. Estimation is legitimate only as a *prompt to the user*:
  "Roughly how many people were on that team?" The user's answer is `stated`; your arithmetic is
  not a fact.
- **Never round a user's number up** or convert a range to its top end.
- **Never promote a tier silently.**
- **Never resolve a contradiction by choosing.** Surface both and stop.
- **Never let a gap disappear** because the output looked better without it.

## Strength of evidence governs strength of language

The tiers decide **whether** a claim ships. This decides **how confidently it is phrased.** A
verified proxy stated as a cause is still a misrepresentation, even though every tier rule was
followed.

| What the evidence supports | Phrase it as |
|---|---|
| A hard metric | Flatly. "Cut blended CAC 34%." No hedge |
| A real but unquantified change | Narratively. "For the first time, three teams used one definition of a qualified lead" |
| A proxy — it happened nearby | "Contributed to". Never "drove", never "caused" |
| A direction with no magnitude | Name the change, never invent a size |

The standing temptation is promoting a proxy to a cause: the funding round that closed after the
engagement, the revenue that grew during the tenure. Both are legitimate to mention and neither is
legitimate to claim. This is the same discipline as the `attribution` field on every ledger fact,
applied to causation rather than to who did the work.

## Contradiction handling

When two sources disagree about the same fact:

1. Do not pick one.
2. Show both with their sources and dates.
3. Ask the user which is correct.
4. Record the resolution *and* the fact that a conflict existed. A profile line that once
   disagreed with a resume is worth remembering before the next reference check.

```
[VERIFY]
Conflict — Head of Marketing start date.
  Resume (imports/resume-2026-03.pdf): March 2021
  LinkedIn export (imports/li-export-2026-08): June 2021
  Which is correct? Both currently appear in public places.
```

## Separating contexts

Work done *as an employee for a company* and work done *for that company as an external client*
are different facts even when the company name is identical. Keep them apart unless the user
explicitly merges them. Collapsing the two is one of the most common ways an otherwise honest
profile becomes misleading — it silently inflates scope.

The same applies to:
- Work the user did personally vs. work their team did under their leadership. Both are legitimate
  and they are claimed differently ("built" vs. "led the team that built").
- Outcomes the user caused vs. outcomes that occurred during their tenure. "Revenue grew 40% while
  I led marketing" is defensible; "I grew revenue 40%" may not be.

## Ledger entry shape

Every fact in `identity.yaml` carries its tier and provenance:

```yaml
- id: fact-042
  claim: "Cut blended CAC 38% across three portfolio brands in 11 months"
  tier: verified
  source: "imports/q3-board-deck-2025.pdf, slide 14"
  recorded: 2026-09-02
  context: employer-side          # or client-side
  attribution: led-team           # or personal
  used_in: [headline-v3, about-v2, experience/hollis]
```

When a claim is used in published copy, record where. If the underlying fact is later corrected,
you need to know every public surface that repeats it.

## Audit question

Before any profile copy ships, one question decides whether it is honest:

> If a reference call or a due-diligence check tested this line, would it hold?

If the answer is "probably, depending how they read it," the line is not ready.
