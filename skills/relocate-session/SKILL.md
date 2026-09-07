---
name: relocate-session
version: 1.0.0
description: >-
  Use when moving a Claude Code session to a different project directory, or
  when a project directory itself has moved or been renamed. Changing the
  working directory silently orphans auto-memory, which is keyed to the old
  path — this carries it across, reports what stays behind, and verifies the
  result. Triggers on "move this session to", "switch to the X repo",
  "continue this in another directory", "I renamed the project directory",
  "change_directory", "my memories stopped loading after I moved".
---

# Relocate Session

`change_directory` moves a session and its whole conversation history in one call. It does
**not** move auto-memory. Auto-memory lives at `~/.claude/projects/<slugified-cwd>/memory/`,
so after the move the session reads a different — usually empty — directory and every stored
memory silently stops loading. Nothing warns you.

This is the procedure. Its only job is to finish the second half.

## 1. Pick the scope

Ask which one this is if it isn't obvious:

| Scope | Meaning | What changes |
|---|---|---|
| **Session move** | This session continues its work somewhere else. The old path still exists and still gets used. | Copy memory. Leave the old memory directory alone — other sessions there still need it. |
| **Project move** | The project directory itself moved or was renamed. Nothing will run at the old path again. | Copy memory. The old directory becomes a stale leftover — say so and let the user decide whether to delete it. Never delete it yourself. Other sessions still running at the old path do **not** follow; see step 5. |

Both scopes run the same copy. Only the reporting differs.

## 2. Resolve both memory directories

The slug is the absolute path with **every character outside `[a-zA-Z0-9]` replaced by `-`**,
including the leading `/`. Dots, slashes, spaces, underscores and tildes all become `-`.

```bash
slug() { python3 -c 'import re,sys; print(re.sub(r"[^a-zA-Z0-9]","-",sys.argv[1]))' "$1"; }
SRC="$HOME/.claude/projects/$(slug "$OLD_ABS_PATH")/memory"
DST="$HOME/.claude/projects/$(slug "$NEW_ABS_PATH")/memory"
```

**Verify, do not assume.** If `$SRC` does not exist, do not conclude there is no memory —
find the directory by inspection instead. Every transcript records its own `cwd`:

```bash
grep -l -F "\"cwd\":\"$OLD_ABS_PATH\"" "$HOME"/.claude/projects/*/*.jsonl | head
```

A session that has already been relocated keeps its transcripts in the directory it started
in, so the recorded `cwd` and the directory name legitimately disagree. Trust the directory
that actually holds the `memory/` files.

## 3. No memory at the source? Skip it

If `$SRC` is absent or empty, there is nothing to carry. Say one line and move on to step 5.
No ceremony.

## 4. Copy — never move, never overwrite

Another session may already be working in the destination. Copy non-colliding files, merge
the `MEMORY.md` index rather than replacing it, and report every collision.

```bash
mkdir -p "$DST"

# Report collisions — these are NOT copied, the destination's version wins.
for f in "$SRC"/*.md; do
  b=$(basename "$f")
  [ "$b" = "MEMORY.md" ] && continue
  [ -e "$DST/$b" ] && echo "COLLISION (kept destination): $b"
done

cp -n "$SRC"/*.md "$DST"/ 2>/dev/null   # -n never clobbers

# Merge index lines: keep the destination's MEMORY.md, append source lines it lacks.
if [ -e "$SRC/MEMORY.md" ] && [ -e "$DST/MEMORY.md" ]; then
  awk 'FNR==NR{seen[$0];next} /^[[:space:]]*-/ && !($0 in seen)' "$DST/MEMORY.md" "$SRC/MEMORY.md" > "$DST/.merge.tmp"
  [ -s "$DST/.merge.tmp" ] && cat "$DST/.merge.tmp" >> "$DST/MEMORY.md"
  rm -f "$DST/.merge.tmp"
fi

# Verify. Do not report success without this.
for f in "$SRC"/*.md; do
  b=$(basename "$f")
  [ -e "$DST/$b" ] || echo "MISSING: $b"
done

# Count via glob, not `ls` — `ls` is aliased to eza on some machines and prints nothing.
count() { set -- "$1"/*.md; [ -e "$1" ] && echo $# || echo 0; }
echo "source=$(count "$SRC") destination=$(count "$DST")"
```

Report the collision list, the two counts, and any `MISSING:` line. A `MISSING:` line means
the copy failed — stop and say so rather than moving the session on top of it.

## 5. Check whether the target is already occupied

```
mcp__ccd_session_mgmt__list_sessions
```

If a session is already running in the destination, say so and offer to send it a context
message with `mcp__ccd_session_mgmt__send_message`. Use the real `sessionId` from
`list_sessions` — the short `[abc123]` display id from `ListAgents` is **not** a valid
`session_id` and the call fails with it.

On a **project move**, also check for sessions still running at the *old* path. You cannot
relocate another session from here; only it can call `change_directory` on itself. Offer to
message each one so it can move itself.

## 6. Move the session

```
mcp__ccd_directory__change_directory  path: <absolute target path>
```

The working directory only takes effect when the turn ends, so **every path used in the same
turn must be absolute** — relative paths still resolve against the old directory.

Do this last. If the memory copy failed, you have not moved yet.

## 7. Report what did not follow

Always state these three, briefly. They are the parts that surprise people.

- **`.remember/`** — lives inside the repo, so it stays with the old one. That is usually
  correct: it belongs to that project's work, and copying it mixes unrelated contexts.
  Surface it as a decision for the user. **Never move it silently.**
- **Environment variables** — anything the old directory's settings exported is already in
  the process and cannot be unset by moving. The new directory's settings env applies on top
  of it, it does not replace it.
- **Everything else switches automatically** — project `CLAUDE.md`, settings, permissions,
  hooks, MCP servers, and skills all come from the new directory from here on. Say so, so
  the user knows what changed under them.

## Common mistakes

| Mistake | What happens |
|---|---|
| Calling `change_directory` and stopping there | Memory silently stops loading. This is the whole reason the skill exists. |
| Assuming the slug and skipping verification | You copy into a directory nothing reads, and report success. |
| `mv` instead of `cp` | The old session loses its memory mid-flight. |
| `cp` without `-n` | You overwrite another session's memory files. |
| Overwriting `MEMORY.md` | The destination's index is destroyed; its memories stay on disk but stop being loaded. |
| Using the short `[abc123]` display id as `session_id` | The message call fails. Use `sessionId` from `list_sessions`. |
| Relative paths in the same turn as the move | They resolve against the old directory. |
