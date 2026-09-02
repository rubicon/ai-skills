---
name: salience-career
description: >-
  Executive job search support — target role definition, job-description alignment and match
  scoring, gap analysis, recruiter and retained-search engagement, company and hiring-manager
  research, interview positioning and story banking, compensation conversations, and opportunity
  evaluation. Triggers on "align my profile to this job", "should I apply", "match score",
  "research this recruiter", "research this company", "prep me for this interview", "reason for
  leaving", "what should I ask for", "evaluate this offer", "am I a fit". Not for consulting or
  fractional business development (use salience-consulting).
version: 0.1.0
---

# Executive Career

Senior search does not work like the funnel most job-search tooling assumes. Three things follow
from that and shape everything here:

1. **Most CMO and VP roles are filled through retained search and referral,** not applications. A
   perfectly optimized profile with no search-firm relationships produces very little. Say this
   plainly rather than optimizing keywords and implying that is the work.
2. **The process is a mutual evaluation.** An executive who behaves like a supplicant is read as
   the wrong level. Evaluation runs in both directions from the first conversation.
3. **Fit and timing decide most outcomes,** not qualification. A strong candidate rejected is
   usually a fit or a timing story, not a failure of preparation. Say so — it is true, and it keeps
   the user calibrated.

---

## Target definition

Before evaluating any specific opportunity, establish the criteria. From `salience-identity`, or by
asking:

- Role and level, and the level below it that would still be acceptable and why
- Company stage, size, ownership (PE, VC, public, founder-led), and industry
- Scope required — team, budget, P&L, reporting line
- Geography and remote constraints, stated honestly
- Compensation floor and target, including equity expectations
- Deal-breakers, explicitly

The deal-breakers list is the one that saves the most time and the one users most often skip.

---

## Role alignment

Given a job description:

### 1. Extract requirements
Separate genuine requirements from aspirational boilerplate. Executive postings routinely list
twelve "requirements" where three are real. Say which is which and why.

### 2. Match against the ledger
Score each requirement: **strong** (verified evidence), **partial** (adjacent experience),
**gap** (none). Cite the specific fact behind every strong match.

### 3. Overall assessment
Weight by what the role actually needs, not by requirement count. Missing one of three real
requirements matters more than missing six of nine boilerplate ones.

```
Match: strong on 6 of 8 real requirements

Strong
  Scaled B2B SaaS marketing $20M→$200M          Hollis, verified
  MarTech consolidation and ownership            14→6 tools, verified
  Distributed team leadership                    22 across 3 units, verified

Partial
  PE-backed operating experience                 board reporting yes, PE sponsor no
  Category creation                              adjacent — repositioned, did not create

Gap
  International expansion (EMEA)                 no evidence in record

Read: the EMEA gap is the only real one, and it is prominent in the posting — likely a genuine
requirement rather than boilerplate. Worth addressing directly rather than hoping it goes unnoticed.
```

### 4. Application strategy
What to emphasize, how to address the gaps honestly, and whether to apply at all. **Recommend
against applying when the fit is poor.** A tool that encourages every application wastes the
user's most limited resource and their credibility with the firms that see repeated misfires.

Alignment tunes the résumé and the conversation. It does **not** rewrite the public profile for one
posting — that is `salience-profile`, and the profile serves every opportunity at once.

**Out of scope, deliberately:** résumé formatting and applicant-tracking-system optimization. Those
are document-layout problems — fonts, parseable headers, avoiding tables and columns — and they
matter mainly for volume applications through portals. Executive roles come through search firms and
referral, where a human opens the file. Salience supplies the content, the claims, and the evidence;
if the user wants ATS formatting, say plainly that it is not what this does and that it is rarely
the binding constraint at this level.

---

## Recruiters and retained search

Different relationship from a corporate recruiter, and treated differently:

- A retained search partner works for the client, not the candidate. They are still worth a real
  long-term relationship — they place repeatedly in the same category.
- Be useful when not a fit: recommend someone else who is. This is the single highest-return
  behavior available with search firms, and it compounds.
- Respond promptly even to declines. Silence is remembered.
- Build the relationship before it is needed. Reaching out only while looking is transparent.

For outreach drafting, produce something specific to the firm's practice area and the user's
category. Never a template.

---

## Interview positioning

### Story bank
Build from the fact ledger, one per competency the target role requires. Situation, action,
outcome — with the real numbers, and the attribution honest about personal versus team.

Have a short version (60–90 seconds) and a long version for each. Executives more often fail by
over-answering than under-answering.

### The hard questions

- **Why are you leaving / why did you leave.** Brief, forward-facing, never critical of the last
  employer. Criticism of a former employer is read as a preview.
- **Gaps.** State plainly in a clause, then what came of it. The evasion is always worse than the fact.
- **Compensation expectations.** See below.
- **Level or age concerns, when they surface obliquely.** Answer the underlying question —
  currency, energy, adaptability — with evidence rather than reassurance.
- **A failure.** A real one, with what changed afterward. A disguised humblebrag fails this question
  and is obvious.

### Questions to ask
An executive who asks nothing sharp is not evaluating. Prepare questions about the real mandate,
what has been tried, who owns what, how success is measured at 12 months, and why the seat is open.

---

## Compensation

- **Never state a number first** when it can be avoided. Redirect to the role's band once.
- **When pressed, give a researched range** with the floor at the target, not below it.
- **Negotiate total compensation** — base, bonus, equity, severance, and the terms that matter at
  executive level: change-of-control provisions, vesting acceleration, notice periods.
- **Anchor on the value of the role,** not on prior compensation. Prior compensation is not a
  legitimate anchor and in several jurisdictions may not be asked.

Salience prepares the position, the range, and the language. It does not decide what the user
should accept, and it does not provide legal advice on contract terms — recommend counsel for
equity and severance language.

---

## Opportunity evaluation

Score against the stated criteria, not against enthusiasm. Cover mandate realism, actual authority
versus title, the CEO or board relationship, financial runway, what happened to the predecessor,
and whether the stated problem matches the resourcing.

State the risks plainly. An executive taking a role with an impossible mandate is the most expensive
outcome this module exists to prevent.

## References

- `references/role-alignment.md` — extraction, scoring, worked example
- `references/interview.md` — story banking, the hard questions, questions to ask
- `references/compensation.md` — research, ranges, scripts, executive terms
