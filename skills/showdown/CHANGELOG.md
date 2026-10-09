# Changelog — showdown

All notable changes to this skill are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
The version tracks the `version:` field in `SKILL.md`.

## [0.2.0](https://github.com/rubicon/ai-skills/compare/showdown-v0.1.0...showdown-v0.2.0) (2026-10-09)


### Features

* add showdown, a skill that compares approaches head to head and recommends one ([#85](https://github.com/rubicon/ai-skills/issues/85)) ([90da50c](https://github.com/rubicon/ai-skills/commit/90da50cce70733f72f501c0d9f7530f707cef518)), closes [#80](https://github.com/rubicon/ai-skills/issues/80)

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
