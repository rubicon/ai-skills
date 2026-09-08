# Changelog — relocate-session

All notable changes to this skill are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
The version tracks the `version:` field in `SKILL.md`.

## [Unreleased]

## [1.0.0] — 2026-09-08

### Added

- Initial release: a procedure for relocating a Claude Code session, or a whole project
  directory, without silently orphaning auto-memory. `change_directory` moves the session and
  its history; the memory under `~/.claude/projects/<slug>/memory/` does not follow, and
  nothing warns you.
- Step 0 checks the session can move at all — a session in a worktree or on a remote host
  cannot be relocated, so this is established before any memory work is done.
- Memory is resolved to the **git repository root**, not the working directory: a
  subdirectory of a repo, and a worktree, both read the root's memory and never own their own.
- A copy/move disposition, asked on every run and defaulting to copy. Move is never `mv` — it
  is copy, verify, then remove, behind four gates, because a memory directory is shared by
  every session in that repo.
- `scripts/carry-memory.sh` performs the copy, the `MEMORY.md` index merge and the
  verification. It ships as a script rather than inline prose because skill text substitutes
  the invocation argument for the shell's zero positional parameter, which silently corrupts
  awk. Every copy is checksum-verified; index lines naming a collided file are not merged.
- Reports what does and does not follow the move: the transcript follows, memory does not,
  environment variables persist in the process, and repo-local agent state stays with the repo
  (detected by what git does *not* track, rather than by a fixed list of names).
