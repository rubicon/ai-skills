# Personality Dossier Contract

Every personality is one file: `references/personalities/<id>.md`. It must
pass `python3 scripts/validate_dossier.py references/personalities/`.

## Header (machine-readable, required)

```yaml
---
id: ron-swanson            # kebab-case, matches the filename
display_name: Ron Swanson
suffix: swanson            # sibling-file suffix: README.swanson.md
default_mode: full-swanson # required if modes present; must appear in modes
aliases: [ron swanson, ron, swanson, swanson-ize]   # unique across roster
modes: [full-swanson, brief-and-blunt, duke-silver] # optional
---
```

## Required body sections (exact `##` headings)

- `## Identity` — who the character is, one paragraph. Character comes from
  worldview and rhythm, not catchphrases.
- `## Speech Patterns` — sentence structure, rhythm, diction, punctuation
  habits. These rules do the heavy lifting.
- `## Vocabulary` — signature words/phrasings the character reaches for, and
  banned words they would never use.
- `## Riff Themes` — topics the character detours into under full editorial
  license.
- `## Anti-Patterns` — what this character would NEVER say or do in text.
- `## Preamble` — how this character hands over a document (1–3 lines,
  in character, funny).
- `## Modes` — required when the header declares modes: each mode's behavior
  and liberty level, default marked.
- `## Examples` — one `### Example (<mode>)` per mode (or
  `### Example (default)` if mode-less), each with `**Before:**` and
  `**After:**` on the SAME source paragraph.

## Hard rules (all personalities)

- **No quote banks.** Canonical dialogue may be studied for analysis but is
  never copied into the dossier or emitted as stock output. Capture abstract
  stylistic traits. All examples are newly written.
- **Factual integrity.** Riffs are rhetorical only — no new factual claims
  about the source subject, no qualified→absolute upgrades, no fictional
  opinions attributed to real people or organizations.
- **Anti-caricature.** No signature phrase more than once per document; not
  every paragraph gets a character reference; scale characterization to
  source length.
- **Clarity wins.** When voice conflicts with the reader's ability to use
  the document, the voice yields.
