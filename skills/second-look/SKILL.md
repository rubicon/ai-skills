---
name: second-look
version: 0.2.0  # x-release-please-version
description: >-
  Use before opening a pull request or merging work done in the current
  session, when the user asks for a fresh, independent, or second review, "a
  second pair of eyes", "have another agent check this", or wants to know
  whether the change actually does what they asked, not only whether it has
  bugs.
---

# Second look

An intent-first review by an agent that did not write the code. A bug hunt asks "is this code broken?" This asks "does this change do what the user asked, all of it, and only that?" and then runs the bug hunt as well.

The reviewer cannot see this conversation. Everything it knows about intent comes from the packet you write. The packet is the skill.

## 1. Write the reviewer packet

Build it from the whole session, not from memory of the first request. Every field is required; write "None" when a field is empty.

```text
ORIGINAL ASK: <the user's first request, quoted>
CHANGES TO THE ASK: <each later clarification or reversal, quoted, with what it replaced>
FINAL REQUIREMENTS: <numbered list; the requirements as they stand now, after every change above>
OUT OF SCOPE: <what the user deferred or excluded, quoted; the reviewer must not report these as missing>
WHAT WAS BUILT: <files changed and why, one line each>
DECISIONS: <trade-offs made and the reason for each>
TESTS RUN: <exact command and result>
KNOWN GAPS: <what you are unsure of or did not finish>
DIFF: <how to see it, e.g. `git diff main...HEAD` plus untracked files>
```

When a later message overrides an earlier one, FINAL REQUIREMENTS states only the current rule. The superseded version appears only under CHANGES TO THE ASK.

## 2. Dispatch a fresh reviewer

Always use a new subagent. Do not review in this context, even for a small diff: the point is a reader without your assumptions. If no subagent is available, say so and stop instead of reviewing your own work.

Give the reviewer the packet, read-only rules (no edits, no commits, no git writes), and these instructions:

1. **Intent review.** For each FINAL REQUIREMENT: met or not met, with file:line evidence and, where possible, a command run against the code. Then: does any test assert behavior that contradicts a requirement? Does the change do anything no requirement asked for? Is it the smallest correct way? Take intent only from the packet; do not infer it from the diff. If the packet is ambiguous, report the ambiguity as a finding.
2. **Report** each finding tagged `[intent]`, verified results kept apart from inferences.

## 3. Run the bug hunt

After dispatching the reviewer, run `/code-review` on the same diff in this session; its finders are separate agents that see only the diff. Tag its findings `[bugs]`. If `/code-review` is not available, tell the reviewer to add one independent correctness pass and tag those `[bugs]`.

## 4. Report to the user

Merge the two sets of findings; when both found the same issue, keep it once and say both found it.

Lead with a verdict: ready, or not ready and why, in one sentence.

Then:

| # | Requirement | Met | Evidence |
|---|---|---|---|

Then findings, grouped:

- **Blocker**: a requirement not met, a test that asserts behavior contradicting a requirement, a likely regression, data loss, or a security issue.
- **Non-blocker**: a real but minor issue, or a test gap.
- **Nit**: worth knowing, never blocking.

Each finding carries its tag, the file and line, and why it matters. Anything listed in OUT OF SCOPE is not a finding. End with what the reviewer ran and what it only read.

The review changes nothing. Offer the fixes and wait for the user.
