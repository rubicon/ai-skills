# Changelog — codebase-memoir

All notable changes to this skill are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
The version tracks the `version:` field in `SKILL.md`.

## [2.0.0](https://github.com/rubicon/ai-skills/compare/codebase-memoir-v1.0.0...codebase-memoir-v2.0.0) (2026-10-13)


### ⚠ BREAKING CHANGES

* the codebase-memory skill is removed. Install codebase-memoir with skillshare -s codebase-memoir instead of -s codebase-memory.

### Features

* replace codebase-memory with codebase-memoir, the maintained version ([#127](https://github.com/rubicon/ai-skills/issues/127)) ([b0ce643](https://github.com/rubicon/ai-skills/commit/b0ce6439db36d8cd8323bd3d26f8fed992b6bd9f))

## [1.0.0] — 2026-10-12

### Added

- Practices for a `codebase-memory-mcp` knowledge graph:
  - query it before grepping, and pick the right `search_graph` mode and filters
  - know that only a live session's project is refreshed in the background (while `auto_watch` is on); reindex every other project after its code changes, and treat `detect_changes` as read-only impact analysis of the changes already made
  - keep plain `worktrees/` directories out of the index
  - rename an indexed project without losing its ADR, and reindex it by hand afterwards
  - write an ADR from the graph, git history, session notes, and cross-session memory without inventing a rationale
  - audit complexity and hot paths
  - check coverage, and the callback, route-handler and override links, before any dead-code or negative claim
  - engine quirks
  - cross-repo intelligence across all six cross-repo edge types
  - what `ingest_traces` does not do yet
- Some tool-behaviour notes and two Cypher examples quote or closely paraphrase the tool descriptions in codebase-memory-mcp (https://github.com/DeusData/codebase-memory-mcp, MIT, Copyright (c) 2025 DeusData). The skill README carries the full MIT notice.

### Changed

- **Breaking:** replaces the `codebase-memory` skill (1.0.0), which shared its name with the skill the codebase-memory-mcp installer adds. Install with `-s codebase-memoir` instead of `-s codebase-memory`.
- The old skill reproduced the `codebase-memory` skill shipped with codebase-memory-mcp (https://github.com/DeusData/codebase-memory-mcp, MIT, Copyright (c) 2025 DeusData), with a version line added and one line edited, and was published without that notice. It is removed here.
