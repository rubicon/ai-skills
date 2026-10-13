# Changelog — right-stuff

All notable changes to this skill are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
The version tracks the `version:` field in `SKILL.md`.

## [0.1.0] — 2026-10-12

### Added

- Initial release: how an agent asks the user for an approval, a missing fact, or a decision through the
  AskUserQuestion pop-up, and when not to ask. The agent looks first, and an order does not waive a written
  policy, gate, or safeguard on the way.
- Two judgments as option-label suffixes, nowhere else: `(Recommended)` for the option the agent would argue
  for, and `(Right Thing)` for the responsible, best-practice choice judged ignoring speed and cost. One option
  can carry both, written `(Right Thing) (Recommended)`.
- A field-by-field contract for the pop-up: the question and descriptions hold facts; descriptions say what
  changes and whether it can be undone; the marked option comes first; marker counts for single- and
  multi-select; a "Saves X; gives up Y" sentence when the two judgments split; `preview` left out.
- Fact and taste questions: labels are bare values, the option that does least harm if wrong gets
  `(Right Thing)` (ties go to the easiest to undo, then the most conventional), and `(Recommended)` appears only
  when the agent can name evidence. A fact answer supplies data only.
- What an answer authorizes: each picked option, once. A pick is consent, not a permission: a denied action is
  retried once, then handed back to the user. No answer, a dismissal, a host-side failure, no pop-up tool, or the
  tool's "no response, proceed on your best judgment" reply all mean no. A validation error on the agent's own
  input is fixed and resent. A decision laid out in prose uses a numbered list with the same markers and
  authorizes nothing by itself.
- README documents an optional always-on line for the global instructions file, which is what makes an agent
  load the skill before an ordered risky step.
