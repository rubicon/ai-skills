---
name: salience-voice
description: >-
  Capture, document, and enforce how the user actually writes, then hold every Salience output to
  it. Builds a reusable voice profile from real writing samples, flags off-voice phrasing, and
  strips AI-writing tells from any draft. Also pitches that one voice for the moment it is used in
  — a layoff, a tribute, a correction, and an ordinary Tuesday are not the same register.
  Triggers on "does this sound like me", "learn my voice", "build my voice profile", "de-AI this",
  "humanize this", "this doesn't sound like me", "make it sound like I wrote it", "review this
  draft before I post", "how do I write about being laid off", "what tone for this". Not for
  deciding what to say (use
  salience-positioning) or what to write about (use salience-content).
version: 0.2.0
---

# Voice

The failure mode this module prevents: a profile and a feed that are technically excellent and
audibly not the person. At executive level that is expensive — the audience is specifically
evaluating judgment, and outsourced-sounding writing reads as outsourced thinking.

Voice is **how** things are said. Positioning is **what**. Keep them separate; conflating them
produces copy that sounds right and says nothing.

## Two operations

| Operation | Trigger |
|---|---|
| **Capture** | No voice profile exists, or the user wants it rebuilt |
| **Enforce** | Any draft, from any module, before it reaches the user |

Between them sits one input that enforcement cannot run without: **the situation**. A voice profile
is a single register, and applying it unchanged to a layoff or a tribute is the module's worst
failure mode. Select the situation before the voice pass — see Situation, below.

Do not capture when a voice profile already exists and the user has not asked to rebuild it. Do not
enforce personal voice on copy the user has said should read neutral — a company-page post or a
formal board communication is a legitimate exception, not a voice failure.

Enforcement runs on every piece of writing this system produces, whether or not the user asks.

---

## Capture

### Samples

Enough genuine writing to see a pattern. Three or four substantial pieces works; 10-20 short posts
works better. A pattern in one sample is a coincidence.

Three source families. Use as many as exist, and record which supplied what — full ranking in
`references/voice-profile.md`.

**Recorded speech is the truest source, and executives have the most of it.** Panels, podcasts,
conference talks, all-hands recordings. Unedited, carrying real cadence and the words the person
reaches for under mild pressure, and a senior executive usually has far more of it in public than
they have writing. Sixty to ninety minutes of transcript is a strong corpus on its own. Rank it
**above** published writing for cadence and vocabulary, **below** it for register and formatting —
nobody speaks in paragraphs.

**Raw writing gives the voice under mild pressure.** Slack, unedited peer email, anything written
while annoyed or convinced.

**Published writing gives the destination register.** The user's own posts, ideally `Shares.csv`
from a data export — free, large, zero-effort.

A voice built only from polished writing is flatter than the person; only from Slack, too loose to
publish; only from transcripts, lost on where the paragraphs go.

**Exclude replies, reshares, quote-posts, and comments on other people's work.** They carry the
other person's frame and half their vocabulary, and they drag the profile toward whoever the user
was answering. Original posts only.

**Poor sources:** anything ghostwritten · press releases · copy already AI-assisted · anything
committee-edited · a résumé

**Minimum gate: roughly 500 words.** Below that, stop and ask for more rather than extracting a
profile that is really a guess:

> "That's too little to find a reliable pattern. Two or three more — old emails, Slack, a
> transcript — and the messier the better."

### Exclusion check

Before extracting, identify what in the samples is **not** the person:

- Platform conventions mistaken for voice — LinkedIn's one-line paragraphs, hashtag habits, the
  short-line cadence the format encourages
- Quoted or borrowed phrasing from someone else
- Unusually formal registers — a legal disclaimer, a press release, board minutes
- Typos and autocorrect artifacts

This step matters most with LinkedIn samples specifically. Extract voice from a feed without it and
you encode LinkedIn's house style as if it were the person's.

Ask directly: *"Send me three or four things you wrote yourself — a memo, a long email, a post you
liked. Unpolished is better than polished."*

If the user has nothing written, capture voice by interview instead: ask four questions they care
about and transcribe how they answer. Speech is closer to real voice than most business writing.

### What to extract

Write to `${SALIENCE_HOME:-~/.claude/salience}/voice.yaml`:

- **Sentence rhythm** — average length, variance, whether they use fragments
- **Opening habits** — how they start: claim, question, story, concession
- **Signature constructions** — patterns that recur across samples
- **Vocabulary** — words they reach for, and the register they hold
- **Argument shape** — do they lead with the conclusion or build to it
- **Concession behavior** — how they handle the counterargument
- **Humor** — present or not, and what kind. Dry, self-deprecating, none
- **Hedging tolerance** — how much qualification is natural to them
- **Formatting** — lists vs. prose, paragraph length, emphasis habits
- **Anti-patterns** — things they visibly never do

