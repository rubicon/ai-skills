# Changelog — relocate-session

All notable changes to this skill are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
The version tracks the `version:` field in `SKILL.md`.

## [Unreleased]

## [1.0.0] — 2026-09-07
- Initial release: procedure for relocating a Claude Code session or a whole project
  directory, carrying auto-memory across `~/.claude/projects/<slugified-cwd>/memory/`.
  Covers the up-front check that the session can move at all (a worktree
  or remote session cannot), the slugification rule, the fact that memory is keyed to the git
  repository root (so a worktree or a subdirectory never owns its own), the same-directory
  short circuit, the verification fallback, a copy/move disposition asked every time and defaulting to copy
  (move is copy-verify-remove behind four gates, never `mv`), a copy that never overwrites, `MEMORY.md` index merging, destination verification, occupied-target
  handling via `list_sessions`, and and a report of what does not follow the move (detected repo-local
  agent state, process environment variables) versus what switches automatically.
