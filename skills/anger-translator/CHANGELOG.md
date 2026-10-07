# Changelog — anger-translator

All notable changes to this skill are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
The version tracks the `version:` field in `SKILL.md`.

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
