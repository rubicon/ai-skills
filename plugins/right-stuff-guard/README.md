# right-stuff-guard

Deny an `AskUserQuestion` call whose option labels break the right-stuff marker rules, so the model fixes them and asks again.

The right-stuff skill teaches an agent to end option labels with `(Right Thing)` and `(Recommended)`. A skill only helps once the model loads it. This plugin checks the mechanical half of those rules on every pop-up, whether or not the skill loaded. It does not judge which option deserves a marker; that still needs the skill.

This plugin does not install or depend on the right-stuff skill. It checks every `AskUserQuestion` call in the session, including calls made by other skills and plugins, so install it only if you want the marker convention enforced everywhere.

## Rules

A call is denied when any question breaks one of these:

- A label ends in `(Right Thing)`, `(Recommended)`, `(Right Thing) (Recommended)` in that order, or has no marker. A marker anywhere else in a label, in another order, or with different capitals is denied.
- The question text, the header, and every option description contain no marker string.
- Single-select: exactly one option ends in `(Right Thing)`, and at most one ends in `(Recommended)`.
- Multi-select: at least one option ends in `(Right Thing)`, and with three or more options at least one is unmarked.
- Option 1 ends in `(Recommended)` when any option does, and otherwise in `(Right Thing)`.

`(Recommended)` is optional because the skill says to leave it off when nothing supports one option over another.

The check is literal. A label or question that quotes text containing `(Recommended)` or `(Right Thing)`, such as a preset named `Express (Recommended)`, is denied, and the model has to rephrase. A label that merely mentions both markers in the middle is told markers go only at the very end; the order hint appears only when the label ends in the two markers swapped. Tabs between markers, a missing space before a marker, and full-width parentheses are not checked.

## What the model sees

On a deny, Claude Code shows the model `PreToolUse:AskUserQuestion hook error:` followed by two lines. The first lists up to four problems joined by `; `, then `(+N more)` if there are more. A problem with a label gives the Q number, option number and the label, cut to 80 characters with whitespace collapsed; a count problem (for example no `(Right Thing)`) gives only the Q number. The second line states the four valid endings, says what the two markers mean, and names the right-stuff skill. The pop-up never reaches you. A valid call produces no hook output, so the pop-up appears as usual.

## Install

```bash
/plugin marketplace add rubicon/ai-skills
/plugin install right-stuff-guard@rubicon
```

Requires `python3` on your PATH and Claude Code 2.1.139 or later, the release that added exec-form hook `args`.

## Fails open

If the hook input is not JSON, is not an `AskUserQuestion` call, or has an unexpected shape, the script exits 0 with no output and the question goes through unchecked. So does a missing `python3`, a crash in the script, or the 10 second timeout, because Claude Code treats those as a non-blocking hook error. The guard cannot stop you from being asked.

## Tests

```bash
python3 plugins/right-stuff-guard/tests/test_check_ask_markers.py
```

The tests run the script as a subprocess on real hook-input JSON. No mocks.
