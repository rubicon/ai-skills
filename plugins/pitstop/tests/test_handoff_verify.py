#!/usr/bin/env python3
"""Tests for handoff-verify.py. Real temp git repos, no mocks.

Run:  python3 plugins/pitstop/tests/test_handoff_verify.py
"""
import os, subprocess, sys, tempfile, unittest

SCRIPT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "scripts", "handoff-verify.py")
GIT = ["git", "-c", "user.name=t", "-c", "user.email=t@example.com",
       "-c", "commit.gpgsign=false", "-c", "init.defaultBranch=main"]

# Invented examples in the shape of a real handoff.
DEFECT_DRAFT_LINE = ("4. Two replies are drafted and unposted: issue 812 comment `9051177320`, "
                     "issue 815 comment `9051177451`.")
DEFECT_PATH_LINE = ("   `tests/cache-warmup.test.mjs:77` still needs the guard "
                    "around the network call")
REAL_PATH = "tests/report-builder.test.mjs"


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


class NonGitProject(unittest.TestCase):
    def test_paths_checked_and_shas_skipped_outside_git(self):
        repo = Repo(git=False)
        self.addCleanup(repo.tmp.cleanup)
        repo.write("notes/plan.md", "x\n")
        rc, out, err = repo.verify("See `notes/plan.md` and `abcdef1`.\n")
        self.assertEqual(rc, 0, out + err)
        self.assertIn("not a git repo", out)


if __name__ == "__main__":
    unittest.main()
