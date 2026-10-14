"""Black-box tests for outbound-comment-review-gate.

Every test runs the real script as a subprocess, feeding the PreToolUse JSON on
stdin exactly as Claude Code does, and reads the real exit code and stdout. The
script is the only code under test; nothing is mocked.

Run: python3 -m unittest discover -s plugins/outbound-review-gate/tests -v   (from the repository root)
"""

import hashlib
import json
import re
import os
import shutil
import statistics
import subprocess
import tempfile
import time
import unittest
from pathlib import Path

GATE = Path(__file__).resolve().parent.parent / "scripts" / "outbound-comment-review-gate"
TP = "otherorg/widgets"  # third-party target
FILE_TEXT = "Thanks for the report. The retry path now waits for the lock before it reads the file.\n"
JSON_TEXT = "Body that arrives through --input.\n"


SCOPE = ["--action", "pr comment", "--target", "7"]
TP_KEY = "github.com/otherorg/widgets"  # how the gate names TP inside a receipt key


def sha(title, body, repo=TP_KEY, action="pr comment", target="7"):
    text = json.dumps([repo, action, target, (title or "").rstrip(), (body or "").rstrip()], ensure_ascii=False)
    return hashlib.sha256(text.encode()).hexdigest()


class GateCase(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp(prefix="gate-test-"))
        self.addCleanup(shutil.rmtree, self.tmp, ignore_errors=True)
        self.receipts = self.tmp / "receipts"
        self.work = self.tmp / "work"
        self.work.mkdir()
        self.body_file = self.work / "body.md"
        self.body_file.write_text(FILE_TEXT)
        self.json_file = self.work / "payload.json"
        self.json_file.write_text(json.dumps({"body": JSON_TEXT}))
        self.env = {
            "PATH": os.environ["PATH"],
            "HOME": str(self.tmp),
            "OUTBOUND_REVIEW_DIR": str(self.receipts),
            "OUTBOUND_GATE_OWNED": "github.com/myorg/*,forgejo/*",
        }

    # -- plumbing ---------------------------------------------------------
    def run_gate(self, args, stdin="", env=None):
        return subprocess.run(
            [str(GATE), *args],
            input=stdin,
            capture_output=True,
            text=True,
            env={**self.env, **(env or {})},
            cwd=self.work,
        )

    def hook(self, payload, env=None, raw=None):
        stdin = raw if raw is not None else json.dumps(payload)
        return self.run_gate([], stdin=stdin, env=env)

    def bash(self, command, cwd=None, env=None):
        command = command.replace("{f}", str(self.body_file)).replace("{j}", str(self.json_file))
        return self.hook(
            {
                "hook_event_name": "PreToolUse",
                "tool_name": "Bash",
                "tool_input": {"command": command},
                "cwd": str(cwd or self.work),
            },
            env=env,
        )

    def mcp(self, name, tool_input, env=None):
        return self.hook(
            {"hook_event_name": "PreToolUse", "tool_name": name, "tool_input": tool_input},
            env=env,
        )

    def scope_for(self, command=None, tool=None, env=None):
        """The repo, action and target a receipt must name for this call, read from the hook's own denial."""
        env = {**(env or {}), "OUTBOUND_REVIEW_DIR": str(self.tmp / "no-receipts")}
        if command is not None:
            r = self.bash(command, env=env)
        else:
            r = self.mcp(tool[0], tool[1], env=env)
        out = json.loads(r.stdout)["hookSpecificOutput"]["permissionDecisionReason"]
        m = re.search(r"scope=(\{.*?\})", out)
        self.assertTrue(m, out)
        return json.loads(m.group(1))

    def record(self, title=None, body=None, dispositioned=True, verdict="go", model="opus", repo=TP,
               action=None, target=None, command=None, tool=None, env=None):
        """What a reviewer subagent does (record) and then what the hub does (disposition).

        The action and target default to a comment on PR 7; pass the command (or MCP call) to take them from
        the hook's own denial instead."""
        if command is not None or tool is not None:
            got = self.scope_for(command, tool, env)
            repo, action, target = got["repo"], got["action"], got["target"]
        action = "pr comment" if action is None else action
        target = "7" if target is None else target
        text = ["--repo", repo, "--action", action, "--target", target]
        if title is not None:
            text += ["--title", title]
        if body is not None:
            text += ["--body", body]
        r = self.run_gate(["record", *text, "--reviewer-model", model, "--verdict", verdict, "--findings", "2"], env=env)
        self.assertEqual(r.returncode, 0, r.stderr)
        key = r.stdout.strip()
        if dispositioned and verdict == "go":
            d = self.run_gate(["disposition", *text], env=env)
            self.assertEqual(d.returncode, 0, d.stderr)
            self.assertEqual(d.stdout.strip(), key)
        return key

    def write_receipt(self, key, **fields):
        self.receipts.mkdir(exist_ok=True)
        data = {
            "sha256": key,
            "reviewer_model": "opus",
            "reviewed_at": "2026-10-14T10:00:00Z",
            "verdict": "go",
            "findings": 1,
            "dispositioned": True,
        }
        data.update(fields)
        (self.receipts / f"{key}.json").write_text(json.dumps(data))

    # -- assertions -------------------------------------------------------
    def assertAllowed(self, r):
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(r.stdout, "", "an allow must print nothing so the normal permission flow runs")

    def assertDenied(self, r, contains=None):
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertTrue(r.stdout, "expected a deny but the hook stayed silent")
        out = json.loads(r.stdout)["hookSpecificOutput"]
        self.assertEqual(out["hookEventName"], "PreToolUse")
        self.assertEqual(out["permissionDecision"], "deny")
        self.assertTrue(out["permissionDecisionReason"])
        if contains:
            self.assertIn(contains, out["permissionDecisionReason"])
        return out["permissionDecisionReason"]


