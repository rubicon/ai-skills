---
name: backup-before-troubleshooting
description: >-
  Stand up a dated, self-documenting recovery workspace BEFORE changing system, app, or
  configuration state, so every change is reversible and the whole effort can be forensically
  reconstructed afterward — including regressions caused by your own fixes. Use this whenever
  you are about to mutate config, application data, system files, or installed components
  during troubleshooting AND want to be able to both undo the changes and reconstruct what
  happened later. Trigger phrases: "back this up first", "before I start messing with this",
  "I want to be able to undo this", "set up a recovery folder", "track this troubleshooting",
  or when resuming an effort that already has a recovery workspace. Do NOT use for read-only
  diagnosis, trivially reversible edits, or code work already tracked by git.
version: 0.1.0
---

# backup-before-troubleshooting

This skill is the discipline behind a recoverable, self-documenting troubleshooting effort. It
is also the **single source of truth** for the safety and scripting rules: the plugin's
commands (`new-recovery-effort`, `recovery-status`, `cleanup`) defer to the rules here rather
than restating them, so there is one place to read and one place to change.

The rules below are not style preferences. Each one is here because its absence caused real
damage during the multi-day desktop-app recovery this generalizes. Where a rule has a "why",
read it — understanding the failure it prevents is what lets you apply it to a new situation
instead of following it blindly.

## When to use

Use this when **both** are true:

1. You are about to **mutate** state — config, application data, system files, installed
   components, extensions/plugins — as part of troubleshooting, and
2. You want to be able to **undo** the changes **and** **forensically reconstruct** what
   happened later (which change caused what, including a fix that introduced a new problem).

Also use it when **resuming** an effort that already has a recovery workspace.

## When not to use

- Read-only diagnosis, quick questions, or trivially reversible edits.
- Code work already under version control — git already gives you reversibility and history.
- Backing up a single directory of plain-text config: a quick `git init` there is lighter than
  a full effort. Reach for this skill when the change spans system/app state, when you need the
  forensic narrative, or when "undo" means more than `git checkout`.

## Platform assumptions

macOS-first (Time Machine, `~/Library/Application Support`, `rsync -aE`, iCloud). The
discipline is portable; the exact commands are not. Two cross-platform hazards are called out
where they bite (xattr flags, iCloud placeholders). Before adapting to Linux, read
[references/platform-notes.md](references/platform-notes.md).

## Core model: the recovery effort

The unit of organization is the **recovery effort** — one named goal that may span hours or
days and accumulate many backups and diagnostic artifacts. One effort is one folder. It is
**not** one folder per file, per command, or per step; individual artifacts and their
timestamps are **rows in a manifest**, never their own folders. (Folder-per-artifact was tried
and produced an unnavigable sprawl that defeated reconstruction.)

"Recovery effort" is prose only. The phrase never appears in a path.

## Workspace layout

```
${RECOVERY_ROOT:-~/Recovery}/          # root: the program directory
  README.md                            # program directory — program-folder -> human identity
  {Program}/
    README.md                          # effort index — one row per effort (+ program version)
    YYYY-MM-DD_HHMMSS_<goal-kebab>/    # one recovery effort; timestamp = when the effort began
      README.md          # what this effort is; the incident; the layout
      CHANGELOG.md       # what was done and when, newest first (the running detail log)
      DECISIONS.md       # ADR-style: each hypothesis, the conclusion, and what was RULED OUT
      RESTORE.md         # the restore runbook for this effort's backups
      CURRENT-STATE.md   # what is true on disk right now; overwritten each run
      MANIFEST.md        # one table: artifact -> original absolute path -> purpose -> confidence
      files/             # backups — two populations (see below)
      evidence/          # diagnostic record — PROTECTED, never a deletion target
```

