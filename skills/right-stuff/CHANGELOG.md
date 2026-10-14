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
  `(Right Thing)` (ties go to the easiest to undo, then the most conventional) and its description names that
  basis, and `(Recommended)` appears only when the agent can name evidence. A fact answer supplies data only.
  With fewer than two real values, the agent asks a decision question over the actions open to it.
- What an answer authorizes: each picked option, once. A pick is consent, not a permission: if a permission
  check, deny rule, or safety check denies the action, the agent follows that denial's own instructions, never
  uses the pick to get around it, and tells the user what was denied. A note on a pick can narrow or veto it;
  a notes-only or free-text answer is a new instruction, and a follow-up request is asked before acting. No
  answer, a dismissal, a host-side failure, no pop-up tool, or the tool's idle-timeout "no response" reply all
  mean no. A validation error on the agent's own input is not a no and approves nothing: it is fixed and
  resent, unless the error says not to retry. A decision laid out in prose uses a numbered list with the same
  markers and authorizes nothing by itself.
- README documents an always-on line for the global instructions file. In one test, two base lines let an
  ordered risky step run unasked in 4 of 5 runs, and the same lines with the invoke clause extended to risky
  steps in 0 of 5; the extended line was not tested alone.