# (name, command template, title, body) -- title/body are what the reviewer must
# have recorded for the command to be allowed. {f} is a body file whose content
# is FILE_TEXT; {j} is a JSON file whose "body" is JSON_TEXT.
OUTBOUND = [
    ("pr_comment_body_file", f"gh pr comment 7 -R {TP} --body-file {{f}}", None, FILE_TEXT),
    ("pr_comment_F_short", f"gh pr comment 7 -R {TP} -F {{f}}", None, FILE_TEXT),
    ("pr_comment_body_inline", f"gh pr comment 7 -R {TP} --body 'Looks right to me.'", None, "Looks right to me."),
    ("pr_comment_b_short", f"gh pr comment 7 -R {TP} -b 'Looks right to me.'", None, "Looks right to me."),
    ("pr_comment_body_equals", f"gh pr comment 7 -R {TP} --body='Looks right to me.'", None, "Looks right to me."),
    ("pr_comment_double_quoted", f'gh pr comment 7 -R {TP} --body "Looks right to me."', None, "Looks right to me."),
    ("pr_comment_edit_last", f"gh pr comment 7 -R {TP} --edit-last --body-file {{f}}", None, FILE_TEXT),
    ("pr_comment_repo_equals", f"gh pr comment 7 --repo={TP} --body-file {{f}}", None, FILE_TEXT),
    ("pr_comment_repo_long", f"gh pr comment 7 --repo {TP} --body-file {{f}}", None, FILE_TEXT),
    ("pr_comment_R_glued", f"gh pr comment 7 -R{TP} --body-file {{f}}", None, FILE_TEXT),
    ("pr_comment_url_arg", "gh pr comment https://github.com/otherorg/widgets/pull/7 --body-file {f}", None, FILE_TEXT),
    ("pr_comment_gh_repo_env", f"GH_REPO={TP} gh pr comment 7 --body-file {{f}}", None, FILE_TEXT),
    (
        "hub_form",
        f"env -u GH_TOKEN -u GITHUB_TOKEN gh pr comment 7 --repo {TP} --body-file {{f}}",
        None,
        FILE_TEXT,
    ),
    ("rtk_prefix", f"rtk gh pr comment 7 -R {TP} --body-file {{f}}", None, FILE_TEXT),
    ("quoted_words", f"'gh' \"pr\" comment 7 -R {TP} --body-file {{f}}", None, FILE_TEXT),
    ("after_cd", f"cd /tmp && gh pr comment 7 -R {TP} --body-file {{f}}", None, FILE_TEXT),
    ("after_semicolon", f"echo hi; gh pr comment 7 -R {TP} --body-file {{f}}", None, FILE_TEXT),
    ("after_newline", f"echo hi\ngh pr comment 7 -R {TP} --body-file {{f}}", None, FILE_TEXT),
    ("after_pipe", f"echo hi | gh pr comment 7 -R {TP} --body-file {{f}}", None, FILE_TEXT),
    ("eval_wrapper", f"eval 'gh pr comment 7 -R {TP} --body-file {{f}}'", None, FILE_TEXT),
    ("bash_dash_c", f"bash -c 'gh pr comment 7 -R {TP} --body-file {{f}}'", None, FILE_TEXT),
    ("command_substitution", f'echo "$(gh pr comment 7 -R {TP} --body-file {{f}})"', None, FILE_TEXT),
    ("backticks", f"echo `gh pr comment 7 -R {TP} --body-file {{f}}`", None, FILE_TEXT),
    ("subshell", f"(gh pr comment 7 -R {TP} --body-file {{f}})", None, FILE_TEXT),
    ("issue_comment", f"gh issue comment 3 -R {TP} --body-file {{f}}", None, FILE_TEXT),
    ("pr_review_comment", f"gh pr review 7 -R {TP} --comment --body 'Two notes.'", None, "Two notes."),
    ("pr_review_request_changes", f"gh pr review 7 -R {TP} --request-changes -b 'Needs a test.'", None, "Needs a test."),
    (
        "pr_create_file",
        f"gh pr create -R {TP} --title 'Fix retry ordering' --body-file {{f}} --head a --base b",
        "Fix retry ordering",
        FILE_TEXT,
    ),
    (
        "pr_create_inline",
        f"gh pr create -R {TP} -t 'Fix retry ordering' -b 'Short body.'",
        "Fix retry ordering",
        "Short body.",
    ),
    ("issue_create", f"gh issue create -R {TP} --title 'Report' --body-file {{f}}", "Report", FILE_TEXT),
    ("pr_edit_body", f"gh pr edit 7 -R {TP} --body-file {{f}}", None, FILE_TEXT),
    ("issue_edit_title", f"gh issue edit 3 -R {TP} --title 'New title'", "New title", None),
    ("issue_close_comment", f"gh issue close 3 -R {TP} --comment 'Superseded.'", None, "Superseded."),
    ("pr_close_comment", f"gh pr close 7 -R {TP} -c 'Superseded.'", None, "Superseded."),
    ("pr_merge_body", f"gh pr merge 7 -R {TP} --squash --subject 'Fix' --body 'Details.'", "Fix", "Details."),
    (
        "api_post_comment",
        f"gh api -X POST repos/{TP}/issues/7/comments -f body='Looks right.'",
        None,
        "Looks right.",
    ),
    ("api_implicit_post", f"gh api repos/{TP}/issues/7/comments -f body=ok", None, "ok"),
    ("api_method_long", f"gh api --method POST repos/{TP}/issues/7/comments -f body=ok", None, "ok"),
    ("api_method_equals", f"gh api --method=POST repos/{TP}/issues/7/comments -f body=ok", None, "ok"),
    ("api_lowercase_method", f"gh api -X post repos/{TP}/issues/7/comments -f body=ok", None, "ok"),
    ("api_patch_comment", f"gh api --method PATCH repos/{TP}/issues/comments/99 -f body=ok", None, "ok"),
    ("api_patch_issue", f"gh api -X PATCH repos/{TP}/issues/7 -f title=T -f body=B", "T", "B"),
    ("api_patch_pull", f"gh api -X PATCH repos/{TP}/pulls/7 -f body=B", None, "B"),
    ("api_put_merge", f"gh api -X PUT repos/{TP}/pulls/7/merge -f commit_title=T -f commit_message=M", "T", "M"),
    ("api_body_from_file", f"gh api -X POST repos/{TP}/issues/7/comments -F body=@{{f}}", None, FILE_TEXT),
    ("api_input_file", f"gh api -X POST repos/{TP}/issues/7/comments --input {{j}}", None, JSON_TEXT),
    ("api_create_issue", f"gh api repos/{TP}/issues -f title=T -f body=B", "T", "B"),
    ("api_create_pull", f"gh api repos/{TP}/pulls -f title=T -f head=a -f base=b -f body=B", "T", "B"),
    ("api_review", f"gh api -X POST repos/{TP}/pulls/7/reviews -f event=COMMENT -f body=B", None, "B"),
    ("api_review_reply", f"gh api -X POST repos/{TP}/pulls/7/comments/5/replies -f body=B", None, "B"),
    ("api_leading_slash", f"gh api -X POST /repos/{TP}/issues/7/comments -f body=ok", None, "ok"),
    ("api_url_endpoint", f"gh api -X POST https://api.github.com/repos/{TP}/issues/7/comments -f body=ok", None, "ok"),
    ("api_flags_after_endpoint", f"gh api repos/{TP}/issues/7/comments -X POST -f body=ok", None, "ok"),
]

