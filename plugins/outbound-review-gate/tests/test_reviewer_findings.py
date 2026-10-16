"""Regression tests for the adversarial review of the first build.

Each test reproduces a payload the reviewer showed getting through (or being
wrongly denied). Shared plumbing lives in test_outbound_comment_review_gate.
"""

import importlib.machinery
import importlib.util
import json
import os
import re
import shlex
import shutil
import subprocess
import tempfile
import time
import unittest

from test_outbound_comment_review_gate import FILE_TEXT, GATE, SCOPE, TP, GateCase, sha


class TestReviewerFindings(GateCase):
    def repo(self, name, *remotes):
        path = self.tmp / name
        path.mkdir()
        subprocess.run(["git", "init", "-q", str(path)], check=True)
        for rname, url in remotes:
            subprocess.run(["git", "-C", str(path), "remote", "add", rname, url], check=True)
        return path

    def owned(self):
        return self.repo("owned", ("origin", "git@github.com:myorg/tools.git"))

    def thirdparty(self):
        return self.repo("tp", ("origin", f"https://github.com/{TP}.git"))

    def shell_tool(self, tool, command):
        return self.hook({"hook_event_name": "PreToolUse", "tool_name": tool, "tool_input": {"command": command}})

    # -- command-line context ----------------------------------------------
    def test_cd_in_the_same_command_makes_cwd_repo_unknown(self):
        tp = self.thirdparty()
        self.assertDenied(self.bash(f"cd {tp} && gh pr comment 7 --body x", cwd=self.owned()))

    def test_cd_in_the_same_command_makes_relative_body_file_unverifiable(self):
        reason = self.assertDenied(self.bash(f"cd .. && gh pr comment 7 -R {TP} --body-file body.md"))
        self.assertIn("cannot be verified", reason)

    def test_absolute_body_file_after_cd_is_still_hashed(self):
        self.record(body=FILE_TEXT)
        self.assertAllowed(self.bash(f"cd / && gh pr comment 7 -R {TP} --body-file {{f}}"))

    def test_exported_gh_repo_decides_the_repo(self):
        self.assertDenied(self.bash(f"export GH_REPO={TP}; gh pr comment 7 --body x", cwd=self.owned()))

    def test_inherited_gh_repo_decides_the_repo(self):
        self.assertDenied(self.bash("gh pr comment 7 --body x", cwd=self.owned(), env={"GH_REPO": TP}))

    def test_gh_host_makes_a_bare_repo_unresolvable(self):
        env = {"GH_HOST": "ghe.example.com"}
        self.assertDenied(self.bash("gh pr comment 7 -R myorg/tools --body x", env=env))
        self.assertAllowed(self.bash("gh pr comment 7 -R github.com/myorg/tools --body x", env=env))

    # -- repo identity -----------------------------------------------------
    def test_url_inside_body_does_not_choose_the_repo(self):
        body = "Fix is in https://github.com/myorg/app/pull/4"
        self.assertDenied(self.bash(f"gh pr comment 7 --body '{body}'", cwd=self.thirdparty()))

    def test_third_party_url_inside_body_does_not_block_owned_repo(self):
        body = f"See https://github.com/{TP}/pull/4"
        self.assertAllowed(self.bash(f"gh pr comment 7 --body '{body}'", cwd=self.owned()))

    def test_url_selector_decides_the_repo(self):
        self.assertDenied(self.bash(f"gh pr comment https://github.com/{TP}/pull/7 --body x", cwd=self.owned()))
        self.assertAllowed(
            self.bash("gh pr comment https://github.com/myorg/tools/pull/7 --body x", cwd=self.thirdparty())
        )

    def test_gh_default_repo_marker_picks_the_remote(self):
        remotes = (("origin", "git@github.com:myorg/tools.git"), ("upstream", f"git@github.com:{TP}.git"))
        owned_default = self.repo("d1", *remotes)
        subprocess.run(["git", "-C", str(owned_default), "config", "remote.origin.gh-resolved", "base"], check=True)
        self.assertAllowed(self.bash("gh pr comment 7 --body x", cwd=owned_default))
        third_default = self.repo("d2", *remotes)
        subprocess.run(["git", "-C", str(third_default), "config", "remote.upstream.gh-resolved", "base"], check=True)
        self.assertDenied(self.bash("gh pr comment 7 --body x", cwd=third_default))
        explicit = self.repo("d3", *remotes)
        subprocess.run(["git", "-C", str(explicit), "config", "remote.upstream.gh-resolved", "myorg/tools"], check=True)
        self.assertAllowed(self.bash("gh pr comment 7 --body x", cwd=explicit))

    def test_owner_and_repo_must_be_plain_names(self):
        for repo in ("myorg/x/../../otherorg/widgets", "myorg/x hi", "myorg/..", "myorg/x\ny"):
            with self.subTest(repo):
                self.assertDenied(self.bash(f"gh pr comment 7 -R '{repo}' --body x"))

    def test_mcp_owner_and_repo_must_be_plain_names(self):
        tool_input = dict(owner="myorg", repo="x/../../otherorg/widgets", issue_number=7, body="B")
        self.assertDenied(self.mcp("mcp__github__add_issue_comment", tool_input))

    # -- flag parsing ------------------------------------------------------
    def test_flag_values_are_not_scanned_as_flags(self):
        self.assertDenied(self.bash(f"gh pr comment 7 -R {TP} --body '-Rmyorg/x hi'"))
        self.assertDenied(self.bash(f"gh pr create -R {TP} --title '-Rmyorg/x: fix' --body x -H h"))

    def test_text_after_a_value_flag_that_looks_like_a_cluster_is_the_posted_text(self):
        self.record(title="T", body="R")
        self.assertDenied(self.bash(f"gh pr create -R {TP} -t T --body 'UNREVIEWED' --head '-bR'"))

    # -- other ways to run a shell -----------------------------------------
    def test_other_shell_tools_are_gated(self):
        command = f"gh pr comment 7 -R {TP} --body x"
        for tool in ("mcp__terminal__run_in_terminal", "Monitor"):
            with self.subTest(tool):
                shutil.rmtree(self.receipts, ignore_errors=True)
                self.assertDenied(self.shell_tool(tool, command))
                self.record(body="x")
                self.assertAllowed(self.shell_tool(tool, command))

    def test_osascript_shell_escape_is_denied_unless_owned(self):
        script = f'do shell script "gh pr comment 7 -R {TP} --body x"'
        reason = self.assertDenied(self.mcp("mcp__Control_your_Mac__osascript", {"script": script}))
        self.assertIn("cannot be verified", reason)
        owned = 'do shell script "gh pr comment 7 -R myorg/x --body x"'
        self.assertAllowed(self.mcp("mcp__Control_your_Mac__osascript", {"script": owned}))
        finder = 'tell application "Finder" to activate'
        self.assertAllowed(self.mcp("mcp__Control_your_Mac__osascript", {"script": finder}))

    # -- performance and robustness ----------------------------------------
    def test_huge_commands_are_fast_and_fail_closed(self):
        padding = "cat <<AAAA\n" * 30000
        start = time.perf_counter()
        r = self.bash(padding + f"gh pr comment 7 -R {TP} --body x")
        self.assertLess(time.perf_counter() - start, 2.0)
        self.assertIn("too large", self.assertDenied(r))
        start = time.perf_counter()
        self.assertAllowed(self.bash("echo hi\n" * 100000))
        self.assertLess(time.perf_counter() - start, 2.0)

    def test_many_heredoc_openers_are_linear(self):
        post = f"gh pr comment 7 -R {TP} --body x"
        start = time.perf_counter()
        self.assertAllowed(self.bash("x = v << s\n" * 5000 + post))  # the shell would swallow the post as a heredoc body
        self.assertDenied(self.bash("cat <<A\nA\n" * 5000 + post))
        self.assertLess(time.perf_counter() - start, 2.0)

    def test_fifo_body_file_is_denied_not_hung(self):
        fifo = self.work / "pipe.md"
        os.mkfifo(fifo)
        start = time.perf_counter()
        r = self.bash(f"gh pr comment 7 -R {TP} --body-file {fifo}")
        self.assertLess(time.perf_counter() - start, 5.0)
        self.assertIn("cannot be verified", self.assertDenied(r))

    def test_oversized_body_file_is_unverifiable(self):
        big = self.work / "big.md"
        big.write_bytes(b"x" * (2 * 1024 * 1024))
        self.assertIn("cannot be verified", self.assertDenied(self.bash(f"gh pr comment 7 -R {TP} --body-file {big}")))

    def test_deeply_nested_receipt_is_denied(self):
        self.receipts.mkdir()
        (self.receipts / f"{sha(None, FILE_TEXT)}.json").write_text("[" * 200000)
        self.assertDenied(self.bash(f"gh pr comment 7 -R {TP} --body-file {{f}}"))

    def test_invalid_utf8_on_stdin_does_not_fail_open(self):
        text = json.dumps({"tool_name": "Bash", "tool_input": {"command": f"gh pr comment 7 -R {TP} --body x # é"}})
        raw = text.encode().replace(b"\\u00e9", b"\xff\xfe")
        r = subprocess.run([str(GATE)], input=raw, capture_output=True, env=self.env, cwd=self.work)
        self.assertEqual(r.returncode, 0)
        self.assertIn(b"deny", r.stdout)

    # -- receipt key and MCP coverage --------------------------------------
    def test_key_cannot_collide_across_title_and_body(self):
        self.record(body="A\n\nB")
        self.assertDenied(self.bash(f"gh pr create -R {TP} -t A -b B -H h"))
        self.record(body="A")
        self.assertDenied(self.bash(f"gh issue edit 3 -R {TP} --title A"))

    def test_unrecognised_mcp_server_names_are_gated_when_they_carry_owner_and_repo(self):
        tool_input = dict(owner="OtherOrg", repo="widgets", issue_number=7, body="B")
        for server in ("gh", "a1b2c3d4-0000-4000-8000-000000000000"):
            with self.subTest(server):
                self.assertDenied(self.mcp(f"mcp__{server}__add_issue_comment", tool_input))

    def test_issue_tools_without_a_repo_are_not_github_posts(self):
        self.assertAllowed(self.mcp("mcp__linear__create_issue", dict(title="T", body="B")))

    def test_mcp_merge_commit_text_is_gated_like_gh_pr_merge(self):
        tool_input = dict(owner="OtherOrg", repo="widgets", pullNumber=7, commit_title="T", commit_message="M")
        self.assertDenied(self.mcp("mcp__github__merge_pull_request", tool_input))
        self.record(title="T", body="M", tool=("mcp__github__merge_pull_request", tool_input))
        self.assertAllowed(self.mcp("mcp__github__merge_pull_request", tool_input))
        bare = dict(owner="OtherOrg", repo="widgets", pullNumber=7)
        self.assertAllowed(self.mcp("mcp__github__merge_pull_request", bare))


