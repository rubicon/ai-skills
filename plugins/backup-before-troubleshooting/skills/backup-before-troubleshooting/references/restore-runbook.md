# Restore runbook

Restoring is deliberate and read-each-step — never a one-shot command. The order exists because
restoring in place can destroy the current (possibly already-fixed) state if the backup turns out
to be wrong. Always: **dry-run → move the live target aside → restore → re-verify.**

Substitute confirmed absolute paths. Command blocks are comment-free per the scripting rules.

## Restoring a copied artifact (from `files/`)

1. Dry-run the restore and read what it would change (`-n` makes no changes):

```
rsync -aEn --relative "/Users/you/Recovery/Claude/2026-06-20_141103_app-hangs-on-launch/files/Users/you/Library/Application Support/Claude/./config.json" /
```

2. Move the live target aside with a timestamp so the current state is itself recoverable:

```
mv "/Users/you/Library/Application Support/Claude/config.json" "/Users/you/Library/Application Support/Claude/config.json.pre-restore-2026-06-23"
```

3. Run the restore for real (drop the `-n`):

```
rsync -aE --relative "/Users/you/Recovery/Claude/2026-06-20_141103_app-hangs-on-launch/files/Users/you/Library/Application Support/Claude/./config.json" /
```

4. Re-verify: confirm the file is back, has sane size and contents, and that the symptom you are
   testing actually changed. Record the result in `CHANGELOG.md` and refresh `CURRENT-STATE.md`
   (rolling its prior contents into the changelog first).

Note the restore target root is `/` because the path under `files/` already mirrors the full
absolute path; the `/./` pivot restores it to its original location.

## Restoring a referenced-in-place folder

These were never copied — they were renamed with a backup marker at their original location
(safety principle 2). "Restoring" is putting the marked folder back under its live name, after
moving any current live folder aside first:

1. Move the current live folder aside (if one exists):

```
mv "/Users/you/Library/Application Support/Claude/Session Storage" "/Users/you/Library/Application Support/Claude/Session Storage.pre-restore-2026-06-23"
```

2. Put the backup back under the live name:

```
mv "/Users/you/Library/Application Support/Claude/Session Storage.bak-2026-06-20" "/Users/you/Library/Application Support/Claude/Session Storage"
```

3. Re-verify and record, as above.

## After any restore

Watch for the gotcha pattern (safety principle 5): if a restored setting silently reverts — for
example an app rewrites a pinned value on launch, or a sync re-evicts a file — put a warning at
the **top** of `CURRENT-STATE.md` so the next person does not chase it blind.