# Forms found by the adversarial review of the first build. Same contract as OUTBOUND.
OUTBOUND_HARDENING = [
    ("continuation_review", f"gh pr review 7 -R {TP} --comment \\\n --body 'x'", None, "x"),
    ("continuation_create", f"gh pr create -R {TP} \\\n --title 'Fix' \\\n --body 'x'", "Fix", "x"),
    ("continuation_api", f"gh api -X POST repos/{TP}/issues/7/comments \\\n -f body='x'", None, "x"),
    ("continuation_repo_flag", f"gh pr comment 7 \\\n --repo {TP} --body 'x'", None, "x"),
    ("brace_group", f"{{ gh pr comment 7 -R {TP} --body x; }}", None, "x"),
    ("if_then", f"if true; then gh pr comment 7 -R {TP} --body x; fi", None, "x"),
    ("if_condition", f"if gh pr comment 7 -R {TP} --body x; then echo ok; fi", None, "x"),
    ("for_do", f"for n in 7; do gh pr comment $n -R {TP} --body x; done", None, "x"),
    ("negation", f"! gh pr comment 7 -R {TP} --body x", None, "x"),
    ("cluster_review", f"gh pr review 7 -R {TP} -cb 'x'", None, "x"),
    ("cluster_close", f"gh pr close 7 -R {TP} -dc 'x'", None, "x"),
    ("cluster_merge", f"gh pr merge 7 -R {TP} -sb 'x'", None, "x"),
    ("cluster_create", f"gh pr create -R {TP} -dt 'Title' -db 'x' -H h -B main", "Title", "x"),
    ("cluster_api", f"gh api -X POST repos/{TP}/issues/7/comments -if body='x'", None, "x"),
    ("issue_new", f"gh issue new -R {TP} --title T --body x", "T", "x"),
    ("pr_new", f"gh pr new -R {TP} --title T --body x", "T", "x"),
    ("pr_revert", f"gh pr revert 7 -R {TP} --title R --body x", "R", "x"),
    ("comment_lines_with_apostrophes", f"# post the reviewer's fixes\ngh pr comment 7 -R {TP} --body x\n# that's it", None, "x"),
    ("hash_inside_quotes", f"gh pr comment 7 -R {TP} --body 'see issue #4'", None, "see issue #4"),
    ("hash_inside_double_quotes", f'gh pr comment 7 -R {TP} --body "a # b"', None, "a # b"),
    ("op_run", f"op run --env-file .env -- gh pr comment 7 -R {TP} --body x", None, "x"),
    ("env_split_string", f"env -S 'gh pr comment 7 -R {TP} --body x'", None, "x"),
    ("find_exec", f"find . -maxdepth 0 -exec gh pr comment 7 -R {TP} --body x \\;", None, "x"),
    ("noglob", f"noglob gh pr comment 7 -R {TP} --body x", None, "x"),
    ("caffeinate", f"caffeinate -i gh pr comment 7 -R {TP} --body x", None, "x"),
    ("timeout_fraction", f"timeout 1.5m gh pr comment 7 -R {TP} --body x", None, "x"),
    ("bash_c_double_dash", f"bash -c -- 'gh pr comment 7 -R {TP} --body x'", None, "x"),
    ("sudo_user", f"sudo -u bob gh pr comment 7 -R {TP} --body x", None, "x"),
    ("xargs_replace", f"xargs -I{{}} gh pr comment 7 -R {TP} --body x", None, "x"),
    (
        "empty_heredoc_hides_gh",
        f"cat <<EOF >/dev/null\nEOF\ngh pr comment 7 -R {TP} --body x\ncat <<EOF >/dev/null\ny\nEOF",
        None,
        "x",
    ),
    (
        "quoted_heredoc_marker",
        f"echo 'use <<EOF here'\ngh pr comment 7 -R {TP} --body x\ncat <<EOF\ny\nEOF",
        None,
        "x",
    ),
    (
        "single_quoted_dollar_and_backticks",
        f"gh pr create -R {TP} --title 'fix: handle `None` in search' --body 'costs $5' -H h",
        "fix: handle `None` in search",
        "costs $5",
    ),
    ("process_substitution_in", f"diff <(gh pr comment 7 -R {TP} --body x) /dev/null", None, "x"),
    ("process_substitution_out", f"cat body.md | tee >(gh pr comment 7 -R {TP} --body x) >/dev/null", None, "x"),
    ("quotes_inside_substitution_do_not_desync", f"echo \"$(cat <<'EOF'\n\"\nEOF\n)\"; gh pr comment 7 -R {TP} --body x", None, "x"),
    ("quotes_inside_substitution_then_post", f"echo \"$(echo 'a \"b')\" && gh pr comment 7 -R {TP} --body x", None, "x"),
    ("alias_variable", f'G="env -u GH_TOKEN gh"; $G pr comment 7 -R {TP} --body x', None, "x"),
    ("alias_variable_braces", f'G=gh; ${{G}} pr comment 7 -R {TP} --body x', None, "x"),
    ("alias_function", f'G() {{ env -u GH_TOKEN gh "$@"; }}; G pr comment 7 -R {TP} --body x', None, "x"),
    ("dynamic_command_word", f"$GH pr comment 7 -R {TP} --body-file {{f}}", None, FILE_TEXT),
    ("web_flag_false", f"gh pr comment 7 -R {TP} --web=false --body x", None, "x"),
    ("env_bash_c", f"env -u GH_TOKEN -u GITHUB_TOKEN bash -c \"gh pr comment 7 -R {TP} --body 'x'\"", None, "x"),
    ("op_run_bash_c", f"op run --env-file .env -- bash -c \"gh pr comment 7 -R {TP} --body 'x'\"", None, "x"),
    ("xargs_bash_c", f"xargs -0 bash -c 'gh pr comment 7 -R {TP} --body x'", None, "x"),
    ("find_exec_sh_c", f"find . -maxdepth 0 -exec sh -c 'gh pr comment 7 -R {TP} --body x' \\;", None, "x"),
    ("if_then_bash_c", f"if true; then bash -c 'gh pr comment 7 -R {TP} --body x'; fi", None, "x"),
    ("env_eval", f"env -u X eval \"gh pr comment 7 -R {TP} --body x\"", None, "x"),
    ("assignment_named_gh", f"GH_CONFIG_DIR=~/.config/gh gh pr comment 7 -R {TP} --body x", None, "x"),
    ("env_assignment_named_gh", f"env GH_CONFIG_DIR=$HOME/.config/gh gh pr comment 7 -R {TP} --body x", None, "x"),
    ("unquoted_heredoc_substitution", f"cat <<EOF\n$(gh pr comment 7 -R {TP} --body x)\nEOF", None, "x"),
    ("unquoted_heredoc_backticks", f"cat <<EOF\n`gh pr comment 7 -R {TP} --body x`\nEOF", None, "x"),
    ("discussion_create", f"gh discussion create -R {TP} --title T --body x -c General", "T", "x"),
    ("discussion_comment", f"gh discussion comment 3 -R {TP} --body x", None, "x"),
    ("discussion_edit", f"gh discussion edit 3 -R {TP} --title T --body x", "T", "x"),
    ("rest_review_dismissal", f"gh api -X PUT repos/{TP}/pulls/7/reviews/1/dismissals -f message=x", None, "x"),
    ("heredoc_delimiter_is_whole_word", f"cat <<'EO'F\nx\nEOF\ngh pr comment 7 -R {TP} --body x\nEO", None, "x"),
    ("heredoc_delimiter_with_colon", f"cat <<END:\nx\nEND:\ngh pr comment 7 -R {TP} --body x", None, "x"),
    ("arithmetic_command_is_not_a_heredoc", f"(( m = 1 << bit ))\ngh pr comment 7 -R {TP} --body x\nbit", None, "x"),
    ("let_is_not_a_heredoc", f"let x=1<<n\ngh pr comment 7 -R {TP} --body x\nn", None, "x"),
    ("head_flag_takes_its_value", f"gh pr create -R {TP} -t T --body 'UNREVIEWED' --head '-bR'", "T", "UNREVIEWED"),
]

