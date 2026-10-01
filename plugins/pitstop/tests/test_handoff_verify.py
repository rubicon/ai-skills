#!/usr/bin/env python3
"""Tests for handoff-verify.py. Real temp git repos, no mocks.

Run:  python3 plugins/pitstop/tests/test_handoff_verify.py
"""
import contextlib, importlib.util, io, os, subprocess, sys, tempfile, unittest

SCRIPT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "scripts", "handoff-verify.py")
GIT = ["git", "-c", "user.name=t", "-c", "user.email=t@example.com",
       "-c", "commit.gpgsign=false", "-c", "init.defaultBranch=main"]

# Invented examples in the shape of a real handoff.
DEFECT_DRAFT_LINE = ("4. Two replies are drafted and unposted: issue 812 comment `9051177320`, "
                     "issue 815 comment `9051177451`.")
DEFECT_PATH_LINE = ("   `tests/cache-warmup.test.mjs:77` still needs the guard "
                    "around the network call")
REAL_PATH = "tests/report-builder.test.mjs"


def run_where(cwd, *extra):
    # Bytes, split on "\n" only: text mode would turn a stray "\r" into a line break and hide it.
    r = subprocess.run([sys.executable, SCRIPT, "--where", *extra], capture_output=True, cwd=cwd)
    pairs = [l.split(": ", 1) for l in r.stdout.decode().split("\n") if ": " in l]
    return r.returncode, pairs, r.stderr.decode()


