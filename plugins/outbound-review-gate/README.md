# outbound-review-gate

A Claude Code `PreToolUse` hook that blocks an agent from posting to a third-party or public repository until a review receipt exists for the exact text. It covers comments, reviews, issue and PR creation and edits, and merges, through `gh` and through the GitHub and Forgejo MCP tools. Repositories you own are exempt.

The point is to turn "have a fresh reviewer check every outbound comment" from something the agent has to remember into something the harness checks on every call. It catches an agent that forgot. It is not a sandbox, and the limits section says what it does not stop.

## Install

```text
/plugin marketplace add rubicon/ai-skills
/plugin install outbound-review-gate@rubicon
```

The plugin registers its own hook, so nothing is edited in `settings.json`. Start a new session after installing. Do not also register the script by hand, or it runs twice.

## Configure

Without configuration, every repository counts as third-party, including your own. Name the repositories you own:

| Variable | Meaning | Default |
| --- | --- | --- |
| `OUTBOUND_GATE_OWNED` | Comma-separated `fnmatch` patterns on `host/owner/repo`, for example `github.com/acme/*,git.example.com/*`. Matching repos are never gated. | none |
| `OUTBOUND_GATE_FORGEJO_HOST` | Host name the Forgejo MCP tools post to, used when matching `OUTBOUND_GATE_OWNED`. | `forgejo` |
| `OUTBOUND_REVIEW_DIR` | Where receipts are stored. | `~/.claude/state/outbound-review` |

Set them in the `env` block of `settings.json` so the hook and the helper commands see the same values.

## What it gates

- Shell tools (`Bash`, `Monitor`, `mcp__terminal__run_in_terminal`): `gh pr` and `gh issue` comment, review, create, edit, close, reopen, merge and revert; `gh discussion` equivalents; `gh api` writes to issue, pull, comment, review and dismissal endpoints; GraphQL mutations that may carry text. `gh` is found anywhere in a command, including wrappers, `if` and `for` bodies, `$( )`, `bash -c`, `eval`, `env -S`, process substitution, variables and functions.
- AppleScript `do shell script` that contains a gated `gh` call.
- GitHub and Forgejo MCP write tools: `add_issue_comment`, `add_reply_to_pull_request_comment`, `add_comment_to_pending_review`, `create_pull_request`, `issue_write`, `pull_request_review_write`, `update_issue_comment`, `update_pull_request`, `merge_pull_request`, `create_issue`, `create_issue_comment`, `create_pull_request_review`, `edit_issue`, `edit_issue_comment`, `edit_pull_request`.
- `Write`, `Edit` and similar file tools aimed at the receipt directory.

The target repo is resolved from `-R/--repo`, a URL argument, `GH_REPO`, then the checkout's remotes (honoring `gh repo set-default`). A checkout with an `upstream` remote and no default marker counts as third-party. A repo that cannot be resolved to exactly one repo is third-party and cannot be unlocked; pass `-R owner/repo`.

Text the hook cannot hash is denied on third-party repos, because no receipt can vouch for it: bodies built by the shell (`$(...)`, `$VAR`, backticks, `$'...'`), `--body-file -` or any stdin, a file that is missing, not a regular file or over 1 MiB, `--editor`, `--fill`, `--template`, a flag the hook does not know, and commands over 256 KiB. Write the text to a file in one command, then post with `--body-file <literal path>` in the next.

## The receipt

A receipt is a JSON file named by the sha256 of the list `[repo, title, body]`, where `repo` is `host/owner/repo` in lowercase and title and body are right-stripped. Changing one character of the text, or the target repo, changes the key. A receipt counts only when its verdict is `go`, it is marked dispositioned, it names a reviewer model, and its inner hash matches its file name.

Recording takes two steps by two different actors:

1. The fresh reviewing subagent runs `record` as the last step of its review, on the exact final text:
   `outbound-comment-review-gate record --repo owner/repo [--title T] --body-file FILE --reviewer-model MODEL --verdict go --findings N`
2. The posting session applies or rejects each finding with a reason, then runs `disposition` on the same text:
   `outbound-comment-review-gate disposition --repo owner/repo [--title T] --body-file FILE`

The hook denies `record` from the main thread (it relies on the `agent_id` field Claude Code puts in the payload of a subagent call), and it denies hand edits to the receipt directory, so a session cannot mark its own draft as reviewed in one step. The denial message prints the full path of the helper and its usage. `hash` prints a key without writing anything.

Then post with the same file, or for an MCP tool the identical string.

## Limits

Not covered: `git push` and commit messages, releases, gists, `curl` or scripts that call the API directly, script files that contain `gh`, command-word obfuscation (`g[h]`, zsh `=gh`), user-defined gh aliases, text typed through a browser or desktop automation, and a command that rewrites the body file after the hook read it.

A subagent can still be briefed to record a receipt it did not earn, and a session can `cd` into the receipt directory and write with relative paths. The gate makes self-approval a visible, deliberate act. It does not make it impossible.

A hook that times out lets the call through, which is why the hook is a single stdlib-only Python file that runs in about 50 ms. Keep the matcher in `hooks/hooks.json` in step with any new shell-running or GitHub write tool, or the hook never sees it.

## Tests

```bash
python3 -m unittest discover -s plugins/outbound-review-gate/tests
```

The suite runs the hook as a subprocess, the way Claude Code does, and needs only Python 3 and `git`. `FLAG_SPECS` in the script mirrors `gh <verb> --help`; set `OUTBOUND_GATE_CHECK_GH_FLAGS=1` to also run the drift test that compares those tables with the installed `gh`, and update the tables after a `gh` upgrade that changes flags.