# Not outbound prose, so the gate must stay out of the way.
ALLOWED_BASH = [
    f"gh pr view 7 -R {TP}",
    f"gh pr list -R {TP}",
    f"gh pr diff 7 -R {TP}",
    f"gh pr checks 7 -R {TP}",
    f"gh pr checkout 7 -R {TP}",
    f"gh issue view 3 -R {TP} --comments",
    f"gh issue list -R {TP}",
    f"gh repo view {TP}",
    f"gh api repos/{TP}/pulls/7",
    f"gh api repos/{TP}/issues/7/comments",
    f"gh api -X GET repos/{TP}/issues/7/comments -f per_page=5",
    f"gh api -X DELETE repos/{TP}/issues/comments/99",
    f"gh api -X POST repos/{TP}/issues/7/labels -f 'labels[]=bug'",
    f"gh api repos/{TP}/pulls/7/reviews -f event=APPROVE",
    f"gh api -X POST repos/{TP}/git/refs -f ref=refs/heads/x -f sha=abc",
    f"gh api graphql -f query='query {{ viewer {{ login }} }}'",
    f"gh pr edit 7 -R {TP} --add-label bug",
    f"gh pr review 7 -R {TP} --approve",
    f"gh pr comment 7 -R {TP} --delete-last",
    f"gh pr create -R {TP} --web",
    f"gh issue close 3 -R {TP}",
    "git status",
    "git commit -m 'docs: mention gh pr comment in the guide'",
    "echo gh pr comment 7 --body x",
    "cat <<'EOF'\nit's a note about gh pr comment\nEOF",
    "ls -la /tmp",
    "bash <<'EOF'\ngh pr list --search review-requested:@me\nEOF",
    "R=myorg/tools; gh issue create -R \"$R\" --title T --body B",
    "gh discussion list -R otherorg/widgets",
    f"echo \"$(gh pr view 5 -R {TP} --json state -q '\"state=\\(.state)\"')\"",
    f"for n in 1 2; do printf \"PR %s: %s\\n\" \"$n\" \"$(gh pr view $n -R {TP} --json mergeable --jq '\"\\(.mergeable)\"')\"; done",
    f'G="env -u GH_TOKEN gh"; $G pr view 7 -R {TP}; $G api repos/{TP}/pulls/7 --jq .title',
    f'G() {{ env -u GH_TOKEN gh "$@"; }}; G pr list -R {TP}',
    f"gh pr merge 7 -R {TP} --squash --delete-branch=false",
    f"gh pr create -R {TP} --web=true",
    "gh api graphql -f query='mutation { resolveReviewThread(input: {threadId: \"x\"}) { clientMutationId } }'",
    'git commit -m "run `bash` then gh pr comment"',
    "echo $(( 1 << 2 )) && git status",
    f"cat > notes.md <<\\EOF\nRun gh pr comment 7 -R {TP} --body x\nEOF",
    f"gh pr checks 7 -R {TP}  # don't merge until green",
    f"# it's only a review read\ngh pr view 7 -R {TP}",
    "grep -rn '$(gh pr comment' .",
    "git commit -m 'docs: explain `gh pr comment` usage'",
    f"git commit -m $'Fix: don\\'t crash' && gh pr view 5 -R {TP}",
    "git commit -m \"$(cat <<'EOF'\nfix: mention gh pr comment (it's fine)\nEOF\n)\"",
    "gh pr comment 7 -R myorg/x --body ok  # owned form",
    "$GH pr comment 7 -R myorg/x --body ok",
    "which gh",
    "brew install gh",
    "command -v gh",
    "git log --oneline | head",
    "python3 -c 'print(1)'",
    "echo 'unterminated",
    "grep -r 'gh api' docs",
    "",
]


