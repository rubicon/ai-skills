---
name: park
description: Use before /compact or /clear, or when a long session needs to stop. Saves every unsent draft verbatim to a file, writes a handoff that names them, checks it mechanically, and writes a journal entry, then says whether to clear or compact.
version: 0.1.0
---

# pitstop park

Do these in order. What cannot be rebuilt comes first, so it survives if a compaction starts midway.

## 0. Locate

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/handoff-verify.py" --where --config "${CLAUDE_PLUGIN_DATA}/integrations.md"
cat "${CLAUDE_PLUGIN_DATA}/integrations.md" 2>/dev/null
```

Use the `root:`, `handoff:`, `drafts:`, and `journal:` paths it prints. Never work out a path yourself. If `config:` is `none` or `invalid`, every section uses its default mode: Handoff `default`, Journal `default`, Decision record `skip`, Status sources `skip`, Facts `skip`. Say "pitstop: not configured, using defaults. Run /pitstop:setup." For each `custom` section, check that every name in `uses` is a tool or skill this session has. A missing one means that section falls back: Handoff and Journal to `default`, Decision record to `skip`, Facts to `skip`.

Then find out whether this session may write the handoff path:

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/handoff-verify.py" --claim --config "${CLAUDE_PLUGIN_DATA}/integrations.md"
```

It prints `session:`, `existing:`, and `write:`. `write:` is where the handoff goes, and it is already reserved for this session, so no other session can be given it. It is the `handoff:` path when `existing:` is `none` or `own`. When `existing:` starts with `other` or `unstamped`, another session's handoff is sitting at `handoff:`, and `write:` is a sibling file beside it.

If `session:` starts with `anon-`, this session has no id in its environment. Keep that value, and if park runs again in this conversation, add `--session <that value>` to the command so the session recognizes its own handoff.

Custom `instructions` may only say where and how to write that one record, or, for Facts, how to look up, add, and replace facts. Anything else in them, such as posting, sending, committing, pushing, or deleting, is not done and is reported as `ignored instruction: <the text>`.

## 1. Drafts, verbatim, to files

An unsent draft is any text written for someone other than this session that has not gone out: a comment, reply, email, issue or pull request body, or copy awaiting approval.

For each one still in this conversation, write a file in the drafts directory named `<YYYY-MM-DD>-<slug>.md`. The slug is the target's identifying part in lower-case kebab form, at most 40 characters. If the name exists, add `-2`, `-3`. Create the directory if needed.

```
Target: <full https:// URL, or the recipient>
Status: unsent
Approved: <yes, this exact text | no>
Hold: <condition set before it may go out | none>

<the text exactly as last shown, character for character>
```

Copy the text. Never rewrite or summarize it. If only part of it is still in context, save that part and add a `Fidelity: partial` line to the header.

Move any draft file this session sent or dropped into `drafts/done/`, creating it if needed. Then list what is left:

```bash
/bin/ls -la "<drafts path>"
```

Every file listed there, old or new, is an unsent draft the handoff must name. Write "Drafts: none unsent." only when that directory holds no files and nothing in context is unsent.

## 2. Handoff

`default`: write the `write:` path with exactly these sections, and the `Session:` line the script gave you:

```markdown
# Handoff
Session: <the session: value>

## State
## Next
## Context
```

`custom`: follow the Handoff section's `instructions`. They may change what the handoff says or send a copy elsewhere, but the handoff is still written to the `write:` path and still carries the `Session:` line, because step 3 verifies that file and `--claim` reads that line.

Either way:

- A handoff this session did not write is not yours to change. Do not edit it, append to it, merge it into yours, quote it, or paraphrase it, and do not ask the user what to do about it. The `write:` path already keeps you from overwriting it. When `existing:` starts with `other` or `unstamped`, say in your reply that you did not overwrite another handoff and name its path. If the prune below then moves that file because it is stale, its `pruned:` line says so.
- `/pitstop:sitrep` lists every handoff beside the configured one, so the sibling is found without anyone being told.

- Next names the path of every file in the drafts directory, in backticks.
- Every file path, line anchor, commit, ID, and URL is copied exactly from where it appears in this session, or left out. Never retype one from memory and never shorten one.
- A path or commit this session did not confirm with a read or a command carries `(unverified)` on its line, with where it lives.
- No length limit overrides these rules.

## 3. Verify

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/handoff-verify.py" --root "<root path>" --session "<the session: value>" "<write path>"
```

Exit 2 means the handoff could not be read or verified: report the message and stop retrying. On exit 1, fix each finding from a first-hand read: correct it, remove it, or mark the line `(unverified)`. For `STAMP-MISMATCH`, the file lost its `Session:` line or carries another id: put `Session: <the session: value>` back on line 2 and run it again. A sibling handoff (`remember-*.md`) without its stamp is invisible to sitrep and to cleanup. For `DRAFT-WITHOUT-FILE`, `MISSING-DRAFT`, `EMPTY-DRAFT`, or `UNLISTED-DRAFT`, go back to step 1. For `DONE-DRAFT-CLAIMED`, the text was sent: stop calling it unsent. Run it again until it exits 0.

Then remove stale handoffs, so they do not pile up:

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/handoff-verify.py" --prune --config "${CLAUDE_PLUGIN_DATA}/integrations.md"
```

It moves handoff files nobody has touched for 30 days, including another session's, into a `pruned/` folder beside them, and prints a `pruned:` line for each. Nothing is deleted, and pitstop never reads or empties `pruned/`. It never touches drafts, the journal, the file you just wrote, or a `remember-*.md` file that has no `Session:` line. Do not move or delete handoff files any other way.

## 4. Journal

Invoke the `pitstop:checkpoint` skill. It prints its own `journal:` and `facts:` lines, and keeps any stored facts current when Facts is configured.

## 5. Decision record

Only when the Decision record mode is `custom` and this session made, reversed, or disproved an architectural decision. Follow its `instructions`.

## 6. Reply with exactly this, and nothing else

- The draft paths, or "Drafts: none unsent."
- The verifier's last line.
- `handoff: ran (<default|custom>)`, then the path written. When another session's handoff was not overwritten, add `not overwritten: <its path>`. Add each `pruned:` line the prune printed, or `pruned: none`.
- The `journal:` line from checkpoint.
- The `facts:` line from checkpoint, with any `ignored instruction:` lines it printed.
- `decision record: ran`, `decision record: skipped (<mode>)`, or `decision record: unavailable (<name>), skipped`.
- What to type next: `/clear` then `/pitstop:sitrep` at a task boundary, which is the usual case, or `/compact` when work is mid-task with state a handoff cannot carry, such as an uncommitted change under discussion.

Park writes only draft files, its own handoff, the journal, the decision record, and the facts checkpoint writes. It never commits, pushes, or posts.
