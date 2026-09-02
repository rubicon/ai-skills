---
name: salience-profile
description: >-
  Audit and rewrite a LinkedIn profile end to end for an executive audience — photo, banner,
  headline, About, Featured, Experience, Skills, custom URL, recommendations — plus recruiter and
  executive-search visibility, AI-search (ChatGPT/Perplexity/Claude) visibility, and resume-to-profile
  consistency. Scores every component honestly, ranks fixes by leverage, and rewrites each failing
  section against verified facts. Triggers on "audit my profile", "review my LinkedIn", "rewrite my
  headline", "fix my About", "my experience section", "profile score", "am I showing up for
  recruiters", "do I show up in AI search", "profile before and after". Not for deciding market
  position (use salience-positioning) or matching one job posting (use salience-career).
version: 0.1.0
---

# Profile Intelligence

A LinkedIn profile has one job for an executive: when a board member, search partner, founder, or
operating partner has a need, this person comes to mind and survives the check that follows. Most
executive profiles fail at the first half (invisible) or the second (unsubstantiated). This module
fixes both, and refuses to fix the first by breaking the second.

**The standard every rewrite must clear:** if a reference call or a due-diligence check tested this
line, would it hold?

---

## Modes

Detect from context; ask only if genuinely unclear.

| Mode | Delivers | Use when |
|---|---|---|
| `quick` | Headline rewrite plus the three highest-leverage fixes | "I have a call tomorrow", "board meeting Thursday" |
| `standard` | Full nine-component audit and every failing rewrite | Default. Profile overhaul |
| `deep` | Standard, plus recruiter-search visibility, AI-search visibility, resume consistency, and a 30-day sequence | Active search, launching content, or going to market as a consultant |
| `audit-only` | Diagnosis and priority order, no rewrites | The user wants to know what is wrong and fix it themselves, or wants to react before committing to a direction |

Default `standard`. Escalate to `deep` without asking when the user says they are in an active
executive search or launching a consulting practice — those need the visibility layers.

---

## Inputs

Required:
- Current profile content — pasted section text, a LinkedIn data export, or screenshots
- **Goal:** `executive search` / `consulting and advisory` / `authority` / `mixed` — Featured
  selection, CTA, and keyword strategy all fork on this
- **Audience:** who specifically must find and believe this profile

Pull everything else from `salience-identity`. Do not re-ask for career facts already in the
record — re-interrogating the user for facts the system already holds is the most common way these
tools become tiresome.

If no identity record exists, stop and run `salience-identity` onboarding. Auditing a profile
without a fact ledger means rewriting claims you cannot check, which is how invention happens.

---

## Workflow

### 1. Evidence gate (before any scoring)

Cross-check every factual claim in the current profile against the fact ledger. This runs **first**
because it can change the entire audit: a profile full of strong-sounding unverifiable claims is a
different problem from a weak-sounding accurate one, and they need opposite fixes.

Produce three lists:

- **Unsupported claims** — in the live profile, no ledger backing. These are the highest-priority
  finding in the entire audit, ahead of any optimization.
- **Contradictions** — profile disagrees with resume, bio, or ledger.
- **Buried proof** — verified facts in the ledger that appear nowhere on the profile. Usually the
  single biggest available upgrade, and free.

### 2. Language scan

Run before scoring so scores reflect what the copy actually does. Flag every instance with a
specific replacement, not a note. See `references/language-scan.md` for the full list.

Auto-flag: results-driven · results-oriented · passionate about · dynamic professional · synergy ·
visionary · thought leader (self-applied) · seasoned professional · proven track record ·
detail-oriented · team player · strategic thinker (unsubstantiated) · go-getter · robust ·
comprehensive · game-changing · cutting-edge · in today's landscape · excited to announce ·
leverage (as verb) · delve · unlock · harness · foster · streamline · fundamentally

Executive-specific additions: transformational leader · change agent · builder of high-performing
teams · data-driven decision maker — all four are claims every VP-and-above profile makes, so none
of them differentiate. Each must be replaced with the specific thing that happened.

### 3. Score the nine components

Score 1–10 with one sentence of diagnosis each. See `references/scorecard.md` for per-component
criteria and the executive weighting.

| Band | Meaning |
|---|---|
| 1–3 | Working against the goal — confusing, generic, or missing |
| 4–6 | Neutral. Present, forgettable, will not convert |
| 7–8 | Strong. Clear and functional, needs sharpening |
| 9–10 | Exceptional. Specific, compelling, built for the stated audience |

Pair every score with a **severity**, which is what actually drives the work:

| Severity | Meaning |
|---|---|
| `critical` | Actively costing reach, credibility, or opportunity right now |
| `important` | A real improvement, not urgent |
| `polish` | Worth doing when convenient |

**Score honestly, in both directions.** Executive profiles that feel most polished often score
lowest, because polish is what buzzwords buy — but the opposite failure matters just as much:
**never manufacture findings to justify the exercise.** If a profile is genuinely in good shape,
say so and offer two polishes. An audit that always finds five critical problems is not auditing.