class TestSecondReview(GateCase):
    def repo(self, name, *remotes):
        path = self.tmp / name
        path.mkdir()
        subprocess.run(["git", "init", "-q", str(path)], check=True)
        for rname, url in remotes:
            subprocess.run(["git", "-C", str(path), "remote", "add", rname, url], check=True)
        return path

    def setUp(self):
        super().setUp()
        self.owned = self.repo("owned", ("origin", "git@github.com:myorg/tools.git"))
        self.third = self.repo("third", ("origin", f"https://github.com/{TP}.git"))

    def test_literal_cd_to_an_owned_checkout_is_owned(self):
        self.assertAllowed(self.bash(f"cd {self.owned} && gh pr create --title T --body B"))
        self.assertAllowed(self.bash("cd owned && gh pr create --title T --body B", cwd=self.tmp))
        self.assertAllowed(self.bash(f"( cd {self.owned} && gh pr create --title T --body B )"))

    def test_literal_cd_to_a_third_party_checkout_is_third_party(self):
        self.assertDenied(self.bash(f"cd {self.third} && gh pr comment 7 --body x", cwd=self.owned))

    def test_cd_inside_a_subshell_does_not_leak_out(self):
        self.assertDenied(self.bash(f"( cd {self.owned} ); gh pr comment 7 --body x", cwd=self.third))
        self.assertAllowed(self.bash(f"( cd {self.third} ); gh pr comment 7 --body x", cwd=self.owned))

    def test_cd_to_a_computed_directory_makes_the_cwd_untrusted(self):
        self.assertDenied(self.bash('cd "$X" && gh pr comment 7 --body x', cwd=self.owned))
        self.assertDenied(self.bash("cd - && gh pr comment 7 --body x", cwd=self.owned))

    def test_relative_body_file_is_read_from_the_directory_cd_moved_to(self):
        (self.third / "body.md").write_text("Third checkout text.\n")
        self.record(body="Third checkout text.")
        self.assertAllowed(self.bash(f"cd {self.third} && gh pr comment 7 -R {TP} --body-file body.md"))
        self.assertDenied(self.bash(f"cd {self.owned} && gh pr comment 7 -R {TP} --body-file body.md"))

    def test_other_ways_to_change_directory_or_repo(self):
        third = self.third
        cases = {
            "chdir": f"chdir {third}; gh pr comment 7 --body u",
            "builtin_cd": f"builtin cd {third} && gh pr comment 7 --body u",
            "if_then_cd": f"if true; then cd {third}; fi; gh pr comment 7 --body u",
            "brace_group_cd": f"{{ cd {third} && gh pr comment 7 --body u; }}",
            "env_dash_C": f"env -C {third} gh pr comment 7 --body u",
            "env_chdir": f"env --chdir={third} gh pr comment 7 --body u",
            "export_after_assign": f"GH_REPO={TP}; export GH_REPO; gh pr comment 7 --body u",
            "typeset_x": f"typeset -x GH_REPO={TP}; gh pr comment 7 --body u",
            "declare_x": f"declare -x GH_REPO={TP}; gh pr comment 7 --body u",
            "set_a": f"set -a; GH_REPO={TP}; gh pr comment 7 --body u",
            "then_export": f"if true; then export GH_REPO={TP}; fi; gh pr comment 7 --body u",
        }
        for name, command in cases.items():
            with self.subTest(name):
                self.assertDenied(self.bash(command, cwd=self.owned))

    def test_graphql_query_files_are_read(self):
        read = self.work / "read.graphql"
        read.write_text("query { viewer { login } }")
        self.assertAllowed(self.bash(f"gh api graphql -F query=@{read}"))
        mutation = self.work / "mutation.graphql"
        mutation.write_text('mutation { addComment(input: {subjectId: "x", body: "u"}) { clientMutationId } }')
        self.assertIn("cannot be verified", self.assertDenied(self.bash(f"gh api graphql -F query=@{mutation}")))
        safe = self.work / "safe.graphql"
        safe.write_text('mutation { resolveReviewThread(input: {threadId: "x"}) { clientMutationId } }')
        self.assertAllowed(self.bash(f"gh api graphql -F query=@{safe}"))

    def test_literal_variable_in_the_repo_flag_is_resolved(self):
        self.assertDenied(self.bash("R=otherorg/widgets; gh issue create -R \"$R\" --title T --body B"))
        self.assertDenied(self.bash("gh issue create -R \"$UNKNOWN\" --title T --body B"))
        self.assertDenied(self.bash("gh issue create -R myorg/$repo --title T --body B"))

    def test_unresolved_repo_denial_says_how_to_fix_it(self):
        reason = self.assertDenied(self.bash("gh pr comment 7 --body x"))
        self.assertIn("-R owner/repo", reason)

    def test_project_board_mutations_without_text_pass_and_text_carrying_ones_do_not(self):
        move = "mutation { addProjectV2ItemById(input: {projectId: \"p\", contentId: \"c\"}) { clientMutationId } }"
        self.assertAllowed(self.bash(f"gh api graphql -f query='{move}'"))
        field = "mutation { updateProjectV2ItemFieldValue(input: {projectId: \"p\", value: {text: \"u\"}}) { clientMutationId } }"
        self.assertDenied(self.bash(f"gh api graphql -f query='{field}'"))
        variable = "mutation { updateProjectV2ItemFieldValue(input: {projectId: \"p\", value: $v}) { clientMutationId } }"
        self.assertDenied(self.bash(f"gh api graphql -f query='{variable}'"))
        select = "mutation { updateProjectV2ItemFieldValue(input: {projectId: \"p\", value: {singleSelectOptionId: \"o\"}}) { clientMutationId } }"
        self.assertAllowed(self.bash(f"gh api graphql -f query='{select}'"))
        draft = "mutation { addProjectV2DraftIssue(input: {projectId: \"p\", title: \"t\"}) { clientMutationId } }"
        self.assertDenied(self.bash(f"gh api graphql -f query='{draft}'"))

    def test_repeated_plain_field_posts_the_last_value_only(self):
        command = f"gh api repos/{TP}/issues/7/comments -f body=A -f body=B"
        self.record(body="B", command=command)
        self.assertAllowed(self.bash(command))
        shutil.rmtree(self.receipts)
        self.record(body="A\n\nB", command=command)
        self.assertDenied(self.bash(f"gh api repos/{TP}/issues/7/comments -f body=A -f body=B"))

    def test_ansi_c_quoted_command_name_is_unverifiable(self):
        reason = self.assertDenied(self.bash(f"$'gh' pr comment 7 -R {TP} --body x"))
        self.assertIn("cannot be verified", reason)

    def test_pipeline_stages_do_not_share_a_working_directory(self):
        post = "gh pr comment 1 --body hi"
        self.assertDenied(self.bash(f"cd {self.owned} | {post}", cwd=self.third))
        self.assertAllowed(self.bash(f"cd {self.third} | true; {post}", cwd=self.owned))
        self.assertAllowed(self.bash(f"cd {self.owned} && {post}", cwd=self.third))

    def test_left_shift_in_old_style_arithmetic_is_not_a_heredoc(self):
        post = f"gh pr comment 1 --body hi -R {TP}"
        self.assertDenied(self.bash(f"echo $[1<<3]\n{post}"))
        self.assertDenied(self.bash(f"a[1<<2]=x\n{post}"))
        self.assertAllowed(self.bash("cat <<EOF\nplain text\nEOF\ngit status"))

    def test_token_count_does_not_make_the_scan_quadratic(self):
        start = time.perf_counter()
        r = self.bash("gh review " + "a " * 120000)
        self.assertLess(time.perf_counter() - start, 2.0)
        self.assertAllowed(r)

    def test_fallback_for_unparseable_commands_is_linear(self):
        command = "gh pr create x " * 15000 + "'never closed"
        start = time.perf_counter()
        r = self.bash(command)
        self.assertLess(time.perf_counter() - start, 2.0)
        self.assertIn("cannot be verified", self.assertDenied(r))


