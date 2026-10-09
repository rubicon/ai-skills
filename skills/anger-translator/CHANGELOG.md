# Changelog — anger-translator

All notable changes to this skill are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
The version tracks the `version:` field in `SKILL.md`.

## [0.2.0](https://github.com/rubicon/ai-skills/compare/anger-translator-v0.1.0...anger-translator-v0.2.0) (2026-10-09)


### Features

* add anger-translator, a skill that turns a heated draft into a firm, professional message ([#97](https://github.com/rubicon/ai-skills/issues/97)) ([1b40e81](https://github.com/rubicon/ai-skills/commit/1b40e8106ac3f8d6d42d055d9679aa35f9e35d95)), closes [#96](https://github.com/rubicon/ai-skills/issues/96)

## [Unreleased]

## [0.1.0] — 2026-10-07

### Added

- Initial release: rewrites a heated draft into a firm, professional message that keeps every fact,
  the ask, and any consequence the user stated, and removes profanity, insults, sarcasm, threats of harm,
  identity-based contempt, and unprovable accusations.
- One answer shape: a one-line read of emotion, intensity, intent, and audience; one translated
  message; the categories removed (never repeating a threat, slur, or identity remark); and a warning only when there
  is real political or legal risk.
- Adds nothing the user did not say: no invented facts, apologies, softeners, escalation, or
  recipients. Missing specifics become bracketed placeholders.
- Handles writing up, writing down, already-calm drafts, requests to keep profanity, non-English
  input, threads, and formal complaints where a protected-class fact is the substance.
