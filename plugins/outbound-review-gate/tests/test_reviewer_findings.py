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

from test_outbound_comment_review_gate import FILE_TEXT, GATE, TP, GateCase, sha


class TestReviewerFindings(GateCase):
    def repo(self, name, *remotes):
        path = self.tmp / name
        path.mkdir()
        subprocess.run(["git", "init", "-q", str(path)], check=True)
        for rname, url in remotes:
            subprocess.run(["git", "-C", str(path), "remote", "add", rname, url], check=True)
        return path

    def owned(self):
        return self.repo("owned", ("origin", "git@github.com:rubicon/mnemnon.git"))

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
        self.assertDenied(self.bash("gh pr comment 7 -R rubicon/mnemnon --body x", env=env))
        self.assertAllowed(self.bash("gh pr comment 7 -R github.com/rubicon/mnemnon --body x", env=env))

    # -- repo identity -----------------------------------------------------
    def test_url_inside_body_does_not_choose_the_repo(self):
        body = "Fix is in https://github.com/rubicon/mempalace/pull/4"
        self.assertDenied(self.bash(f"gh pr comment 7 --body '{body}'", cwd=self.thirdparty()))

    def test_third_party_url_inside_body_does_not_block_owned_repo(self):
        body = f"See https://github.com/{TP}/pull/4"
        self.assertAllowed(self.bash(f"gh pr comment 7 --body '{body}'", cwd=self.owned()))

    def test_url_selector_decides_the_repo(self):
        self.assertDenied(self.bash(f"gh pr comment https://github.com/{TP}/pull/7 --body x", cwd=self.owned()))
        self.assertAllowed(
            self.bash("gh pr comment https://github.com/rubicon/mnemnon/pull/7 --body x", cwd=self.thirdparty())
        )

    def test_gh_default_repo_marker_picks_the_remote(self):
        remotes = (("origin", "git@github.com:rubicon/mnemnon.git"), ("upstream", f"git@github.com:{TP}.git"))
        owned_default = self.repo("d1", *remotes)
        subprocess.run(["git", "-C", str(owned_default), "config", "remote.origin.gh-resolved", "base"], check=True)
        self.assertAllowed(self.bash("gh pr comment 7 --body x", cwd=owned_default))
        third_default = self.repo("d2", *remotes)
        subprocess.run(["git", "-C", str(third_default), "config", "remote.upstream.gh-resolved", "base"], check=True)
        self.assertDenied(self.bash("gh pr comment 7 --body x", cwd=third_default))
        explicit = self.repo("d3", *remotes)
        subprocess.run(["git", "-C", str(explicit), "config", "remote.upstream.gh-resolved", "rubicon/mnemnon"], check=True)
        self.assertAllowed(self.bash("gh pr comment 7 --body x", cwd=explicit))

    def test_owner_and_repo_must_be_plain_names(self):
        for repo in ("rubicon/x/../../MemPalace/mempalace", "rubicon/x hi", "rubicon/..", "rubicon/x\ny"):
            with self.subTest(repo):
                self.assertDenied(self.bash(f"gh pr comment 7 -R '{repo}' --body x"))

    def test_mcp_owner_and_repo_must_be_plain_names(self):
        tool_input = dict(owner="rubicon", repo="x/../../MemPalace/mempalace", issue_number=7, body="B")
        self.assertDenied(self.mcp("mcp__github__add_issue_comment", tool_input))

    # -- flag parsing ------------------------------------------------------
    def test_flag_values_are_not_scanned_as_flags(self):
        self.assertDenied(self.bash(f"gh pr comment 7 -R {TP} --body '-Rrubicon/x hi'"))
        self.assertDenied(self.bash(f"gh pr create -R {TP} --title '-Rrubicon/x: fix' --body x -H h"))

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
        owned = 'do shell script "gh pr comment 7 -R rubicon/x --body x"'
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
        tool_input = dict(owner="MemPalace", repo="mempalace", issue_number=7, body="B")
        for server in ("gh", "a1b2c3d4-0000-4000-8000-000000000000"):
            with self.subTest(server):
                self.assertDenied(self.mcp(f"mcp__{server}__add_issue_comment", tool_input))

    def test_issue_tools_without_a_repo_are_not_github_posts(self):
        self.assertAllowed(self.mcp("mcp__linear__create_issue", dict(title="T", body="B")))

    def test_mcp_merge_commit_text_is_gated_like_gh_pr_merge(self):
        tool_input = dict(owner="MemPalace", repo="mempalace", pullNumber=7, commit_title="T", commit_message="M")
        self.assertDenied(self.mcp("mcp__github__merge_pull_request", tool_input))
        self.record(title="T", body="M")
        self.assertAllowed(self.mcp("mcp__github__merge_pull_request", tool_input))
        bare = dict(owner="MemPalace", repo="mempalace", pullNumber=7)
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
        self.owned = self.repo("owned", ("origin", "git@github.com:rubicon/mnemnon.git"))
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
        self.assertDenied(self.bash("R=MemPalace/mempalace; gh issue create -R \"$R\" --title T --body B"))
        self.assertDenied(self.bash("gh issue create -R \"$UNKNOWN\" --title T --body B"))
        self.assertDenied(self.bash("gh issue create -R rubicon/$repo --title T --body B"))

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
        self.record(body="B")
        self.assertAllowed(self.bash(f"gh api repos/{TP}/issues/7/comments -f body=A -f body=B"))
        shutil.rmtree(self.receipts)
        self.record(body="A\n\nB")
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
        r = self.run_gate(["record", "--repo", TP, "--body", "x", "--reviewer", "opus", "--verdict", "go",
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
        self.assertDenied(self.bash("gh pr comment 7 -R rubicon/mnemnon --body x", env=unset))
        self.assertDenied(self.bash("gh pr comment 7 -R git.example.test/rubicon/x --body x", env=unset))

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


class TestHelperRobustness(GateCase):
    """Fourth review: the helper must fail with a parser error, never a traceback or a hang."""

    FLAGS = ["--repo", TP, "--reviewer-model", "opus", "--verdict", "go", "--findings", "1"]

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
                    extra = self.FLAGS[2:] if cmd == "record" else []
                    self.assertCleanFailure(self.run_cli([cmd, "--repo", TP, "--body-file", str(path), *extra]))

    def test_unwritable_receipt_directories_give_a_parser_error(self):
        self.receipts.write_text("not a directory")
        self.assertCleanFailure(self.run_cli(["record", "--body", "x", *self.FLAGS]))
        self.receipts.unlink()
        self.receipts.mkdir()
        self.receipts.chmod(0o500)
        self.addCleanup(self.receipts.chmod, 0o700)
        self.assertCleanFailure(self.run_cli(["record", "--body", "x", *self.FLAGS]))

    def test_text_that_cannot_be_encoded_gives_a_parser_error(self):
        self.assertCleanFailure(self.run_cli(["hash", "--repo", TP, "--body", "\udcff"]))

    def test_record_refuses_values_no_receipt_could_ever_use(self):
        for flags in (["--repo", TP, "--reviewer-model", "", "--verdict", "go", "--findings", "1"],
                      ["--repo", TP, "--reviewer-model", "  ", "--verdict", "go", "--findings", "1"],
                      ["--repo", TP, "--reviewer-model", "opus", "--verdict", "go", "--findings", "-5"]):
            with self.subTest(flags):
                self.assertCleanFailure(self.run_cli(["record", "--body", "x", *flags]))
                self.assertFalse(self.receipts.exists() and any(self.receipts.iterdir()))

    def test_disposition_says_malformed_for_a_receipt_it_cannot_read(self):
        key = sha(None, "x")
        self.receipts.mkdir()
        (self.receipts / f"{key}.json").write_bytes(b"\xff\xfe not json")
        r = self.run_cli(["disposition", "--repo", TP, "--body", "x"])
        self.assertCleanFailure(r)
        self.assertIn("malformed", r.stderr)

    def test_repo_may_be_given_as_an_ssh_remote(self):
        want = self.run_cli(["hash", "--repo", TP, "--body", "x"]).stdout
        for spec in (f"git@github.com:{TP}.git", f"ssh://git@github.com/{TP}.git"):
            with self.subTest(spec):
                self.assertEqual(self.run_cli(["hash", "--repo", spec, "--body", "x"]).stdout, want)


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
