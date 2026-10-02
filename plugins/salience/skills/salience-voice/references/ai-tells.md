# AI Tells

**Last reviewed: 2026-09-23. Assume a half-life of about a year.** See *This list expires*, below,
before trusting an entry — every one of them is a fact about a generation of models, not a fact
about English.

Three tiers. Tier assignment decides whether a pattern is removed unconditionally or only when the
voice profile says the user does not do it.

## Rhythm first, vocabulary second

**Uniformity is the stronger signal, and the lists below are the weaker one.** Sentence length with
a standard deviation under roughly four words across a hundred-sentence window detects machine-flat
prose better than any vocabulary list, and unlike a word list it does not punish a writer for having
a plain style.

This matters because the two failure modes are asymmetric. A competent writer avoids every word
below and still produces even, characterless paragraphs — the word list misses them entirely. An
executive with a deliberately spare register trips the word list constantly and is not generating
anything. Measuring the rhythm gets both right.

Measure first:

```
# sentence-length standard deviation across the piece
# sigma < 4 over ~100 sentences is a strong tell on its own
```

Then read the lexical list as a **rate, not a hit**: roughly one flagged term per 500 words is where
frequency starts to mean something. A single occurrence of anything below means nothing at all.

## These markers are biased against non-native English writers

Liang et al. (2023), *GPT detectors are biased against non-native English writers*, found that GPT
detectors misclassified a majority of TOEFL essays by non-native speakers as machine-generated while
classifying native-speaker essays almost perfectly. The markers of "AI writing" overlap heavily with
the markers of careful, formally-learned English: controlled vocabulary, even sentence length,
conventional transitions, low idiom.

Two rules follow, and the second is absolute:

1. **Treat any single signal as suspicion, never proof.** This is the cluster principle below, and
   the bias evidence is why it exists rather than a stylistic preference.
2. **Never use this file to allege that someone else's writing was machine-generated.** Not a
   colleague's draft, not a candidate's cover letter, not a competitor's post. The list exists to
   improve the user's own copy. Pointed at another person it produces a confident accusation with a
   known demographic skew, and the accusation is not retractable.

## Clusters, not isolated hits

**One tell is not evidence. A cluster is.** A single em dash means nothing — many editors and
journalists use them constantly. Em dashes *plus* rule-of-three *plus* "vibrant tapestry" *plus* a
summarizing conclusion is a confession.

Applied without this rule, the list below flattens good writing into cautious, characterless prose —
which is the exact failure it exists to prevent. Read the whole piece, count the tells, and act on
density rather than on any single hit.

## Forensic — always remove

Patterns almost no human produces unprompted. Their presence is close to diagnostic.

**Constructions**
- "It's not just X, it's Y" (and "It isn't about X. It's about Y.")
- "In today's fast-paced / ever-evolving / rapidly changing [landscape|world|environment]"
- "I'm excited to announce / thrilled to share"
- "Let's dive in" / "Let's unpack this"
- "At the end of the day" as a paragraph pivot
- Closing a piece by restating its opening claim in different words
- "This isn't just about X — it's about fundamentally reimagining Y"

**Vocabulary**
delve · leverage (as verb) · harness · unlock · foster · streamline · elevate · empower ·
navigate (metaphorical) · landscape (metaphorical) · realm · tapestry · testament to · beacon ·
crucial (as filler) · pivotal (as filler) · robust (outside engineering) · comprehensive (as filler)

**Structural**
- Every paragraph the same length
- A rule-of-three list in every section
- Perfectly parallel bullet construction across an entire piece
- A heading structure with no orphan sections — real writing is lumpier

**Copula avoidance** — a reliable tell on its own. Generated prose reaches for elaborate substitutes
where a plain verb belongs: *serves as · stands as · marks a · represents a · boasts · features ·
constitutes*. Use **is / are / has**.

**"-ing" tag-ons that manufacture depth** — a clause appended to a finished sentence to make it feel
analytical: *highlighting · underscoring · reflecting · showcasing · ensuring · fostering ·
contributing to · demonstrating*. Cut the clause; the sentence was done.

**Aphorism formulas** — "X is the language of Y", "X is not a tool but a mirror", "X becomes a trap".
These read as profound and assert nothing.

**Synonym cycling** — calling the same thing four different names across a paragraph to avoid
repetition: *the protagonist … the main character … the central figure … the hero*. Repetition-avoidance
taken past the point a person would. Use the same word; it reads as confidence, not as poverty.