Anti-patterns matter as much as patterns. A person who never uses exclamation points and never
opens with a question has told you two firm rules.

### Record absence, with counts

An anti-pattern is only worth having if it was measured. "You have not used 'leverage' once across
eleven samples" constrains generation. "Avoids corporate jargon" is a guess wearing a finding's
clothes.

Count the candidate across the sample set and record the denominator in `absence_signals` —
`{pattern: "em dash", observed: 0, samples: 40}`.

This is what makes the AI-tell pass safe. With counts, Salience says *"you have not used this once
in forty posts"* — a fact about this person — rather than *"this reads as machine-written"*, which
is a rule about writing in general and is wrong often enough to matter. It protects in the other
direction too: a construction the user demonstrably **does** use is then defended by evidence
rather than by judgment.

**Do not assert an absence you have not counted.** Where the samples are too few to count against,
say the profile is thin on that point rather than stating a negative you cannot support.

### Stated preference outranks sample evidence

Two kinds of statement go into a voice profile, and they are not the same kind of thing:

- **Sample evidence describes what the voice is.** Absence counts live here. "No em dashes in 40
  samples" is a finding.
- **A stated preference declares what the voice should be.** "I never use hashtags" is an
  instruction, not a report. It is a boundary, the same shape as `boundaries.will_not_claim` in the
  identity record.

**Where they disagree, the stated preference governs — and the evidence is recorded, not
discarded.** One stray hashtag from 2019 does not overturn an instruction. Say the disagreement out
loud rather than silently picking a side:

> "You said you never use hashtags. I found two, both from 2019. I have recorded the preference as
>  the rule and kept the count — tell me if those old posts are actually the truer signal."

Silently siding with the evidence argues with the user about their own intent. Silently siding with
the preference enshrines whatever they happened to say that day. Naming the conflict costs one
sentence and is right in both directions.

### Tier the record

Salience tiers every career fact and then stores the voice profile as an untiered blob. A voice
built from forty real posts and a voice built from four interview answers are not the same object,
and every downstream draft inherits the difference unmarked.

| Tier | Source | Handling |
|---|---|---|
| `verified` | Ten or more genuine samples, with counts computed | Use directly |
| `stated` | Declared preferences, few or no samples | Use, and name which rules rest on preference alone |
| `provisional` | Interview-derived, no written samples | Use, and say so the first time each session that it drives a draft |

A `provisional` profile carries its own replacement prompt: *"This was built from what you told me,
not from what you wrote. Send me four real samples when you have them and I will rebuild it."*

### Confidence zones

A flat voice profile makes a person sound equally certain about everything, which is the fastest way
to sound fake. Map expertise into three registers and record which topics sit where:

| Zone | When | Sounds like |
|---|---|---|
| **Full authority** | Genuine expertise, years of evidence | No hedging. "This is what happens when you..." |
| **Earned perspective** | Real experience, not mastery | "In my experience..." / "Every time I've seen this..." |
| **Active exploration** | Learning it now, in public | "I'm testing..." / "What I'm seeing so far..." |

For an executive this is the difference between credible and grandiose. Writing about a core
discipline in exploration voice reads as falsely modest; writing about something genuinely new in
full-authority voice is the single most damaging voice error available, because the audience most
likely to notice is the audience being targeted.

Record the zone per topic. `salience-content` reads it when choosing how to pitch a claim.

### Validate before saving

Write the same short passage twice — once in the captured voice, once deliberately off it — and
show both:

```
This sounds like you:
  "The measurement layer broke before the marketing did. Everyone argued about creative for
   two quarters."

This doesn't:
  "In today's evolving landscape, it's crucial to leverage data-driven insights to unlock
   marketing potential."
```

Then ask: *"Does the first one sound like you when you're not overthinking it? What's off?"*

The contrast is what makes the test work. Shown alone, almost any competent passage reads as
plausible; shown against a wrong version, people identify the mismatch immediately.

**Source every anti-pattern to evidence.** "You never used 'leverage' across eleven samples" is a
finding. "Avoid corporate jargon" is a guess wearing a finding's clothes.

An unvalidated voice profile is a guess that will silently distort every future output. If the user
says it is close but off, ask what specifically is off — that answer is usually the most valuable
line in the whole profile.

### Refine, and show your work