`RECOVERY_ROOT` defaults to `~/Recovery` and is configurable (see `config.example.env`). It
must be a location that is always materialized locally — never `~/Downloads` or `~/Desktop`,
which are iCloud-evictable. The three README levels and the per-effort docs (including how the
program's own version is recorded at three granularities) are specified in
[references/workspace-layout.md](references/workspace-layout.md). Read it before seeding a new
effort by hand; the `new-recovery-effort` command seeds them for you.

## The forensic core: `files/` and `evidence/`

These are **siblings**, and they are treated differently by cleanup. Keeping them separate is
deliberate: it is what lets cleanup delete backups without ever endangering the evidence.

- **`files/`** holds backups, in two populations:
  1. **Copied in** — artifacts duplicated into `files/` at their *mirrored absolute path*
     (a backup of `/Users/x/Library/.../config.json` lands at
     `files/Users/x/Library/.../config.json`). This makes the workspace self-documenting and
     restore near-symmetric. Mechanic: [references/path-preservation.md](references/path-preservation.md).
  2. **Referenced in place** — large folders that are *not* copied. They are renamed with a
     backup marker at their original location (e.g. `Claude.bak`, `claude-ext-disabled`) and
     recorded in `MANIFEST.md`. This avoids two real failures: hitting `PATH_MAX` when deep
     session caches are re-nested under `files/`, and duplicating gigabytes of app data.

- **`evidence/`** holds the diagnostic record: hang/crash logs, boot logs, command output,
  screenshots, and any log excerpts pasted during the effort. It is **protected** — never a
  deletion target (see safety principle 6).

## Safety principles (single source of truth)

1. **Discover real paths before referencing them.** Never write a command against a constructed
   or assumed path. List or stat it, confirm it exists, then act on the confirmed path. *Why:*
   an assumed path silently backs up nothing, or worse, names the wrong target for a later
   destructive step.

2. **Copy, don't move, by default.** Leave originals in place and produce duplicates. Delete an
   original only in a separate, explicit, post-verification cleanup step. *Why:* a move is a
   backup and a deletion in one irreversible motion; if the copy is bad you have destroyed the
   only good copy.

3. **Restore safely, in order:** dry-run first (`rsync -n`), move the live target aside (rename
   it with a timestamp), then restore, then re-verify the state. *Why:* a restore that
   overwrites in place can destroy the current (possibly fixed) state if the backup turns out
   to be wrong. Full runbook: [references/restore-runbook.md](references/restore-runbook.md).

4. **Document confidence.** When an artifact's purpose or origin is uncertain, say so plainly in
   `MANIFEST.md`: HIGH / MEDIUM / LOW plus a one-line note. *Why:* honest uncertainty lets a
   future reader (or a cleanup decision) weigh the artifact correctly; false precision gets
   things deleted that should have been kept.

5. **Surface recurring gotchas loudly.** If something keeps undoing an action — a restore that
   silently reverts a pinned setting, a sync that re-evicts a file — put a warning at the **top**
   of `CURRENT-STATE.md`. *Why:* the next person (often you, days later) will otherwise rediscover
   the trap the hard way.

6. **Docs and evidence are never deletion targets.** In every effort and every cleanup tier, the
   protected set is: every `*.md` at all three README levels, the six per-effort docs, and the
   entire `evidence/` folder. Cleanup only ever targets `files/` contents and the
   manifest-listed external in-place folders. *Why:* the record of what happened must outlive the
   backups it describes.

## Scripting rules

- **No `set -e` in discovery / inventory scripts.** Optional `ls`/probe commands on missing
  paths return non-zero, and with `set -e` in an interactive shell that **kills the user's
  terminal tab**. Guard probes with `2>/dev/null` and let the script run to the end.
- **Copy-paste command blocks contain no inline comments.** A block handed to the user must be
  clean, top-to-bottom executable. Explanation goes in the surrounding prose, never inside the
  block.
- **Paths: `~/` in docs, absolute in commands.** Write `~/Library/...` for readability in docs,
  but expand to the real absolute path in any command — never create a literal `~` directory.
- **Paths must be byte-accurate**, including capitals and spaces (e.g. `Claude Extensions`).
- **The internal recovery docs omit any "Generated:" footer.** They are a working record, not a
  published artifact.

## Workflows

- **Start an effort** — create the dated folder and seed the docs, then back up before each
  mutation. Use the `new-recovery-effort` command, or follow
  [references/workflows.md](references/workflows.md) to do it by hand.
- **Back up an artifact** — discover and confirm the real path (principle 1), then file it.
  Filing is a guided, discovery-first copy-paste block, intentionally **not** a turnkey script
  — see [references/workflows.md](references/workflows.md) and
  [references/path-preservation.md](references/path-preservation.md).
- **Resume** — read `CURRENT-STATE.md`, the open items in `DECISIONS.md`, and any gotcha
  warnings, then brief the user on where the effort left off. Use the `recovery-status` command.
- **Restore** — follow [references/restore-runbook.md](references/restore-runbook.md). Restore
  is a deliberate, read-each-step runbook, never a one-shot command.
- **Clean up** — use the `cleanup` command. It is gated and deliberate (user-invocation only),
  and it enforces the protected set in principle 6.
- **Already-scattered artifacts (two-pass migration)** — pass 1 discovers and reports real
  paths and moves nothing; pass 2 files them from the confirmed inventory. Never file from an
  assumed path. See [references/workflows.md](references/workflows.md).

## References

- [references/workspace-layout.md](references/workspace-layout.md) — directory scheme, the three
  README levels, the six effort docs, and the program-version model.
- [references/path-preservation.md](references/path-preservation.md) — the `rsync --relative`
  mechanic and the `-aE` (macOS) vs `-X` (GNU) cross-platform flag difference.
- [references/workflows.md](references/workflows.md) — starting, filing, and the two-pass
  migration, as comment-free copy-paste blocks.
- [references/restore-runbook.md](references/restore-runbook.md) — the safe-restore procedure.
- [references/platform-notes.md](references/platform-notes.md) — macOS assumptions, the iCloud
  source-materialization caveat, and Linux adaptation notes.
