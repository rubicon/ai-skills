# Voice Profile

## Schema

Written to `${SALIENCE_HOME:-~/.claude/salience}/voice.yaml`.

```yaml
version: "1.0.0"
built: 2026-08-14
validated: true

# The record carries its own tier, the same vocabulary the identity schema uses.
# A voice built from 40 posts and one built from 4 interview answers are not the
# same object, and every downstream draft inherits the difference.
#   verified    — 10+ genuine samples, counts computed
#   stated      — declared preferences, few or no samples
#   provisional — interview-derived, no written samples
tier: verified
evidence:
  samples: 40
  sources:
    - {kind: speech,    items: 6,  note: "3 panels, 2 podcasts, 1 all-hands — 94 min"}
    - {kind: raw,       items: 12, note: "peer emails and Slack"}
    - {kind: published, items: 22, note: "Shares.csv, replies and reshares excluded"}

rhythm:
  avg_sentence_words: 16
  variance: high            # low | medium | high
  fragments: true
  paragraph_length: "1-3 sentences, varies hard"

openings:
  habits: ["flat assertion", "the specific number", "a concession before the argument"]
  never: ["rhetorical question", "greeting", "I am"]

argument:
  shape: "conclusion first, evidence after"
  concession: "names the strongest counterargument early, then answers it"
  hedging: low

vocabulary:
  reaches_for: ["actually", "the pattern", "plumbing", "the number", "worth it"]
  register: "plain, technical when needed, no corporate abstraction"
  never: ["leverage", "synergy", "excited to", "passionate", "journey"]

# What the samples SHOW. Every entry carries its denominator — an absence that
# was not counted is not a finding. See "Absence, with counts" below.
absence_signals:
  - {pattern: "em dash",                   observed: 0, samples: 40}
  - {pattern: "rhetorical question opener", observed: 1, samples: 40}
  - {pattern: "exclamation point",          observed: 0, samples: 40}
  - {pattern: "hashtag",                    observed: 2, samples: 40}

# What the user DECLARED. These are boundaries, not observations, and they
# outrank the counts above. Record the disagreement rather than resolving it
# silently — see "Preference and evidence" below.
stated_preferences:
  - rule: "never uses hashtags"
    conflicts_with: "absence_signals: hashtag observed 2 of 40"
    resolution: "preference governs; both retained; surfaced to user 2026-08-14"

# 5-12 moves, rationed at draft time: max 2 in a short post, 3 in a long one,
# never the same move twice in one piece. Unrationed, the tic becomes the brand.
signature_moves:
  - "opens on the number that contradicts the received view"
  - "one dry self-deprecating line, usually late"
  - "names the strongest counterargument before answering it"
  - "ends on a flat assertion rather than a summary"
  budget: {short_post: 2, long_form: 3, repeat_within_piece: false}

formatting:
  lists: "sparingly, and only when genuinely enumerable"
  emphasis: "italics rarely, bold never"
  emoji: none
  exclamation: none

humor: "dry, usually self-deprecating, usually one line"

# Which register applies to which topic. Prevents the flat, uniformly-certain
# voice that reads as fake, and stops the worst error: full authority on
# something genuinely new.
confidence_zones:
  full_authority:
    topics: ["marketing measurement", "demand generation", "MarTech consolidation"]
    markers: "no hedging; states the mechanism directly"
  earned_perspective:
    topics: ["building marketing orgs", "board communication"]
    markers: "'every time I've seen this', 'in my experience'"
  active_exploration:
    topics: ["AI-assisted workflows"]
    markers: "'I'm testing', 'what I'm seeing so far'"

# How the voice pitches for the moment. Identity never flexes; these five
# dimensions do. Record only what the samples actually evidence — where there is
# none, mark it `inferred` so the draft can say so.
situational:
  flexes: [hedging, humor, distance, sentence_length, claim_ratio]
  evidenced:
    ordinary: {humor: dry, hedging: low, source: "38 of 40 samples"}
    disagreement: {humor: off, claim_ratio: high, source: "2 samples"}
  inferred:
    loss: "no samples. Humor off, sentences short, first person — flag as inference"
    own_setback: "no samples. Flag as inference"

# Tell-list entries this user has overridden. The shipped ai-tells.md is
# identical on every machine; per-user corrections live here and nowhere else.
tell_overrides:
  - pattern: "em-dash-driven rhythm"
    action: allow
    reason: "rejected the flag 4 times; 31 of 40 samples use them"
    since: 2026-09-14

# Patterns present in the samples that belong to the platform or the format,
# not to the person. Recorded so they are never mistaken for voice.
excluded_from_extraction:
  - "one-line paragraphs — LinkedIn formatting convention, not their prose rhythm"
  - "hashtag block at the end — platform habit"

anti_patterns:
  - "never opens with a question"
  - "never uses three-item lists as a rhetorical device"
  - "never closes by restating the opening"
```

Anti-patterns carry as much weight as patterns. Two firm negatives constrain generation more
usefully than ten soft positives.

## Sources

Ranked. Use as many families as are available; record in the profile which supplied what.

| Source | Rank for cadence | Rank for register | Notes |
|---|---|---|---|
| Recorded speech — panels, podcasts, talks, all-hands | **1** | 4 | 60-90 min is a strong corpus on its own. Unedited, and executives have the most of it |
| Raw writing — peer email, Slack, unsent drafts | 2 | 3 | The voice under mild pressure |
| Published writing — own posts, ideally `Shares.csv` | 3 | **1** | Shaped for an audience, so it shows the destination register |
| Interview transcript (fallback) | 4 | 2 | Produces a `provisional` record, never a `verified` one |

