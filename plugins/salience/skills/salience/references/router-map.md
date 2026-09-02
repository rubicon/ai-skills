# Router Map

Intent phrases mapped to modules, including the near-misses that route wrong if taken literally.

## Direct routes

| The user says | Module | Notes |
|---|---|---|
| "audit my profile", "review my LinkedIn", "score my profile" | `salience-profile` | Full nine-component audit |
| "rewrite my headline", "fix my headline" | `salience-profile` | Needs positioning; establish it first if absent |
| "fix my About", "rewrite my summary", "my bio" | `salience-profile` | |
| "am I showing up for recruiters", "recruiter search", "keywords" | `salience-profile` | Search-visibility path |
| "do I show up in ChatGPT / AI search" | `salience-profile` | AI-visibility path |
| "what do I stand for", "how do I differentiate", "my value prop" | `salience-positioning` | |
| "position me for CMO roles" | `salience-positioning` | Then `salience-profile` to apply it |
| "does this sound like me", "de-AI this", "learn my voice" | `salience-voice` | |
| "what should I post about", "content plan", "pillars" | `salience-content` | |
| "write a post", "draft an article", "newsletter" | `salience-content` | |
| "turn this into a LinkedIn post" | `salience-content` | Repurposing path |
| "comment on this", "reply to this" | `salience-engage` | |
| "follow up with", "reconnect with", "who should I talk to" | `salience-engage` | |
| "draft a connection request" | `salience-engage` | |
| "align my profile to this job", "should I apply", "match score" | `salience-career` | |
| "prep me for this interview", "what do I say about leaving" | `salience-career` | |
| "what should I ask for", "compensation", "the offer" | `salience-career` | |
| "consulting outreach", "fractional", "advisory", "speaking" | `salience-consulting` | |
| "research this company / this recruiter / this prospect" | Depends — see below | |
| "import my resume", "here's my profile export" | `salience-data` | |
| "how did my posts do", "what's working" | `salience-analytics` | |
| "add this achievement", "that number was wrong" | `salience-identity` | |
| "what do you know about me", "delete that", "export my data" | `salience-identity` | Memory controls |

## Near-misses

These route wrong when read literally. The distinction is always **what the user is trying to
achieve**, not the noun in the sentence.

| Phrase | Wrong route | Right route | Why |
|---|---|---|---|
| "research this recruiter" | `salience-consulting` | `salience-career` | Recruiters are a career-search surface, not a prospect |
| "research this company" | `salience-career` | Ask | Target employer or consulting prospect? One question |
| "write my executive summary" | `salience-profile` | Ask | LinkedIn About, or a resume section? Different formats |
| "make me sound more senior" | `salience-voice` | `salience-positioning` | Seniority is a positioning problem; voice only changes how it reads |
| "my profile isn't getting views" | `salience-profile` | `salience-analytics` first | Diagnose before rewriting; the cause may be content cadence |
| "write a post about my new role" | `salience-content` | `salience-identity` first | The role change is a fact that must enter the record before it is announced |
| "clean up my experience section" | `salience-profile` | `salience-profile`, after `salience-identity` | Rewriting bullets without the fact ledger invites invention |
| "help me network" | `salience-engage` | Ask | Broad relationship plan, or one specific person? |
| "what's my brand" | `salience-voice` | `salience-positioning` | Brand here means position, not prose style |

## Dependency order

When a request needs more than one module, run them in this order regardless of how the request
was phrased:

```
salience-identity  →  salience-positioning  →  salience-voice
                              ↓
        salience-profile / salience-content / salience-engage
                              ↓
        salience-career / salience-consulting
                              ↓
                     salience-analytics
```

`salience-data` feeds identity at any point. `salience-governance` gates every external write and
is never skipped for expedience.

## Handling ambiguity

One question, two or three concrete options, then proceed. Do not ask a second clarifying question
unless the first answer genuinely opened a new fork.

> "Help me with my LinkedIn."

```
Which outcome are you after right now?

1. Profile — audit and rewrite so it works for CMO-level search
2. Content — a pillar set and a cadence you can actually sustain
3. A specific opportunity — a role, a prospect, or a person to follow up with
```

Do not default to the audit because it is the most requested. Guessing costs more than asking.