**Vague attribution** — "experts say", "industry reports suggest", "observers have noted", "many
believe", "research shows" with no research named. Especially damaging in executive content, where
the whole value is that this person knows. Either name the source or make the claim in the first
person from experience.

**False ranges** — "from X to Y" where X and Y do not sit on any real scale: "from the birth of
stars to the dance of dark matter". It performs sweep and carries no information. State the things.

**Significance inflation** — "marked a turning point", "underscores the broader shift", "represents a
fundamental change in how we think about". Generated text reaches for historical weight that the
content does not support.

**Sycophancy and meta-commentary** — "Great question", "You're absolutely right", "I hope this
helps", "Let me know if...". Never in published copy, and rarely useful in delivery either.

**Hedges about knowledge** — "based on available information", "as of my last update".

**Formatting tells**
- Title Case In Headings where sentence case belongs
- Curly quotes where the destination renders straight ones
- Inline-header bullets (`- **Speed:** it is fast`) used where prose reads better
- Bold scattered for emphasis rather than reserved for genuine key terms
- Emoji decorating bullets or headings

**Filler that always cuts**

| Written | Meant |
|---|---|
| in order to | to |
| due to the fact that | because |
| at this point in time | now |
| has the ability to | can |
| a number of | some, or the number |
| it is important to note that | *(delete)* |

## Stylistic — remove unless the voice profile says otherwise

Common in generated text and also in real writing. Judge against the profile; when the profile is
silent, remove.

- Em-dash-driven rhythm
- Rhetorical question openers
- Sentence-initial "Look," / "Here's the thing"
- Semicolons in short-form social copy
- Bolded lead-ins on every bullet
- "Not only... but also"
- Numbered lists where prose would read better

## Contextual — depends on destination

Right in one register, wrong in another. A LinkedIn post and a board memo differ.

- Contractions — natural in a post, sometimes wrong in formal correspondence
- First-person plural for a solo practitioner
- Emoji — never in an executive About, occasionally defensible in a post
- Exclamation points — rarely defensible at this level in either
- Fragments — strong in short-form, weaker in long-form argument

## Replacement, not deletion

Removing a tell leaves a hole. Fill it with something that says more.

| Tell | Weak fix | Real fix |
|---|---|---|
| "Leveraging AI to transform marketing" | "Using AI to improve marketing" | "I use AI where it removes work, not where it makes a deck look modern" |
| "It's not just about tools, it's about outcomes" | "It's about outcomes" | "The tools were never the problem" |
| "In today's fast-paced landscape" | "Today" | Delete and start at the actual claim |
| "I'm excited to announce" | "I'm announcing" | "Starting Monday I'm..." |
| "Delve into the data" | "Look at the data" | "The data says..." |

The weak fix removes the tell and leaves generic text. The real fix replaces it with the specific
thing the sentence was avoiding.

## The profile wins

Some people genuinely write with em dashes, rhetorical questions, and rule-of-three lists.
Stripping those makes the text less like them, not more. When the voice profile contradicts a
stylistic or contextual rule, **the profile wins.** Only the forensic tier is unconditional.

## Do not flag these

Every one of these appears in clean human writing, and treating any of them as evidence on its own
produces confident wrong corrections.

| Not a tell | Why |
|---|---|
| Perfect grammar and consistent style | The person may simply be a good writer, or edited |
| Mixed casual and formal registers | Common in technical fields and in plenty of natural prose |
| "Bland" or dry prose | AI has *specific* tells. Dryness without them is just dry |
| Formal or unusual vocabulary | Generated text overuses a *particular* set of fancy words, not all of them. Do not flatten "ostensibly" because it sounds elevated |
| A single transition word | "However" once is not a tell. Piled up, it is |
| Curly quotes | Word, Google Docs, and macOS curl them automatically |
| One em dash | Evidence only alongside a formulaic rhythm |
| One short emphatic sentence | Humans land points that way. Flag staccato only when several run together |
| "Honestly" or "look" mid-sentence | Ordinary. The tell is the standalone theatrical opener |
| An unsourced claim | Most writing is unsourced. It says nothing about authorship |
| Clean formatting | Templates and editors produce that without help |

## Preserve these

These are positive evidence of a real person, and over-editing destroys exactly what makes the
writing worth reading:

- **Specific, hard-to-fabricate detail.** A real number, an odd quote, a name. Generated text rounds
  specifics off; people hoard them
- **Mixed feelings and unresolved tension.** "I think this was right and it still bothers me."
  Generated text defaults to clean positions
- **Genuine asides, parentheticals, and self-corrections.** "(I keep wanting to say 'almost' here,
  but it really was certain.)"