One validation round is not enough to converge, and the most useful thing a round produces is not
the corrected sentence — it is the corrected rule.

Run **at least five rounds**. Each round, draft three short samples on topics drawn from the user's
own material, and **name the profile lines that produced each one** — `From: openings.habits "flat
assertion" · argument.shape "conclusion first" · humor "dry, one line"`. Worked example in
`references/voice-profile.md`.

Naming the source lines makes the profile auditable. A user who dislikes a sentence can see it came
from `hedging: low` and fix the rule, instead of fixing the sentence and meeting the same problem
again next week.

Five rounds is a floor, not a target. Keep going while corrections are still changing rules; stop
when they are only changing wording.

### Check your own work first

Before showing the profile, answer these honestly. The same evidence discipline that governs career
facts governs voice extraction:

- Are the signature phrases actually **in** the samples, or did I infer them from tone?
- Does the anti-pattern list name specific words, or vague categories?
- Do the two validation passages differ in a way a reader would actually notice?
- Are the confidence zones mapped to named topics, or generic?
- Could someone else write in this voice from this document without asking a follow-up question?

Flag the gaps rather than papering over them: *"The anti-pattern list only has two entries, which
isn't enough to constrain anything. Send me two more samples or tell me three phrases you'd never
use."*

---

## Situation

Confidence zones vary the voice by **topic**. Register varies it by **destination**. Neither covers
the third axis, and it is the one that produces the expensive mistakes: the same voice pitched for
the wrong **moment**.

A voice profile is captured from a person at work — analytical, in command of the material, usually
mildly amused. That is the right register for most of what they will ever publish, which is exactly
why the profile gets built from it. Applied unchanged to a layoff, a death, or a public correction,
it is badly wrong, and the user finds out after publishing.

### What flexes and what does not

**Identity does not flex.** Vocabulary, argument shape, formatting habits, and the anti-pattern list
hold in every situation. Someone who never uses exclamation points does not start at a funeral. A
voice that swaps its whole register under pressure was never captured correctly, and it reads as a
different person writing — which is worse than reading as cold.

Five dimensions flex, and only these:

| Dimension | Which way, and when |
|---|---|
| **Hedging** | Up when the user genuinely does not know yet. Down when they do |
| **Humor** | On, dry, or off. This is the one that causes real damage when it is wrong |
| **Distance** | First person and specific, or abstract and general. Weight moves toward specific |
| **Sentence length** | Shorter under weight. Long analytical sentences read as unbothered |
| **Claim-to-acknowledgment ratio** | How much of the piece asserts, against how much registers what happened |

### The situations that go wrong

| Situation | The default failure | The correction |
|---|---|---|
| The user's own layoff, or a project that failed publicly | Dry humor reads as callous; flat assertion reads as cold | Humor off. Distance in. Acknowledgment before claim |
| Someone else's milestone | The analytical register reads as withholding | Warmth up, length down, and keep it about them — an analytical aside steals the post |
| Someone else's loss | Any signature move at all reads as performance | Almost everything off. Short, plain, first person, no structure |
| A new role the user is genuinely unsure about | Low hedging plus real uncertainty produces overclaiming | Hedging up, to match what is actually known |
| Correcting the user's own public mistake | Directness without modulation becomes combative | Claim ratio down hard. State the error before the reasoning |
| Industry bad news touching the user's clients or team | Analysis published while people are still absorbing it reads as opportunism | Wait. Say that waiting is the recommendation |

That last row is not a tone adjustment. **Not posting is a valid output**, and it is the right one
often enough to belong in the table. Offer it as a recommendation rather than burying it.

### Bounded by evidence

A captured profile usually holds no evidence of how this person writes under grief, because people
do not write that way at work. Do not synthesize it and do not present the synthesis as their voice.

> "I have forty samples of how you write about measurement and none of how you write about
>  something like this. Here is a version with the humor off and the sentences short — but that
>  register is my inference, not your pattern. Read it for whether it sounds like you."

Flagging the inference is the whole discipline. A confident draft in an unevidenced register is the
precise failure this module exists to prevent, and the situation being emotional makes that worse
rather than exempt.

### Substance belongs to positioning

This section governs **how** a thing is said. What to actually say about a layoff, a gap, a short
tenure, or a pivot is already decided in
`../salience-positioning/references/executive-narrative.md` — say the word, state it in one clause,
lead with the through-line. Route there for the substance and come back here for the pitch. Do not
re-decide the narrative from inside a voice pass.

---

## Enforce

### Against the voice profile
Check rhythm, openings, vocabulary, argument shape, and formatting. Flag deviations with the
specific fix.

