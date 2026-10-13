# right-stuff-guard

Deny an `AskUserQuestion` call whose option labels break the right-stuff marker rules, so the model fixes them and asks again.

The right-stuff skill teaches an agent to end option labels with `(Right Thing)` and `(Recommended)`. A skill only helps once the model loads it. This plugin checks the mechanical half of those rules on every pop-up, whether or not the skill loaded. It does not judge which option deserves a marker; that still needs the skill.

## Rules

A call is denied when any question breaks one of these:

- A label ends in `(Right Thing)`, `(Recommended)`, `(Right Thing) (Recommended)` in that order, or has no marker. A marker anywhere else in a label, in another order, or with different capitals is denied.
- The question text, the header, and every option description contain no marker string.
- Single-select: exactly one option ends in `(Right Thing)`, and at most one ends in `(Recommended)`.
- Multi-select: at least one option ends in `(Right Thing)`, and with three or more options at least one is unmarked.
- Option 1 ends in `(Recommended)` when any option does, and otherwise in `(Right Thing)`.

`(Recommended)` is optional because the skill says to leave it off when nothing supports one option over another.

## What the model sees

On a deny, Claude Code shows the model `PreToolUse:AskUserQuestion hook error:` followed by one line naming each problem (Q number, option number, label) and a reminder of the four valid endings. The pop-up never reaches you. A valid call produces no hook output, so the pop-up appears as usual.

## Install

```bash
/plugin marketplace add rubicon/ai-skills
/plugin install right-stuff-guard@rubicon
```

Requires `python3` on your PATH.

## Fails open

If the hook input is not JSON, is not an `AskUserQuestion` call, or has an unexpected shape, the script exits 0 with no output and the question goes through unchecked. A bug in the guard cannot stop you from being asked.

## Tests

```bash
python3 plugins/right-stuff-guard/tests/test_check_ask_markers.py
```

The tests run the script as a subprocess on real hook-input JSON. No mocks.
