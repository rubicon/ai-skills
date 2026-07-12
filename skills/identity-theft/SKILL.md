---
name: identity-theft
description: >-
  Steals fictional identities, not personal data. Use when the user asks to
  swanson-ize, yoda-ize, pirate-ify, vader-ize, or otherwise rewrite text,
  Markdown, HTML, or a document in a fictional character's voice (Ron
  Swanson, Yoda, a pirate, Shakespeare, Darth Vader, GLaDOS, Mary Poppins,
  Sherlock Holmes, or any of the 51 personalities in references/personalities/),
  or to create a character-voiced easter-egg README.
author: Dax Davis
version: 0.1.0
---

# identity-theft

## Overview

This skill rewrites supplied prose in a selected fictional character's voice
while preserving the input format and protecting every non-prose construct.
One personality-agnostic engine drives all characters; each character is one
dossier under `references/personalities/`. The roster grows by adding
dossiers — the engine never changes.

The engine is a strict transformer with an output gate, not a Markdown
compiler wearing a fake mustache. The model transforms; a bundled script
verifies; output ships only if it passes. The transformation is not
guaranteed to preserve everything — the **accepted output** is, because
invalid output is rejected.

Primary use: easter-egg documents (`README.swanson.md` beside a repo's real
`README.md`). Secondary use: paste text in chat, get converted text back.

## Invocation

