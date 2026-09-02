# Salience

**Be the one they think of first.**

An executive presence system for LinkedIn. One entry point covering profile intelligence,
positioning, brand voice, content and authority, relationship intelligence, executive career search,
and consulting development — held together by a verified-fact ledger that never invents a
professional claim.

Built for senior marketing and general-management executives who need LinkedIn to produce
opportunity, not engagement.

## What makes it different

**It refuses to invent.** Every claim it puts in front of a recruiter, board, or client traces to
something you supplied or approved. Where a number would strengthen a line and none exists, it
writes the strongest true version and tells you what to go find. The test every rewrite must clear:
*if a reference call tested this line, would it hold?*

**It is honest about what LinkedIn does and does not do.** Most CMO and VP seats are filled through
retained search and referral, not keyword search. Salience optimizes search visibility and says so
plainly rather than implying keyword tuning will produce an executive seat.

**It measures outcomes, not volume.** Impressions are diagnostic. A search-firm conversation is the
result. Reports lead with the second and will tell you when a quarter of effort produced nothing.

**Your data never enters this repository.** The plugin is public; your career record, relationship
notes, and analytics live in a local store outside it.

## Install

```bash
/plugin marketplace add rubicon/ai-skills
/plugin install salience@rubicon
```

Then initialize the private store:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/salience-store.sh" init
```

## Start

```
/salience:identity
```

Onboarding takes about 15 minutes and works best if you hand it a resume or a LinkedIn data export
(Settings → Data privacy → Get a copy of your data). Everything else is downstream of this record.

Then:

```
/salience:profile-audit executive search
```

Or just say what you want — `/salience` routes it.

## Commands

| Command | Does |
|---|---|
| `/salience` | Routes any LinkedIn request to the right module |
| `/salience:profile-audit` | Audits and rewrites the profile against verified facts |
| `/salience:identity` | Builds or corrects the career record and fact ledger |
| `/salience:memory` | Inspect, correct, export, or reset what is stored |
| `/salience:evals` | Runs the evaluation suite |

You do not need the commands. Ask for what you want and the router handles it.

## Modules

| Module | Owns |
|---|---|
| `salience` | Entry point, intent routing, evidence and output contracts |
| `salience-identity` | Career record, fact ledger, memory controls |
| `salience-profile` | Nine profile components, audit scoring, rewrites, search and AI visibility |
| `salience-positioning` | Narrative, differentiation, audience value propositions |
| `salience-voice` | Voice capture and enforcement, AI-tell removal |
| `salience-content` | Pillars, editorial planning, posts, long-form, repurposing |
| `salience-engage` | Comments, replies, connection requests, follow-up, relationships |
| `salience-career` | Target roles, alignment, recruiters, interviews, compensation |
| `salience-consulting` | Offer design, prospect research, outreach, pipeline |
| `salience-data` | Import, parsing, identity resolution, retrieval tiers |
| `salience-analytics` | Outcome tracking, experiments, learning |
| `salience-governance` | Approval matrix, safety boundaries, refusals |

Modules load on demand. You never pick one.

## Your data

Everything personal is written to a local store outside this repository:

```
${SALIENCE_HOME:-~/.claude/salience}/
├── identity.yaml        career record and fact ledger
├── voice.yaml           captured writing voice
├── positioning.yaml     approved positioning
├── relationships.yaml   people, context, what is owed
├── content-log.yaml     what was published and what happened
├── experiments.yaml     what was tried and what it produced
└── imports/             resumes, exports, pasted source material
```

Inspect it, correct it, export it, or reset it at any time with `/salience:memory`. The store script
marks the directory git-ignored so a surrounding repository cannot pick it up.

Never stored, regardless of instruction: credentials of any kind, sensitive third-party personal
information, private message contents, or anything you asked to delete.

## Approval

Salience analyzes, recommends, and drafts. It does not act on the outside world on its own.

Publishing, sending, live profile edits, external writes, and paid API calls each require an
explicit approval, per item, every time. There is no batch approval and no standing approval —
publishing is the one place where a mistake is public and hard to walk back.

It will not collect credentials, reuse sessions, bypass CAPTCHAs, evade rate limits, fabricate
engagement, send bulk messages, or write testimony attributed to another person. Those have no
approval path.

## Optional adapters

Salience is fully functional with nothing configured. See `adapters/README.md`.

| Adapter | Adds | Cost |
|---|---|---|
| LinkedIn data export | Your complete career history | Free — the best onboarding path |
| MCP publishing tool | Publish approved drafts without copy-paste | Free, OAuth setup |
| Third-party retrieval | Engagement analysis at volume | Paid per call |

Pasting content is not a degraded mode. For profile work, positioning, drafting, and role alignment
it is exactly equivalent.

## Evaluation

31 cases in `evals/`, covering every module plus routing and the safety boundary. Fabrication and
unapproved-action violations fail the suite outright regardless of output quality.

```
/salience:evals
```

## Limits

- It has no live view of your LinkedIn analytics. Where your account offers a per-post analytics
  export it can work from that; otherwise outcome tracking is what you record plus what you paste.
- It cannot guarantee search ranking or AI-assistant citation, and says so rather than implying
  otherwise.
- It will not tell you what compensation to accept or interpret contract language — that is
  counsel's job.
- Sample sizes in personal-brand content are small. It reports correlation as correlation and
  refuses to conclude from too little data.

## Licence

MIT. See the repository `LICENSE`.
