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

## 0. Check the session can move at all

`change_directory` refuses outright for a session running in an isolated worktree or on a
remote host. Check before doing anything else — otherwise you do the whole memory procedure
and then discover the move was never possible.

```bash
g=$(git rev-parse --path-format=absolute --git-dir 2>/dev/null)
c=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)
[ -n "$g" ] && [ "$g" != "$c" ] && echo "WORKTREE — this session cannot be relocated."
```

If it cannot move, say so and stop. Do not reach for `request_directory` as a substitute: it
grants access to a folder, it does not move the session, and it leaves memory keyed where it
already was. The user's options are to start a session in the target directory, or to relocate
a session that is not in a worktree.

## 1. Pick the scope and the disposition

**Ask both, every time. Never assume either one**, even when the move looks routine.

### Disposition — what happens to the old memory

| Disposition | Meaning |
|---|---|
| **Copy** (default) | Both locations keep the memory. The old one still works. |
| **Move** | Copy, verify, *then* remove the source. Only ever performed as copy-then-remove, never as `mv`, and only when the gates in step 4b all pass. |

Default to copy and say that you are. The asymmetry is the reason: a stray copy leaves a
duplicate the user can see and delete, while a wrong move destroys memory that is not in
version control, from the one location that was working, with no undo.

The trap that makes move dangerous is not obvious: **memory directories are routinely shared.**
Because memory is keyed to the repo root, every session in that repo — including every
worktree session, which never has memory of its own — reads the *same* directory. "The old
path" is very often still in active use by someone else.

### Scope — what kind of move this is

| Scope | Meaning | What changes |
|---|---|---|
| **Session move** | This session continues its work somewhere else. The old path still exists and still gets used. | Copy memory. Leave the old memory directory alone — other sessions there still need it. |
| **Project move** | The project directory itself moved or was renamed. Nothing will run at the old path again. | Copy memory. The old directory becomes a stale leftover — say so and let the user decide whether to delete it. Never delete it yourself. Other sessions still running at the old path do **not** follow; see step 5. |

Both scopes run the same copy. Only the reporting differs.

## 2. Resolve both memory directories

The source is **the running session's own working directory** — with one exception. Derive it;
never hardcode a path, and never carry one over from a previous run of this skill.

**The exception: memory is keyed to the git repository root.** A session sitting in a
subdirectory of a repo reads memory from the repo root, not from the subdirectory. A session
in a worktree reads it from the *main* repo root — a worktree never owns memory. Only a path
outside any repo owns its own. Resolve this with git and confirm against disk rather than
slugging `$PWD` and trusting the result.

The slug is that absolute path with **every character outside `[a-zA-Z0-9]` replaced by `-`**,
including the leading `/`. Dots, slashes, spaces, underscores and tildes all become `-`.
Illustrative only:

| Absolute path | Project directory |
|---|---|
| `/Users/someone/dev/example.com/proj` | `-Users-someone-dev-example-com-proj` |
| `/Users/someone/Local Sites/my_app` | `-Users-someone-Local-Sites-my-app` |

The second row is the one that catches people: a rule that only maps `/` and `.` looks correct
until a path contains a space, an underscore or a tilde.

```bash
slug() { python3 -c 'import re,sys; print(re.sub(r"[^a-zA-Z0-9]","-",sys.argv[1]))' "$1"; }

# The path that owns a directory's memory: the main repo root if it is a worktree,
# otherwise the directory itself. Falls back cleanly outside a git repo.
owner() {
  local r
  r=$(git -C "$1" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) \
    && dirname "$r" || echo "$1"
}

OLD="$PWD"                   # the session's own cwd — derived, not supplied
NEW="<absolute target path>"  # the only input this skill takes
SRC="$HOME/.claude/projects/$(slug "$(owner "$OLD")")/memory"
DST="$HOME/.claude/projects/$(slug "$(owner "$NEW")")/memory"
```

Apply `owner` to **both** ends. Relocating *into* a subdirectory or a worktree has the same
asymmetry: memory copied to that path's own slug would never be read.

Verified against every memory-bearing project directory on a real machine: the rule holds in
35 of 36 testable cases, and the single exception is a session that had itself been relocated
— this bug, showing up in its own evidence.

**Verify, do not assume.** If `$SRC` does not exist, do not conclude there is no memory —
find the directory by inspection instead. Every transcript records its own `cwd`:

```bash
grep -l -F "\"cwd\":\"$OLD\"" "$HOME"/.claude/projects/*/*.jsonl | head
```

A session that has already been relocated keeps its transcripts in the directory it started
in, so the recorded `cwd` and the directory name legitimately disagree. Trust the directory
that actually holds the `memory/` files.

## 3. No memory at the source? Skip it

If `$SRC` is absent or empty, there is nothing to carry. Say one line and move on to step 5.
No ceremony.

## 4. Copy — never move, never overwrite

First, the case that looks like a move but isn't one. If both ends resolve to the same
memory directory — moving between a worktree and its main root, or into a subdirectory of the
same repo — there is nothing to carry. Say so and skip to step 5. Do not run the copy.

