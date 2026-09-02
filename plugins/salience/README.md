# Salience

### Be the one they think of first.

**An executive presence system for LinkedIn — built for the people whose next opportunity arrives
through a search partner, a board seat, or a referral, not through an application form.**

Salience does not write you a better LinkedIn post. It builds a verified record of what you have
actually done, decides what you should be known for, writes every surface in your own voice against
that record — and then refuses, every single time, to put a claim in front of a recruiter that you
could not defend on a reference call.

```
/salience audit my profile for CMO roles
```

---

## The problem it actually solves

Every AI writing tool will happily make you sound impressive. That is the problem.

Ask one to sharpen your LinkedIn headline and it will hand you a number you never gave it, a
transformation you never led, and a phrase like *"driving transformative growth at scale"* that
signals, to the exact audience you are trying to reach, that you did not write it. Executive search
partners read hundreds of these a week. They can tell.

Meanwhile the things that would genuinely move you — a scope line that tells a search partner how
big the job was, the one proof point you can document, the mandate you were hired against, whether
your record contradicts itself between your résumé and your profile — go untouched, because they
require knowing your career rather than generating text about it.

**Salience inverts that.** It spends its effort on the record first and the prose second. Its
sharpest output is frequently not a rewrite at all — it is *"this bullet on your live profile has
nothing behind it, and it is the only claim here that would not survive a reference check."*

---

## What it does

| | |
|---|---|
| **Profile** | Audits all nine components against your goal, scores with severity, and rewrites headline, About, and Experience — including the search-visibility and AI-assistant-visibility layers most tools ignore entirely |
| **Positioning** | What you should be known for, who needs to believe it, and what you are deliberately not claiming |
| **Voice** | Learns how you actually write, then enforces it — including a de-AI pass that removes machine tells without flattening genuine executive prose |
| **Content** | Pillars, a cadence you will actually keep, drafts, long-form, repurposing |
| **Engagement** | Comments and replies worth the signature on them; relationship follow-up that remembers what is owed |
| **Career** | Role alignment against real postings, recruiter conversations, interview prep, compensation framing |
| **Consulting** | Offer design, proof assets, prospect research, outreach that is not a template |
| **Analytics** | Outcome tracking that leads with conversations started, not impressions |
| **Governance** | The approval gate. Nothing reaches the outside world without you saying so, per item, every time |

Twelve modules. You never choose one — say what you want and the router does.

---

## What makes it different

**It refuses to invent.** Every fact carries a tier — verified, stated, inferred, proposed, or a
logged gap — and a source. Where a number would strengthen a line and none exists, Salience writes
the strongest *true* version and tells you exactly what artifact to go find. Corrections propagate:
change a figure once and everything built on it is flagged. The test every rewrite must clear is
simply *would this hold on a reference call?*

**It is honest about what LinkedIn does and does not do.** Most CMO and VP seats are filled through
retained search and referral, not recruiter keyword search. Salience optimizes your search
visibility properly — and says that out loud rather than implying keyword tuning will produce an
executive seat.

**It knows the difference between a critique and a manufactured finding.** A strong profile gets
told it is strong. An audit that must produce ten problems will invent ten problems, and the
scorecard is explicitly guarded against it.

**It will tell you when you are wrong, once.** Then it does what you asked. Cautions are advice and
you can overrule them. The approval gate is not advice, and it does not move.

**Your data never enters this repository.** The plugin is public. Your career record, your
relationship notes, and your analytics live in a local store outside it, which you can inspect,
correct, export, or delete in one command.

---

## Point it at what you already have

Most executives are already sitting on their own evidence — a career folder with résumés, press
coverage, awards, case studies, prior applications, writing samples. Salience reads it.

```
My career material is in ~/Documents/Career — use that instead of asking me.
```

It **surveys the directory first**, proposes a read plan, and opens only what the plan names. It
classifies by folder signal, tiers by artifact type — dated press coverage is third-party
corroboration; a résumé is your own assertion in a file, and does not become verified by sitting in
a folder — and records the source path behind every fact it extracts.

Read-only, always. It never writes to, moves, renames, or deletes anything in your corpus.

No corpus? A résumé works. So does a LinkedIn data export, a conference bio, or a fifteen-minute
conversation.

