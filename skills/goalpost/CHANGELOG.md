# Changelog — goalpost

All notable changes to this skill are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
The version tracks the `version:` field in `SKILL.md`.

## [0.2.0](https://github.com/rubicon/ai-skills/compare/goalpost-v0.1.0...goalpost-v0.2.0) (2026-10-09)


### Features

* add goalpost, a skill that writes /goal conditions that are checkable and can finish ([#86](https://github.com/rubicon/ai-skills/issues/86)) ([323db2c](https://github.com/rubicon/ai-skills/commit/323db2ceec6fa966dc282428637c7b0fb962d26b)), closes [#81](https://github.com/rubicon/ai-skills/issues/81)

## [Unreleased]

## [0.1.0] — 2026-10-04

### Added

- Initial release: writes one pasteable `/goal` line in a fixed order: an outcome observable
  from outside the code, evidence that must be shown in the conversation (a command confirmed
  to run in the repo), constraints, and an escape clause.
- The escape clause lets a run end by reporting a blocker. Without it, the `/goal` evaluator
  rejects a reported blocker every turn and the session keeps working until the user clears it.
- Investigates the repo for the real test or check command before using it, and never invents
  commands, targets, or acceptance criteria.
- Adapted from OpenChamber's `/craft-goal` magic prompt (MIT).
