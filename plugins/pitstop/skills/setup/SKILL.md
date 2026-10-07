---
name: setup
description: Use when configuring pitstop for the first time, or when the tools you use for handoffs, journals, decision records, project status, or stored facts have changed. Detects what this session has, recommends a configuration, confirms each choice with you, and writes the one file that park and sitrep read.
version: 0.1.0
---

# pitstop setup

Writes one file, `${CLAUDE_PLUGIN_DATA}/integrations.md`, and nothing else.

## 1. Look at what exists now

```bash
cat "${CLAUDE_PLUGIN_DATA}/integrations.md" 2>/dev/null || echo "no integrations file yet"
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/handoff-verify.py" --where --config "${CLAUDE_PLUGIN_DATA}/integrations.md"
command -v gh >/dev/null && echo "gh: present" || echo "gh: absent"
```

## 2. Detect candidates

Use only the tools and skills this session actually lists. Do not guess names.

| Section | Look for |
|---|---|
| Handoff | A skill whose name or description says it writes a session handoff |
| Journal | A tool or skill that writes a diary, journal, log, or memory entry |
| Decision record | A tool that stores architecture decision records |
| Status sources | A tool that reports issues, tickets, CI runs, or deployments for this project. `gh` is already built into sitrep, so do not list it |
| Facts | Tools that store and look up facts (a subject, a predicate, and a value) and can replace a current value |

## 3. Recommend, then confirm one section at a time

For each section show: what you detected (or "nothing"), the mode you recommend, and for `custom` the exact `uses` and `instructions`. Then ask the user to accept, edit, or pick another mode. Ask one section per question.

- Modes. Handoff: `default` or `custom`. Journal: `default`, `skip`, or `custom`. Decision record, Status sources, and Facts: `skip` or `custom`.
- Recommend `default` for Handoff and Journal, and `skip` for the other three, unless a detected tool clearly does that job.
- `uses` lists the exact tool or skill names, comma-separated, as this session shows them.
- A `custom` Handoff may change what the handoff says or also send it somewhere else, but its instructions must still write the file at the `write:` path that `--claim` prints, with its `Session:` line, because park verifies that file and uses that line to tell sessions apart.
- Facts `instructions` say which tool or command looks up, adds, and replaces a fact. Name the replace or supersede operation explicitly.
- `instructions` may say only where and how to write that one record, how to look up, add, and replace facts, or what to read for status. Never put posting, sending, committing, pushing, or deleting into them. If the user asks for that, explain that pitstop ignores such instructions at run time, and leave it out.

## 4. Write the file

If a file already exists, show it next to the new one and ask before replacing it. Then write exactly this shape, keeping the header lines and the five headings:

```markdown
---
handoff_path: .remember/remember.md
---
## Handoff
mode: default

## Journal
mode: custom
uses: example_journal_tool
instructions: |
  Write the entry with the journal tool, under the project's name.

## Decision record
mode: skip

## Status sources
mode: skip

## Facts
mode: skip
```

A file written before Facts existed has no `## Facts` section; park and checkpoint treat that as `skip`.

`handoff_path` is relative to the project root. Change it only if the user keeps handoffs somewhere else.

```bash
mkdir -p "${CLAUDE_PLUGIN_DATA}"
```

## 5. Prove it

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/handoff-verify.py" --where --config "${CLAUDE_PLUGIN_DATA}/integrations.md"
```

The `config:` line must show the file's path. If it says `invalid`, fix the header and run it again. Then print the file and one line per section saying what park and sitrep will do with it.
