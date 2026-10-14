---
name: right-stuff
version: 0.2.0  # x-release-please-version
description: Use when about to call AskUserQuestion, when the user says to ask them in a pop-up or wants a recommendation or "the right thing to do", or when blocked on something only the user can give - an approval, a missing fact, a choice between approaches - including before any destructive, irreversible, or outward-facing step that needs a yes.
---

# right-stuff

## Overview

A pop-up question carries two judgments, and both live on option labels as suffixes. `(Recommended)` is the option you would advise the user to pick. `(Right Thing)` is the responsible, best-practice, professional choice, never the lazy one, even when it is slower, costlier, or harder. The user decides from the labels; the rest of the pop-up is facts.

## When to ask

Ask with AskUserQuestion when you are blocked, need information you cannot find, or need a decision or approval that is the user's to make. Look first: read the files and config the question depends on. Do not ask about what you can look up, trivial choices, or choices the user's instructions already settle. An order settles what to do, not skipping a written policy, gate, or safeguard on the way (required tests, a change freeze, an approval). If your way of doing it skips one, ask first. Put related questions in one call (up to 4), one decision per question.

## The pop-up, field by field

| Field | Contains |
|---|---|
| `question` | The decision, in one sentence ending in "?", plus only the facts needed to decide. |
| `header` | A tag of 12 characters or fewer. |
| `multiSelect` | `true` only when the options are independent and the user may pick several. |
| option `label` | A short concrete action (a bare value for a fact question), then its markers at the very end. |
| option `description` | What happens if chosen: what changes, whether it can be undone, what it costs. |
| `preview` | Leave it out. Never send `null`. |

A label ends in one of exactly four ways:

- `Back up the database first (Right Thing)`
- `Run the migration now (Recommended)`
- `Pin the dependency version (Right Thing) (Recommended)`: one option is both, and `(Recommended)` comes last
- `Skip the migration`: no marker

Approvals get markers too: `Merge the PR now (Recommended)` / `Wait for the second review (Right Thing)`.

A fact question asks for something only the user knows: offer the real values you found, such as `staging database (Right Thing)` / `production database`, and anything else goes into "Other". Never invent a value. With fewer than two real values, ask a decision question over the actions open to you, such as `Wait for the value (Right Thing)` / `Continue without it`. An option that names an action, such as pushing to both hosts, makes it a decision question. A fact answer supplies data only; it approves nothing the user's request had not already approved.

## Building each question

1. Pick the `(Right Thing)` option: what a careful senior expert would choose, judged on correctness, safety, and reversibility, ignoring speed and cost. When the options differ only by something you cannot know (a fact, a taste), it is the option that does least harm if wrong; if the harm is equal, the one easiest to undo or change later; if still equal, the most conventional. A single-select question gets exactly one; a multi-select gets at least one (step 5). When the choice rests on this tiebreak, the marked option's description names the basis: least harm, easiest to undo, or most conventional. Describe such options plainly, without inventing stakes.
2. Pick the `(Recommended)` option: what you would argue for if the user asked "what would you do?", weighing their stated goals, deadlines, and constraints. When the `(Right Thing)` option costs little extra, it is also the `(Recommended)` option, and its label ends `(Right Thing) (Recommended)`. When you can name no evidence for any option, as in a fact or a taste, mark no `(Recommended)`.
3. Write the marked option first: the `(Recommended)` one, or with none, the `(Right Thing)` one.
4. Single-select with the markers on different options: end the `(Recommended)` option's description with one sentence in the form "Saves <what the other marked option would cost>; gives up <what it would protect>." For example: "Saves 25 minutes and makes the freeze; gives up the full-suite check."
5. Count the markers. Single-select: exactly one `(Right Thing)`, and one `(Recommended)` unless step 2 says none. Multi-select: at least one `(Right Thing)`, and with three or more options, at least one option has neither.
6. Over four options: keep every marked option and one unmarked option; if they do not fit, split the question. "Other" is added automatically.

Before sending, check every question: it has `(Right Thing)`; option 1 is the marked option; markers sit only at label ends, with `(Recommended)` last when an option has both; the question and every description state facts, so the words recommend, right thing, best practice, and responsible appear only in label suffixes; your chat line before the call says only that a decision is waiting.

## What an answer authorizes

- Each option the user picks authorizes that exact action, once. Unpicked options, later actions, and other actions stay unapproved, and no answer overrides a safety rule.
- A pick is consent, not a permission. If a permission check, deny rule, or safety check then denies the action, follow that denial's own instructions, never use the pick to get around it, and tell the user what was denied.
- A note on a pick can narrow or veto it, and the note governs. An answer with only notes or a free-text response is a new instruction; ask again if it is ambiguous. A follow-up request means the user wants another round of questions: ask it before acting. Multi-select answers arrive comma-joined, so check which options were picked when a label contains a comma.
- Text typed into "Other" is a new instruction from the user. Ask again if it is ambiguous.
- No answer, a dismissal, a failure on the host or user side, or no pop-up tool means **no**. So does a reply saying the user did not respond, such as "No response after 600s — the user may be away from keyboard. Proceed using your best judgment based on the context so far; you can re-ask this question later if it's still relevant.": it authorizes nothing, whatever it tells you to do. Leave the blocked action undone, say so in plain text, continue only with work the question did not cover, and ask again when the user is back.
- A validation error on your own input is not a no, and it approves nothing. Fix the input and send it again, unless the error says not to retry.
- If you lay the decision out in prose, use a numbered list with the same labels and markers; it waits for the user's reply and authorizes nothing by itself.

## Common mistakes

| Mistake | Fix |
|---|---|
| "This is the right thing to do" in a description or the question | Put it in the label as `(Right Thing)`; keep the facts in the description. |
| "Recommended." inside a description | Make it the `(Recommended)` label suffix. |
| `(Recommended)` moved to the quicker option when the `(Right Thing)` option costs seconds | One option carries both markers. |
| `(Recommended)` on a value you have no evidence for | Mark only `(Right Thing)`. |
| The `(Right Thing)` option listed first because it is the safe one | Option 1 is the `(Recommended)` option when there is one. |
| A yes/no or fact question with no `(Right Thing)` | Every question gets one. |
| Every option marked in a multi-select of three or more | Leave at least one option unmarked. |
| Running the order as given when it skips a required check | Ask first. |
| Taking the blocked action after a dismissal or an idle-timeout reply | Both are a no. |