class Repo:
    def __init__(self, git=True):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = os.path.realpath(self.tmp.name)
        self.is_git = git
        if git:
            self.git("init", "-q")
        self.write(".remember/.gitignore", "*\n")

    def git(self, *args):
        return subprocess.run(GIT + list(args), cwd=self.root, check=True,
                              capture_output=True, text=True).stdout.strip()

    def write(self, rel, text):
        path = os.path.join(self.root, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w") as fh:
            fh.write(text)

    def commit(self, rel, text, msg="c"):
        self.write(rel, text)
        self.git("add", rel)
        self.git("commit", "-q", "-m", msg)
        return self.git("rev-parse", "--short", "HEAD")

    def verify(self, handoff_text):
        self.write(".remember/remember.md", handoff_text)
        r = subprocess.run([sys.executable, SCRIPT,
                            os.path.join(self.root, ".remember/remember.md")],
                           capture_output=True, text=True, cwd="/")
        return r.returncode, r.stdout, r.stderr


class HandoffVerify(unittest.TestCase):
    def setUp(self):
        self.repo = Repo()
        self.addCleanup(self.repo.tmp.cleanup)
        self.sha = self.repo.commit(REAL_PATH, "a\nb\nc\n")

    def test_draft_mentioned_without_file_fails(self):
        rc, out, err = self.repo.verify("# Handoff\n\n## Next\n" + DEFECT_DRAFT_LINE + "\n")
        self.assertEqual(rc, 1, out + err)
        self.assertIn("DRAFT-WITHOUT-FILE", out)
        self.assertIn("line 4", out)

    def test_invented_path_fails(self):
        rc, out, err = self.repo.verify("# Handoff\n\n" + DEFECT_PATH_LINE + "\n")
        self.assertEqual(rc, 1, out + err)
        self.assertIn("MISSING-PATH", out)
        self.assertIn("tests/cache-warmup.test.mjs", out)

    def test_clean_handoff_with_draft_file_passes(self):
        self.repo.write(".remember/drafts/2026-01-15-issue-812-reply.md", "Fixed in `3c1e9ab7`.\n")
        rc, out, err = self.repo.verify(
            "# Handoff\n\n## Next\n"
            f"1. `{REAL_PATH}:2` at `{self.sha}` needs a guard.\n"
            "2. One reply is drafted and unposted: `.remember/drafts/2026-01-15-issue-812-reply.md`\n")
        self.assertEqual(rc, 0, out + err)
        self.assertIn("drafts on disk: 1", out)
        self.assertEqual(err, "")

    def test_draft_path_on_wrapped_next_line_passes(self):
        self.repo.write(".remember/drafts/a.md", "text\n")
        rc, out, err = self.repo.verify(
            "1. One reply is drafted and unposted, awaiting the maintainer:\n"
            "   `.remember/drafts/a.md`\n")
        self.assertEqual(rc, 0, out + err)

    def test_empty_draft_file_fails(self):
        self.repo.write(".remember/drafts/a.md", "")
        rc, out, err = self.repo.verify("1. Reply drafted and unposted: `.remember/drafts/a.md`\n")
        self.assertEqual(rc, 1, out + err)
        self.assertIn("EMPTY-DRAFT", out)

    def test_missing_draft_file_cannot_be_acknowledged(self):
        rc, out, err = self.repo.verify(
            "1. Reply unposted: `.remember/drafts/gone.md` (unverified)\n")
        self.assertEqual(rc, 1, out + err)
        self.assertIn("MISSING-DRAFT", out)
        self.assertNotIn("ACKNOWLEDGED", out)

    def test_not_posted_wording_needs_a_draft_file(self):
        rc, out, err = self.repo.verify("The reply is approved by the maintainer and NOT posted.\n")
        self.assertEqual(rc, 1, out + err)
        self.assertIn("DRAFT-WITHOUT-FILE", out)

    def test_draft_outside_the_handoff_drafts_dir_does_not_count(self):
        self.repo.commit("src/drafts/reply.md", "text\n")
        rc, out, err = self.repo.verify("Reply unposted: `src/drafts/reply.md`\n")
        self.assertEqual(rc, 1, out + err)
        self.assertIn("DRAFT-WITHOUT-FILE", out)

    def test_draft_only_in_git_history_does_not_count(self):
        self.repo.git("checkout", "-q", "-b", "other")
        self.repo.git("add", "-f", ".remember/.gitignore")
        self.repo.write(".remember/drafts/old.md", "text\n")
        self.repo.git("add", "-f", ".remember/drafts/old.md")
        self.repo.git("commit", "-q", "-m", "draft")
        self.repo.git("checkout", "-q", "main")
        self.assertFalse(os.path.exists(os.path.join(self.repo.root, ".remember/drafts/old.md")))
        rc, out, err = self.repo.verify("Reply unposted: `.remember/drafts/old.md`\n")
        self.assertEqual(rc, 1, out + err)
        self.assertIn("MISSING-DRAFT", out)

    def test_line_range_must_lie_inside_the_file(self):
        for anchor in ("2-999", "0", "3-1", "0-2"):
            rc, out, err = self.repo.verify(f"See `{REAL_PATH}:{anchor}`.\n")
            self.assertEqual(rc, 1, f"{anchor}: {out}{err}")
            self.assertIn("LINE-OUT-OF-RANGE", out, anchor)
        for anchor in ("1", "3", "1-3", "2-2"):
            rc, out, err = self.repo.verify(f"See `{REAL_PATH}:{anchor}`.\n")
            self.assertEqual(rc, 0, f"{anchor}: {out}{err}")

    def test_line_range_on_a_path_only_in_history_is_checked(self):
        self.repo.git("checkout", "-q", "-b", "side")
        self.repo.commit("src/gone.ts", "one\ntwo\n")
        self.repo.git("checkout", "-q", "main")
        rc, out, err = self.repo.verify("See `src/gone.ts:2`.\n")
        self.assertEqual(rc, 0, out + err)
        rc, out, err = self.repo.verify("See `src/gone.ts:3`.\n")
        self.assertEqual(rc, 1, out + err)
        self.assertIn("LINE-OUT-OF-RANGE", out)

    def test_line_range_on_a_deleted_file_uses_the_last_version_that_had_it(self):
        self.repo.commit("src/old.ts", "a\nb\nc\n")
        self.repo.git("rm", "-q", "src/old.ts")
        self.repo.git("commit", "-q", "-m", "drop")
        rc, out, err = self.repo.verify("See `src/old.ts:3`.\n")
        self.assertEqual(rc, 0, out + err)
        rc, out, err = self.repo.verify("See `src/old.ts:4`.\n")
        self.assertEqual(rc, 1, out + err)
        self.assertIn("LINE-OUT-OF-RANGE", out)

    def test_a_draft_on_disk_that_the_handoff_does_not_name_fails(self):
        self.repo.write(".remember/drafts/old.md", "text\n")
        rc, out, err = self.repo.verify("Drafts: none unsent. (unverified)\n")
        self.assertEqual(rc, 1, out + err)
        self.assertIn("UNLISTED-DRAFT line 0: .remember/drafts/old.md", out)
        self.assertNotIn("ACKNOWLEDGED", out)

    def test_hidden_files_and_the_done_folder_are_not_unlisted_drafts(self):
        self.repo.write(".remember/drafts/.DS_Store", "x")
        self.repo.write(".remember/drafts/done/sent.md", "text\n")
        rc, out, err = self.repo.verify("Drafts: none unsent.\n")
        self.assertEqual(rc, 0, out + err)
        self.assertIn("drafts on disk: 0", out)

    def test_a_draft_named_by_absolute_path_counts(self):
        self.repo.write(".remember/drafts/a.md", "text\n")
        full = os.path.join(self.repo.root, ".remember", "drafts", "a.md")
        rc, out, err = self.repo.verify(f"Reply unposted: `{full}`\n")
        self.assertEqual(rc, 0, out + err)

    def test_a_draft_claim_pointing_into_done_fails(self):
        self.repo.write(".remember/drafts/done/a.md", "text\n")
        rc, out, err = self.repo.verify("Reply unposted: `.remember/drafts/done/a.md`\n")
        self.assertEqual(rc, 1, out + err)
        self.assertIn("DONE-DRAFT-CLAIMED line 1", out)

    def test_a_done_file_on_the_next_line_does_not_spoil_a_live_claim(self):
        self.repo.write(".remember/drafts/a.md", "text\n")
        self.repo.write(".remember/drafts/done/b.md", "text\n")
        rc, out, err = self.repo.verify(
            "Reply unposted: `.remember/drafts/a.md`\n"
            "Sent earlier: `.remember/drafts/done/b.md`\n")
        self.assertEqual(rc, 0, out + err)

    def test_saying_there_are_no_unsent_drafts_is_not_a_draft_claim(self):
        for text in ("Drafts: none unsent.\n", "There are no unposted replies.\n"):
            rc, out, err = self.repo.verify(text)
            self.assertEqual(rc, 0, text + out + err)
        rc, out, err = self.repo.verify("Reply unposted. None of the drafts are saved yet.\n")
        self.assertEqual(rc, 1, out + err)
        self.assertIn("DRAFT-WITHOUT-FILE", out)

    def test_output_ends_with_age_drafts_and_summary(self):
        rc, out, err = self.repo.verify("Nothing to report.\n")
        tail = out.splitlines()[-3:]
        self.assertEqual(tail[0], "handoff age: 0 min")
        self.assertTrue(tail[1].startswith("drafts on disk: 0"), tail[1])
        self.assertTrue(tail[2].startswith("handoff-verify: "), tail[2])

    def test_handoff_age_is_reported_in_minutes(self):
        path = os.path.join(self.repo.root, ".remember", "remember.md")
        self.repo.write(".remember/remember.md", "Nothing to report.\n")
        old = os.path.getmtime(path) - 3600
        os.utime(path, (old, old))
        r = subprocess.run([sys.executable, SCRIPT, path], capture_output=True, text=True)
        self.assertIn("handoff age: 60 min", r.stdout)

    def test_each_draft_claim_needs_its_own_file(self):
        self.repo.write(".remember/drafts/issue-6.md", "text\n")
        rc, out, err = self.repo.verify(
            "- Reply to issue 5 is drafted and unposted.\n"
            "- Reply to issue 6 is drafted and unposted: `.remember/drafts/issue-6.md`\n")
        self.assertEqual(rc, 1, out + err)
        self.assertIn("DRAFT-WITHOUT-FILE line 1", out)

    def test_a_negation_does_not_cancel_a_real_claim_on_the_same_line(self):
        rc, out, err = self.repo.verify(
            "No drafted replies saved yet; the reply to issue 5 is unsent.\n")
        self.assertEqual(rc, 1, out + err)
        self.assertIn("DRAFT-WITHOUT-FILE", out)

    def test_git_missing_from_path_is_not_a_crash(self):
        py = os.path.realpath(sys.executable)
        bindir = os.path.join(self.repo.tmp.name, "onlypython")
        os.makedirs(bindir)
        os.symlink(py, os.path.join(bindir, "python3"))
        self.repo.write(".remember/remember.md", "See `" + REAL_PATH + "`.\n")
        handoff = os.path.join(self.repo.root, ".remember", "remember.md")
        r = subprocess.run([os.path.join(bindir, "python3"), SCRIPT, handoff],
                           capture_output=True, text=True, env={"PATH": bindir})
        self.assertNotIn("Traceback", r.stderr)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)

    def test_unreadable_bytes_in_the_handoff_are_not_a_crash(self):
        path = os.path.join(self.repo.root, ".remember", "remember.md")
        with open(path, "wb") as fh:
            fh.write(b"Caf\xe9 notes. See `" + REAL_PATH.encode() + b"`.\n")
        r = subprocess.run([sys.executable, SCRIPT, path], capture_output=True, text=True)
        self.assertNotIn("Traceback", r.stderr)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)

    def test_an_unexpected_error_exits_2_not_1(self):
        drafts = os.path.join(self.repo.root, ".remember", "drafts")
        os.makedirs(drafts)
        os.chmod(drafts, 0)
        self.addCleanup(os.chmod, drafts, 0o755)
        rc, out, err = self.repo.verify("Nothing to report.\n")
        self.assertNotIn("Traceback", err)
        self.assertIn(rc, (0, 2), out + err)

    def test_path_only_in_ref_history_is_found(self):
        self.repo.git("checkout", "-q", "-b", "feature")
        self.repo.commit("src/only-on-branch.ts", "x\n")
        self.repo.git("checkout", "-q", "main")
        rc, out, err = self.repo.verify("See `src/only-on-branch.ts`.\n")
        self.assertEqual(rc, 0, out + err)

    def test_uncommitted_file_in_another_worktree_is_found(self):
        wt = self.repo.root + "-wt"
        self.repo.git("worktree", "add", "-q", "-b", "pr-branch", wt)
        self.addCleanup(subprocess.run, ["rm", "-rf", wt])
        os.makedirs(os.path.join(wt, "src"))
        with open(os.path.join(wt, "src", "uncommitted-in-worktree.ts"), "w") as fh:
            fh.write("one\ntwo\nthree\n")
        rc, out, err = self.repo.verify("See `src/uncommitted-in-worktree.ts:3`.\n")
        self.assertEqual(rc, 0, out + err)
        rc, out, err = self.repo.verify("See `src/uncommitted-in-worktree.ts:4`.\n")
        self.assertEqual(rc, 1, out + err)
        self.assertIn("LINE-OUT-OF-RANGE", out)

    def test_unverified_marker_acknowledges_missing_identifier(self):
        rc, out, err = self.repo.verify(
            "Upstream file `tests/not-fetched-here.test.mjs` at `abcdef1` (unverified).\n")
        self.assertEqual(rc, 0, out + err)
        self.assertEqual(out.count("ACKNOWLEDGED"), 2)

    def test_draft_pr_wording_is_not_an_outbound_draft(self):
        rc, out, err = self.repo.verify(
            "PR 34 is still draft and not deployed. 4 still drafts. Deploy, then un-draft it.\n")
        self.assertEqual(rc, 0, out + err)

    def test_line_anchor_past_end_of_file_fails(self):
        rc, out, err = self.repo.verify(f"See `{REAL_PATH}:999`.\n")
        self.assertEqual(rc, 1, out + err)
        self.assertIn("LINE-OUT-OF-RANGE", out)

    def test_unknown_sha_fails_but_numeric_id_is_ignored(self):
        rc, out, err = self.repo.verify("Commit `abcdef1`, comment `9051177320`.\n")
        self.assertEqual(rc, 1, out + err)
        self.assertIn("MISSING-SHA", out)
        self.assertIn("abcdef1", out)
        self.assertNotIn("9051177320", out)

    def test_urls_domains_and_commands_are_not_paths(self):
        rc, out, err = self.repo.verify(
            "`op://Vault/Item/field`, `docs.example.com`, `v1.34.0`, "
            "`grep -c x app/compose.yaml`, `dev/12-add-search`, "
            "https://github.com/o/r/blob/main/a/b.ts\n")
        self.assertEqual(rc, 0, out + err)

    def test_missing_handoff_exits_2(self):
        r = subprocess.run([sys.executable, SCRIPT, os.path.join(self.repo.root, "nope.md")],
                           capture_output=True, text=True)
        self.assertEqual(r.returncode, 2)
        self.assertIn("cannot read", r.stderr)


