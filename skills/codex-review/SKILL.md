---
name: codex-review
version: 1.0.0  # x-release-please-version
description: >-
  Use when you want an independent code review from a different model family: reviewing a
  diff before merging, self-reviewing a PR, or getting a second opinion on recent changes
  with the Codex CLI. Covers the codex review invocations that work, including the rule that
  a scope flag and a custom prompt cannot be combined.
---

# Codex Review

An independent review from a different model family. Value is author-bias: Codex sees what
the model that wrote the code does not.

## Preflight

`which codex`: if missing, tell the user to install it and stop. Then check that it can
authenticate. `codex login status` exits 1 with "Not logged in" when there is no saved login.
That does not always mean a review will fail: `codex review` also accepts the `CODEX_API_KEY`
environment variable, and a non-OpenAI `model_provider` in the user's config needs no
`codex login`. So if the status check fails, ask the user how they authenticate before
stopping, and do not work around a missing credential.

## The constraint that breaks the obvious invocation

**A scope flag and a custom prompt are mutually exclusive.** Confirmed by running codex-cli
0.162.1; in the codex source, every release checked (a sample, not all) has the same rule.

```
$ echo "focus on X" | codex review --base main -
error: the argument '--base <BRANCH>' cannot be used with '[PROMPT]'
```

All three scope flags reject a prompt: `--base`, `--uncommitted`, `--commit`. Only a bare
`codex review <PROMPT>`, with no scope flag, accepts one.

Some published review skills document `cat prompt.md | codex review --base main -`. That
form fails the same way.

## Quick reference

| Goal | Command |
|---|---|
| Review a branch vs its base | `codex review --base main` |
| Review uncommitted work (staged, unstaged, untracked) | `codex review --uncommitted` |
| Review one commit | `codex review --commit <sha>` |
| Review a target you name | `codex review "<what to review>"` |

A bare prompt is the whole review request: the prompt itself is the target, and Codex is not
given a diff, so it must say what to review (for example "the changes on this branch since
main"). `codex review` with neither a flag nor a prompt exits with an error.

`--title "<title>"` works only with `--commit`: alone it exits 2, and with other forms it is
not used. It sets the commit title shown in the review summary. Run `codex review --help`
before assuming any other flag exists: this CLI changes.

## Before the first run

- **Ask before sending code out.** Codex sends the diff, and anything else it reads or runs
  while reviewing, to its configured model provider (OpenAI by default). Its default sandbox
  can read files well beyond the repo, such as `.env` files and anything under the home
  directory. `--uncommitted` also includes untracked files that are not git-ignored, which can
  include stray secrets. Confirm with the user that this is acceptable for the repo. Do not
  rely on the sandbox to limit it: a read-only sandbox blocks writes and network access, not
  reads, and Codex's commands still run inside it. If a file must not leave the machine, do
  not run the review on that repo.
- **Know what it may do.** Per the codex source, the review never stops to ask you.
  The sandbox it runs in comes from the user's Codex configuration (`sandbox_mode`, a
  permissions profile, project trust, or a `-c` override), not from this skill.
- **Keep reports out of the review.** `--uncommitted` reviews untracked files, so an
  unignored report folder gets reviewed by the next run, including the report being written.
  Check with `git check-ignore -q .reviews/codex/x.md`: exit 0 means ignored, 1 means not
  ignored, and 128 means this is not a git repository or something else failed. If it is not
  ignored, ask the user before adding `.reviews/` to `.gitignore` (or to `.git/info/exclude`
  for a local-only rule). If they decline, ask them for a directory outside the repo and use
  it wherever `.reviews/codex` appears below, or do not use `--uncommitted`.
- **Check the base branch exists** before `--base`: `git rev-parse --verify main`. If it
  fails, ask the user for the right base (for example `master` or a release branch) and use
  that instead; codex does not stop on a missing base, it quietly switches to a different
  review prompt. When the remote branch is ahead of the local one, codex compares against the
  remote, so fetch first if that matters.

## Use it

```bash
mkdir -p .reviews/codex
set -o pipefail
codex review --base main 2>&1 | tee ".reviews/codex/$(date +%Y-%m-%d-%H%M%S).md"
```

`pipefail` keeps codex's exit status visible through `tee`. Reviews can take minutes on a
large diff, so in Claude Code start the command with `run_in_background`. The Bash tool's
timeout is 120 seconds by default and cannot be set above 10 minutes, so a timeout alone is
not a safe way to wait. When the background run finishes, read the saved report before
summarizing it.

Codex reads the repo itself and can run commands while it reviews. Treat every finding, and
any claim it makes about the code (such as tests passing), as a claim to verify.

## Don't reach for a custom prompt

The scope flags carry their own built-in review prompt, so choosing a scope means giving up
your own instructions. That is a smaller loss than it looks: steering the reviewer with your
own framing is how you get your own blind spots reflected back. Keep your reasoning out of
any prompt you do write; the neutral review is the independent one.

If review guidance genuinely must persist, the documented place is the repo's `AGENTS.md`,
which Codex loads when a session starts (32 KiB by default, set by `project_doc_max_bytes`).
That a `codex review` run applies it is supported by the codex source but not confirmed in a
run, so check it on your repo before relying on it. It also applies to every `codex`
invocation in the repo, not just reviews, so decide it deliberately.

## Rules

- **Advisory only.** Never auto-apply findings. Report them, then fix with approval.
- **Report what Codex actually said**, including findings you disagree with. Disagree in
  your own voice afterward; don't soften or omit.
- Save to `.reviews/codex/` (or the directory the user chose instead), never inside `.claude/`,
  which holds agent configuration.
- One report per run. The timestamp, to the second, keeps runs comparable and stops a rerun
  from overwriting the last report.
