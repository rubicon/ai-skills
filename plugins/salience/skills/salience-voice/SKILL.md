---
name: salience-voice
description: >-
  Capture, document, and enforce how the user actually writes, then hold every Salience output to
  it. Builds a reusable voice profile from real writing samples, flags off-voice phrasing, and
  strips AI-writing tells from any draft. Triggers on "does this sound like me", "learn my voice",
  "build my voice profile", "de-AI this", "humanize this", "this doesn't sound like me", "make it
  sound like I wrote it", "review this draft before I post". Not for deciding what to say (use
  salience-positioning) or what to write about (use salience-content).
version: 0.1.0
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

Do not capture when a voice profile already exists and the user has not asked to rebuild it. Do not
enforce personal voice on copy the user has said should read neutral — a company-page post or a
formal board communication is a legitimate exception, not a voice failure.

Enforcement runs on every piece of writing this system produces, whether or not the user asks.

---

## Capture

### Samples

Enough genuine writing to see a pattern. Three or four substantial pieces works; 10-20 short posts
works better. A pattern in one sample is a coincidence.

Two source families, and they capture different things. Use both where possible.

**Raw sources give the truer voice.** Slack messages, unedited emails to peers, call or podcast
transcripts, anything written while annoyed or convinced. The less edited, the more of the actual
person survives.

**Published sources give the right register.** The user's own past LinkedIn posts — ideally
`Shares.csv` from a data export, which is free, large, and zero-effort. These have been shaped for
an audience, so they carry less raw voice, but they show how the person writes *in the destination*.

Prefer raw sources for the underlying voice and published posts for calibration. Say which is
which in the profile — a voice built only from polished writing will be flatter than the person,
and one built only from Slack will be too loose for a profile.

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

## Enforce

### Against the voice profile
Check rhythm, openings, vocabulary, argument shape, and formatting. Flag deviations with the
specific fix.

### Against AI tells
Strip regardless of what the voice profile says. See
`../salience-profile/references/language-scan.md` for the full list. The core:

**Vocabulary:** leverage (verb) · delve · unlock · harness · foster · streamline · robust ·
comprehensive · fundamentally · seamless · elevate · empower · navigate (metaphorical) · landscape
(metaphorical) · testament to · realm · tapestry

**Constructions:** "It's not just X, it's Y" · "In today's fast-paced…" · "I'm excited to
announce…" · rule-of-three everywhere · uniform paragraph lengths · closing by restating the
opening · rhetorical question openers used as a formula

**Punctuation:** em-dash rhythm the person does not otherwise use · decorative arrow bullets ·
emoji in executive copy · exclamation points

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
- Multiple registers are normal — a board memo and a LinkedIn post differ. Register flexes;
  identity does not.

## References

- `references/voice-profile.md` — the schema, the capture interview, worked extraction
- `references/ai-tells.md` — full pattern list with tiers and replacements
