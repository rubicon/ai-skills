# Path preservation

How backups land in `files/` at their original absolute path, so the workspace is
self-documenting and restore is near-symmetric.

## The mechanic

Copy an artifact while recreating its original absolute path under `files/`, using `rsync` with
`--relative` and a `/./` pivot that marks where the preserved path begins:

```
rsync -aE --relative "/Users/you/Library/Application Support/Claude/./config.json" "<effort>/files/"
```

That writes `<effort>/files/Users/you/Library/Application Support/Claude/config.json`. Everything
before `/./` is the source root rsync strips; everything after is the path it preserves.

- `-a` preserves the tree, permissions, timestamps, and symlinks.
- `-E` on **macOS** rsync preserves extended attributes (`--extended-attributes`). See the
  cross-platform note below — this flag means something different on GNU rsync.
- `--relative` plus the `/./` pivot is what mirrors the absolute path.

Substitute the **confirmed** absolute path (safety principle 1) — never a constructed one. Paths
must be byte-accurate, including capitals and spaces.

## Paths with spaces

Quote the whole argument; the `/./` pivot goes inside the quotes:

```
rsync -aE --relative "/Users/you/Library/Application Support/Claude Extensions/./settings.json" "<effort>/files/"
```

## Cross-platform: `-aE` vs `-X` (this one is silent data loss)

The `-E` flag is **not portable**, and the failure is quiet — metadata simply does not come
across:

- **Apple rsync:** `-E` = `--extended-attributes` (preserves macOS xattrs, resource forks).
- **GNU rsync (Linux):** `-E` = `--executability`. To preserve extended attributes you need
  `-X` (`--xattrs`), and `-A` (`--acls`) if you care about ACLs.

So the macOS-correct form is `rsync -aE --relative ...`; the GNU-correct equivalent is
`rsync -aX --relative ...` (add `-A` for ACLs). Newer rsync builds on macOS (e.g. via Homebrew)
are GNU-flavored — check `rsync --version` and which binary is first on `PATH` before trusting
`-E`.

## Why mirror the path at all

A flat backup folder loses the one piece of context you most need months later: where the file
came from. Mirroring the absolute path means the backup's location *is* its documentation, and
restoring is the same rsync in reverse against a confirmed, moved-aside target (see the restore
runbook). Large folders are the exception — they are referenced in place in the manifest rather
than copied, to avoid `PATH_MAX` and gigabyte duplication.
