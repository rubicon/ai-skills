# Scorecard

Per-component criteria and the weighting that makes this an *executive* audit rather than a generic
one.

## Executive weighting

Generic profile advice treats the nine components as roughly equal and orders them the way LinkedIn
renders them. That ordering is wrong for a senior audience, because the decision path is different:
a search partner or board member does not read top to bottom. They scan the headline, decide whether
to keep going, and then look for proof.

Weight each component's score by the multiplier for the stated goal when computing the total.

| Component | Executive search | Consulting / advisory | Authority |
|---|---|---|---|
| Headline | ×3 | ×3 | ×2 |
| About | ×3 | ×3 | ×3 |
| Experience | ×3 | ×2 | ×1 |
| Featured | ×1 | ×3 | ×3 |
| Skills | ×2 | ×1 | ×1 |
| Recommendations | ×2 | ×2 | ×1 |
| Photo | ×1 | ×1 | ×1 |
| Banner | ×1 | ×2 | ×2 |
| Custom URL | ×1 | ×1 | ×1 |

**Why these differ from the usual advice.**

- **Experience carries triple weight in a search** and single weight for authority. A search partner
  validates scope — team size, budget, P&L, reporting line. A newsletter reader never opens the
  Experience section.
- **Featured carries triple weight for consulting** and single weight in a search. It is where a
  buyer converts. Roughly four in five profiles leave it empty, which makes filling it well one of
  the few remaining free advantages on the platform.
- **Skills carry double weight in a search only.** Skills are a search-index surface, not a
  persuasion surface. Nobody has ever hired a CMO because of an endorsement count.
- **Banner doubles outside of search.** For a consultant it is unused advertising space directly
  above the fold.

Report the raw total and the weighted total. When they diverge sharply, that divergence *is* the
finding: "Your profile scores 34/90 raw but 71/150 weighted against consulting — the pieces that are
working are the ones consulting buyers never see."

## Per-component criteria

### 1. Photo
- 9–10: current, professional, warm, face fills the frame, background neutral, shot within 2 years
- 5–6: acceptable but dated, poorly lit, or too far from camera
- 1–3: cropped group photo, sunglasses, vacation shot, heavily filtered, obvious stock image, or absent

### 2. Banner
- 9–10: value proposition and CTA in the right two-thirds, high contrast, legible at phone size, reinforces the headline claim
- 5–6: branded and tidy but says nothing
- 1–3: LinkedIn default, stock handshake, stock skyline, or text hidden behind the profile photo

### 3. Headline
- 9–10: uses most of 220 characters, leads with value, names the audience, carries a metric or a claim a peer cannot copy, includes the searchable role noun
- 5–6: title and company only; accurate and forgettable
- 1–3: "Open to Work", a bare job title, an emoji chain, or a pipe-separated list of every title ever held

### 4. About
- 9–10: hook lands in the first 265 characters, first person, concrete numbers, clear CTA, reads like a person
- 5–6: competent summary in résumé voice with a dead "Let's connect!" ending
- 1–3: third person, wall of text, buzzword-led, or empty

### 5. Featured
- 9–10: three items matched to the goal with custom benefit-titled thumbnails
- 5–6: populated but generic, or stale beyond a year
- 1–3: empty, or default content pulled from someone else's post

### 6. Experience
- 9–10: every bullet is action verb plus specific metric, scope explicit, media attached
- 5–6: duties described accurately with no outcomes
- 1–3: "Responsible for..." throughout, or roles listed with no description

### 7. Skills
- 9–10: 15–25 genuine, relevant skills; top 3 pinned and deliberate; mirrors target-role language; pinned three endorsed
- 5–6: a dozen generic skills, unpinned — or 50 slots padded with weak ones, which scores the same
- 1–3: fewer than 5, stale, or irrelevant to the stated goal

### 8. Custom URL
- Binary. Pass on `linkedin.com/in/firstnamelastname`, fail on the hash tail. Score 10 or 3; there is
  no middle and no reason not to fix it in under a minute.

### 9. Recommendations
- 9–10: 3+ recent, specific, from varied contexts
- 5–6: present but generic ("a pleasure to work with"), or all from one context
- 1–3: none, or all more than five years old

## Reporting shape

```
| Component | Score | Weighted | Diagnosis |
|---|---|---|---|
| Headline | 4/10 | 12/30 | Names the title, not the value — no reason to keep reading |
| About | 3/10 | 9/30 | Opens in third person; the strongest metric appears in paragraph four |
...

Raw 41/90 · Weighted for executive search 78/180

Priority order
1. Headline — every downstream surface inherits it; fixing it lifts search and About together
2. About hook — your best proof point is below the fold where nobody reads it
3. Experience metrics — three roles describe duties; scope is invisible to a search partner
```

Every row also carries a severity — `critical`, `important`, or `polish`. Severity, not the
number, is what drives the priority order: a `critical` Featured gap on a consulting profile
outranks an `important` headline weakness even when the headline scores lower.

Deliver this **after** the rewrites, not before. The user wants the new headline first.

## Two failure modes, not one

Softening scores to be encouraging produces a softened rewrite and wastes the user's time. The
opposite failure is just as real and less discussed: **manufacturing findings to justify the
audit.** If a profile is genuinely strong, the correct output is "this is in good shape — here are
two polishes if you want them." An audit that always returns five critical problems is not
auditing, and the user learns to discount it.

Never promise an outcome from a fix. Describe what a change does; do not forecast what it will
produce.