- **Sentence-length variety.** Real writing alternates; generated writing settles into an even
  mid-length cadence
- **An editorial choice the writer can defend.** If they can say why they made a cut, leave it

## Clean is not the same as human

A draft can pass every check above and still be lifeless — even sentence lengths, no opinions, no
acknowledgment of uncertainty, no first person where it belongs. That is a press release, and it
fails for a different reason than an AI tell does.

Three things restore a pulse: **take a position** rather than presenting balanced pros and cons,
**vary the rhythm** hard, and **let some mess in** — a tangent, an aside, a half-resolved thought.
Perfect structure reads as machined.

## Rewriting rules

- **Rewrite, do not delete.** If the original covered five points, the rewrite covers five points.
  Removing a tell and losing the content is not a fix
- **Do not upgrade their vocabulary.** If the person writes "stuff" and "things", the cleaned
  version does not say "elements" and "components". That is a different failure wearing the same
  clothes
- **Replace with the person's own patterns**, taken from the voice profile — not with a neutral
  register

## Final scan before delivering

Mechanical, and it catches what reading past does not. Run it on every piece of copy:

1. **Scan for em and en dashes** where the voice profile does not license them. Any hit, redraft
   that sentence rather than swapping punctuation.
2. **Scan for every word in the forensic vocabulary list.** Any hit, rewrite the sentence — not the
   word. A tell is usually load-bearing for a sentence that was avoiding something specific.
3. **Scan for "not just X, it's Y"** and its variants.
4. **Check the rhythm.** Three short fragments in a row mid-paragraph, or every paragraph the same
   length, means the cadence was generated rather than written.

## Apply while writing, not after

These constraints are how the copy gets written, not a pass run over finished text. A draft written
freely and then scrubbed still carries the underlying rhythm, and the scrub leaves holes where the
tells were.

**Do not narrate the pass on drafted copy.** For a *rewrite* of the user's existing text, the
before/after diff is the product and should be shown. For copy Salience drafted itself, showing a
"before humanizer / after humanizer" sequence is noise — deliver the clean version.

## This list expires

Every entry here is a fact about a particular generation of language models. "Delve" is on the list
because of a quirk in one era of training data, not because of anything about the word. Models
change, the tells change, and a list nobody revisits fails in both directions:

- **Under-catching** is the obvious failure. New models produce patterns this file does not name, and
  a list that never grows stops being a detector.
- **Over-catching** is the damaging one. An entry drifts back toward ordinary usage and the list
  keeps stripping it — which is this module flattening the voice it exists to protect. The cluster
  principle guards against acting on one hit; it does nothing about an entry that should no longer
  be here at all.

There is a loop underneath both. As writers scrub flagged words to avoid seeming machine-written,
the *absence* of those words becomes the signal, and the list starts measuring its own effect.

### How an entry earns its place

The same evidence discipline that governs career facts. A pattern reaches the forensic tier only
when it is:

- **Specific** — a named construction or word, never a category or a register
- **Observed**, not theorized, in actual generated output
- **Rare in genuine writing**, checked against real samples rather than assumed

"Feels AI-generated" is not an entry. Neither is "corporate tone".

### How an entry leaves

Three ways, and only the first happens on its own:

1. **The user overrides it repeatedly.** Three rejections of the same flag is the user telling you
   the entry is wrong for them. Demote it for that user and stop raising it.
2. **The review date passes and the pattern no longer holds.** Check the forensic tier against
   recent writing the user considers good. Anything that fires on writing they like is not forensic,
   whatever it used to be.
3. **It was never evidenced.** An entry nobody can source to observed output comes off.

### Local demotions live in the voice record, not here

This file ships inside the plugin and is byte-identical on every machine that installs it. Per-user
corrections belong in `${SALIENCE_HOME:-~/.claude/salience}/voice.yaml`:

```yaml
tell_overrides:
  - pattern: "em-dash-driven rhythm"
    action: allow
    reason: "rejected the flag 4 times; 31 of 40 samples use them"
    since: 2026-09-14
```

**Never edit the shipped file to record something about one user.** The override record is also the
refresh signal: a pattern accumulating overrides across a user's history is the closest thing to
real-time evidence available here, and it is worth more than this list's original reasoning.

## Detection scores

Treat any AI-detection score as weak evidence. These tools produce false positives on clear,
well-structured human writing — particularly on executive writing, which is trained toward exactly
the register they flag. Never rewrite good copy to satisfy a detector. The goal is sounding like
the user, and the user is the only reliable judge of that.
