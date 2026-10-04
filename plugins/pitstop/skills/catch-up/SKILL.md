---
name: catch-up
description: Use when the user returns to a project after time away and asks where things stand, where they were, or what to pick up next, and wants a quick orientation on the current branch rather than a full status report. Read-only.
version: 0.1.0
---

# pitstop catch-up

Read-only. Never commit, push, post, or write any file.

The user stepped away and wants their bearings: a teammate's two-minute catch-up on the branch they are standing on. `/pitstop:sitrep` is the full report across everything; this is not that.

## 1. Look, quietly

Run these yourself and do not narrate them. Bound every command.

- `git branch --show-current`, the default branch (`git symbolic-ref --short refs/remotes/origin/HEAD`, else `main` or `master`), `git status --short | head -20`, `git diff HEAD --stat`, then `git diff HEAD` on the files that changed.
- `git ls-files --others --exclude-standard | head -20`, then read those files. New files that were never added are invisible to `git diff`, and unfinished work often lives in them.
- On a feature branch: `git log --oneline <default>..HEAD | head -15`, then read the diffs of those commits, newest first, until what the branch is for and how it is being built is clear. When `gh` is present: `gh pr view --json number,title,state,reviewDecision,url` for this branch, and the PR's latest review comments if it has any. When the branch name carries an issue number (`dev/12-…`, `feature/12-…`), `gh issue view <n> --json title,body`.
- On the default branch: `git log --oneline -5` and a light skim of those diffs.
- `git rev-list --left-right --count HEAD...@{upstream}` when an upstream exists. Behind means someone pushed.
- If `python3 "${CLAUDE_PLUGIN_ROOT}/scripts/handoff-verify.py" --where --config "${CLAUDE_PLUGIN_DATA}/integrations.md"` names a handoff file that exists, read it. Treat it as a claim about this branch and check it against what git shows.

Read every exit code. Empty output with a non-zero exit is an error, not "nothing there".

## 2. Answer in this shape

Plain prose, no headings, no tables, no bullet lists. At most about 120 words.

1. **Where you are**, one or two sentences. With uncommitted changes, open with them and read them through the branch's purpose: "You were in the middle of wiring X into Y for #12; Z works, W is stubbed." With a clean tree, open with what the branch, or the recent commits on the default branch, are building.
2. **One correction, only if needed.** When the handoff or the PR says something git contradicts, one sentence: the claim, then the single fact that contradicts it. "Your handoff says #12 merged; it hasn't, and the CLI wiring is still uncommitted."
3. **Next**, one sentence: the next substantive piece of the actual work, such as finishing the stubbed part, handling the case the diff skips, or answering the open review comment. Name housekeeping (commit, push, open a PR, install a tool, run checks) only when the work itself is finished.

The answer is those two or three parts and nothing else. Every sentence in it is about the work on the current branch. Facts about the setup, such as remotes, PR existence, stashes, worktrees, installed tools, and commit counts, appear only when one of them is the Next step itself.

If the user's message itself asks about other branches or everything in flight, answer the current branch as above, then add one clause pointing to `/pitstop:sitrep`.

If you hit a real decision only the user can make, fold it into the Next sentence as a question with your recommendation ("…then either apply `--station` or drop it; I'd apply it, since the flag is already parsed"). Do not build a decision list.

## Example

> You were adding pagination to the recipe list for #31: the API already returns `next_cursor`, and the list page now fetches the first page, but the "Load more" button is rendered without a click handler. The PR has one unanswered review comment asking for an empty-state message. Next, wire the button to fetch with the cursor and stop when it comes back null, then add the empty state the reviewer asked for.