Two hard limits on how scores are used:

- **The composite number is not the deliverable.** It exists to rank fixes and to make change
  measurable across audits. Lead with rewrites and severity, never with a grade.
- **Never promise an outcome from a fix.** "Fix these and you will get more recruiter messages" is
  not a claim this system can support. Describe what the change does, not what it will produce.

### 4. Rank fixes by leverage

Not by section order and not by how broken something is — by **how much the fix moves the stated
goal.** An empty Featured section on a consulting profile outranks a merely adequate headline,
because Featured is where a buyer decides to book. Give one sentence of reasoning per rank.

### 5. Rewrite

Per component, using verified facts only. Every rewrite shows `BEFORE` and `AFTER` — the diff is
what makes the change reviewable and teaches the pattern for the next edit.

Where a number would transform a line and none exists, write the strongest true version and record
the gap. Never fill the hole with an estimate.

### 6. Visibility layers (`deep`)

- **Recruiter and executive search** — `references/search-visibility.md`
- **AI search** — `references/ai-visibility.md`

### 7. Deliver

Standard output contract. Result first: the rewrites. `[VERIFY]`: unsupported claims,
contradictions, gaps. `[NEXT]`: one action.

Full scorecard tables ship only in `standard` and `deep`, and even then after the rewrites — the
user wants the new headline, not the grading.

---

## The nine components

| # | Component | Passes when |
|---|---|---|
| 1 | Photo | ≥400×400, face fills ~60% of frame, current within 2–3 years, natural light, direct eye contact |
| 1b | Name fields | Custom pronunciation recorded where the name is often mispronounced; former name shown where it carries professional continuity |
| 2 | Banner | 1584×396, content held to the right two-thirds, high contrast, carries a value proposition and one CTA, legible on mobile |
| 3 | Headline | Uses the full 220 characters, leads with value not title, carries the searchable role nouns, makes a claim a peer cannot copy verbatim |
| 4 | About | 200–300 words, first person, hook lands inside the first 265 characters, follows the seven-step structure, ends on one specific CTA |
| 5 | Featured | Three strong items matched to the goal, custom 1200×627 thumbnails with benefit-driven titles |
| 6 | Experience | Every bullet is action verb plus specific metric, 5+ skills per role, media attached where it exists |
| 7 | Skills | 15–25 genuine and relevant (not the 50-slot cap filled), top 3 pinned deliberately and matching the headline claim, mirrors target-role language, pinned three endorsed |
| 8 | Custom URL | `linkedin.com/in/firstnamelastname`, not the default hash tail |
| 9 | Recommendations | At least 3 recent and specific, from varied contexts — peer, senior, client, direct report |

Executive weighting, and why the generic ordering is wrong for this audience, is in
`references/scorecard.md`.

---

## Posture

The audit is honest, not brutal. Most executives have spent years on this profile and are attached
to it, and an audit that reads as an attack gets dismissed rather than acted on.

- **State facts, not verdicts.** "The role noun does not appear in the first 50 characters" is a
  fact that implies its own fix. "Your headline is bad" is a verdict that implies nothing.
- **Note what works, briefly.** One line, then move on. An audit that finds nothing good is not
  credible, and it teaches the user to discount the parts that matter.
- **Be specific enough to act on.** "Generic" is not feedback. "'Passionate about innovation' does
  not distinguish you from the several hundred other marketing executives in this metro" is.

## Hard rules

- **First person.** "I help..." never "Jane is a passionate...". Third person on a personal profile
  reads as a press release and suppresses replies.
- **No claim without a fact behind it.** If the ledger does not support it, it does not ship.
- **Specificity over completeness.** A profile that says one precise thing beats one that says nine
  vague things. Cutting is a legitimate rewrite.
- **Every recommendation must be actionable on this profile.** "Strengthen your headline" is not
  advice. "Replace 'Marketing Executive' with 'Marketing executive for B2B SaaS | 34% lower CAC at
  Hollis'" is advice.
- **Never write the Open to Work banner into the headline.** It belongs in the setting, where it is
  visible to recruiters without broadcasting availability to clients and boards.
- **Do not optimize a profile the user cannot defend.** If a rewrite depends on a claim they are
  uneasy about, cut it and say why.

---

## References

- `references/scorecard.md` — per-component criteria, executive weighting, worked scoring
- `references/headline.md` — formulas, three strategic variants, keyword placement, 220-char budget
- `references/about.md` — seven-step structure with character budgets, hook mechanics, worked examples
- `references/experience-skills.md` — bullet rewriting, skills strategy, custom URL, recommendation requests
- `references/featured.md` — goal-matched selection, thumbnails, rotation
- `references/photo-banner.md` — specifications, composition, mobile crop test
- `references/search-visibility.md` — recruiter and executive-search discovery
- `references/ai-visibility.md` — surfacing in ChatGPT, Perplexity, and Claude
- `references/language-scan.md` — full flag list with replacements
- `references/resume-alignment.md` — what to keep identical, expand, and deliberately differ