class Where(unittest.TestCase):
    def setUp(self):
        self.repo = Repo()
        self.addCleanup(self.repo.tmp.cleanup)
        os.makedirs(os.path.join(self.repo.root, "src", "deep"))
        self.cfg = os.path.join(self.repo.root, "cfg", "integrations.md")

    def write_cfg(self, text, newline="\n"):
        os.makedirs(os.path.dirname(self.cfg), exist_ok=True)
        with open(self.cfg, "w", newline=newline) as fh:
            fh.write(text)

    def test_defaults_from_a_subdirectory_resolve_to_the_repo_root(self):
        rc, pairs, err = run_where(os.path.join(self.repo.root, "src", "deep"))
        self.assertEqual(rc, 0, err)
        root = self.repo.root
        self.assertEqual(pairs, [
            ["root", root], ["config", "none"],
            ["handoff", os.path.join(root, ".remember", "remember.md")],
            ["drafts", os.path.join(root, ".remember", "drafts")],
            ["journal", os.path.join(root, ".remember", "journal.md")],
        ])

    def test_missing_config_file_is_none(self):
        rc, pairs, err = run_where(self.repo.root, "--config", self.cfg)
        self.assertEqual(dict(pairs)["config"], "none")

    def test_handoff_path_comes_from_the_header(self):
        self.write_cfg("---\nhandoff_path: notes/handoff.md\n---\n## Handoff\nmode: default\n")
        rc, pairs, err = run_where(self.repo.root, "--config", self.cfg)
        d = dict(pairs)
        self.assertEqual(d["config"], self.cfg)
        self.assertEqual(d["handoff"], os.path.join(self.repo.root, "notes", "handoff.md"))
        self.assertEqual(d["drafts"], os.path.join(self.repo.root, "notes", "drafts"))
        self.assertEqual(d["journal"], os.path.join(self.repo.root, "notes", "journal.md"))

    def test_crlf_header_parses(self):
        self.write_cfg("---\nhandoff_path: notes/handoff.md\n---\n", newline="\r\n")
        rc, pairs, err = run_where(self.repo.root, "--config", self.cfg)
        self.assertEqual(dict(pairs)["handoff"], os.path.join(self.repo.root, "notes", "handoff.md"))

    def test_header_without_closing_fence_is_invalid_and_uses_defaults(self):
        self.write_cfg("---\nhandoff_path: notes/handoff.md\n## Handoff\n")
        rc, pairs, err = run_where(self.repo.root, "--config", self.cfg)
        d = dict(pairs)
        self.assertEqual(rc, 0, err)
        self.assertEqual(d["config"], "invalid " + self.cfg)
        self.assertEqual(d["handoff"], os.path.join(self.repo.root, ".remember", "remember.md"))

    def test_bad_arguments_exit_2(self):
        r = subprocess.run([sys.executable, SCRIPT, "--where", "--bogus"],
                           capture_output=True, text=True, cwd=self.repo.root)
        self.assertEqual(r.returncode, 2)
        self.assertIn("usage", r.stderr)

    def test_project_path_with_a_space(self):
        spaced = os.path.join(self.repo.tmp.name, "my project")
        os.makedirs(spaced)
        subprocess.run(GIT + ["init", "-q"], cwd=spaced, check=True)
        rc, pairs, err = run_where(spaced)
        d = dict(pairs)
        self.assertEqual(d["root"], os.path.realpath(spaced))
        self.assertEqual(d["handoff"], os.path.join(os.path.realpath(spaced), ".remember", "remember.md"))