class TestOutboundForms(GateCase):
    def test_every_form_is_denied_without_a_receipt(self):
        for name, template, _title, _body in OUTBOUND + OUTBOUND_HARDENING:
            with self.subTest(name):
                self.assertDenied(self.bash(template))

    def test_every_form_is_allowed_with_a_receipt_for_its_exact_text(self):
        for name, template, title, body in OUTBOUND + OUTBOUND_HARDENING:
            with self.subTest(name):
                self.record(title=title, body=body, command=template)
                self.assertAllowed(self.bash(template))

    def test_a_receipt_for_different_text_does_not_allow(self):
        for name, template, title, body in OUTBOUND + OUTBOUND_HARDENING:
            with self.subTest(name):
                self.record(title=title and title + "!", body=body and body + "!", command=template)
                self.assertDenied(self.bash(template))

    def test_denial_names_the_hash_and_how_to_record_a_receipt(self):
        reason = self.assertDenied(self.bash(f"gh pr comment 7 -R {TP} --body-file {{f}}"))
        self.assertIn(sha(None, FILE_TEXT), reason)
        self.assertIn("record --help", reason)
        self.assertIn("disposition", reason)
        self.assertIn("scope=", reason)

    def test_non_outbound_commands_are_allowed(self):
        for command in ALLOWED_BASH:
            with self.subTest(command):
                self.assertAllowed(self.bash(command))


class TestReceiptValidity(GateCase):
    def cmd(self):
        return f"gh pr comment 7 -R {TP} --body-file {{f}}"

    def test_edited_body_changes_the_hash_and_is_denied(self):
        self.record(body=FILE_TEXT)
        self.assertAllowed(self.bash(self.cmd()))
        self.body_file.write_text(FILE_TEXT + "One more sentence.\n")
        self.assertDenied(self.bash(self.cmd()))

    def test_trailing_whitespace_does_not_change_the_hash(self):
        self.record(body=FILE_TEXT.rstrip("\n"))
        self.assertAllowed(self.bash(self.cmd()))

    def test_receipt_recorded_from_file_matches_command_using_same_file(self):
        text = ["--repo", TP, *SCOPE, "--body-file", str(self.body_file)]
        r = self.run_gate(["record", *text, "--reviewer-model", "opus", "--verdict", "go", "--findings", "0"])
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertDenied(self.bash(self.cmd()))  # recorded but not yet dispositioned
        self.assertEqual(self.run_gate(["disposition", *text]).returncode, 0)
        self.assertAllowed(self.bash(self.cmd()))

    def test_undispositioned_receipt_is_denied(self):
        self.record(body=FILE_TEXT, dispositioned=False)
        self.assertDenied(self.bash(self.cmd()))

    def test_no_go_verdict_is_denied(self):
        self.record(body=FILE_TEXT, verdict="no-go")
        self.assertDenied(self.bash(self.cmd()))

    def test_receipt_without_reviewer_model_is_denied(self):
        self.write_receipt(sha(None, FILE_TEXT), reviewer_model="")
        self.assertDenied(self.bash(self.cmd()))

    def test_corrupt_receipt_is_denied(self):
        self.receipts.mkdir()
        (self.receipts / f"{sha(None, FILE_TEXT)}.json").write_text("{not json")
        self.assertDenied(self.bash(self.cmd()))

    def test_receipt_whose_inner_hash_disagrees_with_filename_is_denied(self):
        self.write_receipt(sha(None, FILE_TEXT), sha256="0" * 64)
        self.assertDenied(self.bash(self.cmd()))

    def test_receipt_that_is_not_an_object_is_denied(self):
        self.receipts.mkdir()
        (self.receipts / f"{sha(None, FILE_TEXT)}.json").write_text("[]")
        self.assertDenied(self.bash(self.cmd()))

    def test_a_receipt_for_another_repo_does_not_unlock(self):
        self.record(body=FILE_TEXT, repo="other/thing")
        self.assertDenied(self.bash(self.cmd()))
        self.record(body=FILE_TEXT, repo=TP)
        self.assertAllowed(self.bash(self.cmd()))

    def test_unresolved_or_ambiguous_repo_cannot_be_unlocked(self):
        self.record(body="x")
        reason = self.assertDenied(self.bash("gh pr comment 7 --body x"))
        self.assertIn("-R owner/repo", reason)
        mixed = self.tmp / "mixed"
        mixed.mkdir()
        subprocess.run(["git", "init", "-q", str(mixed)], check=True)
        subprocess.run(["git", "-C", str(mixed), "remote", "add", "origin", "git@github.com:myorg/tools.git"], check=True)
        subprocess.run(["git", "-C", str(mixed), "remote", "add", "upstream", f"git@github.com:{TP}.git"], check=True)
        self.assertIn("-R owner/repo", self.assertDenied(self.bash("gh pr comment 7 --body x", cwd=mixed)))

    def test_title_is_part_of_the_key(self):
        self.record(title="Fix", body=FILE_TEXT)
        template = f"gh pr create -R {TP} --title 'Other' --body-file {{f}}"
        self.assertDenied(self.bash(template))


class TestRepoOwnership(GateCase):
    def cmd(self, repo):
        return f"gh pr comment 7 -R {repo} --body-file {{f}}"

    def test_owned_repos_need_no_receipt(self):
        for repo in ("myorg/tools", "Myorg/Tools", "github.com/myorg/x", "forgejo/myorg/x"):
            with self.subTest(repo):
                self.assertAllowed(self.bash(self.cmd(repo)))

    def test_lookalikes_are_third_party(self):
        for repo in ("myorg-evil/x", "OtherOrg/myorg", "notmyorg/x", "evil.com/myorg/x"):
            with self.subTest(repo):
                self.assertDenied(self.bash(self.cmd(repo)))

    def test_owned_patterns_can_be_overridden(self):
        env = {"OUTBOUND_GATE_OWNED": "github.com/someoneelse/*"}
        self.assertAllowed(self.bash(self.cmd("someoneelse/x"), env=env))
        self.assertDenied(self.bash(self.cmd("myorg/x"), env=env))

    def git_repo(self, *remotes):
        repo = self.tmp / "checkout"
        repo.mkdir(exist_ok=True)
        subprocess.run(["git", "init", "-q", str(repo)], check=True)
        for name, url in remotes:
            subprocess.run(["git", "-C", str(repo), "remote", "add", name, url], check=True)
        return repo

    def test_without_repo_flag_cwd_remotes_decide(self):
        owned = self.git_repo(("origin", "git@github.com:myorg/tools.git"))
        self.assertAllowed(self.bash("gh pr comment 7 --body-file {f}", cwd=owned))

    def test_a_third_party_remote_makes_the_checkout_third_party(self):
        repo = self.git_repo(
            ("origin", "git@github.com:myorg/app.git"),
            ("upstream", "https://github.com/otherorg/widgets.git"),
        )
        self.assertDenied(self.bash("gh pr comment 7 --body-file {f}", cwd=repo))

    def test_unresolvable_repo_is_treated_as_third_party(self):
        self.assertDenied(self.bash("gh pr comment 7 --body-file {f}", cwd=self.tmp / "work"))

    def test_explicit_repo_beats_cwd_remotes(self):
        owned = self.git_repo(("origin", "git@github.com:myorg/tools.git"))
        self.assertDenied(self.bash(self.cmd(TP), cwd=owned))

    def test_gh_api_endpoint_repo_decides(self):
        self.assertAllowed(self.bash("gh api -X POST repos/myorg/tools/issues/7/comments -f body=ok"))
        self.assertDenied(self.bash(f"gh api -X POST repos/{TP}/issues/7/comments -f body=ok"))


