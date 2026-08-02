#!/usr/bin/env bash
#
# new-recovery-effort.sh — seed a recovery-effort workspace.
#
# This is the ONLY script in the plugin, and by design it touches no source artifacts: it
# creates the dated effort folder, the files/ and evidence/ subdirs, the six per-effort docs,
# and the level-1 (program directory) and level-2 (effort index) README rows. Backing up,
# filing, restoring, and cleanup are deliberately NOT scripted (see the skill's safety rules).
#
# Deliberately no `set -e`: a half-aborted seed is worse than a clear error, and the skill's
# scripting rules warn against `set -e` in this family of scripts. Errors are checked explicitly.
#
# Usage: new-recovery-effort.sh <Program> <goal words...>
#   <Program>     short path-stable program name, e.g. Claude, UniFi, Plex
#   <goal words>  free text; kebab-cased for the folder, kept verbatim in the docs
#
# RECOVERY_ROOT resolution: $RECOVERY_ROOT env, else ~/.config/backup-before-troubleshooting/
# config.env, else ~/Recovery.

set -u

die() { printf 'error: %s\n' "$*" >&2; exit 1; }

[ "$#" -ge 2 ] || die "usage: new-recovery-effort.sh <Program> <goal words...>"

program="$1"; shift
goal_text="$*"

# Resolve RECOVERY_ROOT.
if [ -z "${RECOVERY_ROOT:-}" ] && [ -f "$HOME/.config/backup-before-troubleshooting/config.env" ]; then
  # shellcheck disable=SC1091
  . "$HOME/.config/backup-before-troubleshooting/config.env"
fi
RECOVERY_ROOT="${RECOVERY_ROOT:-$HOME/Recovery}"
RECOVERY_ROOT="${RECOVERY_ROOT/#\~/$HOME}"

# Kebab-case the goal for the folder name; keep goal_text verbatim for the docs.
goal_kebab=$(printf '%s' "$goal_text" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd 'a-z0-9-' )
goal_kebab="${goal_kebab:-effort}"

ts=$(date "+%Y-%m-%d_%H%M%S")
started=$(date "+%Y-%m-%d %H:%M")

program_dir="$RECOVERY_ROOT/$program"
effort_dir="$program_dir/${ts}_${goal_kebab}"

mkdir -p "$effort_dir/files" "$effort_dir/evidence" || die "could not create $effort_dir"

# --- level 1: program directory README (signpost; no dates/efforts/versions) ---
root_readme="$RECOVERY_ROOT/README.md"
if [ ! -f "$root_readme" ]; then
  {
    printf '# Recovery workspaces\n\n'
    printf '| Program | What it is |\n|---|---|\n'
    printf '| %s | %s |\n' "$program" "TODO: one-line identity of $program"
  } > "$root_readme"
elif ! grep -q "| $program |" "$root_readme" 2>/dev/null; then
  printf '| %s | %s |\n' "$program" "TODO: one-line identity of $program" >> "$root_readme"
fi

# --- level 2: per-program effort index README ---
program_readme="$program_dir/README.md"
if [ ! -f "$program_readme" ]; then
  {
    printf '# %s — recovery efforts\n\n' "$program"
    printf '| Effort folder | Dates | Topic | Program version | Outcome |\n|---|---|---|---|---|\n'
  } > "$program_readme"
fi
printf '| %s | %s → | %s | TBD | in progress |\n' "${ts}_${goal_kebab}" "$(date +%Y-%m-%d)" "$goal_text" >> "$program_readme"

# --- level 3: the six per-effort docs ---
cat > "$effort_dir/README.md" <<EOF
# $program recovery — $goal_text

Program version: TBD
Effort started: $started

## Incident
TODO: one or two sentences — what is wrong, what triggered this effort.

## Layout
- files/    — backups (copied at mirrored absolute paths; large folders referenced in place)
- evidence/ — logs, command output, screenshots (protected; never deleted)
- MANIFEST.md, CHANGELOG.md, DECISIONS.md, RESTORE.md, CURRENT-STATE.md
EOF

cat > "$effort_dir/CHANGELOG.md" <<EOF
# Changelog — $goal_text

## $started
- Started the effort; seeded the workspace.
EOF

cat > "$effort_dir/DECISIONS.md" <<EOF
# Decisions — $goal_text

## D1 — TODO: first hypothesis
- Status: open
- Test:
- Conclusion:
- Ruled out:
EOF

cat > "$effort_dir/RESTORE.md" <<EOF
# Restore runbook — $goal_text

See the skill's restore runbook for the procedure (dry-run → move aside → restore → re-verify).
Per-artifact restore steps go here as backups are added.
EOF

cat > "$effort_dir/CURRENT-STATE.md" <<EOF
# Current state — $goal_text

> Gotchas (read first): none yet.

Last updated: $started

TODO: what is currently true on disk, what is backed up, what has been changed.
EOF

cat > "$effort_dir/MANIFEST.md" <<EOF
# Manifest — $goal_text

## Copied into files/
| Artifact | Original absolute path | Purpose | Program version | Confidence |
|---|---|---|---|---|

## Referenced in place (not copied)
| Artifact (marked path) | Original location | Purpose | Program version | Confidence |
|---|---|---|---|---|
EOF

printf 'Seeded recovery effort:\n  %s\n\n' "$effort_dir"
printf 'Next: fill the README incident + program version, then back up BEFORE each change\n'
printf '(discover the real path first, copy do not move). See the bundled skill.\n'