class AwkwardPaths(unittest.TestCase):
    def test_absolute_draft_path_with_a_space_counts(self):
        tmp = tempfile.TemporaryDirectory(); self.addCleanup(tmp.cleanup)
        root = os.path.join(os.path.realpath(tmp.name), "my project")
        os.makedirs(os.path.join(root, ".remember", "drafts"))
        subprocess.run(GIT + ["init", "-q"], cwd=root, check=True)
        draft = os.path.join(root, ".remember", "drafts", "2026-01-15-reply.md")
        with open(draft, "w") as fh:
            fh.write("text\n")
        handoff = os.path.join(root, ".remember", "remember.md")
        with open(handoff, "w") as fh:
            fh.write(f"Reply unposted: `{draft}`\n")
        r = subprocess.run([sys.executable, SCRIPT, handoff], capture_output=True, text=True)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)

    def test_root_flag_outside_git_with_a_nested_handoff(self):
        repo = Repo(git=False); self.addCleanup(repo.tmp.cleanup)
        repo.write("src/a.ts", "x\n")
        repo.write("notes/session/drafts/r.md", "text\n")
        repo.write("notes/session/handoff.md",
                   "See `src/a.ts`. Reply unposted: `notes/session/drafts/r.md`\n")
        handoff = os.path.join(repo.root, "notes", "session", "handoff.md")
        r = subprocess.run([sys.executable, SCRIPT, "--root", repo.root, handoff],
                           capture_output=True, text=True)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)