class TestUnverifiableText(GateCase):
    """Outbound-looking commands whose text cannot be hashed fail closed."""

    def denied_as_unverifiable(self, command):
        self.assertDenied(self.bash(command), contains="cannot be verified")

    def test_dynamic_or_unreadable_bodies_are_denied(self):
        cases = {
            "command_substitution_body": f'gh pr comment 7 -R {TP} --body "$(cat {{f}})"',
            "variable_body": f'gh pr comment 7 -R {TP} --body "$BODY"',
            "backtick_body": f'gh pr comment 7 -R {TP} --body "`code`"',
            "stdin_body_file": f"gh pr comment 7 -R {TP} --body-file -",
            "heredoc_stdin": f"gh pr comment 7 -R {TP} --body-file - <<'EOF'\nreviewed text\nEOF",
            "herestring": f"gh pr comment 7 -R {TP} --body-file - <<< 'text'",
            "missing_file": f"gh pr comment 7 -R {TP} --body-file /nonexistent/body.md",
            "variable_path": f"gh pr comment 7 -R {TP} --body-file $HOME/body.md",
            "comment_without_body": f"gh pr comment 7 -R {TP}",
            "editor": f"gh pr create -R {TP} --editor",
            "fill": f"gh pr create -R {TP} --fill",
            "fill_first": f"gh pr create -R {TP} --fill-first",
            "template": f"gh pr create -R {TP} --template t.md",
            "api_stdin_input": f"gh api -X POST repos/{TP}/issues/7/comments --input -",
            "api_stdin_field": f"gh api -X POST repos/{TP}/issues/7/comments -F body=@-",
            "api_missing_input": f"gh api -X POST repos/{TP}/issues/7/comments --input /nonexistent.json",
            "api_graphql_mutation": (
                f"gh api graphql -f query='mutation {{ addComment(input: {{subjectId: \"x\", body: \"b\"}}) "
                f"{{ clientMutationId }} }}'"
            ),
            "bash_c_variable": f"bash -c \"gh pr comment 7 -R {TP} --body-file $F\"",
            "graphql_query_built_by_shell": "Q='mutation { addComment(input: {subjectId: \"x\", body: \"u\"}) { clientMutationId } }'; gh api graphql -f query=\"$Q\"",
            "graphql_query_from_substitution": "gh api graphql -f query=\"$(cat m.graphql)\"",
            "graphql_submit_review": "gh api graphql -f query='mutation { submitPullRequestReview(input: {pullRequestId: \"x\", event: COMMENT, body: \"u\"}) { clientMutationId } }'",
            "sentinel_characters": f"gh pr comment 7 -R {TP} --body \"costs \x025\"",
            "script_on_stdin_heredoc": f"bash <<'EOF'\ngh pr comment 7 -R {TP} --body x\nEOF",
            "script_piped_to_shell": f'echo "gh pr comment 7 -R {TP} --body x" | sh',
            "repeated_body_flags_differ": f"gh pr comment 7 -R {TP} --body 'Unreviewed words' --body 'R'",
            "bool_with_junk_value": f"gh pr merge 7 -R {TP} --delete-branch=maybe",
            "graphql_comment_mutation": (
                "gh api graphql -f query='mutation { addComment(input: {subjectId: \"x\", body: \"b\"}) { clientMutationId } }'"
            ),
            "fill_equals_true": f"gh pr create -R {TP} --fill=true -H h",
            "editor_equals_true": f"gh pr create -R {TP} --editor=true",
            "template_equals": f"gh pr create -R {TP} --template=t.md",
            "draft_plus_fill_cluster": f"gh pr create -R {TP} -df -H h",
            "unknown_flag": f"gh pr comment 7 -R {TP} --frobnicate --body x",
            "unknown_short_flag": f"gh pr comment 7 -R {TP} -Z --body x",
            "double_quoted_dollar": f'gh pr comment 7 -R {TP} --body "costs $5"',
            "ansi_c_body": f"gh pr comment 7 -R {TP} --body $'line\\nbreak'",
            "api_graphql_file": "gh api graphql -F query=@mut.graphql",
            "api_traversal": f"gh api -X POST repos/myorg/x/../../{TP}/issues/7/comments -f body=x",
            "url_and_repo_disagree": f"gh pr comment https://github.com/{TP}/pull/7 -R myorg/tools --body x",
            "unbalanced_quote_in_post": f'gh pr comment 7 -R {TP} --body "never closed',
        }
        for name, command in cases.items():
            with self.subTest(name):
                self.denied_as_unverifiable(command)

    def test_a_receipt_cannot_unlock_an_unverifiable_command(self):
        self.record(body="anything")
        self.denied_as_unverifiable(f"gh pr comment 7 -R {TP} --body-file -")

    def test_unverifiable_commands_on_owned_repos_are_allowed(self):
        self.assertAllowed(self.bash("gh pr comment 7 -R myorg/tools --body-file -"))
        self.assertAllowed(self.bash("gh pr create -R myorg/tools --fill"))