class ShellCase(GateCase):
    def shell(self, command, agent=False, tool="Bash", env=None):
        payload = {"hook_event_name": "PreToolUse", "tool_name": tool, "tool_input": {"command": command},
                   "cwd": str(self.work)}
        if agent:
            payload.update(agent_id="a1b2c3", agent_type="general-purpose")
        return self.hook(payload, env=env)

    @property
    def record_line(self):
        return (f"{shlex.quote(str(GATE))} record --repo {TP} --body x --reviewer-model opus "
                "--verdict go --findings 0")


class TestReceiptIntegrity(ShellCase):
    """Only a reviewing subagent records a receipt, and nobody writes the receipt files by hand."""

    def test_record_is_denied_for_the_main_thread_and_allowed_for_a_subagent(self):
        reason = self.assertDenied(self.shell(self.record_line))
        self.assertIn("subagent", reason)
        self.assertAllowed(self.shell(self.record_line, agent=True))

    def test_every_way_of_running_the_helper_counts(self):
        gate = shlex.quote(str(GATE))
        flags = f"--repo {TP} --body x --reviewer-model opus --verdict go --findings 0"
        variants = {
            "home_path": f"~/.claude/hooks/outbound-comment-review-gate record {flags}",
            "env_prefix": f"env X=1 {gate} record {flags}",
            "after_cd": f"cd /tmp && {gate} record {flags}",
            "bash_c": f'bash -c "{gate} record {flags}"',
            "copied_and_renamed": f"python3 /tmp/copy.py record {flags}",
            "flag_only": f"python3 /tmp/copy.py {flags}",
            "if_then": f"if true; then {gate} record {flags}; fi",
        }
        for name, command in variants.items():
            with self.subTest(name):
                self.assertDenied(self.shell(command))
                self.assertAllowed(self.shell(command, agent=True))

    def test_other_helper_commands_stay_available_to_the_main_thread(self):
        gate = shlex.quote(str(GATE))
        for command in (f"{gate} disposition --repo {TP} --body x", f"{gate} hash --repo {TP} --body x",
                        f"{gate} record --help", f"{gate} --help"):
            with self.subTest(command):
                self.assertAllowed(self.shell(command))

    def test_receipt_files_cannot_be_written_by_hand(self):
        d = self.receipts
        denied = {
            "redirect": f"echo '{{}}' > {d}/x.json",
            "append": f"echo '{{}}' >> {d}/x.json",
            "tee": f"echo '{{}}' | tee {d}/x.json",
            "cp": f"cp /tmp/a {d}/x.json",
            "touch": f"touch {d}/x.json",
            "sed_i": f"sed -i '' s/a/b/ {d}/x.json",
            "python": f"python3 -c \"open('{d}/x.json', 'w').write('{{}}')\"",
            "redirect_from_reader": f"cat /tmp/a > {d}/x.json",
        }
        for name, command in denied.items():
            with self.subTest(name):
                self.assertIn("helper", self.assertDenied(self.shell(command)))
                self.assertIn("helper", self.assertDenied(self.shell(command, agent=True)))
        default = {"OUTBOUND_REVIEW_DIR": ""}
        for command in ("echo '{}' > ~/.claude/state/outbound-review/x.json",
                        "echo '{}' > $HOME/.claude/state/outbound-re''view/x.json",
                        'cp /tmp/a "$HOME/.claude/state/outbound-review/x.json"'):
            with self.subTest(command):
                self.assertDenied(self.shell(command, env=default))

    def test_receipt_files_can_be_read(self):
        d = self.receipts
        d.mkdir()
        (d / "x.json").write_text("{}")
        for command in (f"ls {d}", f"ls -la {d} 2>&1", f"cat {d}/x.json", f"jq . {d}/x.json",
                        f"grep -l go {d}/x.json", f"wc -c {d}/x.json", f"cat {d}/x.json > /tmp/copy.json"):
            with self.subTest(command):
                self.assertAllowed(self.shell(command))

    def test_edit_and_write_tools_cannot_touch_the_receipt_directory(self):
        d = self.receipts
        for tool in ("Write", "Edit"):
            with self.subTest(tool):
                inside = {"hook_event_name": "PreToolUse", "tool_name": tool,
                          "tool_input": {"file_path": f"{d}/x.json", "content": "{}"}}
                self.assertDenied(self.hook(inside))
                outside = {**inside, "tool_input": {"file_path": f"{self.work}/x.json", "content": "{}"}}
                self.assertAllowed(self.hook(outside))


class TestReceiptGuardHardening(ShellCase):
    """Fourth review: ways around the receipt-directory guard, and ordinary work it must not block."""

    def test_find_sort_and_rg_cannot_write_into_the_receipt_directory(self):
        d = self.receipts
        d.mkdir()
        for command in (
            f"printf x | sort -o {d}/k.json",
            f"printf x | sort --output={d}/k.json",
            f"find {d} -maxdepth 0 -fprint {d}/k.json",
            f"find /tmp -maxdepth 0 -exec cp /tmp/x {d}/k.json \\;",
            f"rg --pre ./x . {d}",
            f"find {d} -mtime +30 -delete",
        ):
            with self.subTest(command):
                self.assertDenied(self.shell(command))

    def test_find_sort_and_rg_can_still_read_the_receipt_directory(self):
        d = self.receipts
        d.mkdir()
        (d / "x.json").write_text("{}")
        for command in (f"find {d} -name '*.json'", f"sort {d}/x.json", f"rg go {d}", f"find {d} -newer /tmp -print"):
            with self.subTest(command):
                self.assertAllowed(self.shell(command))

    def test_the_receipt_directory_is_matched_without_regard_to_case(self):
        flipped = str(self.receipts).swapcase()
        for tool, tool_input in (("Write", {"file_path": f"{flipped}/k.json", "content": "x"}),
                                 ("Bash", {"command": f"touch {flipped}/k.json"})):
            with self.subTest(tool):
                payload = {"hook_event_name": "PreToolUse", "tool_name": tool, "tool_input": tool_input,
                           "cwd": str(self.work)}
                self.assertDenied(self.hook(payload))
        default = {"OUTBOUND_REVIEW_DIR": ""}
        self.assertDenied(self.shell("touch ~/.claude/State/OUTBOUND-REVIEW/k.json", env=default))

    def test_a_receipt_path_held_in_a_variable_is_expanded(self):
        d = self.receipts
        self.assertDenied(self.shell(f"D={d}; echo x > $D/k.json"))
        self.assertDenied(self.shell(f"D={d}; echo x > ${{D}}/k.json"))
        home_dir = {"OUTBOUND_REVIEW_DIR": "~/r"}
        self.assertDenied(self.shell("touch $HOME/r/a.json", env=home_dir))
        self.assertDenied(self.shell("touch ~/r/a.json", env={"OUTBOUND_REVIEW_DIR": f"{self.tmp}/r"}))

    def test_relative_and_dotdot_paths_to_the_receipt_directory_are_resolved(self):
        d = self.receipts
        self.assertDenied(self.shell(f"cd {d.parent} && touch receipts/k.json"))
        self.assertDenied(self.shell(f"touch {self.work}/../receipts/k.json"))
        payload = {"hook_event_name": "PreToolUse", "tool_name": "Write",
                   "tool_input": {"file_path": "../receipts/k.json", "content": "x"}, "cwd": str(self.work)}
        self.assertDenied(self.hook(payload))

    def test_the_helper_rejects_abbreviated_flags(self):
        r = self.run_gate(["record", "--repo", TP, *SCOPE, "--body", "x", "--reviewer", "opus", "--verdict", "go",
                           "--findings", "0"])
        self.assertEqual(r.returncode, 2, r.stdout + r.stderr)
        self.assertFalse(self.receipts.exists())

    def test_ordinary_work_in_paths_that_merely_contain_the_words_is_not_blocked(self):
        home = {"OUTBOUND_REVIEW_DIR": ""}
        for command in (
            'git commit -m "update outbound-review notes"',
            "git -C ~/Developer/outbound-review status",
            "python3 -m pytest ~/notes/outbound-review-gate/tests -q",
            "vim ~/notes/outbound-review-notes/todo.md",
            "code ~/Developer/outbound-review",
            "echo done > /tmp/outbound-review-log.txt",
            "grep -rn -- --reviewer-model ~/.claude/hooks",
            "git log --grep record -- outbound-comment-review-gate",
            "cd ~/Developer/outbound-review && pytest -q",
        ):
            with self.subTest(command):
                self.assertAllowed(self.shell(command, env=home))
        for path in ("~/notes/outbound-review-notes/a.md", "~/Developer/outbound-review/README.md",
                     "relative/outbound-review/x.json"):
            with self.subTest(path):
                payload = {"hook_event_name": "PreToolUse", "tool_name": "Write",
                           "tool_input": {"file_path": os.path.expanduser(path), "content": "x"}, "cwd": str(self.work)}
                self.assertAllowed(self.hook(payload, env=home))

    def test_a_short_receipt_directory_name_does_not_block_everything(self):
        env = {"OUTBOUND_REVIEW_DIR": "r"}
        self.assertAllowed(self.shell("npm run build", env=env))
        self.assertAllowed(self.shell("make -C r2 all", env=env))
        payload = {"hook_event_name": "PreToolUse", "tool_name": "Write",
                   "tool_input": {"file_path": "/a/src/main.py", "content": "x"}, "cwd": str(self.work)}
        self.assertAllowed(self.hook(payload, env=env))

    def test_the_helper_commands_still_work_from_inside_the_receipt_directory_path(self):
        gate = shlex.quote(str(GATE))
        self.assertAllowed(self.shell(f"{gate} hash --repo {TP} --body x"))
        self.assertAllowed(self.shell(f"cd {self.receipts.parent} && {gate} disposition --repo {TP} --body x"))


