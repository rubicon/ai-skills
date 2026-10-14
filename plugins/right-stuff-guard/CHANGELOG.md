# Changelog

All notable changes to this plugin are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versions use [Semantic Versioning](https://semver.org/).

## [0.2.0](https://github.com/rubicon/ai-skills/compare/right-stuff-guard-v0.1.0...right-stuff-guard-v0.2.0) (2026-10-14)


### Features

* add right-stuff-guard, a hook that denies malformed AskUserQuestion markers ([#157](https://github.com/rubicon/ai-skills/issues/157)) ([8c80f7b](https://github.com/rubicon/ai-skills/commit/8c80f7bb3a2c20844addb23bc6240684b363f6ae))

## [0.1.0] - 2026-10-13

### Added

- PreToolUse hook for `AskUserQuestion` with `scripts/check-ask-markers.py`. It denies a call whose option labels break the right-stuff marker rules. The reason names the first four problems on one line, with the question and option number for label problems, then a count of any more, so the model can usually fix them in one retry.
- A call that passes, any other tool, and any input the script cannot read all produce no output, so the normal pop-up appears. A crash in the script never blocks a question either: Claude Code treats a non-blocking hook failure as no decision.