class TestMcp(GateCase):
    def test_every_tool_is_gated_on_third_party_repos_and_unlocked_by_its_receipt(self):
        o, r = "OtherOrg", "widgets"
        cases = [
            ("mcp__github__add_issue_comment", dict(owner=o, repo=r, issue_number=7, body="B"), None, "B"),
            (
                "mcp__github__add_reply_to_pull_request_comment",
                dict(owner=o, repo=r, pullNumber=7, commentId=5, body="B"),
                None,
                "B",
            ),
            (
                "mcp__github__add_comment_to_pending_review",
                dict(owner=o, repo=r, pullNumber=7, path="a.py", body="B", subjectType="LINE"),
                None,
                "B",
            ),
            (
                "mcp__github__create_pull_request",
                dict(owner=o, repo=r, title="T", body="B", head="a", base="b"),
                "T",
                "B",
            ),
            ("mcp__github__issue_write", dict(method="create", owner=o, repo=r, title="T", body="B"), "T", "B"),
            ("mcp__github__issue_write", dict(method="update", owner=o, repo=r, issue_number=3, body="B"), None, "B"),
            (
                "mcp__github__pull_request_review_write",
                dict(method="create", owner=o, repo=r, pullNumber=7, event="COMMENT", body="B"),
                None,
                "B",
            ),
            (
                "mcp__github__pull_request_review_write",
                dict(method="submit_pending", owner=o, repo=r, pullNumber=7, event="COMMENT", body="B"),
                None,
                "B",
            ),
            ("mcp__github__update_issue_comment", dict(owner=o, repo=r, comment_id=9, body="B"), None, "B"),
            ("mcp__github__update_pull_request", dict(owner=o, repo=r, pullNumber=7, title="T", body="B"), "T", "B"),
            ("mcp__plugin_github_github__add_issue_comment", dict(owner=o, repo=r, issue_number=7, body="B"), None, "B"),
        ]
        for name, tool_input, title, body in cases:
            with self.subTest(name + str(tool_input.get("method", ""))):
                shutil.rmtree(self.receipts, ignore_errors=True)
                self.assertDenied(self.mcp(name, tool_input))
                self.record(title=title, body=body, tool=(name, tool_input))
                self.assertAllowed(self.mcp(name, tool_input))
                self.assertDenied(self.mcp(name, {**tool_input, "body": "edited"} if "body" in tool_input
                                           else {**tool_input, "title": "edited"}))

    def test_owned_github_owner_is_allowed(self):
        tool_input = dict(owner="myorg", repo="tools", issue_number=7, body="B")
        self.assertAllowed(self.mcp("mcp__github__add_issue_comment", tool_input))

    def test_calls_without_prose_are_allowed(self):
        o, r = "OtherOrg", "widgets"
        cases = [
            ("mcp__github__add_issue_comment", dict(owner=o, repo=r, issue_number=7, reaction="+1")),
            ("mcp__github__issue_write", dict(method="update", owner=o, repo=r, issue_number=3, labels=["bug"])),
            ("mcp__github__update_pull_request", dict(owner=o, repo=r, pullNumber=7, state="closed")),
            ("mcp__github__pull_request_review_write", dict(method="resolve_thread", owner=o, repo=r, pullNumber=7, threadId="PRRT_x")),
            ("mcp__github__pull_request_review_write", dict(method="create", owner=o, repo=r, pullNumber=7, event="APPROVE")),
            ("mcp__github__list_issues", dict(owner=o, repo=r)),
            ("mcp__github__get_me", {}),
            ("mcp__forgejo__list_issues", dict(owner=o, repo=r)),
            ("Read", dict(file_path="/tmp/x")),
        ]
        for name, tool_input in cases:
            with self.subTest(name):
                self.assertAllowed(self.mcp(name, tool_input))

    def test_forgejo_tools_target_the_owned_host_by_default(self):
        cases = [
            ("mcp__forgejo__create_issue", dict(owner="myorg", repo="x", title="T", body="B")),
            ("mcp__forgejo__create_issue_comment", dict(owner="myorg", repo="x", index=1, body="B")),
            ("mcp__forgejo__create_pull_request", dict(owner="myorg", repo="x", title="T", head="a", base="b")),
            ("mcp__forgejo__create_pull_request_review", dict(owner="myorg", repo="x", index=1, event="COMMENT", body="B")),
            ("mcp__forgejo__edit_issue", dict(owner="myorg", repo="x", index=1, body="B")),
            ("mcp__forgejo__edit_issue_comment", dict(owner="myorg", repo="x", id=1, body="B")),
            ("mcp__forgejo__edit_pull_request", dict(owner="myorg", repo="x", index=1, title="T")),
        ]
        for name, tool_input in cases:
            with self.subTest(name):
                self.assertAllowed(self.mcp(name, tool_input))

    def test_forgejo_tools_are_gated_when_the_owned_list_excludes_the_host(self):
        env = {"OUTBOUND_GATE_OWNED": "github.com/myorg/*"}
        tool_input = dict(owner="myorg", repo="x", index=1, body="B")
        self.assertDenied(self.mcp("mcp__forgejo__create_issue_comment", tool_input, env=env))
        self.record(body="B", tool=("mcp__forgejo__create_issue_comment", tool_input), env=env)
        self.assertAllowed(self.mcp("mcp__forgejo__create_issue_comment", tool_input, env=env))

    def test_forgejo_review_inline_comments_are_part_of_the_reviewed_text(self):
        env = {"OUTBOUND_GATE_OWNED": "github.com/myorg/*"}
        tool_input = dict(
            owner="myorg", repo="x", index=1, event="COMMENT", body="B",
            comments=[{"path": "a.py", "body": "inline one"}],
        )
        self.record(body="B", tool=("mcp__forgejo__create_pull_request_review", tool_input), env=env)
        self.assertDenied(self.mcp("mcp__forgejo__create_pull_request_review", tool_input, env=env))
        self.record(body="B\n\ninline one", tool=("mcp__forgejo__create_pull_request_review", tool_input), env=env)
        self.assertAllowed(self.mcp("mcp__forgejo__create_pull_request_review", tool_input, env=env))


class TestFailOpenAndMalformed(GateCase):
    def test_garbage_payloads_are_allowed(self):
        cases = {
            "empty_stdin": "",
            "not_json": "{oops",
            "json_list": "[]",
            "json_null": "null",
            "no_tool_name": "{}",
            "no_tool_input": '{"tool_name": "Bash"}',
            "tool_input_not_object": '{"tool_name": "Bash", "tool_input": "x"}',
            "command_not_string": '{"tool_name": "Bash", "tool_input": {"command": 5}}',
            "command_null": '{"tool_name": "Bash", "tool_input": {"command": null}}',
            "mcp_input_not_object": '{"tool_name": "mcp__github__add_issue_comment", "tool_input": []}',
            "mcp_body_not_string": (
                '{"tool_name": "mcp__github__add_issue_comment", '
                '"tool_input": {"owner": "OtherOrg", "repo": "widgets", "body": 5}}'
            ),
        }
        for name, raw in cases.items():
            with self.subTest(name):
                self.assertAllowed(self.hook(None, raw=raw))

    def test_mcp_post_with_no_resolvable_repo_is_denied(self):
        self.assertDenied(self.mcp("mcp__github__add_issue_comment", dict(issue_number=7, body="B")))

    def test_unknown_hook_event_is_allowed(self):
        payload = {"hook_event_name": "PostToolUse", "tool_name": "Bash",
                   "tool_input": {"command": f"gh pr comment 7 -R {TP} --body x"}}
        self.assertAllowed(self.hook(payload))


