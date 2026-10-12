# Changelog — right-stuff

All notable changes to this skill are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
The version tracks the `version:` field in `SKILL.md`.

## [0.1.0] — 2026-10-12

### Added

- Initial release: how an agent asks the user for an approval, a missing fact, or a decision through the
  AskUserQuestion pop-up, and when not to ask.
- Two judgments as option-label suffixes, nowhere else: `(Recommended)` for the option the agent would argue
  for, and `(Right Thing)` for the responsible, best-practice choice judged ignoring speed and cost. One option
  can carry both, written `(Right Thing) (Recommended)`.
- A field-by-field contract for the pop-up: the question and descriptions hold facts; descriptions say what
  changes and whether it can be undone; the `(Recommended)` option comes first; marker counts for single- and
  multi-select; a "Saves X; gives up Y" sentence when the two judgments split. When the right option costs
  little extra, one option carries both markers.
- Yes/no approvals and requests for a fact get markers too; fact questions offer only real candidates.
- What an answer authorizes: each picked option, once. No answer, a dismissal, an error, or no pop-up tool means
  no; a decision laid out in prose uses a numbered list with the same markers and authorizes nothing by itself.