class TestRecordViaInterpreters(ShellCase):
    """Fourth review, unprobed forms: a shell or interpreter fed the record command on stdin, and osascript."""

    FLAGS = f"--repo {TP} --body x --reviewer-model opus --verdict go --findings 0"

    def test_record_fed_to_an_interpreter_counts_as_running_the_helper(self):
        h = "~/.claude/hooks/outbound-comment-review-gate"
        variants = {
            "bash_heredoc": f"bash <<'EOF'\n{h} record {self.FLAGS}\nEOF",
            "sh_dash_s_heredoc": f"sh -s <<EOF\n{h} record {self.FLAGS}\nEOF",
            "pipe_into_bash": f"echo '{h} record {self.FLAGS}' | bash",
            "pipe_into_zsh_dash_s": f"printf %s '{h} record {self.FLAGS}' | zsh -s",
            "python_stdin": f"python3 - <<'EOF'\nimport subprocess\nsubprocess.run(['{h}', 'record'])\nEOF",
            "source_process_substitution": f"source <(echo '{h} record {self.FLAGS}')",
            "dot_process_substitution": f". <(echo '{h} record {self.FLAGS}')",
        }
        for name, command in variants.items():
            with self.subTest(name):
                self.assertDenied(self.shell(command))
                self.assertAllowed(self.shell(command, agent=True))

    def test_osascript_cannot_run_record_for_the_main_thread(self):
        script = f'do shell script "~/.claude/hooks/outbound-comment-review-gate record {self.FLAGS}"'
        payload = {"hook_event_name": "PreToolUse", "tool_name": "mcp__Control_your_Mac__osascript",
                   "tool_input": {"script": script}, "cwd": str(self.work)}
        self.assertDenied(self.hook(payload))
        self.assertAllowed(self.hook({**payload, "agent_id": "a1"}))

    def test_interpreters_that_merely_mention_the_words_are_not_blocked(self):
        for command in ("python3 -m pytest outbound-comment-review-gate/tests -k record",
                        "bash scripts/run.sh --reviewer",
                        "bash <<'EOF'\necho record\nEOF",
                        "python3 - <<'EOF'\nprint('outbound-comment-review-gate')\nEOF"):
            with self.subTest(command):
                self.assertAllowed(self.shell(command))


class TestPublishedDefaults(ShellCase):
    """The script ships without any maintainer-specific default: nothing is owned until the user says so."""

    def test_nothing_is_exempt_when_no_owned_list_is_configured(self):
        unset = {"OUTBOUND_GATE_OWNED": ""}
        self.assertDenied(self.bash("gh pr comment 7 -R myorg/tools --body x", env=unset))
        self.assertDenied(self.bash("gh pr comment 7 -R git.example.test/myorg/x --body x", env=unset))

    def test_the_forgejo_host_comes_from_the_environment(self):
        tool_input = dict(owner="acme", repo="x", index=1, body="B")
        env = {"OUTBOUND_GATE_OWNED": "git.example.test/acme/*", "OUTBOUND_GATE_FORGEJO_HOST": "git.example.test"}
        self.assertAllowed(self.mcp("mcp__forgejo__create_issue_comment", tool_input, env=env))
        elsewhere = {"OUTBOUND_GATE_OWNED": "git.example.test/acme/*", "OUTBOUND_GATE_FORGEJO_HOST": "other.test"}
        self.assertDenied(self.mcp("mcp__forgejo__create_issue_comment", tool_input, env=elsewhere))
        unset = {"OUTBOUND_GATE_OWNED": "git.example.test/acme/*"}
        self.assertDenied(self.mcp("mcp__forgejo__create_issue_comment", tool_input, env=unset))

    def test_every_denial_that_points_at_the_helper_gives_its_full_path(self):
        record = f"{shlex.quote(str(GATE))} record --repo {TP} --body x --reviewer-model opus --verdict go --findings 0"
        self.assertIn(str(GATE), self.assertDenied(self.shell(record)))
        self.assertIn(str(GATE), self.assertDenied(self.shell(f"touch {self.receipts}/k.json")))
        self.assertIn(str(GATE), self.assertDenied(self.bash(f"gh pr comment 7 -R {TP} --body x")))


def scope_of(reason):
    """The scope=<json> segment of a denial: the repo, action and target a receipt must name."""
    m = re.search(r"scope=(\{.*?\})", reason)
    assert m, reason
    return json.loads(m.group(1))


class TestReceiptScope(ShellCase):
    """A receipt vouches for one repo, one kind of post and one target, not for the text anywhere in the repo."""

    NONE_OWNED = {"OUTBOUND_GATE_OWNED": "none/*"}

    def scope(self, command=None, **mcp):
        if command is not None:
            reason = self.assertDenied(self.bash(command, env=self.NONE_OWNED))
        else:
            reason = self.assertDenied(self.mcp(mcp.pop("tool"), mcp.pop("tool_input"), env=self.NONE_OWNED))
        return scope_of(reason)

    def test_gh_commands_report_their_action_and_target(self):
        cases = {
            f"gh pr comment 7 -R {TP} --body x": ("pr comment", "7"),
            f"gh issue comment 9 -R {TP} --body x": ("issue comment", "9"),
            f"gh pr comment https://github.com/{TP}/pull/7 --body x": ("pr comment", "7"),
            f"gh pr comment -R {TP} --body x": ("pr comment", ""),
            f"gh pr create -R {TP} --title t --body x -H h": ("pr create", ""),
            f"gh issue new -R {TP} --title t --body x": ("issue create", ""),
            f"gh pr merge 5 -R {TP} --body x": ("pr merge", "5"),
            f"gh pr close 7 -R {TP} --comment hi": ("pr close", "7"),
            f"gh pr review 7 -R {TP} --comment --body x": ("pr review --comment", "7"),
            f"gh pr review 7 -R {TP} --approve --body x": ("pr review --approve", "7"),
            f"gh api -X POST repos/{TP}/issues/7/comments -f body=x": ("api POST", f"repos/{TP}/issues/7/comments".lower()),
        }
        for command, (action, target) in cases.items():
            with self.subTest(command):
                got = self.scope(command)
                self.assertEqual((got["action"], got["target"]), (action, target))
                self.assertEqual(got["repo"], TP.lower().join(["github.com/", ""]))

    def test_mcp_tools_report_their_action_and_target(self):
        o, r = "otherorg", "widgets"
        cases = [
            ("mcp__github__add_issue_comment", dict(owner=o, repo=r, issue_number=7, body="B"), ("add_issue_comment", "7")),
            ("mcp__github__create_issue", dict(owner=o, repo=r, title="T", body="B"), ("create_issue", "")),
            ("mcp__github__merge_pull_request", dict(owner=o, repo=r, pullNumber=5, commit_message="B"), ("merge_pull_request", "5")),
            ("mcp__forgejo__create_issue_comment", dict(owner=o, repo=r, index=3, body="B"), ("create_issue_comment", "3")),
            ("mcp__forgejo__edit_issue_comment", dict(owner=o, repo=r, id=11, body="B"), ("edit_issue_comment", "11")),
            ("mcp__github__issue_write", dict(method="update", owner=o, repo=r, issue_number=4, title="T"), ("issue_write update", "4")),
            ("mcp__github__add_reply_to_pull_request_comment", dict(owner=o, repo=r, pullNumber=5, commentId=99, body="B"),
             ("add_reply_to_pull_request_comment", "5/99")),
        ]
        for tool, tool_input, (action, target) in cases:
            with self.subTest(tool):
                got = self.scope(tool=tool, tool_input=tool_input)
                self.assertEqual((got["action"], got["target"]), (action, target))

    def test_a_receipt_unlocks_only_its_own_action_and_target(self):
        self.record(body="hi", action="pr comment", target="7")
        ok = f"gh pr comment 7 -R {TP} --body hi"
        self.assertAllowed(self.bash(ok))
        for other in (f"gh pr comment 8 -R {TP} --body hi", f"gh issue comment 7 -R {TP} --body hi",
                      f"gh pr merge 7 -R {TP} --body hi", f"gh pr close 7 -R {TP} --comment hi",
                      f"gh issue create -R {TP} --title t --body hi"):
            with self.subTest(other):
                self.assertDenied(self.bash(other))

    def test_a_receipt_does_not_unlock_a_sibling_comment_or_review_mode(self):
        reply = dict(owner="otherorg", repo="widgets", pullNumber=5, commentId=99, body="B")
        tool = ("mcp__github__add_reply_to_pull_request_comment", reply)
        self.record(body="B", tool=tool)
        self.assertAllowed(self.mcp(*tool))
        self.assertDenied(self.mcp(tool[0], dict(reply, commentId=100)))
        self.record(body="x", command=f"gh pr review 7 -R {TP} --comment --body x")
        self.assertDenied(self.bash(f"gh pr review 7 -R {TP} --approve --body x"))

    def test_the_helper_prints_the_same_key_as_the_hook_computes(self):
        for command in (f"gh pr comment 7 -R {TP} --body hi", f"gh pr create -R {TP} --title t --body hi -H h"):
            with self.subTest(command):
                got = self.scope(command)
                r = self.run_gate(["hash", "--repo", got["repo"], "--action", got["action"], "--target", got["target"],
                                   "--title", "t", "--body", "hi"] if "create" in command else
                                  ["hash", "--repo", got["repo"], "--action", got["action"], "--target", got["target"],
                                   "--body", "hi"])
                self.assertEqual(r.returncode, 0, r.stderr)
                self.assertRegex(r.stdout.strip(), r"^[0-9a-f]{64}$")

    def test_record_and_hash_require_an_action(self):
        flags = ["--repo", TP, "--body", "x"]
        self.assertEqual(self.run_gate(["hash", *flags]).returncode, 2)
        self.assertEqual(self.run_gate(["record", *flags, "--reviewer-model", "opus", "--verdict", "go",
                                        "--findings", "0"]).returncode, 2)

    def test_following_the_denial_unlocks_forgejo_and_enterprise_hosts(self):
        forgejo = dict(owner="acme", repo="x", index=1, body="B")
        got = self.scope(tool="mcp__forgejo__create_issue_comment", tool_input=forgejo)
        self.record(body="B", repo=got["repo"], action=got["action"], target=got["target"], env=self.NONE_OWNED)
        self.assertAllowed(self.mcp("mcp__forgejo__create_issue_comment", forgejo, env=self.NONE_OWNED))
        env = {"GH_HOST": "ghe.example.test", "OUTBOUND_GATE_OWNED": "none/*"}
        denial = self.assertDenied(self.bash(f"gh pr comment 7 -R acme/x --body B", env=env))
        got = scope_of(denial)
        self.assertEqual(got["repo"], "ghe.example.test/acme/x")
        self.record(body="B", repo="acme/x", action=got["action"], target=got["target"], env=env)
        self.assertAllowed(self.bash("gh pr comment 7 -R acme/x --body B", env=env))

    def test_graphql_text_mutations_say_they_cannot_be_reviewed(self):
        mutation = "mutation { addComment(input:{subjectId:\"I_1\", body:\"y\"}) { clientMutationId } }"
        reason = self.assertDenied(self.bash(f"gh api graphql -f query='{mutation}'", env={"OUTBOUND_GATE_OWNED": "github.com/myorg/*"}))
        self.assertIn("GraphQL", reason)
        self.assertNotIn("--body-file", reason)
        self.assertIn("gh pr comment", reason)


