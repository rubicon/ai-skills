# Platform notes

This skill is macOS-first. The discipline is portable; the exact commands and locations are not.
State these assumptions explicitly so the skill can be adapted rather than silently mis-fire.

## macOS assumptions

- Application state typically lives under `~/Library/Application Support/<app>`, logs under
  `~/Library/Logs/<app>`, preferences under `~/Library/Preferences/*.plist`.
- `rsync -aE` is the macOS-correct copy (see the `-E` vs `-X` caveat in
  [path-preservation.md](path-preservation.md)).
- Time Machine and APFS local snapshots (`tmutil localsnapshot`) are a useful belt-and-braces
  whole-disk fallback, but they are *not* a substitute for this workspace: they do not record
  why a snapshot was taken or what you concluded. This skill captures that narrative.

## iCloud: source-materialization caveat (read before copying from Desktop/Downloads)

Files under `~/Desktop` and `~/Downloads` may be **iCloud-managed dataless placeholders** —
the icon and metadata are present but the bytes live in the cloud. If you `rsync` such a file
before it is materialized, you copy a **zero-byte stub** and leave the real data in iCloud.

Before copying *from* those locations, force the file local and confirm it is materialized:

```
brctl download "/Users/you/Desktop/some-export.zip"
ls -l "/Users/you/Desktop/some-export.zip"
```

This is a **source-read** hazard. It is separate from where the workspace lives — `RECOVERY_ROOT`
must itself be a permanently-local location (never `~/Downloads`/`~/Desktop`), so the forensic
record is never evicted.

## Linux adaptation notes

Not implemented — assumptions only, for whoever ports this:

- Replace `-E` with `-X` (and `-A` for ACLs) on GNU rsync (see path-preservation).
- Application/config locations differ: expect `~/.config/<app>`, `~/.local/share/<app>`,
  `~/.cache/<app>`, and `/etc` for system config. The "discover before reference" rule matters
  even more here, since layouts vary by distro and app.
- There is no iCloud placeholder problem, so the `brctl` step drops away. Watch instead for
  other lazily-materialized stores (network homes, overlay/snapshot filesystems).
- `RECOVERY_ROOT` default of `~/Recovery` is fine; the tilde expansion in the seeding script is
  POSIX shell, so it carries over.
