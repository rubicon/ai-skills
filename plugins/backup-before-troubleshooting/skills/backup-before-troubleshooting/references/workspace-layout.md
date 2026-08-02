# Workspace layout

The directory scheme, the three README levels, the six per-effort docs, and how the program's
own version is recorded. Read this before seeding a new effort by hand; `new-recovery-effort.sh`
seeds the per-effort files for you.

## Directory scheme

```
${RECOVERY_ROOT:-~/Recovery}/          # root: the program directory
  README.md                            # program directory (level 1)
  {Program}/                           # one folder per program worked on
    README.md                          # effort index (level 2)
    YYYY-MM-DD_HHMMSS_<goal-kebab>/    # one recovery effort
      README.md          # effort doc (level 3)
      CHANGELOG.md
      DECISIONS.md
      RESTORE.md
      CURRENT-STATE.md
      MANIFEST.md
      files/             # backups (copied + referenced-in-place)
      evidence/          # diagnostic record (protected)
```

- `{Program}` names the target in a human-stable way (e.g. `Claude`, `UniFi`, `Plex`). It is a
  path segment, so keep it simple; the human-readable identity lives in the level-1 README.
- The effort folder name's timestamp is **when the effort began**, not when the first backup was
  taken. Always keep the timestamp — it differentiates similar efforts and aids retrieval.
- `<goal-kebab>` is a short kebab-case goal, e.g. `app-hangs-on-launch`.

## The three README levels

Each level answers a different question. Keeping them separate is what stops the top-level index
from rotting into detail.

### Level 1 — `${RECOVERY_ROOT}/README.md` (program directory)

A thin signpost: one row per program, mapping the program folder to a human-readable identity.
**No dates, no efforts, no versions.** It changes only when a new program is recovered for the
first time.

```
# Recovery workspaces

| Program | What it is |
|---|---|
| Claude  | Claude Desktop — Anthropic's macOS desktop app |
| UniFi   | UniFi Network controller (self-hosted) |
```

### Level 2 — `${RECOVERY_ROOT}/{Program}/README.md` (effort index)

One row per recovery effort for this program: folder name, dates, topic, outcome, and the
**program version** (see below). This is the table you scan to find a past effort.

```
# Claude — recovery efforts

| Effort folder | Dates | Topic | Program version | Outcome |
|---|---|---|---|---|
| 2026-06-20_141103_app-hangs-on-launch | 2026-06-20 → 06-23 | Hard hang on launch | 1.4.2 → 1.5.0 | Resolved: GPU-accel flag |
```

### Level 3 — `${RECOVERY_ROOT}/{Program}/{effort}/README.md` (the effort doc)

What this effort is, the incident, and the layout. Carries a **program-version line** at the top
as fixed context. One of the six per-effort docs below.

## The six per-effort docs

`new-recovery-effort.sh` seeds these. Templates (the recovery docs deliberately omit any
"Generated:" footer):

### `README.md`
```
# {Program} recovery — {goal}

Program version: {version-span}
Effort started: {YYYY-MM-DD HH:MM}

## Incident
One or two sentences: what is wrong, what triggered this effort.

## Layout
- files/    — backups (copied at mirrored absolute paths; large folders referenced in place)
- evidence/ — logs, command output, screenshots (protected; never deleted)
- MANIFEST.md, CHANGELOG.md, DECISIONS.md, RESTORE.md, CURRENT-STATE.md
```

### `CHANGELOG.md` — the running detail log, newest first
```
# Changelog — {goal}

## {YYYY-MM-DD HH:MM}
- Started the effort; seeded the workspace.
```

### `DECISIONS.md` — ADR-style; each hypothesis, the conclusion, and what was ruled out
```
# Decisions — {goal}

## D1 — {hypothesis}
- Status: open | confirmed | ruled out
- Test:
- Conclusion:
- Ruled out:
```

### `RESTORE.md` — the restore runbook for this effort's backups
```
# Restore runbook — {goal}

See the skill's restore runbook for the procedure. Per-artifact restore steps go here as
backups are added, with the dry-run, move-aside, restore, and re-verify commands for each.
```

### `CURRENT-STATE.md` — what is true on disk right now; overwritten each run
```
# Current state — {goal}

> Gotchas (read first): none yet.

Last updated: {YYYY-MM-DD HH:MM}

What is currently true on disk, what is backed up, what has been changed.
```

**Amnesia rule:** before overwriting `CURRENT-STATE.md` on a new run, roll its prior contents
into a `CHANGELOG.md` entry. The live doc stays current without losing history.

### `MANIFEST.md` — one table of every artifact
```
# Manifest — {goal}

## Copied into files/
| Artifact | Original absolute path | Purpose | Program version | Confidence |
|---|---|---|---|---|

## Referenced in place (not copied)
| Artifact (marked path) | Original location | Purpose | Program version | Confidence |
|---|---|---|---|---|
```

## Program version — three granularities

This is the **application's** version (e.g. Claude Desktop 1.5.0), unrelated to the skill's own
SemVer. Record it at three scopes, each correct for its scope:

1. **Effort index (level 2) — a version column, per effort.** May be a range when the build
   changed mid-effort: `1.4.2 → 1.5.0`, or enumerated `1.2, 1.3, 2.0`.
2. **Effort README (level 3) — a version line at the top**, the same per-effort span. Fixed once
   the effort closes, so it never goes stale.
3. **MANIFEST — per-artifact, absolute point-in-time version**: the single build in effect when
   *that* backup was taken.

Cross-check: the effort-index range should equal the span of the manifest's per-artifact
versions. If they disagree, one of them is wrong. The version does **not** appear in the level-1
program-directory README.
