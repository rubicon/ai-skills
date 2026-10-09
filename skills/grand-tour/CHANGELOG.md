# Changelog — grand-tour

All notable changes to this skill are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
The version tracks the `version:` field in `SKILL.md`.

## [0.2.0](https://github.com/rubicon/ai-skills/compare/grand-tour-v0.1.0...grand-tour-v0.2.0) (2026-10-09)


### Features

* add grand-tour, an onboarding-style tour of a codebase ([#87](https://github.com/rubicon/ai-skills/issues/87)) ([9bc01fa](https://github.com/rubicon/ai-skills/commit/9bc01fa1b19bdf57bd74370fa3c62e95d195f33c)), closes [#83](https://github.com/rubicon/ai-skills/issues/83)

## [Unreleased]

## [0.1.0] — 2026-10-04

### Added

- Initial release: a five-part onboarding tour (what this is, the main parts as one table of
  at most eight areas, one representative flow traced step by step through named files,
  conventions and traps with where each is enforced, and where to start).
- Starts from a code-graph index when one covers the repo (a codebase-memory MCP server or a
  `graphify-out/` directory), fans out with the Explore agent in a large repo without one, and
  reads directly in a small repo.
- Describes the codebase as it is on disk, not session state; defects noticed along the way
  go in a short "Also noticed" list instead of turning the tour into an audit.
- Adapted from OpenChamber's `/explore` magic prompt (MIT).