```bash
[ "$SRC" = "$DST" ] && echo "Same memory directory — nothing to carry."
```

Otherwise: another session may already be working in the destination. Copy non-colliding
files, merge the `MEMORY.md` index rather than replacing it, and report every collision.

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

## 4b. Only if the disposition is move: remove the source

Never `mv`, and never delete anything before the copy has been verified. All four gates must
pass. If any fails, keep the source, say which gate failed, and treat the result as a copy.

1. **Verification was clean.** No `MISSING:` line in step 4, and the destination count is at
   least the source count. A failed copy plus a deletion is data loss.
2. **Skip every file that collided.** A collision means the destination already had a
   *different* file under that name and kept its own. Deleting the source copy destroys the
   only version of that memory. Collided files stay put — say so.
3. **No other session shares the source.** Run `list_sessions` and resolve each session's
   `cwd` through `owner`. If any other session resolves to the same owner as the source, do
   not delete: they are reading that directory. Remember that worktree sessions resolve to the
   repo root, so a repo with worktrees almost always fails this gate.
4. **The user confirmed the deletion**, after seeing the file list from gate 2.

The commonest reason to want a move is *"I started this session in the wrong project."* In
that case only the memories **this session created** are pollution — everything the old
project had before belongs to it and must stay. Do not delete the whole copied set. List the
source files with modification times, separate the ones that predate this session's work, and
confirm the shorter list:

```bash
find "$SRC" -maxdepth 1 -name '*.md' -exec stat -f '%Sm  %N' -t '%Y-%m-%d %H:%M' {} \;
```

(`stat -f` is the BSD/macOS form; `stat -c '%y %n'` on GNU.)

```bash
# Only the files that were verifiably copied AND did not collide.
for f in "$SRC"/*.md; do
  b=$(basename "$f")
  [ "$b" = "MEMORY.md" ] && continue                      # index is merged, never deleted
  [ -e "$DST/$b" ] || { echo "KEPT (not copied): $b"; continue; }
  cmp -s "$f" "$DST/$b" || { echo "KEPT (collided, differs): $b"; continue; }
  rm -- "$f" && echo "removed: $b"
done
```

`cmp` is what makes this safe: it deletes a source file only when the destination holds an
identical copy. A collided file differs, so it is kept automatically even if gate 2 was
misread.

Leave `MEMORY.md` alone. Its lines were merged into the destination, but the source index
still describes whatever memory remains at the source. Prune its entries for removed files
rather than deleting the file.

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

- **Repo-local agent state** — anything an agent keeps *inside* the project stays with the
  project. Detect what is actually there; do not assume a particular name or layout, and do
  not claim a list like this is complete:

  ```bash
  # Directories only — a dotfile like .gitignore is repo content, not agent state.
  find "$OLD" -maxdepth 1 -type d -name '.*' \
       -not -name '.git' -not -name '.github' -not -path "$OLD" -print 2>/dev/null
  [ -d "$OLD/.claude/agent-memory" ] && echo "$OLD/.claude/agent-memory"
  ```

  Report whatever turns up and let the user decide per item. Leaving it behind is usually
  correct — it belongs to that project's work, and copying it mixes unrelated contexts.
  **Never move any of it silently.**
- **The transcript does follow** — this is the one thing the harness carries for you. The
  session's `.jsonl` is re-filed under the destination project directory, keeping the entries
  written before the move, and appending continues there. So the history is resumable and
  searchable from the new path, and the old project is not left holding it. Confirm it rather
  than assuming — on the turn after the move:

  ```bash
  find "$HOME/.claude/projects/$(slug "$(owner "$NEW")")" -maxdepth 1 -name '*.jsonl' | head
  ```

  Older releases left a partial copy behind at the origin instead of moving cleanly. If you
  find one, it is a stale prefix of the real transcript — report it, do not delete it.

  Memory is the thing that does *not* follow. That asymmetry is the whole reason this skill
  exists: history moves itself, memory does not, and only one of them announces itself.
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
| `mv` instead of `cp` | The old session loses its memory mid-flight. Even a move is copy-verify-remove. |
| Defaulting to move, or not asking | Memory directories are shared across every session in a repo, worktrees included. The deletion hits sessions you never considered. |
| Deleting a collided source file | The destination kept its own different file of that name, so the source version is the only copy and it is gone. |
| `cp` without `-n` | You overwrite another session's memory files. |
| Overwriting `MEMORY.md` | The destination's index is destroyed; its memories stay on disk but stop being loaded. |
| Using the short `[abc123]` display id as `session_id` | The message call fails. Use `sessionId` from `list_sessions`. |
| Relative paths in the same turn as the move | They resolve against the old directory. |
| Slugging `$PWD` inside a repo | In a subdirectory or a worktree that directory is always empty — memory belongs to the repo root. Resolve with `owner` first. |
| Running the whole procedure in a worktree session | `change_directory` refuses at the end. Check step 0 first. |
| Substituting `request_directory` for a refused move | It grants folder access; the session does not move and memory stays keyed to the old root. |