---

## Install

```bash
/plugin marketplace add rubicon/ai-skills
/plugin install salience@rubicon
```

Initialize the private store:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/salience-store.sh" init
```

Then:

```
/salience:identity
```

About fifteen minutes, and considerably less if you hand it a folder or a data export. Everything
else in Salience is downstream of that record, so it is the one step worth doing properly.

---

## The first hour

```
/salience:identity                          build the record — import, confirm, log the gaps
/salience:profile-audit executive search     score, diagnose, rewrite, prioritize
/salience what should I be known for         positioning, if the audit surfaced drift
/salience does this sound like me            voice capture from your own writing
```

After that, stop using commands. Say what you want.

> *"Rewrite my headline for PE-backed CMO roles."*
> *"Should I apply to this?"* + a job posting
> *"That CAC number was 34%, not 38%."*
> *"Draft a comment on this."*
> *"What do you know about me?"*

---

## Commands

| Command | Does |
|---|---|
| `/salience` | Routes any LinkedIn request to the right module |
| `/salience:profile-audit` | Audits and rewrites the profile against verified facts |
| `/salience:identity` | Builds or corrects the career record and fact ledger |
| `/salience:memory` | Inspect, correct, export, or reset what is stored |
| `/salience:evals` | Runs the evaluation suite |

---

## Your data

```
${SALIENCE_HOME:-~/.claude/salience}/
├── identity.yaml        career record and fact ledger
├── voice.yaml           captured writing voice
├── positioning.yaml     approved positioning
├── relationships.yaml   people, context, what is owed
├── content-log.yaml     what was published and what happened
├── experiments.yaml     what was tried and what it produced
└── imports/             résumés, exports, pasted source material
```

Outside this repository, always. The store script marks the directory git-ignored so a surrounding
repository cannot pick it up. `/salience:memory` inspects, corrects, exports, or resets it — and
deletion means deletion, not "retained for context."

Never stored, regardless of who asks or how it is framed: credentials of any kind, sensitive
third-party personal information, private message contents, or anything you asked to delete.

---

## Approval

**Salience analyzes, recommends, and drafts. It does not act on the outside world on its own.**

Publishing a post or comment, sending a message or connection request, editing your live profile,
writing to an external system, exporting third-party data, and calling a paid service each require
an explicit approval — per item, every time, showing the exact content that will be sent. There is
no batch approval and no standing approval. Ask for one and it will tell you plainly that this is
not a thing it does, then carry on drafting.

Refused outright, with no approval path: collecting or reusing credentials, cookies, or sessions;
bypassing CAPTCHAs or bot detection; evading rate limits; fabricated engagement; bulk unsolicited
messaging; bulk connection requests; publishing a comment you have not read as your genuine
reaction; and inventing any employer, title, date, metric, client, award, or credential.

---

## Optional adapters

Salience is fully functional with nothing configured.

| Adapter | Adds | Cost |
|---|---|---|
| Career corpus directory | Your own evidence, already organized | Free — the best onboarding path |
| LinkedIn data export | Complete first-party career history | Free |
| MCP publishing tool | Publish approved drafts without copy-paste | Free, OAuth setup |
| Third-party retrieval | Engagement analysis at volume | Paid per call |

Pasting content is not a degraded mode. For profile work, positioning, drafting, and role alignment
it is exactly equivalent. See `adapters/README.md`.

---

## Evaluation

33 cases in `evals/`, covering every module plus routing and the safety boundary. Fabrication and
unapproved-action violations fail the suite outright, regardless of how good the output is.

```
/salience:evals
```

---

## Limits — stated, not buried

- **No live view of your LinkedIn analytics.** Where your account offers a per-post export it works
  from that; otherwise outcome tracking is what you record plus what you paste.
- **No guarantee of search ranking or AI-assistant citation.** Nobody can promise that. Salience
  optimizes the inputs and reports what it can measure.
- **No compensation advice or contract interpretation.** That is counsel's job, and it will say so.
- **Small sample sizes are real.** Personal-brand content produces very little data. Salience
  reports correlation as correlation and declines to conclude from five posts.

---

## Licence

MIT. See the repository `LICENSE`.
