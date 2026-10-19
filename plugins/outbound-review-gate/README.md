# outbound-review-gate

A Claude Code `PreToolUse` hook that blocks an agent from posting text to a third-party or public repository until a review receipt exists for that exact post. It covers comments, reviews, issue and PR creation and edits, and merge or close messages, through `gh` and through the GitHub and Forgejo MCP tools. Repositories you own are exempt.

The point is to turn "have a fresh reviewer check every outbound comment" from something the agent has to remember into something the harness checks on every call. It catches an agent that forgot. It is not a sandbox, and the limits section says what it does not stop.

## Install

```text
/plugin marketplace add rubicon/ai-skills
/plugin install outbound-review-gate@rubicon
```

The plugin registers its own hook, so nothing is edited in `settings.json`. Start a new session after installing. Do not also register the script by hand, or it runs twice.

The hook sets `"onFailure": "block"`, which needs Claude Code 2.1.295 or later. With it, a crash, a timeout or a missing `python3` blocks the tool call instead of letting it through. The trade-off: `Bash`, `Write` and `Edit` are in the matcher, so if `python3` breaks, those calls are blocked until you fix it or disable the plugin. On an older Claude Code the field has no effect and a failing hook lets the call through.

## Configure

Without configuration, every repository counts as third-party, including your own. Name the repositories you own:

| Variable | Meaning | Default |
| --- | --- | --- |
| `OUTBOUND_GATE_OWNED` | Comma-separated `fnmatch` patterns on `host/owner/repo`, for example `github.com/acme/*,git.example.com/*`. Matching repos are never gated. | none |
| `OUTBOUND_GATE_FORGEJO_HOST` | Host name the Forgejo MCP tools post to, used when matching `OUTBOUND_GATE_OWNED`. | `forgejo` |
| `OUTBOUND_REVIEW_DIR` | Where receipts are stored. | `~/.claude/state/outbound-review` |

Set them in the `env` block of `settings.json` so the hook and the helper commands see the same values.

## What it gates

- Shell tools (`Bash`, `Monitor`, `mcp__terminal__run_in_terminal`): `gh pr` and `gh issue` comment, review, create, edit, close, reopen, merge and revert; `gh discussion` equivalents; `gh api` writes to issue, pull, comment, review and dismissal endpoints. `gh` is found anywhere in a command, including `if` and `for` bodies, `$( )`, process substitution, variables, and functions that pass their arguments to `gh` (`c() { gh "$@"; }`), and inside a string handed to `bash -c`, `eval`, `env -S`, `watch`, `tmux`, `script -c`, `ssh`, `osascript -e`, `git -c alias.x='!...'`, `git rebase --exec` and `vim -c '!...'`. Other programs that run a string as a shell command are not rescanned, and `python3 -c` is denied only when it spells out a `gh pr` or `gh issue` call.
- `curl` and `wget` calls (also behind these wrappers: `env`, `sudo`, `doas`, `timeout`, `nohup`, `xargs`, `exec`, `command`, `time`, `nice`, `stdbuf`, `setsid`, `watch`, `find`, `parallel`, `su`, `script`, in their argument form (`timeout 5 curl ...`); a command given to them as a quoted string, such as `su root -c 'curl ...'`, `script -c 'curl ...'` or `watch 'curl ...'`, is not looked through; other wrappers are not looked through either) to `api.github.com`, a GitHub Enterprise `/api/v3/repos/...` or a Forgejo `/api/v1/repos/...` endpoint, or to `/api` or `/graphql` on a host that is GitHub, `GH_HOST`, `OUTBOUND_GATE_FORGEJO_HOST` or named in `OUTBOUND_GATE_OWNED`, that are write-shaped (an explicit or implied POST, PATCH or PUT, or any data flag such as `-d`, `--data*`, `--json`, `-F`, `-T`, `--post-data`, `--post-file`). The repo comes from the URL and a repo that is not owned is denied, with no receipt possible because the body cannot be reviewed; use `gh` or the MCP tools instead. A URL built from a variable is denied unless its host is spelled out and is not an API host. Reads, and curl or wget to any other host, pass.
- AppleScript `do shell script` that contains a gated `gh` call.
- GitHub and Forgejo MCP write tools: `add_issue_comment`, `add_reply_to_pull_request_comment`, `add_comment_to_pending_review`, `create_pull_request`, `issue_write`, `pull_request_review_write`, `update_issue_comment`, `update_pull_request`, `merge_pull_request`, `create_issue`, `create_issue_comment`, `create_pull_request_review`, `edit_issue`, `edit_issue_comment`, `edit_pull_request`.
- `Write`, `Edit`, `MultiEdit` and `NotebookEdit` aimed at the receipt directory.

The gate looks at text. A merge, close, approve or other call that carries no text is allowed without a receipt; the same call with `--body`, `--comment` or a commit message is gated. A `gh api` write whose endpoint is built by the shell is denied, because the hook cannot tell what it posts to, except when the repo part is a variable under an owner whose repos are all owned.

The target repo is resolved from `-R/--repo`, a URL argument, `GH_REPO`, then the checkout's remotes (honoring `gh repo set-default`). A checkout with an `upstream` remote and no default marker counts as third-party. A repo that cannot be resolved to exactly one repo is third-party and cannot be unlocked; pass `-R owner/repo`.

