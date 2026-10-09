# Changelog — second-look

All notable changes to this skill are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
The version tracks the `version:` field in `SKILL.md`.

## [0.2.0](https://github.com/rubicon/ai-skills/compare/second-look-v0.1.0...second-look-v0.2.0) (2026-10-09)


### Features

* add second-look, an intent-first review by a fresh agent ([#91](https://github.com/rubicon/ai-skills/issues/91)) ([e73995d](https://github.com/rubicon/ai-skills/commit/e73995dff6b15e4d67fbd9ec0b3096fbbd9086cf)), closes [#82](https://github.com/rubicon/ai-skills/issues/82)

## [Unreleased]

## [0.1.0] — 2026-10-04

### Added

- Initial release: an intent-first review before a PR or merge. The working session writes a
  reviewer packet with required fields (original ask, changes to the ask, final requirements,
  out of scope, what was built, decisions, tests run, known gaps, diff), so a later reversal
  or a deliberate deferral survives into the review.
- Always dispatches a fresh reviewer; never reviews in the authoring context.
- The reviewer checks each final requirement with evidence, flags tests that assert
  contradicted behavior, and takes intent only from the packet. The session runs
  `/code-review` on the same diff for the bug hunt; findings are tagged `[intent]` or `[bugs]`.
- Report: verdict, a requirement-by-requirement table, then blocker / non-blocker / nit.
  Anything listed as out of scope is not a finding.
- Adapted from OpenChamber's `/handoff-review` and `/workspace-review` magic prompts (MIT).
