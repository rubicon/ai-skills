---
name: right-stuff
description: Use when about to call AskUserQuestion, or when blocked on something only the user can give - an approval, a missing fact, a choice between approaches - including before any destructive, irreversible, or outward-facing step that needs a yes.
version: 0.1.0  # x-release-please-version
---

# right-stuff

## Overview

A pop-up question carries two judgments, and both live on option labels as suffixes. `(Recommended)` is the option you would advise the user to pick. `(Right Thing)` is the responsible, best-practice, professional choice, never the lazy one, even when it is slower, costlier, or harder. The user decides from the labels; the rest of the pop-up is facts.

## When to ask

Ask with AskUserQuestion when you are blocked, need information you cannot find, or need a decision or approval that is the user's to make. Do not ask about what you can look up, trivial choices, or choices the user's instructions already settle. Put related questions in one call (up to 4), one decision per question.

## The pop-up, field by field

| Field | Contains |
|---|---|
| `question` | The decision, in one sentence ending in "?", plus only the facts needed to decide. |
| `header` | A tag of 12 characters or fewer. |
| `multiSelect` | `true` only when the options are independent and the user may pick several. |
| option `label` | A short concrete action, then its markers at the very end. |
| option `description` | What happens if chosen: what changes, whether it can be undone, what it costs. |

A label ends in one of exactly four ways:

- `Back up the database first (Right Thing)`
- `Run the migration now (Recommended)`
- `Pin the dependency version (Right Thing) (Recommended)`: one option is both, and `(Recommended)` comes last
- `Skip the migration`: no marker

Approvals and requests for a fact get markers too:

- Approval: `Merge the PR now (Recommended)` / `Wait for the second review (Right Thing)`
- Fact: offer the real values you found, such as `staging database (Right Thing) (Recommended)` / `production database`; anything else goes into "Other". Never invent a value. With none found, offer the actions open to you, such as `Wait for the value (Right Thing) (Recommended)` / `Skip this step`. A fact answer supplies data only; it approves nothing the user's request had not already approved.

## Building each question

1. Pick the `(Right Thing)` option: what a careful senior expert would choose, judged on correctness, safety, and reversibility, ignoring speed and cost. On a pure preference, still pick the most responsible option, and describe the options plainly, without inventing stakes.
2. Pick the `(Recommended)` option: what you would argue for if the user asked "what would you do?", weighing their stated goals, deadlines, and constraints. When the `(Right Thing)` option costs little extra, it is also the `(Recommended)` option, and its label ends `(Right Thing) (Recommended)`.
3. Write the `(Recommended)` option first, then the others.
4. Single-select with the markers on different options: end the `(Recommended)` option's description with one sentence in the form "Saves <what the other marked option would cost>; gives up <what it would protect>." For example: "Saves 25 minutes and makes the freeze; gives up the full-suite check."
5. Count the markers. Single-select: exactly one of each. Multi-select: at least one of each, and with three or more options, at least one option has neither.
6. Over four options: keep every marked option and, with three or more options, one unmarked one; if that does not fit, split the question. "Other" is added automatically.

Before sending, check every question: it has both markers; option 1 carries `(Recommended)`; markers sit only at label ends, with `(Recommended)` last when an option has both; the question and every description state facts, so the words recommend, right thing, best practice, and responsible appear only in label suffixes; your chat line before the call says only that a decision is waiting.

## What an answer authorizes

- Each option the user picks authorizes that exact action, once. Unpicked options, later actions, and other actions stay unapproved, and no answer overrides a permission denial or a safety rule.
- Text typed into "Other" is a new instruction from the user. Ask again if it is ambiguous.
- No answer, a dismissal, an error, or no pop-up tool means **no**. Leave the blocked action undone, say so in plain text, and continue only with work the question did not cover. If you lay the decision out in prose, use a numbered list with the same labels and markers; it waits for the user's reply and authorizes nothing by itself.

## Common mistakes

| Mistake | Fix |
|---|---|
| "This is the right thing to do" in a description or the question | Put it in the label as `(Right Thing)`; keep the facts in the description. |
| "Recommended." inside a description | Make it the `(Recommended)` label suffix. |
| `(Recommended)` moved to the quicker option when the `(Right Thing)` option costs seconds | One option carries both markers. |
| The `(Right Thing)` option listed first because it is the safe one | Option 1 is the `(Recommended)` option. |
| A yes/no or fact question with no markers | Both get markers, like any other question. |
| Every option marked in a multi-select of three or more | Leave at least one option unmarked. |
| Taking the blocked action after the question was dismissed | A dismissal is a no. |
