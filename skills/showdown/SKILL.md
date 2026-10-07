---
name: showdown
version: 0.1.0  # x-release-please-version
description: >-
  Use when the user knows what they want to build or change but not how to
  approach it, and wants the options compared before anyone plans or codes.
  Triggers on "how should I approach this", "which way should I go", "compare
  my options", "what are the trade-offs", "help me decide between", "is X or Y
  better here", or when the user is weighing architectures, libraries, or
  designs for a known goal.
---

# Showdown

Put two or three genuinely different approaches head to head on the same terms, pick one, and stop. The output is a decision, not a plan and not code. Once the user picks, planning or building is a separate step.

## 1. Investigate first

Read the code the decision touches: the relevant modules, the existing patterns, the data shapes, and the constraints. Every option and every cell in the comparison must be grounded in what the repo actually does. Make sure you understand what the user is trying to achieve and why.

Ask a question only when a missing fact would change which options exist or which one wins. Ask it in plain text, numbered, at most three, and wait.

## 2. Choose the contenders

Two or three options. Each one must be an approach a competent engineer would choose in some real situation, and you must be able to name that situation. If you cannot, the option is a straw man: replace it with a real alternative or drop to two.

Include the option that fully delivers the goal even when it is the hardest. Include the cheapest option that plausibly works, so the user sees what the extra effort buys.

## 3. Answer in this shape

**Goal**: one sentence restating what the user is trying to achieve, in their terms.

**The contenders**: one table, one row per option, these columns in this order:

| Option | What it involves | How fully it meets the goal | Fit with this codebase | Effort and risk | Right choice when |
|---|---|---|---|---|---|

Every cell is specific to this repo and this goal. "Right choice when" names a concrete situation in which that option wins, stated on its own terms, not "it depends". Whether that situation applies to this user is argued in the Pick.

**Pick**: one paragraph. Which option, and why, argued from the goal. Effort and risk are reasons only when two options meet the goal about equally well. Then one sentence that starts "Pick <other option> instead if" and names an observable condition that would flip the decision.

**Before you build**: only the open questions whose answer would change the pick, numbered. Omit this part when there are none.

The answer ends there. Anything you could not check while investigating, such as tests you could not run, goes in one sentence inside the opening bug line or a Before you build question, not after them.

If you find a bug or a blocker in the existing code while investigating, state it in one sentence before the Goal line, and treat fixing it as a constraint every option must meet.

## Example

> **Goal**: let support staff resend a failed order-confirmation email without asking engineering.
>
> | Option | What it involves | How fully it meets the goal | Fit with this codebase | Effort and risk | Right choice when |
> |---|---|---|---|---|---|
> | Admin button that re-enqueues the existing `SendConfirmation` job | One endpoint and one button in the existing admin panel | Fully, for single orders | Reuses the job queue and audit log already in `admin/` | Low; double-sends possible without an idempotency key | Resends are occasional and one at a time |
> | Bulk resend screen with filters | A filtered order list, select-all, and a batch job | Fully, including outage recovery | New batch job type; the admin panel has no bulk actions yet | Medium; a wrong filter can email thousands | Outages produce hundreds of failures at once |
> | Self-serve "resend my email" link for customers | A public endpoint with rate limiting | Partly; support still handles customers who never got the first email | Needs a public route, which the app has none of | Medium; new abuse surface | Most failures are spam-folder issues, not send failures |
>
> **Pick**: the admin button. It fully meets the goal as stated, reuses the queue and audit log, and adding an idempotency key closes its one real risk. Pick the bulk screen instead if the failure log shows more than a few dozen failures at a time.
