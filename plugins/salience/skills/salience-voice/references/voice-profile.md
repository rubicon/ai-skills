# Voice Profile

## Schema

Written to `${SALIENCE_HOME:-~/.claude/salience}/voice.yaml`.

```yaml
version: "1.0.0"
built: 2026-08-14
samples: 4
validated: true

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

## Validation

Mandatory before saving. Write 150 words in the captured voice on a topic drawn from the samples,
show it beside a real sample, and ask:

> "Does this sound like you, or like someone imitating you?"

If the answer is "close but off", ask what specifically is off. That answer is usually the single
most valuable line in the profile, and it is the one you cannot derive from the samples.

An unvalidated profile silently distorts every future output, and the distortion compounds because
each generated piece looks like more evidence of the voice.

## Maintenance

- Rebuild when the user's writing changes materially, or after roughly a year
- Every rejected phrasing is a signal — record it in `never`
- When the user rewrites a draft, diff their version against yours. The diff is the correction
- The voice profile is not positioning. A person whose position changed still writes the same way
