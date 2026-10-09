---
name: goalpost
version: 0.2.0  # x-release-please-version
description: >-
  Use when the user wants Claude Code to keep working autonomously with /goal
  and needs the goal condition written, or asks to "turn this into a goal",
  "write me a /goal", "phrase a goal so Claude keeps going until it's done", or
  wants a finish line that a long unattended run can actually reach.
---

# Goalpost

Turn what the user wants into one `/goal` line that a long unattended run can finish, and that stops honestly when it cannot.

## How /goal works

`/goal <condition>` sets a session goal. After every turn, a separate evaluator reads the conversation and decides whether the condition is met; until it is, Claude keeps working. `/goal clear` removes it. Two consequences shape everything below:

- The evaluator judges from what appears in the conversation. Evidence that is never shown, such as a test run whose output was not printed, does not count.
- A condition that cannot be met keeps the session working until the user clears it. Every goal therefore needs an honest way to end without success.

## 1. Investigate

Find what would prove the outcome in this repo: the test command that actually runs here (try it; a command that fails to start is not evidence), validation scripts, build steps, or an observable behavior such as a CLI's output and exit code. Note the constraints a run must not break and the things it must not touch.

If the request is a one-off edit or a single obvious step, say so in one sentence and suggest a normal prompt. Continue only if the user still wants a goal.

## 2. Ask only what the workspace cannot answer

At most three numbered questions, each with your recommended answer first, and only about decisions that change what "done" means. If none are needed, skip straight to the goal.

## 3. Answer in this shape

One fenced `text` block holding a single line that starts with `/goal ` and is one paragraph, in this order:

1. **Outcome**: what is true when the work is done, described as behavior someone could observe from outside the code. Do not name functions, files to create, or implementation steps; leave the path to the working agent.
2. **Evidence**: the exact command or check, and that its output is shown in the conversation. "`<command>` exits 0, with its full output shown."
3. **Constraints**: what must stay intact and what is off limits, such as files not to change, nothing committed or pushed, no new dependencies.
4. **Escape clause**, always last, in these words: "Or: Claude has stopped and reported a blocker that needs the user, with the evidence and every approach it tried."

Then three short bullets: why the evidence is checkable from the conversation, which constraint matters most, and any assumption that still matters (or "No open assumptions").

Never invent a command, a target number, or an acceptance criterion. If the evidence cannot be pinned down, the goal says what evidence would count and the escape clause covers the rest.

Do not start the work. End by inviting the user to edit the line or run it.

## Example

```text
/goal Uploading a photo larger than 10 MB in the profile editor shows a "File too large" message instead of a blank page, and photos under 10 MB still upload. Evidence: `npm test -- profile-upload` exits 0 with its full output shown, including at least one new test for the over-limit case that was shown failing before the fix. Constraints: no change to the upload API's response format, no new dependencies, nothing committed. Or: Claude has stopped and reported a blocker that needs the user, with the evidence and every approach it tried.
```