class TestRecordHelper(GateCase):
    def test_record_then_disposition_complete_the_receipt(self):
        text = ["--repo", TP, *SCOPE, "--title", "T", "--body", "B"]
        r = self.run_gate(["record", *text, "--reviewer-model", "opus", "--verdict", "go", "--findings", "2"])
        self.assertEqual(r.returncode, 0, r.stderr)
        key = r.stdout.strip()
        self.assertEqual(key, sha("T", "B"))
        data = json.loads((self.receipts / f"{key}.json").read_text())
        self.assertEqual(data["sha256"], key)
        self.assertEqual(data["repo"], TP_KEY)
        self.assertEqual(data["reviewer_model"], "opus")
        self.assertEqual(data["verdict"], "go")
        self.assertEqual(data["findings"], 2)
        self.assertIs(data["dispositioned"], False)
        self.assertRegex(data["reviewed_at"], r"^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ$")
        d = self.run_gate(["disposition", *text])
        self.assertEqual(d.returncode, 0, d.stderr)
        self.assertEqual(d.stdout.strip(), key)
        data = json.loads((self.receipts / f"{key}.json").read_text())
        self.assertIs(data["dispositioned"], True)
        self.assertRegex(data["dispositioned_at"], r"^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ$")

    def test_disposition_accepts_the_key_instead_of_the_text(self):
        key = self.record(body="B", dispositioned=False)
        self.assertEqual(self.run_gate(["disposition", "--sha256", key]).returncode, 0)
        data = json.loads((self.receipts / f"{key}.json").read_text())
        self.assertIs(data["dispositioned"], True)

    def test_disposition_refuses_without_a_go_receipt(self):
        text = ["--repo", TP, *SCOPE, "--body", "B"]
        missing = self.run_gate(["disposition", *text])
        self.assertEqual(missing.returncode, 2)
        self.assertIn("no receipt", missing.stderr)
        self.record(body="B", verdict="no-go")
        refused = self.run_gate(["disposition", *text])
        self.assertEqual(refused.returncode, 2)
        self.assertIn("verdict", refused.stderr)

    def test_record_no_longer_accepts_a_self_declared_disposition(self):
        r = self.run_gate(["record", "--repo", TP, *SCOPE, "--body", "B", "--reviewer-model", "opus", "--verdict", "go",
                           "--findings", "0", "--dispositioned"])
        self.assertEqual(r.returncode, 2)

    def test_hash_subcommand_matches_the_gate_key(self):
        r = self.run_gate(["hash", "--repo", TP, *SCOPE, "--title", "T", "--body-file", str(self.body_file)])
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(r.stdout.strip(), sha("T", FILE_TEXT))

    def test_the_key_depends_on_the_repo(self):
        a = self.run_gate(["hash", "--repo", TP, *SCOPE, "--body", "B"]).stdout
        b = self.run_gate(["hash", "--repo", "other/thing", *SCOPE, "--body", "B"]).stdout
        c = self.run_gate(["hash", "--repo", "github.com/OTHERORG/Widgets.git", *SCOPE, "--body", "B"]).stdout
        self.assertRegex(a, r"^[0-9a-f]{64}$")
        self.assertNotEqual(a, b)
        self.assertEqual(a, c)

    def test_the_key_depends_on_the_action_and_the_target(self):
        base = ["hash", "--repo", TP, "--body", "B"]
        keys = {self.run_gate([*base, "--action", a, "--target", t]).stdout
                for a, t in (("pr comment", "7"), ("pr comment", "8"), ("issue comment", "7"), ("pr merge", "7"),
                             ("pr comment", ""))}
        self.assertEqual(len(keys), 5)
        self.assertNotIn("", keys)

    def test_record_requires_repo_text_model_verdict_and_findings(self):
        base = ["--repo", TP, "--body", "B", "--reviewer-model", "opus", "--verdict", "go", "--findings", "1",
                "--action", "pr comment"]

        def without(flag):
            args = list(base)
            i = args.index(flag)
            return ["record", *args[:i], *args[i + 2:]]

        def swap(flag, value, new_flag=None):
            args = list(base)
            i = args.index(flag)
            args[i:i + 2] = [new_flag or flag, value]
            return ["record", *args]

        bad = [
            without("--repo"),
            without("--action"),
            without("--body"),
            without("--reviewer-model"),
            without("--verdict"),
            without("--findings"),
            swap("--findings", "x"),
            swap("--repo", "not a repo"),
            swap("--repo", "myorg/../x"),
            swap("--body", "/nonexistent", "--body-file"),
            swap("--verdict", "maybe"),
        ]
        for args in bad:
            with self.subTest(args):
                r = self.run_gate(args)
                self.assertEqual(r.returncode, 2)
                self.assertTrue(r.stderr.strip())
                self.assertEqual(r.stdout, "")

    def test_record_creates_the_receipt_directory(self):
        self.assertFalse(self.receipts.exists())
        self.record(body="B")
        self.assertTrue(self.receipts.is_dir())


class TestSpeed(GateCase):
    def test_median_runtime_is_well_under_100ms(self):
        payload = json.dumps({"tool_name": "Bash", "tool_input": {"command": "git status && ls -la"}})
        outbound = json.dumps({"tool_name": "Bash", "tool_input": {"command": f"gh pr comment 7 -R {TP} --body-file {self.body_file}"}})
        for label, stdin in (("non_outbound", payload), ("outbound", outbound)):
            times = []
            for _ in range(9):
                start = time.perf_counter()
                self.run_gate([], stdin=stdin)
                times.append(time.perf_counter() - start)
            with self.subTest(label):
                self.assertLess(statistics.median(times), 0.25, times)


if __name__ == "__main__":
    unittest.main()
