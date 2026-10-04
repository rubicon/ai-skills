# Changelog — showdown

All notable changes to this skill are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
The version tracks the `version:` field in `SKILL.md`.

## [Unreleased]

## [0.1.0] — 2026-10-04

### Added

- Initial release: compares two or three genuinely distinct approaches to a known goal in one
  table with fixed columns (what it involves, how fully it meets the goal, fit with the
  codebase, effort and risk, right choice when), then gives a pick argued from the goal and the
  one observable condition that would flip it. Stops there: no plan, no code.
- Each contender must have a real situation in which it wins, which rules out straw men.
- Effort counts as a reason only when two options meet the goal about equally well, so time
  pressure does not steer the pick toward the weaker option.
- Adapted from OpenChamber's `/weigh` magic prompt (MIT).
