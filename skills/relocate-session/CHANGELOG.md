# Changelog — relocate-session

All notable changes to this skill are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
The version tracks the `version:` field in `SKILL.md`.

## [Unreleased]

## [1.0.0] — 2026-09-07
- Initial release: procedure for relocating a Claude Code session or a whole project
  directory, carrying auto-memory across `~/.claude/projects/<slugified-cwd>/memory/`.
  Covers the slugification rule and its verification fallback, a copy that never moves and
  never overwrites, `MEMORY.md` index merging, destination verification, occupied-target
  handling via `list_sessions`, and a report of what does not follow the move (`.remember/`,
  process environment variables) versus what switches automatically.
