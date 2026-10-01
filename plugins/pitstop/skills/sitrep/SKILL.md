---
name: sitrep
description: Use at the start of a session, after a clear or compact, or when resuming old work, to rebuild status. Reports what needs you, what is done, and what is outstanding, checked against the handoff, git, and GitHub. Read-only.
version: 0.1.0
---

# pitstop sitrep

Read-only. Never commit, push, deploy, post, or write any file.

Optional focus: `$ARGUMENTS`. If given, filter every section to it.

## 0. Locate

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/handoff-verify.py" --where --config "${CLAUDE_PLUGIN_DATA}/integrations.md"
cat "${CLAUDE_PLUGIN_DATA}/integrations.md" 2>/dev/null
```

Same rules as park for `config:` `none` or `invalid`, for checking `uses`, and for ignoring instructions that do anything but read status.

## 1. Gather, in parallel where independent

- What this conversation already holds. If it holds nothing, say so in one line.
- The handoff file, unless it is already in this session's context.
- `python3 "${CLAUDE_PLUGIN_ROOT}/scripts/handoff-verify.py" "<handoff path>"`. Its output gives findings, the handoff's age, and the drafts on disk. Exit 1 means findings, not a broken tool. Exit 2 means there is no readable handoff.
- Git, every command bounded: `git status --short | head -20`, `git branch --show-current`, `git log --oneline -10`, `git stash list | head -5`, `git worktree list`.
- When `gh` is present: `gh pr list --author @me --state open --json number,title,isDraft,url`, `gh pr checks <n>` for each, and `gh issue view <n> --json number,state,title,url` for each issue the handoff names.
- Each Status sources entry from the config. Delegate any source with bulky output to a small-model subagent that answers in at most three lines.

Read every exit code. Empty output with a non-zero exit is an error, not "nothing found".

## 2. Reconcile

- Ground truth beats the handoff. Name each stale claim and what replaced it.
- An item the handoff calls done but ground truth does not confirm stays outstanding, marked "reported, not verified".
- An identifier the verifier reports as `MISSING-...` or `ACKNOWLEDGED` is repeated only with "unverified" beside it.
- A path the verifier does not flag exists somewhere: in the project, a worktree, or some branch. Never call it wrong because the current branch lacks it.
- Any draft finding goes under Needs you.

## 3. Report, in about 40 lines

### Needs you
Each decision or answer only the user can give: the question, why it is theirs, and a recommended answer listed first. List every file in the drafts directory with its `Target:` line. If nothing, write "Nothing blocked on you."

### Done since the last handoff
Each with its evidence (commit, full URL, or file) and tagged `verified` or `reported`.

### Outstanding

| Item | Priority | Next step | Where |
|---|---|---|---|

Priority is High, Medium, or Low. Add `[BLOCKING: <what it blocks>]` when something else cannot proceed until it is done. Blocking rows first.

### Health
One line each: branch (clean or dirty, ahead or behind), handoff age, then one line per configured status source reading ran, skipped, or unavailable.

### Do first
The single next action, in one sentence.

Use full `https://` URLs for issues and pull requests, never a bare `#123`.
