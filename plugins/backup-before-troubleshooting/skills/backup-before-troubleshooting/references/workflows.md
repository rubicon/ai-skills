# Workflows

Starting an effort, filing an artifact, and the two-pass migration for already-scattered
artifacts. Command blocks here are comment-free and top-to-bottom executable, per the scripting
rules. Substitute confirmed absolute paths — never assumed ones.

## Start an effort

Use the `new-recovery-effort` command, which runs `new-recovery-effort.sh`. By hand, the script
does the equivalent of: resolve `RECOVERY_ROOT` (default `~/Recovery`), create
`${RECOVERY_ROOT}/{Program}/{timestamp}_{goal}/` with `files/` and `evidence/`, seed the six
docs, and create or update the level-1 and level-2 README index rows.

Then, before each mutation, back up what you are about to change (next section).

## File an artifact (discovery-first)

Filing is intentionally a guided block, not a turnkey script: a generic `file <path>` would act
on unconfirmed input and violate safety principle 1. The shape is always **discover → confirm →
file → record**.

1. Discover and confirm the real path exists (this is read-only):

```
ls -ld "/Users/you/Library/Application Support/Claude"
ls -l "/Users/you/Library/Application Support/Claude/config.json"
```

2. Only after you have seen it exists, copy it into `files/` at its mirrored path:

```
rsync -aE --relative "/Users/you/Library/Application Support/Claude/./config.json" "/Users/you/Recovery/Claude/2026-06-20_141103_app-hangs-on-launch/files/"
```

3. For a large folder, do **not** copy it. Move it aside in place with a backup marker and record
   it as referenced-in-place:

```
mv "/Users/you/Library/Application Support/Claude/Session Storage" "/Users/you/Library/Application Support/Claude/Session Storage.bak-2026-06-20"
```

4. Add the manifest row (copied or referenced-in-place, with purpose, program version, and a
   HIGH/MEDIUM/LOW confidence note), and append a `CHANGELOG.md` line.

## Two-pass migration (already-scattered artifacts)

When artifacts are already strewn around from earlier ad-hoc work, never file from an assumed
path. Split discovery from action.

**Pass 1 — discover and report, move nothing.** Probe candidate locations read-only and write
the findings into `MANIFEST.md` as a confirmed inventory. Guard every probe so a missing path
does not abort the run (no `set -e`; see the scripting rules):

```
for p in \
  "/Users/you/Library/Application Support/Claude" \
  "/Users/you/Library/Logs/Claude" \
  "/Users/you/Library/Preferences/com.anthropic.claude.plist"
do
  if [ -e "$p" ]; then
    printf 'FOUND: %s\n' "$p"
    ls -ld "$p" 2>/dev/null
  else
    printf 'absent: %s\n' "$p"
  fi
done
```

**Pass 2 — file from the confirmed inventory.** For each `FOUND` path recorded in pass 1, file
it with the copied or referenced-in-place mechanic above, then add its manifest row. Because you
are acting only on paths pass 1 confirmed, you never touch an assumed path.