### Against AI tells

**Rhythm first, vocabulary second.** Uniformity is the stronger signal. Sentence length with a
standard deviation under roughly four words across a hundred-sentence window detects machine-flat
prose better than any word list, and it does not punish a writer for having a plain vocabulary. A
competent writer avoids every flagged word and still produces even, characterless paragraphs; an
executive with a deliberately spare style trips a word list constantly. Measure the rhythm, then
read the list.

Treat the lexical list as the **secondary** signal and as a rate rather than a hit: roughly one
flagged term per 500 words is where it starts to mean something. One occurrence means nothing.

**Never use any of this to allege that someone else's writing was machine-generated.** These
markers overlap heavily with careful non-native English — see the bias evidence in
`references/ai-tells.md`. The list is for improving the user's own drafts, never for judging
another person's.

The core list, applied under those conditions. See
`../salience-profile/references/language-scan.md` and `references/ai-tells.md` for the full
version:

**Vocabulary:** leverage (verb) · delve · unlock · harness · foster · streamline · robust ·
comprehensive · fundamentally · seamless · elevate · empower · navigate (metaphorical) · landscape
(metaphorical) · testament to · realm · tapestry

**Constructions:** "It's not just X, it's Y" · "In today's fast-paced…" · "I'm excited to
announce…" · rule-of-three everywhere · uniform paragraph lengths · closing by restating the
opening · rhetorical question openers used as a formula

**Punctuation:** em-dash rhythm the person does not otherwise use · decorative arrow bullets ·
emoji in executive copy · exclamation points

### Ration the signature moves

A voice profile names the handful of things that make the user sound like themselves. The failure of
every voice-matched generator is to then do all of them in every paragraph, producing a caricature
that is recognisably derived from the person and obviously not the person.

Signature moves carry a **budget**, spent while drafting rather than caught in review:

- **5–12 moves** in the profile. Fewer than five is not a voice; more than twelve is a transcript
- At most **two** in a short post, **three** in a long piece
- **Never the same move twice** in one piece
- The strongest move is spent once and held back everywhere else

For an executive publishing weekly this compounds. Unrationed, the tic becomes the brand, and it is
the sort of thing an audience notices well before the writer does.

### Never rewrite an engineered hook

A hook that another module deliberately constructed — for tension, specificity, or a fold
constraint — is **not** subject to naturalness editing. Rewriting it to sound more like the user
destroys the structure it was built for, and it is the most common way a voice pass makes a draft
worse.

Enforce voice on the body. Leave a hook alone unless it contains a forensic tell or an unsupported
claim, and if it does, say so and hand it back rather than quietly smoothing it.

### Tiered, not absolute

Not every flagged pattern is wrong. Some people genuinely write with em dashes and rule-of-three
lists, and stripping those makes the text less like them, not more.

| Tier | Handling |
|---|---|
| **Forensic** | Patterns almost no human produces unprompted. Always remove |
| **Stylistic** | Common in AI output and also in real writing. Remove only if the voice profile shows the user does not do it |
| **Contextual** | Fine in one register, wrong in another. Judge against the destination |

When the voice profile contradicts a general rule, **the voice profile wins.** The goal is sounding
like the user, not sounding like a style guide.

### Reporting

```
Voice check — 3 changes

  "Leveraging AI to fundamentally transform demand generation"
→ "Using AI where it actually removes work"
  Two forensic tells. You don't write "leverage" in any of your samples.

  "It's not just about tools — it's about outcomes."
→ "The tools were never the problem."
  Formulaic construction; your samples make this move by flat assertion.

  Four paragraphs, all 3 sentences.
→ Broke the third into a one-line paragraph.
  Your writing varies hard between long and very short. The evenness read as generated.
```

Explain the meaningful ones. Silent correction teaches nothing and the same phrasing returns next
draft.

## Boundaries

- Voice is not a licence to overstate. Confident phrasing must still rest on a real fact — the
  evidence contract outranks the voice profile.
- Never fabricate a personal anecdote to sound authentic.
- Multiple registers are normal — a board memo and a LinkedIn post differ, and so do a product
  launch and a eulogy. Register flexes along the five dimensions under Situation; identity does not
  flex at all.
- Never claim a voice profile is stronger than its tier. A `provisional` profile that drove a draft
  gets said out loud, once per session.

## References

- `references/voice-profile.md` — the schema, source ranking, the capture interview, the refinement
  loop, worked extraction
- `references/ai-tells.md` — full pattern list with tiers and replacements, the uniformity measure,
  the non-native-English bias evidence, and the list's own expiry and override rules