Text the hook cannot hash is denied on third-party repos, because no receipt can vouch for it: bodies built by the shell (`$(...)`, `$VAR`, backticks, `$'...'`), `--body-file -` or any stdin, a file that is missing, not a regular file or over 1 MiB, `--editor`, `--fill`, `--template`, a flag the hook does not know, and commands over 256 KiB. Write the text to a file in one command, then post with `--body-file <literal path>` in the next.

GraphQL mutations that may carry text (`gh api graphql`, or any endpoint path ending in `/graphql`, with `addComment` and similar) are denied, on owned repositories too, because their text cannot be hashed and no receipt can unlock them. Use `gh pr comment`, `gh issue comment` or a REST endpoint instead. Mutations known to carry no text (labels, reactions, thread resolution, project moves) pass.

## The receipt

A receipt is a JSON file named by the sha256 of the list `[repo, action, target, title, body]`:

- `repo` is `host/owner/repo` in lowercase.
- `action` is the kind of post: `pr comment`, `issue create`, `pr merge`, `pr review --approve` (the review mode is part of it), `api POST`, or the MCP tool name plus its method when it has one, such as `add_issue_comment` or `issue_write update`. Copy it from the denial's `scope=` line rather than building it by hand.
- `target` is the PR or issue number (also taken from a URL), a branch name, the REST path for `gh api`, the MCP tool's number and id fields joined with `/` (a reply to comment 99 on PR 5 is `5/99`), or empty when the call has none (a create, or a command that relies on the current branch).
- Title and body are right-stripped.

So a review of a reply for one thread does not unlock the same text on another PR or issue, on another comment (a `gh api` reply is keyed on its `in_reply_to`, an MCP review comment on its path and line), as a merge message, or in another repo. A receipt is reusable: it never expires. A later `record` for the same scope and text replaces it, so a `no-go` revokes it and a new `go` must be dispositioned again. It counts only when its verdict is `go`, it is marked dispositioned, it names a reviewer model, and its inner hash matches its file name.

A denial prints the exact scope the receipt must name, as `scope={"repo": ..., "action": ..., "target": ...}`, so you never have to guess the host or the action. Recording takes two steps by two different actors:

1. The fresh reviewing subagent runs `record` as the last step of its review, on the exact final text, using the repo, action and target from the denial:
   `outbound-comment-review-gate record --repo HOST/OWNER/REPO --action "pr comment" --target 7 [--title T] --body-file FILE --reviewer-model MODEL --verdict go --findings N`
2. The posting session applies or rejects each finding with a reason, then runs `disposition` with the same repo, action, target and text:
   `outbound-comment-review-gate disposition --repo HOST/OWNER/REPO --action "pr comment" --target 7 [--title T] --body-file FILE`

A bare `OWNER/REPO` is read on `GH_HOST` if it is set and on `github.com` otherwise. Forgejo posts are keyed on `OUTBOUND_GATE_FORGEJO_HOST`, so give `--repo` with the host the denial shows. `hash` prints a key without writing anything.

The hook denies `record` from the main thread (it relies on the `agent_id` field Claude Code puts in the payload of a subagent or in-process teammate call), and it denies hand edits to the receipt directory, so a session cannot mark its own draft as reviewed in one step. The denial message prints the full path of the helper and its usage. Then post with the same file, or for an MCP tool the identical string.

## Limits

Not covered: `git push` and commit messages, releases, gists, scripts and `python3 -c` code that call the API directly, script files that contain `gh`, command-word obfuscation (`g[h]`, zsh `=gh`), user-defined gh aliases, text typed through a browser or desktop automation, and a command that rewrites the body file after the hook read it.

Self-approval is still possible, and the gate only makes it a visible, deliberate act:

- From the main thread the hook allows only `disposition`, `hash` and `--help` after the helper, and treats an argument built by a variable, a substitution or `$'...'` as `record`. A command that hides the helper itself behind something it cannot resolve (a name built at run time, `runpy`, a copy made by a redirect) is still not recognised.
- `agent_id` marks any subagent or in-process teammate, so a teammate that drafts and posts passes the check meant for the reviewer.
- A subagent can run `disposition` as well as `record`, so one subagent can complete both steps if it is briefed to.
- A session can name the receipt directory with a glob, or build its path at run time.

A MCP tool is matched by its `owner` and `repo` arguments. A server that is not named GitHub or Forgejo but takes `owner` and `repo` is treated as unresolvable and always denied, so it cannot borrow an owned `github.com/<owner>/*` pattern.

A shell function counts as a `gh` alias when `gh` appears between its opening and the first `}`, so a `gh` call after a nested `}` in the same function body is missed.

Analysis is cut off after 6 seconds (`OUTBOUND_GATE_BUDGET` overrides this for tests): a command that mentions a gated `gh` call, `curl` or `wget` is then denied, any other command passes.

Keep the matcher in `hooks/hooks.json` in step with any new shell-running or GitHub write tool, or the hook never sees it.

## Tests

```bash
python3 -m unittest discover -s plugins/outbound-review-gate/tests
```

The suite runs the hook as a subprocess, the way Claude Code does, and needs only Python 3 and `git`. `FLAG_SPECS` in the script mirrors `gh <verb> --help`; set `OUTBOUND_GATE_CHECK_GH_FLAGS=1` to also run the drift test that compares those tables with the installed `gh`, and update the tables after a `gh` upgrade that changes flags.