**Floor: roughly 500 words, and at least three samples.** A pattern present in one sample is a
coincidence. Below the floor, stop and ask rather than extracting a profile that is really a guess.

**Exclusions.** Cut these before extracting, every time:

- **Replies, reshares, quote-posts, and comments on other people's work.** They carry the other
  person's frame and half their vocabulary, and they drag the profile toward whoever the user was
  answering
- Platform conventions mistaken for voice — LinkedIn's one-line paragraphs, hashtag habits
- Quoted or borrowed phrasing
- Unusually formal registers — legal disclaimers, press releases, board minutes
- Typos and autocorrect artifacts
- Anything ghostwritten, committee-edited, or already AI-assisted

## Absence, with counts

An anti-pattern is worth having only if it was measured. Count each candidate across the sample set
and record the denominator:

```
grep -oic 'leverage' samples/*.txt       # 0 hits
find samples -name '*.txt' | wc -l       # 40 samples
```

→ `{pattern: "leverage", observed: 0, samples: 40}`

This is what makes the tell pass safe. With a count, Salience says *"you have not used this once in
forty posts"* — a fact about this person. Without one it says *"this reads as machine-written"*,
which is a rule about writing in general and is wrong often enough to do real harm.

It protects in both directions. A construction the user demonstrably **does** use is then defended
by evidence rather than by judgment, which is the difference between a tell list that sharpens a
voice and one that flattens it.

**Never assert an absence you have not counted.** Where the sample set is too small to count
against, record the profile as thin on that point.

## Preference and evidence

- **Sample evidence describes what the voice is.** Absence counts live here.
- **A stated preference declares what the voice should be.** It is a boundary, the same shape as
  `boundaries.will_not_claim` in the identity record.

**Where they disagree, the preference governs and the evidence is retained.** Record both in
`stated_preferences.conflicts_with`, and say it out loud once:

> "You said you never use hashtags. I found two, both from 2019. I have recorded the preference as
>  the rule and kept the count — tell me if those old posts are actually the truer signal."

Silently siding with the evidence argues with the user about their own intent. Silently siding with
the preference enshrines whatever they happened to say that day.

## Capture interview

When no written samples exist, capture from speech — it is closer to real voice than most business
writing. Ask four questions the person actually cares about and transcribe how they answer:

1. "What does almost everyone in your field get wrong?"
2. "Walk me through the last hard call you made and how you decided."
3. "What's the part of your job you'd do for free?"
4. "What would you tell someone about to take a job like yours?"

Listen for: how they open, whether they concede before arguing, sentence length variance, the words
they reach for under mild pressure, and whether humor appears.

## Extraction

Work from at least three samples. A pattern present in one sample is a coincidence.

| Extract | Look for |
|---|---|
| Rhythm | Sentence length distribution, not just the mean. High variance is a strong signature |
| Openings | The first sentence of every sample. People are remarkably consistent here |
| Argument shape | Conclusion first, or built to? Does evidence precede or follow the claim? |
| Concession | Do they acknowledge the counterargument, and where? |
| Vocabulary | Words appearing across samples that a peer would not have chosen |
| Formatting | Lists vs. prose, paragraph length, emphasis |
| Negatives | Things conspicuously absent across every sample |

## Validation and refinement

Mandatory before saving, and it is a loop rather than a single check.

**Round one.** Write 150 words in the captured voice on a topic drawn from the samples, show it
beside a real sample, and ask:

> "Does this sound like you, or like someone imitating you?"

If the answer is "close but off", ask what specifically is off. That answer is usually the single
most valuable line in the profile, and it is the one you cannot derive from the samples.

**Rounds two through five, at minimum.** Three short drafts per round on the user's own topics, and
each draft **names the profile lines that produced it**:

```
Draft 2 of 3 — on martech consolidation

  "Most consolidation decks are a cost story. The ones that work are an
   integration story, and nobody wants to own that."

  From: openings.habits "flat assertion" · argument.shape "conclusion first"
        vocabulary.reaches_for "the pattern" · humor "dry, one line"
```

Naming the source lines is what makes the profile auditable. A user who dislikes that sentence can
see it came from `hedging: low` and correct the rule, rather than correcting the sentence and
meeting the same problem again next week.

Five rounds is a floor, not a target. Keep going while corrections are still changing rules; stop
when they are only changing wording.

An unvalidated profile silently distorts every future output, and the distortion compounds because
each generated piece looks like more evidence of the voice.

## Maintenance

- Rebuild when the user's writing changes materially, or after roughly a year
- Every rejected phrasing is a signal — record it in `never`
- **Every rejected AI-tell flag is also a signal, and it goes somewhere different.** Three
  rejections of the same flag means the shipped list is wrong for this user: record it under
  `tell_overrides` and stop raising it. Never edit the shipped `ai-tells.md` to hold something
  about one person
- When the user rewrites a draft, diff their version against yours. The diff is the correction
- Re-tier when the evidence changes. A `provisional` record that gains ten real samples becomes
  `verified`, and the prompt to replace it stops firing
- The voice profile is not positioning. A person whose position changed still writes the same way