class TestFalsePositivesAndTiming(ShellCase):
    def test_text_that_merely_mentions_the_receipt_directory_is_not_a_write(self):
        home = {"OUTBOUND_REVIEW_DIR": "", "OUTBOUND_GATE_OWNED": "github.com/myorg/*"}
        for command in (
            'gh issue create -R myorg/x --title t --body "receipts live in ~/.claude/state/outbound-review"',
            'git commit -m "document ~/.claude/state/outbound-review"',
            "mkdir -p ~/.claude/state/outbound-review-notes",
            "echo ~/.claude/state/outbound-review",
        ):
            with self.subTest(command):
                self.assertAllowed(self.shell(command, env=home))

    def test_the_receipt_directory_is_still_protected_where_it_is_written(self):
        home = {"OUTBOUND_REVIEW_DIR": ""}
        for command in ("mkdir -p ~/.claude/state/outbound-review/sub", "touch ~/.claude/state/outbound-review/k.json",
                        "python3 -c \"open('/x/.claude/state/outbound-review/k.json','w')\"".replace("/x", "$HOME")):
            with self.subTest(command):
                self.assertDenied(self.shell(command, env=home))

    def test_other_spellings_of_the_receipt_directory_are_still_writes(self):
        home = {"OUTBOUND_REVIEW_DIR": ""}
        for command in ("echo x > ${VAR}/.claude/state/outbound-review/k.json",
                        "echo x > /Users/$USER/.claude/state/outbound-review/k.json",
                        f"echo x > /System/Volumes/Data{self.tmp}/.claude/state/outbound-review/k.json"):
            with self.subTest(command):
                self.assertDenied(self.shell(command, env=home))
        payload = {"hook_event_name": "PreToolUse", "tool_name": "Write", "cwd": str(self.work),
                   "tool_input": {"file_path": f"/System/Volumes/Data{self.tmp}/.claude/state/outbound-review/k.json", "content": "x"}}
        self.assertDenied(self.hook(payload, env=home))

    def test_a_gh_call_deep_inside_a_function_body_is_still_found(self):
        body = "echo filler\n" * 2000
        command = f"c() {{\n{body}  gh \"$@\"\n}}\nc pr comment 7 -R {TP} --body x"
        self.assertDenied(self.bash(command))

    def test_function_definition_scan_stays_linear(self):
        start = time.perf_counter()
        r = self.bash(f"gh pr comment 7 -R {TP} --body x\n" + "f(){ " * 24000)
        self.assertLess(time.perf_counter() - start, 5.0)
        self.assertEqual(r.returncode, 0)

    def test_a_file_named_dash_is_not_stdin(self):
        (self.work / "-").write_text("body from a file named dash")
        self.record(body="body from a file named dash")
        self.assertDenied(self.bash(f"gh pr comment 7 -R {TP} --body-file -"))


class TestHooksJson(unittest.TestCase):
    HOOKS = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "hooks", "hooks.json")

    def entry(self):
        with open(self.HOOKS) as fh:
            groups = json.load(fh)["hooks"]["PreToolUse"]
        self.assertEqual(len(groups), 1)
        return groups[0]

    def test_the_matcher_covers_every_tool_the_gate_inspects(self):
        loader = importlib.machinery.SourceFileLoader("gate_for_hooks", str(GATE))
        spec = importlib.util.spec_from_loader("gate_for_hooks", loader)
        gate = importlib.util.module_from_spec(spec)
        loader.exec_module(gate)
        matcher = re.compile(self.entry()["matcher"])
        names = ["Bash", "Write", "Edit", "MultiEdit", "NotebookEdit", "Monitor", "mcp__terminal__run_in_terminal",
                 "mcp__Control_your_Mac__osascript"]
        names += [f"mcp__{server}__{tool}" for server in ("github", "forgejo") for tool in gate.MCP_FIELDS]
        for name in names:
            with self.subTest(name):
                self.assertTrue(matcher.search(name), name)
        for name in ("Read", "Grep", "Glob", "WebFetch", "mcp__github__list_issues", "mcp__github__issue_read"):
            with self.subTest(name):
                self.assertFalse(matcher.search(name), name)

    def test_a_failing_hook_blocks_the_call(self):
        hook = self.entry()["hooks"][0]
        self.assertEqual(hook.get("onFailure"), "block")
        self.assertEqual(hook["type"], "command")
        self.assertIn("${CLAUDE_PLUGIN_ROOT}/scripts/outbound-comment-review-gate", hook["command"])
        self.assertTrue(os.access(str(GATE), os.X_OK))


class TestBuild7MainThreadHelper(ShellCase):
    """Independent review of build 6: the main thread may only run the helper's disposition, hash and help."""

    H = "~/.claude/hooks/outbound-comment-review-gate"
    FLAGS = f"--repo {TP} --body x --verdict go --findings 0"

    def test_hidden_record_is_denied_for_the_main_thread_and_allowed_for_a_subagent(self):
        h, f = self.H, self.FLAGS
        forms = {
            "variables": f"R=record M=--reviewer-model; {h} $R {f} $M opus",
            "ansi_c": f"{h} $'record' {f} $'--reviewer-model' opus",
            "substitution": f'{h} "$(echo record)" {f} "$(echo --reviewer-model)" opus',
            "variable_helper": f"HV={h}; $HV record {f} --reviewer-model opus",
            "copied_helper": f"cp {h} /tmp/x-copy && /tmp/x-copy record {f} --reviewer-model opus",
            "copied_helper_hidden_word": f"cp {h} /tmp/x-copy && /tmp/x-copy $R {f} $M opus",
            "backtick": f"{h} `echo record` {f}",
            "git_alias": f"git -c alias.x='!{h} record {f} --reviewer-model opus' x",
            "vim_command": f"vim -c '!{h} record {f} --reviewer-model opus' -c q",
            "xargs": f"echo x | xargs {h} $R {f}",
            "env_wrapper": f"env A=1 {h} $'rec''ord' {f}",
        }
        for name, command in forms.items():
            with self.subTest(name):
                self.assertDenied(self.shell(command))
                self.assertAllowed(self.shell(command, agent=True))

    def test_a_help_flag_does_not_excuse_the_record_only_flags(self):
        h = self.H
        self.assertDenied(self.shell(f"{h} record {self.FLAGS} --reviewer-model opus --help"))
        self.assertDenied(self.shell(f"python3 /tmp/copy.py {self.FLAGS} --note -h"))
        self.assertAllowed(self.shell(f"{h} record --help"))

    def test_the_main_thread_may_still_disposition_hash_and_ask_for_help(self):
        h = self.H
        plain = f"--repo {TP} --action 'pr comment' --target 7 --body x"
        for command in (f"{h} disposition {plain}", f"{h} hash {plain}", f"{h} --help", f"{h} -h",
                        f"{h} disposition --help", f"cat {h}", f"ls -la {h}", f"grep -n record {h}",
                        "git log --oneline -- outbound-comment-review-gate", f"rm -f /tmp/{h.rsplit('/', 1)[-1]}"):
            with self.subTest(command):
                self.assertAllowed(self.shell(command))