- **A personality is required.** It is named at invocation ("swanson-ize
  this", "convert README.md as Yoda"). There is no global default
  personality. If none is named, ask which character before doing anything.
- **Aliases select the dossier.** Each dossier's header declares trigger
  `aliases`; match the user's request against them across the roster.
- **Modes are per-personality.** A dossier may declare `modes`; one is marked
  `default_mode`. Select a non-default mode only when the user names it.
  Ron Swanson defaults to The Full Swanson.
- **Input** is pasted text, HTML, or Markdown in chat, or a file path.
- **Output format always matches input format.** Markdown in → Markdown out.
  HTML in → HTML out with every tag and attribute intact and only text nodes
  converted. Plain text in → plain text out.
- **File input writes a sibling file** `<name>.<suffix>.<ext>` — e.g.
  `README` + suffix `swanson` + `md` → `README.swanson.md`. The suffix is
  declared by the dossier. Never write in place unless the user explicitly
  asks for it.

## Workflow

Run this sequence for every conversion:

1. **Load the dossier** for the selected personality from
   `references/personalities/<id>.md`. Read only that one file — other
   personalities stay out of context. Apply its speech patterns, vocabulary,
   riff themes, anti-patterns, preamble guidance, and selected mode.
2. **Classify** every span of the source into the three content classes
   (Protected / Conservative / Free) defined below. Do this before writing a
   single word.
3. **Transform** the Free and Conservative spans in voice; copy Protected
   spans through byte-identically; prepend the preamble per the placement
   rules.
4. **Write the result to a temporary file** — never directly to the sibling
   path.
5. **Run the output gate** from this skill's directory:

   ```bash
   python3 scripts/validate_output.py SOURCE TEMP
   ```

   `SOURCE` is the original file (or a temp file holding the pasted source);
   `TEMP` is the transformed temp file. Exit 0 = pass; exit 1 = fail with a
   per-region report.
6. **On pass**, move the temp file to the sibling path
   `<name>.<suffix>.<ext>`. **On fail**, do not create the sibling file.
   Report the damage the gate named — region type, occurrence index, expected
   content, what was found — and **retry once** with stricter adherence,
   correcting exactly the regions the gate flagged. If the retry also fails,
   keep the temp file for diagnostics only and report the failure. **Never
   ship failed output and never silently downgrade to writing anyway.**
7. **Chat inputs validate the same way.** Pasted Markdown or HTML is written
   to a temp file, validated against the supplied source (also via a temp
   file) before the result is returned. Plain text with no recognized
   protected constructs needs no region validation.

The gate enforces **structural** invariants only: protected-region type,
order, count, and exact contents (compared region-by-region, not one
concatenated hash); link-class rules; zero unresolved same-document anchors;
matching output format, line-ending style, and final-newline state. Factual
integrity, quote classification, legal-text recognition, and voice quality
are enforced by these instructions and by review — the script does not check
them, so honor them yourself.

## Preamble

The preamble is the engine's wrapper — the character saying "here you go." It
is **not** part of the transformed body; mode liberty rules govern the body
only. It appears in **every output, every personality, every mode.**

- **Length:** 1–3 lines, in character, funny. Brief & Blunt uses exactly one
  short line.
- **Placement:**

  | Input | Preamble goes |
  |---|---|
  | Plain text | At the beginning. |
  | Markdown without frontmatter | At the beginning, as a blockquote. |
  | Markdown with YAML frontmatter | Immediately after the closing frontmatter delimiter, as a blockquote. |
  | HTML document | First child of `<body>`, as a `<blockquote>`. |
  | HTML fragment | Before the first convertible text node. |

Emit the transformed document plus this preamble and nothing else. Add no
"Here's the Ron Swanson version" framing, no trailing meta-commentary, no
notes about what you did.

## Content handling — three classes

Classify every span before transforming.

### Class 1 — Protected (byte-identical)

Executable, referential, legal, and machine-readable content. Copy through
character-for-character, in original order, unchanged:

- fenced and indented code blocks
- inline code spans
- `<code>` / `<pre>` / `<kbd>` / `<samp>` / `<script>` / `<style>` /
  `<textarea>` / `<template>` contents
- HTML comments
- YAML frontmatter
- badges / shields
- HTML tags and attributes (including `alt`, `title`, `aria-label` —
  accessibility text is preserved in HTML)
- file paths
- version numbers
- license and legal text
- link destinations (see Link classes)

Code is data, not prose. A fenced block keeps its info string; an indented
block keeps its indentation; an inline span keeps its backticks and contents.

### Class 2 — Conservatively transformed

Headings, table headers, navigation labels, and instructional prose
(requirements, installation steps, warnings). Transform under the meaning
floor and factual-integrity rules; the result must remain followable and
scannable. **Exception — headings:** reproduce every heading verbatim and in
original order, including duplicate headings; do not rename, merge, or
deduplicate them, because same-document anchors depend on exact heading text
(see Anchor repair for the one permitted change).

### Class 3 — Freely transformed

Descriptive and expressive prose. Full personality treatment, subject to
factual integrity and anti-caricature. Default liberty is full editorial license — the character may riff, add asides, and add in-character commentary; a dossier or mode may restrict this.

### Class boundaries

- **Markdown image alt text is convertible** (class 2). **HTML attributes are
  not** (class 1) — `alt`, `title`, and `aria-label` in HTML stay verbatim.
- **Natural-language instructions** ("run the installer, then restart the
  service") are prose (class 2), not protected commands. Command protection
  is **structural**: it applies to explicitly delimited machine-readable
  content only (code fences, spans, the tags above).
- **Table structure is protected:** the delimiter row (`| --- | --- |`),
  column count, and cell layout stay exact; only cell text that is class 2/3
  prose may be voiced. **Task-list checkbox syntax** (`- [x]` / `- [ ]`) and
  its state are protected; only the trailing label text is eligible.

## Link classes

- **External URLs and non-fragment destinations:** byte-identical, always.
  This covers inline destinations, reference-style definitions, autolinks,
  bare `http(s)://` URLs, and HTML `href`/`src`. Only link *text* is voiced.
- **Relative links with a path component** (`guide.md#setup`): external to the
  current document; unchanged.
- **Same-document fragment links** (`#installation`): may change **only** to
  repair a renamed heading's anchor, and the repaired fragment must resolve
  to exactly one heading in the output.
- **Fragments inside code or other protected regions:** untouched.

## Anchor repair

- Because headings are reproduced verbatim (class 2 exception above), anchors
  normally need no repair. Repair applies only if a heading legitimately
  changed.
- Compute slugs with GitHub's heading-ID behavior. Use the GitHub-compatible
  slug implementation already vendored in the runtime — `gfm_slug` in
  `scripts/validate_output.py` — not a hand-rolled algorithm.
- Duplicate headings receive renderer-compatible numeric suffixes
  (`-1`, `-2`, …) exactly as the slug function assigns them.
- The gate confirms every rewritten same-document fragment resolves uniquely;
  an unresolved fragment fails validation.

## Quotes

- **Attributed quotations** — a named person, a testimonial, cited material,
  or any blockquote followed by an em-dash attribution — are reproduced
  **byte-for-byte**, including punctuation and the attribution line. This is a
  hard rule, not a hope.
- **Decorative callout text converts** — its existing wording may be re-voiced
  in tone. But **no blockquote gains new sentences, asides, or commentary**:
  converting a callout means re-voicing the text that is there, never
  appending to it or changing its factual content or length beyond tone.
  Admonitions, notes, and warnings additionally keep meaning-floor
  followability.
- **Unsure → untouched.** If you cannot tell whether a blockquote is a real
  quotation, leave it exactly as written.

## Factual integrity (universal invariant)

Voice changes tone, never content or claims. Preserve factual propositions,
names, dates, quantities, comparisons, and qualification levels. In-character
additions must be clearly rhetorical and must not:

- introduce personal authorship or attribution claims absent from the source
  (do not turn an anonymous "we built this" into "I built this");
- fabricate instructions, remedies, or steps that replace the source's actual
  guidance (do not replace "check connectivity" with invented advice);
- assert reliability or quality claims the source does not make ("works most
  of the time");
- convert qualified claims into absolute ones;
- attribute fictional opinions to real people or organizations.

Quantifiers are qualifications: "multiple machines" does not become "every
machine you own", "some users" does not become "all users".

Do not editorialize about the document's own content or the task itself
(never call a documented section "a fake problem"). Voiced commentary stays
in-character narration about the subject matter, not meta-commentary that
undermines the document's credibility.

## Voice quality (anti-caricature)

- Character comes from sentence rhythm, worldview, priorities, and rhetorical
  habits — not catchphrase insertion.
- **No signature phrase more than once per document.** Not every paragraph
  gets a character reference. Rate-limit persona markers rather than leaving
  frequency to chance.
- Scale characterization to source length: a short document gets a light
  touch, not a saturated one.
- When voice conflicts with the reader's ability to use the document, the
  voice yields — clarity wins.

## Intellectual property

- Canonical dialogue may be studied for analysis but is never copied into
  dossiers or emitted as stock output.
- Do not reproduce or substantially paraphrase memorable copyrighted
  dialogue. Capture abstract stylistic traits, not quotation banks.
- All dossier examples are newly written.

## File fidelity

- Preserve LF vs CRLF line endings and the presence or absence of a final
  newline. The gate fails output that changes either.
- Do not normalize whitespace outside converted prose.

## Markdown dialect (v0.1.0)

Supported: GitHub Flavored Markdown — YAML frontmatter, fenced and indented
code blocks, tables, task lists, autolinks, reference-style links, and raw
HTML blocks.

Conservatively preserved (treated as Protected, not transformed): MDX,
template languages (Hugo/Jekyll shortcodes), Mermaid, math, and app-specific
extensions.

## Non-goals (v0.1.0)

- Generation of canonical dialogue or exact impersonation
- Modification of code, configuration, or executable commands
- Full MDX / template-language support
- Semantic rewriting of legal text
- Transformation of HTML accessibility attributes
- In-place file modification by default
- Chunked large-document processing

## Known limitations

- Intended for README-scale documents. Large documents are processed in one
  pass and may exceed practical context or voice-consistency limits.
- MDX, template languages, and app-specific Markdown extensions are
  conservatively preserved, not transformed.
- If validation fails after one retry, no final output file is produced.
- The gate's guarantee is structural only; factual integrity, quote
  classification, legal-text recognition, and voice quality rest on these
  instructions and on review.
