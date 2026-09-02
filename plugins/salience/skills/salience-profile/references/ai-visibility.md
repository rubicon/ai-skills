# AI-Search Visibility

An increasing share of "who should I talk to about X" now begins in an AI assistant rather than a
search engine. Being citable by those systems is a distinct problem from ranking in LinkedIn search,
and almost no profile is built for it.

**Be honest about the mechanism.** These systems synthesize from what they can retrieve across the
open web. A LinkedIn profile is one input among many and often not the strongest, because much of
LinkedIn is gated. The moves below improve the odds; none of them guarantee a citation, and anyone
promising otherwise is selling something. Present this as improving retrievability, not as ranking.

## Test it before auditing it

The checks below describe what makes a person retrievable. They are a proxy. **The actual finding
comes from asking the assistants and reading what comes back** — run this first, because it
frequently overturns the checklist result.

Run each on at least two of ChatGPT, Perplexity, and Claude. Where the tool cannot reach them, give
the user the exact queries to run and paste back.

**Identity**
- "Who is [full name]?"
- "What is [full name] known for?"

**Category** — the queries a buyer or board member actually types
- "Who are the best fractional CMOs for B2B SaaS?"
- "Who should I talk to about [the user's specialty]?"
- "[A peer or known name] alternatives"

**Expertise**
- "Who are the experts on [the user's core topic]?"
- "What is the best approach to [the problem the user solves]?"

For each, record: does it know them · is the description **accurate** · what does it cite · do
competitors appear instead.

### Misattribution is worse than absence

The check almost everyone skips. Not "does it know you" but **does it get you wrong** — wrong
employer, wrong industry, wrong seniority, conflated with someone who shares the name, credited with
work that is not theirs.

An assistant confidently describing the wrong person under the user's name does more damage than
silence, and the user will never discover it unless someone asks. Common names carry a much higher
risk; check them specifically and flag any misattribution as the top finding, ahead of every
optimization below.

## Eight checks

Score each: **Pass** / **Needs work** / **Missing**.

### 1. Entity clarity
Is it unambiguous who this person is — name, role, and domain — within the first 50 words?
These systems build entity records. "Marketing professional" resolves to nothing. "Chief Marketing
Officer for B2B SaaS" resolves to a specific entity that can be retrieved for a specific question.
→ **Pass** if name, a specific role, and a specific domain all appear in the headline or opening
About lines.

### 2. Niche specificity
Is there a claim narrow enough to be the answer to a real question?
"I help companies grow" is never the answer to anything. "I rebuild demand generation for B2B SaaS
companies whose CAC has stopped responding to spend" is a direct answer to a question someone
actually asks.
→ **Pass** if at least one claim combines audience, method, and outcome.

### 3. External corroboration
Does the person appear anywhere outside LinkedIn — publications, podcasts, conference listings,
company pages, press, a personal site?
Entity confidence is built from agreement across independent sources. A profile with no external
footprint is a single unverified assertion.
→ **Pass** if at least one external, indexable mention exists. When absent, this is almost always
the highest-leverage item on the entire list, and it is off-LinkedIn work.

### 4. Terminology consistency
Does the profile use the same vocabulary as the user's other public material?
If the profile says "demand generation" and every article says "growth marketing", the systems may
treat those as weakly related entities and neither accumulates authority.
→ **Pass** when the primary terms match across profile, posts, site, and bio.

### 5. Answer-shaped language
Does the About section contain at least one sentence that reads like the answer to a question?
"Morgan Reyes is a marketing executive who rebuilds demand engines for B2B SaaS companies" is
retrievable as an answer. "I am a results-driven leader with 20 years of experience" is not the
answer to any question a person would ask.
→ **Pass** if at least one such sentence exists. Note the tension with the first-person rule: keep
About in first person, and place the third-person, answer-shaped phrasing on the personal site or
bio, where it is natural.

### 6. Recency
Is there evidence of current activity — recent posts, current role, accurate dates?
Stale entities are deprioritized everywhere.
→ **Pass** if the current role is accurate and there is visible activity within about 90 days.

### 7. Name and URL resolution
Is the custom URL claimed and does it match the name?
Clean, name-matched URLs resolve more reliably to the right entity, particularly for common names.
→ **Pass** if `linkedin.com/in/firstnamelastname` (or a close variant) is set.

### 8. Cross-platform consistency
Do name, role, and positioning agree across LinkedIn, personal site, other social profiles, and
speaker or author bios?
Disagreement across platforms splits one person into several low-confidence entities.
→ **Pass** if positioning is consistent across at least two platforms beyond LinkedIn.

## Output

```
AI-search visibility: 4/8

Passing    Entity clarity · Recency · URL resolution · Answer-shaped language
Needs work Terminology consistency — profile says "demand generation", your writing says "growth marketing"
Missing    External corroboration · Niche specificity · Cross-platform consistency

Highest leverage, in order:
1. One indexable external mention — a guest post, a podcast, or a conference bio. This is the
   binding constraint; the profile changes below matter less until it exists.
2. Pick one term and use it everywhere. Two names for one practice halves the authority of both.
3. Align the personal-site bio with the profile positioning — currently they describe two people.
```

Note the ordering discipline: the off-LinkedIn item leads when it is the binding constraint, even
though this is a LinkedIn tool. Recommending profile tweaks when the actual limitation is having no
external footprint would be optimizing the wrong thing.

## Re-testing

This only means anything as a trend. Set actual dates and re-run the same query set — a different
query set produces a different answer and proves nothing.

| Query set | Baseline | +30 days | +90 days |
|---|---|---|---|
| Identity — known and accurate? | | | |
| Category — appears? | | | |
| Expertise — cited? | | | |
| Misattribution present? | | | |

Ninety days is the useful interval. These systems change slowly and on their own schedule, and a
two-week re-test measures noise.

## Never recommend

Fabricated reviews or citations · fake directory listings · misleading structured data · keyword
stuffing anywhere · content written solely to be scraped. These are the AI-search equivalent of link
farms, they are detectable, and they put the user's name on tactics that are embarrassing to explain.