class TestBuild7Wrappers(ShellCase):
    """gh calls hidden inside a string handed to a wrapper that runs it as a shell command."""

    POST = f"gh pr comment 7 -R {TP} --body x"

    def test_wrapped_third_party_posts_are_denied(self):
        post = self.POST
        forms = {
            "watch": f"watch -n 1 '{post}'",
            "tmux": f"tmux new-session -d '{post}'",
            "script": f"script -q /dev/null -c '{post}'",
            "ssh": f"ssh host '{post}'",
            "osascript": f"osascript -e 'do shell script \"{post}\"'",
            "git_alias": f"git -c alias.p='!{post}' p",
            "git_rebase_exec": f"git rebase --exec '{post}' HEAD~1",
            "vim": f"vim -c '!{post}' -c q",
            "python": "python3 -c 'import subprocess; subprocess.run([\"gh\", \"pr\", \"comment\", \"7\", \"-R\", \"" + TP + "\"])'",
        }
        for name, command in forms.items():
            with self.subTest(name):
                self.assertDenied(self.bash(command))

    def test_wrapped_owned_posts_and_plain_mentions_are_allowed(self):
        for command in ("watch -n 1 'gh pr comment 7 -R myorg/x --body x'", "ssh host ls",
                        'git commit -m "document gh pr comment usage"', "watch -n 1 date",
                        f"echo '{self.POST}'", f"grep -rn 'gh pr comment' docs"):
            with self.subTest(command):
                self.assertAllowed(self.bash(command))

    def test_a_gh_command_is_not_rescanned_for_gh_text_in_its_own_body(self):
        own = {"OUTBOUND_GATE_OWNED": "github.com/myorg/*"}
        body = "enable it with `gh api -X PUT repos/myorg/x/automated-security-fixes`; it is \"quoted"
        command = f"env -u GH_TOKEN gh issue create -R myorg/x --title t --body '{body}' 2>&1 | tail -2"
        self.assertAllowed(self.bash(command, env=own))

    def test_ordinary_programs_whose_arguments_mention_gh_text_are_not_rescanned(self):
        for command in ("docker run -e MSG='please run gh pr comment later' img",
                        "make deploy NOTE='after gh pr comment 7 --body done'",
                        "npm run task -- 'gh pr comment 1 --body hey'",
                        "python3 tool.py --msg 'gh pr comment 1 --body hey'",
                        "echo x | xargs -I{} echo 'gh issue comment {} --body hi'"):
            with self.subTest(command):
                self.assertAllowed(self.bash(command))

    def test_a_wrapped_string_that_cannot_be_parsed_is_denied(self):
        self.assertDenied(self.bash(f"ssh host 'gh pr comment 7 -R {TP} --body \"unclosed'"))

    def test_a_wrapped_post_is_allowed_with_a_receipt_for_its_scope(self):
        command = f"watch -n 1 '{self.POST}'"
        self.record(body="x", command=command)
        self.assertAllowed(self.bash(command))


class TestBuild7Api(ShellCase):
    NONE = {"OUTBOUND_GATE_OWNED": "none/*"}

    def test_an_endpoint_built_by_the_shell_is_denied_for_writes(self):
        for command in (
            f"EP=repos/{TP}/issues/1/comments; gh api \"$EP\" -f body=x",
            f"K=issues/1/comments; gh api \"repos/{TP}/$K\" -f body=x",
            "gh api \"$EP\" -f body=x",
            "gh api \"$(echo repos/a/b/issues/1/comments)\" -f body=x",
            "gh api \"$EP\" -X PATCH --input payload.json",
        ):
            with self.subTest(command):
                self.assertDenied(self.bash(command, env=self.NONE))

    def test_a_literal_variable_endpoint_is_expanded_and_can_be_unlocked(self):
        command = f"EP=repos/{TP}/issues/1/comments; gh api \"$EP\" -f body=x"
        self.assertDenied(self.bash(command))
        self.record(body="x", command=command)
        self.assertAllowed(self.bash(command))

    def test_a_variable_repo_under_an_owned_owner_is_allowed(self):
        own = {"OUTBOUND_GATE_OWNED": "github.com/myorg/*"}
        self.assertAllowed(self.bash("gh api -X PUT \"repos/myorg/$r/automated-security-fixes\"", env=own))
        self.assertDenied(self.bash("gh api -X PUT \"repos/otherorg/$r/issues/1/comments\" -f body=x", env=own))
        self.assertDenied(self.bash("gh api -X PUT \"repos/$o/$r/issues/1/comments\" -f body=x", env=own))

    def test_reads_through_a_variable_endpoint_stay_allowed(self):
        self.assertAllowed(self.bash("gh api \"$EP\"", env=self.NONE))
        self.assertAllowed(self.bash("gh api \"$EP\" -X GET", env=self.NONE))

    def test_graphql_roots_hidden_by_commas_comments_aliases_or_spreads_are_denied(self):
        safe = 'resolveReviewThread(input:{threadId:"t"}){clientMutationId}'
        bad = {
            "comma": f'mutation {{ {safe} addComment(,input:{{subjectId:"X", body:"y"}}) {{ clientMutationId }} }}',
            "comment": f'mutation {{ {safe} addComment( # note\n input:{{subjectId:"X", body:"y"}}) {{ clientMutationId }} }}',
            "alias": f'mutation {{ {safe} x: addComment(input:{{subjectId:"X", body:"y"}}) {{ clientMutationId }} }}',
            "spread": f'mutation {{ {safe} ...F }} fragment F on Mutation {{ addComment(input:{{subjectId:"X", body:"y"}}) {{ clientMutationId }} }}',
            "variables": 'mutation($i: AddCommentInput!) { addComment(input: $i) { clientMutationId } }',
            "second_operation": f'mutation A {{ {safe} }} mutation B {{ addComment(input:{{subjectId:"X", body:"y"}}) {{ clientMutationId }} }}',
        }
        for name, query in bad.items():
            with self.subTest(name):
                (self.work / "q.graphql").write_text(query)
                self.assertDenied(self.bash(f"gh api graphql -F query=@{self.work}/q.graphql", env=self.NONE))

    def test_graphql_is_recognised_on_any_path_ending_in_graphql(self):
        mutation = 'mutation { addComment(input:{subjectId:"X", body:"y"}) { clientMutationId } }'
        for endpoint in ("graphql", "api/graphql", "https://ghe.example.test/api/graphql", "/graphql"):
            with self.subTest(endpoint):
                self.assertDenied(self.bash(f"gh api {endpoint} -f query='{mutation}'", env=self.NONE))

    def test_graphql_mutations_known_to_carry_no_text_still_pass(self):
        for query in ('mutation { resolveReviewThread(input:{threadId:"t"}){clientMutationId} }',
                      'mutation { a: resolveReviewThread(input:{threadId:"t"}){id}, b: unresolveReviewThread(input:{threadId:"u"}){id} }',
                      'query { viewer { login } }'):
            with self.subTest(query):
                (self.work / "q.graphql").write_text(query)
                self.assertAllowed(self.bash(f"gh api graphql -F query=@{self.work}/q.graphql", env=self.NONE))


class TestBuild7Curl(ShellCase):
    NONE = {"OUTBOUND_GATE_OWNED": "myorg/none-*"}
    GH = f"https://api.github.com/repos/{TP}/issues/1/comments"

    def test_write_shaped_curl_and_wget_to_a_third_party_api_are_denied(self):
        forms = [
            f"curl -s -X POST -H \"Authorization: token $T\" {self.GH} -d '{{\"body\":\"x\"}}'",
            f"curl -d '{{\"body\":\"x\"}}' {self.GH}",
            f"curl --json '{{\"body\":\"x\"}}' {self.GH}",
            f"curl -F body=x {self.GH}",
            f"curl -T notes.txt {self.GH}",
            f"curl -XPOST {self.GH}",
            f"curl --request PATCH {self.GH}",
            f"curl --data-binary @body.json {self.GH}",
            f"wget --post-data='x' {self.GH}",
            f"wget --method=PATCH --body-data=x {self.GH}",
            f"wget --post-file=body.json {self.GH}",
            "curl -X PATCH https://ghe.example.test/api/v3/repos/o/r/issues/1 -d x",
            "curl -X POST https://codeberg.example.test/api/v1/repos/o/r/issues/1/comments -d x",
            "curl -X POST https://api.github.com/graphql -d x",
            "curl -d x \"$URL\"",
            "curl -d x \"https://$HOST/api/v1/repos/o/r/issues/1/comments\"",
            f"curl -X POST {self.GH.replace('https://', '')} -d x",
            f"curl -d @body {self.GH.replace('api.github.com', 'api.github.com.')}",
            f"curl -d @body {self.GH.replace('https://', '//')}",
            f"curl -d @body {self.GH.replace('api.github.com', 'API.GitHub.com.')}",
            "curl -d @body https://ghe.example.test./api/v3/repos/o/r/issues/1/comments",
        ]
        for command in forms:
            with self.subTest(command):
                self.assertDenied(self.bash(command, env=self.NONE))

    def test_reads_other_hosts_and_owned_repos_are_allowed(self):
        own = {"OUTBOUND_GATE_OWNED": "github.com/myorg/*"}
        for command, env in (
            (f"curl -s {self.GH}", self.NONE),
            (f"curl -sL -X GET {self.GH}", self.NONE),
            ("curl -L -o x.tgz https://github.com/o/r/archive/main.tar.gz", self.NONE),
            ("curl -d x https://hooks.example.test/service", self.NONE),
            ("curl -d x https://example.test/$PATH_VAR", self.NONE),
            ("curl -s -X POST http://127.0.0.1:$p/api/explore/add -d x", self.NONE),
            ("wget https://example.test/f.tgz", self.NONE),
            ("curl -X POST https://api.github.com/repos/myorg/x/issues/1/comments -d x", own),
        ):
            with self.subTest(command):
                self.assertAllowed(self.bash(command, env=env))