class NonGitProject(unittest.TestCase):
    def test_where_uses_the_working_directory_outside_git(self):
        repo = Repo(git=False)
        self.addCleanup(repo.tmp.cleanup)
        rc, pairs, err = run_where(repo.root)
        self.assertEqual(rc, 0, err)
        self.assertEqual(dict(pairs)["root"], repo.root)

    def test_paths_checked_and_shas_skipped_outside_git(self):
        repo = Repo(git=False)
        self.addCleanup(repo.tmp.cleanup)
        repo.write("notes/plan.md", "x\n")
        rc, out, err = repo.verify("See `notes/plan.md` and `abcdef1`.\n")
        self.assertEqual(rc, 0, out + err)
        self.assertIn("not a git repo", out)

    def test_guessed_root_outside_git_is_named_on_stderr(self):
        repo = Repo(git=False)
        self.addCleanup(repo.tmp.cleanup)
        rc, out, err = repo.verify("Nothing to report.\n")
        self.assertIn(f"note: no --root given, assuming project root {repo.root}", err)
        handoff = os.path.join(repo.root, ".remember", "remember.md")
        r = subprocess.run([sys.executable, SCRIPT, "--root", repo.root, handoff],
                           capture_output=True, text=True)
        self.assertNotIn("assuming project root", r.stderr)


class HungGit(unittest.TestCase):
    def test_a_git_call_that_hangs_exits_2_instead_of_blocking(self):
        spec = importlib.util.spec_from_file_location("handoff_verify", SCRIPT)
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        mod.GIT_TIMEOUT = 1
        tmp = tempfile.TemporaryDirectory(); self.addCleanup(tmp.cleanup)
        fake = os.path.join(tmp.name, "git")
        with open(fake, "w") as fh:
            fh.write("#!/bin/sh\nsleep 10\n")
        os.chmod(fake, 0o755)
        old_path = os.environ["PATH"]
        os.environ["PATH"] = tmp.name + os.pathsep + old_path
        self.addCleanup(os.environ.__setitem__, "PATH", old_path)
        err = io.StringIO()
        with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(err):
            rc = mod.run(["handoff-verify.py", "--where"])
        self.assertEqual(rc, 2, err.getvalue())
        self.assertIn("TimeoutExpired", err.getvalue())


if __name__ == "__main__":
    unittest.main()
