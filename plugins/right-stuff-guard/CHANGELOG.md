# Changelog

All notable changes to this plugin are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versions use [Semantic Versioning](https://semver.org/).

## [0.1.0] - 2026-10-13

### Added

- PreToolUse hook for `AskUserQuestion` with `scripts/check-ask-markers.py`. It denies a call whose option labels break the right-stuff marker rules and prints one line naming every problem found (the first four, then a count) so the model can fix them in one retry.
- A call that passes, any other tool, and any input the script cannot read all produce no output, so the normal pop-up appears and a bug in the script never blocks a question.