class TestBuild7Nits(ShellCase):
    def git_repo(self, name, url):
        path = self.tmp / name
        subprocess.run(["git", "init", "-q", str(path)], check=True)
        subprocess.run(["git", "-C", str(path), "remote", "add", "origin", url], check=True)
        return path

    def test_many_cwd_calls_finish_in_time_and_still_deny_the_third_party_post(self):
        owned = self.git_repo("owned", "git@github.com:myorg/tools.git")
        command = "gh pr comment 1 --body x; " * 1500 + f"gh pr comment 7 -R {TP} --body x"
        start = time.perf_counter()
        r = self.bash(command, cwd=owned)
        self.assertLess(time.perf_counter() - start, 9.0)
        self.assertDenied(r)

    def test_a_server_that_is_not_github_or_forgejo_cannot_borrow_an_owned_github_name(self):
        tool_input = dict(owner="myorg", repo="r", issue_number=1, body="x")
        self.assertDenied(self.mcp("mcp__gitea__create_issue_comment", tool_input))
        self.assertAllowed(self.mcp("mcp__github__add_issue_comment", tool_input))

    def test_free_text_issue_fields_are_part_of_the_reviewed_text(self):
        tool = ("mcp__github__issue_write", dict(method="update", owner="otherorg", repo="widgets", issue_number=1,
                                                  issue_fields=[{"field_name": "Notes", "value": "free text"}]))
        self.assertDenied(self.mcp(*tool))
        self.record(body="free text", tool=tool)
        self.assertAllowed(self.mcp(*tool))
        edited = dict(tool[1], issue_fields=[{"field_name": "Notes", "value": "other text"}])
        self.assertDenied(self.mcp(tool[0], edited))

    def test_terminal_cwd_may_be_relative_or_use_a_tilde(self):
        self.git_repo("owned2", "git@github.com:myorg/tools.git")
        for cwd in ("~/owned2", "owned2"):
            with self.subTest(cwd):
                payload = {"hook_event_name": "PreToolUse", "tool_name": "mcp__terminal__run_in_terminal",
                           "tool_input": {"command": "gh pr comment 7 --body x", "cwd": cwd}, "cwd": str(self.tmp)}
                self.assertAllowed(self.hook(payload))


class TestBuild8(ShellCase):
    """Hub review of build 7: false denials of ordinary work, and gaps in the new curl and wrapper coverage."""

    H = "~/.claude/hooks/outbound-comment-review-gate"
    NONE = {"OUTBOUND_GATE_OWNED": "none/*"}
    GH = f"https://api.github.com/repos/{TP}/issues/1/comments"

    def test_naming_the_helper_among_other_operands_is_not_running_it(self):
        h = self.H
        for command in (f"git add {h} tests/t.py", f"git diff a b -- {h} README.md", f"git commit -m x {h} tests/t.py",
                        f"chmod +x {h} tests/t.py", f"sed -n 1,10p {h} tests/t.py",
                        f"python3 -m py_compile {h} tests/t.py"):
            with self.subTest(command):
                self.assertAllowed(self.shell(command))

    def test_wrappers_that_execute_the_helper_still_count(self):
        h, f = self.H, "--repo a/b --body x --verdict go --findings 0"
        for command in (f"timeout 5 {h} $'rec''ord' {f}", f"python3 {h} $R {f}", f"nohup {h} $R {f}",
                        f"sudo -u x {h} $R {f}", f"find . -exec {h} $R {f} \\;"):
            with self.subTest(command):
                self.assertDenied(self.shell(command))
                self.assertAllowed(self.shell(command, agent=True))

    def test_copying_the_helper_is_denied_for_the_main_thread_only(self):
        self.assertDenied(self.shell(f"cp {self.H} /tmp/x-copy"))
        self.assertAllowed(self.shell(f"cp {self.H} /tmp/x-copy", agent=True))
        self.assertAllowed(self.shell("cp tests/a.py /tmp/x-copy"))

    def test_local_and_unrelated_apis_pass_while_the_configured_hosts_are_gated(self):
        for command in ("curl -X POST http://localhost:3000/api/v1/login -d x",
                        "curl -X POST https://example.com/graphql -d '{}'",
                        "curl -s -d '{\"q\":1}' http://localhost:4000/graphql"):
            with self.subTest(command):
                self.assertAllowed(self.bash(command, env=self.NONE))
        forgejo = {"OUTBOUND_GATE_OWNED": "none/*", "OUTBOUND_GATE_FORGEJO_HOST": "git.example.test"}
        self.assertDenied(self.bash("curl -X POST https://git.example.test/api/v1/user -d x", env=forgejo))
        self.assertDenied(self.bash("curl -X POST https://api.github.com/graphql -d x", env=self.NONE))
        owned_host = {"OUTBOUND_GATE_OWNED": "git.mine.test/*"}
        self.assertDenied(self.bash("curl -X POST https://git.mine.test/api/v1/user -d x", env=owned_host))

    def test_a_scheme_cannot_hide_a_variable_host(self):
        self.assertDenied(self.bash('curl -d x "https://$H/$P"', env=self.NONE))

    def test_curl_and_wget_behind_exec_wrappers_are_gated(self):
        for command in (f"timeout 5 curl -d x {self.GH}", f"nohup curl -d x {self.GH}", f"sudo curl -d x {self.GH}",
                        f"env -u X curl -d x {self.GH}", f"exec curl -d x {self.GH}",
                        f"echo u | xargs curl -d x {self.GH}", f"nice wget --post-data=x {self.GH}",
                        f"time -p curl -d x {self.GH}"):
            with self.subTest(command):
                self.assertDenied(self.bash(command, env=self.NONE))

    def test_git_aliases_and_the_equals_form_of_rebase_exec_are_scanned(self):
        post = f"gh pr comment 7 -R {TP} --body x"
        self.assertDenied(self.bash(f"git -c alias.p='!gh' p pr comment 7 -R {TP} --body x"))
        self.assertDenied(self.bash(f"git rebase --exec='{post}' HEAD~1"))
        self.assertAllowed(self.bash("git -c alias.p='!echo' p hello"))

    def test_graphql_survives_trailing_slashes_escaped_quotes_and_bare_cr_comments(self):
        text = 'addComment(input:{subjectId:"X", body:"y"}){id}'
        queries = {
            "block_string": 'mutation { resolveReviewThread(input:{threadId:"""a\\"""b"""}){id} ' + text + ' }',
            "cr_comment": 'mutation { resolveReviewThread(input:{threadId:"t"}){id} #c\r' + text + ' }',
        }
        for name, query in queries.items():
            with self.subTest(name):
                (self.work / "q.graphql").write_text(query)
                self.assertDenied(self.bash(f"gh api graphql -F query=@{self.work}/q.graphql", env=self.NONE))
        mutation = 'mutation { addComment(input:{subjectId:"X", body:"y"}) { clientMutationId } }'
        for endpoint in ("graphql/", "/graphql/"):
            with self.subTest(endpoint):
                self.assertDenied(self.bash(f"gh api {endpoint} -f query='{mutation}'", env=self.NONE))

    def test_dot_segments_are_checked_before_a_variable_endpoint_is_accepted(self):
        own = {"OUTBOUND_GATE_OWNED": "github.com/myorg/*"}
        self.assertDenied(self.bash('gh api -X PUT "repos/myorg/../otherorg/x/$K"', env=own))

    def test_a_variable_repo_needs_a_whole_owner_pattern(self):
        partial = {"OUTBOUND_GATE_OWNED": "github.com/myorg/tools-*"}
        self.assertDenied(self.bash('gh api -X PUT "repos/myorg/$r/automated-security-fixes"', env=partial))

    def test_reply_targets_and_review_comment_positions_are_part_of_the_scope(self):
        a = self.scope(f"gh api -X POST repos/{TP}/pulls/5/comments -F in_reply_to=5 -f body=x")
        b = self.scope(f"gh api -X POST repos/{TP}/pulls/5/comments -F in_reply_to=6 -f body=x")
        self.assertNotEqual(a["target"], b["target"])
        base = dict(owner="otherorg", repo="widgets", pullNumber=5, body="B")
        one = self.scope(tool="mcp__github__add_comment_to_pending_review", tool_input=dict(base, path="a.py", line=3))
        two = self.scope(tool="mcp__github__add_comment_to_pending_review", tool_input=dict(base, path="a.py", line=4))
        self.assertNotEqual(one["target"], two["target"])

    def test_a_later_go_record_for_the_same_post_resets_its_disposition(self):
        key = self.record(body="hi")
        self.assertAllowed(self.bash(f"gh pr comment 7 -R {TP} --body hi"))
        r = self.run_gate(["record", "--repo", TP, *SCOPE, "--body", "hi", "--reviewer-model", "opus", "--verdict", "go",
                           "--findings", "1"])
        self.assertEqual(r.stdout.strip(), key)
        self.assertDenied(self.bash(f"gh pr comment 7 -R {TP} --body hi"))

    def test_the_analysis_budget_fails_closed_for_gated_commands_only(self):
        owned_post = "echo a; echo b; gh pr comment 7 -R myorg/x --body x"
        self.assertAllowed(self.bash(owned_post))
        slow = {"OUTBOUND_GATE_BUDGET": "0.000001"}
        self.assertDenied(self.bash(owned_post, env=slow))
        self.assertAllowed(self.bash("echo a; echo b; ls; ls; pwd", env=slow))

    def scope(self, command=None, **mcp):
        if command is not None:
            reason = self.assertDenied(self.bash(command, env=self.NONE))
        else:
            reason = self.assertDenied(self.mcp(mcp["tool"], mcp["tool_input"], env=self.NONE))
        return scope_of(reason)


class TestBuild9(ShellCase):
    """Fourth hub review: the helper rule is strict only for the command word, and four claims made true."""

    H = "~/.claude/hooks/outbound-comment-review-gate"
    NONE = {"OUTBOUND_GATE_OWNED": "none/*"}

    def test_naming_the_helper_behind_wrappers_and_interpreters_is_not_running_it(self):
        h = self.H
        for command in (f"find ~/.claude -name outbound-comment-review-gate -type f 2>/dev/null",
                        f"timeout 60 python3 -m py_compile {h} tests/t.py", f"env X=1 git commit -m x {h} tests/t.py",
                        f"nohup git add {h} tests/t.py", f"perl -pi -e 's/a/b/' {h} tests/t.py",
                        f"node --check {h} tests/t.py"):
            with self.subTest(command):
                self.assertAllowed(self.shell(command))

    def test_unlisted_wrappers_cannot_hide_a_record_call(self):
        h, f = self.H, "--repo a/b --body x"
        for command in (f"caffeinate {h} record {f}", f"uv run {h} record {f}", f"ionice -c3 {h} record {f}",
                        f"time -p {h} record {f}", f"python3 -m cProfile -o /dev/null {h} record {f}",
                        f"caffeinate {h} $R {f}"):
            with self.subTest(command):
                self.assertDenied(self.shell(command))
                self.assertAllowed(self.shell(command, agent=True))

    def test_in_reply_to_inside_an_input_file_is_part_of_the_scope(self):
        scopes = []
        for n in (5, 6):
            (self.work / "reply.json").write_text(json.dumps({"body": "x", "in_reply_to": n}))
            reason = self.assertDenied(self.bash(f"gh api -X POST repos/{TP}/pulls/5/comments --input {self.work}/reply.json",
                                                 env=self.NONE))
            scopes.append(scope_of(reason)["target"])
        self.assertNotEqual(scopes[0], scopes[1])

    def test_a_git_alias_whose_value_has_several_words_is_scanned(self):
        self.assertDenied(self.bash(f"git -c alias.p='!gh pr' p comment 7 -R {TP} -b x"))

    def test_the_budget_also_fails_closed_for_curl_and_wget(self):
        slow = {"OUTBOUND_GATE_BUDGET": "0.000001"}
        self.assertDenied(self.bash("echo a; echo b; curl -d x https://example.test/hook", env=slow))
        self.assertAllowed(self.bash("echo a; echo b; ls", env=slow))


class TestHelperRobustness(GateCase):
    """Fourth review: the helper must fail with a parser error, never a traceback or a hang."""

    TAIL = ["--reviewer-model", "opus", "--verdict", "go", "--findings", "1"]
    FLAGS = ["--repo", TP, *SCOPE, *TAIL]

    def run_cli(self, args, **kw):
        return subprocess.run([str(GATE), *args], capture_output=True, text=True, env={**self.env, **kw.get("env", {})},
                              cwd=self.work, timeout=8)

    def assertCleanFailure(self, r):
        self.assertEqual(r.returncode, 2, r.stdout + r.stderr)
        self.assertNotIn("Traceback", r.stderr)

    def test_body_files_that_are_not_small_regular_files_are_refused(self):
        big = self.work / "big.md"
        big.write_bytes(b"x" * (1024 * 1024 + 1))
        fifo = self.work / "pipe"
        os.mkfifo(fifo)
        for path in (big, fifo, "/dev/zero"):
            for cmd in ("hash", "record"):
                with self.subTest(f"{cmd} {path}"):
                    extra = self.TAIL if cmd == "record" else []
                    self.assertCleanFailure(self.run_cli([cmd, "--repo", TP, *SCOPE, "--body-file", str(path), *extra]))

    def test_unwritable_receipt_directories_give_a_parser_error(self):
        self.receipts.write_text("not a directory")
        self.assertCleanFailure(self.run_cli(["record", "--body", "x", *self.FLAGS]))
        self.receipts.unlink()
        self.receipts.mkdir()
        self.receipts.chmod(0o500)
        self.addCleanup(self.receipts.chmod, 0o700)
        self.assertCleanFailure(self.run_cli(["record", "--body", "x", *self.FLAGS]))

    def test_text_that_cannot_be_encoded_gives_a_parser_error(self):
        self.assertCleanFailure(self.run_cli(["hash", "--repo", TP, *SCOPE, "--body", "\udcff"]))

    def test_record_refuses_values_no_receipt_could_ever_use(self):
        for flags in (["--repo", TP, *SCOPE, "--reviewer-model", "", "--verdict", "go", "--findings", "1"],
                      ["--repo", TP, *SCOPE, "--reviewer-model", "  ", "--verdict", "go", "--findings", "1"],
                      ["--repo", TP, *SCOPE, "--reviewer-model", "opus", "--verdict", "go", "--findings", "-5"]):
            with self.subTest(flags):
                self.assertCleanFailure(self.run_cli(["record", "--body", "x", *flags]))
                self.assertFalse(self.receipts.exists() and any(self.receipts.iterdir()))

    def test_disposition_says_malformed_for_a_receipt_it_cannot_read(self):
        key = sha(None, "x")
        self.receipts.mkdir()
        (self.receipts / f"{key}.json").write_bytes(b"\xff\xfe not json")
        r = self.run_cli(["disposition", "--repo", TP, *SCOPE, "--body", "x"])
        self.assertCleanFailure(r)
        self.assertIn("malformed", r.stderr)

    def test_repo_may_be_given_as_an_ssh_remote(self):
        want = self.run_cli(["hash", "--repo", TP, *SCOPE, "--body", "x"]).stdout
        self.assertRegex(want, r"^[0-9a-f]{64}$")
        for spec in (f"git@github.com:{TP}.git", f"ssh://git@github.com/{TP}.git"):
            with self.subTest(spec):
                self.assertEqual(self.run_cli(["hash", "--repo", spec, *SCOPE, "--body", "x"]).stdout, want)


@unittest.skipUnless(os.environ.get("OUTBOUND_GATE_CHECK_GH_FLAGS"),
                     "set OUTBOUND_GATE_CHECK_GH_FLAGS=1 to compare the flag tables with the installed gh")
class TestFlagTables(unittest.TestCase):
    """The gate parses gh flags from a table; it must match the installed gh."""

    @classmethod
    def setUpClass(cls):
        loader = importlib.machinery.SourceFileLoader("gate_module", str(GATE))
        spec = importlib.util.spec_from_loader("gate_module", loader)
        cls.gate = importlib.util.module_from_spec(spec)
        loader.exec_module(cls.gate)

    def help_flags(self, key):
        env = {
            "PATH": os.environ["PATH"],
            "HOME": os.environ["HOME"],
            "GH_CONFIG_DIR": tempfile.mkdtemp(),
            "NO_COLOR": "1",
        }
        out = subprocess.run(["gh", *key.split(), "--help"], capture_output=True, text=True, env=env).stdout
        found = set()
        section = out.split("FLAGS", 1)[1].split("EXAMPLES")[0].split("LEARN MORE")[0]
        for line in section.splitlines():
            m = re.match(r"^\s+(?:(-\w),\s+)?(--[\w-]+)", line)
            if m and m.group(2) != "--help":
                found.add((m.group(2), m.group(1)))
        return found

    @unittest.skipUnless(shutil.which("gh"), "gh is not installed")
    def test_every_gated_verb_matches_gh_help(self):
        for key, (value_flags, bool_flags) in self.gate.FLAG_SPECS.items():
            with self.subTest(key):
                ours = set()
                for item in (value_flags + " " + bool_flags).split():
                    long, _, short = item.partition("/")
                    ours.add((long, short or None))
                self.assertEqual(ours, self.help_flags(key))


if __name__ == "__main__":
    unittest.main()
