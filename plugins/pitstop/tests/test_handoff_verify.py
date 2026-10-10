#!/usr/bin/env python3
"""Tests for handoff-verify.py. Real temp git repos, no mocks.

Run:  python3 plugins/pitstop/tests/test_handoff_verify.py
"""
import contextlib, importlib.util, io, os, subprocess, sys, tempfile, time, unittest

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


def run_flag(cwd, flag, session=None, host_session=None, *extra):
    """Run `--claim` or `--list` with a controlled session environment."""
    env = {k: v for k, v in os.environ.items()
           if k not in ("CLAUDE_CODE_SESSION_ID", "CLAUDE_CODE_HOST_SESSION_ID")}
    if session:
        env["CLAUDE_CODE_SESSION_ID"] = session
    if host_session:
        env["CLAUDE_CODE_HOST_SESSION_ID"] = host_session
    r = subprocess.run([sys.executable, SCRIPT, flag, *extra], capture_output=True, cwd=cwd, env=env)
    lines = [l for l in r.stdout.decode().split("\n") if l]
    return r.returncode, lines, r.stderr.decode()


def handoff_text(path):
    with open(path) as fh:
        return fh.read()


SESSION_A = "aaaaaaaa-1111-4111-8111-111111111111"
SESSION_B = "bbbbbbbb-2222-4222-8222-222222222222"


class HandoffOwnership(unittest.TestCase):
    """Two sessions in one folder must not replace each other's handoff."""

    def setUp(self):
        self.repo = Repo()
        self.addCleanup(self.repo.tmp.cleanup)
        self.canonical = os.path.join(self.repo.root, ".remember", "remember.md")

    def claim(self, session=SESSION_A, host_session=None):
        rc, lines, err = run_flag(self.repo.root, "--claim", session, host_session)
        self.assertEqual(rc, 0, err)
        return dict(l.split(": ", 1) for l in lines)

    def test_no_handoff_writes_the_canonical_path(self):
        d = self.claim()
        self.assertEqual(d["session"], SESSION_A)
        self.assertEqual(d["existing"], "none")
        self.assertEqual(d["write"], self.canonical)

    def test_own_handoff_is_replaced_in_place(self):
        self.repo.write(".remember/remember.md", f"# Handoff\nSession: {SESSION_A}\n\n## State\n")
        d = self.claim()
        self.assertTrue(d["existing"].startswith("own"), d["existing"])
        self.assertEqual(d["write"], self.canonical)

    def test_another_sessions_handoff_is_never_the_write_target(self):
        self.repo.write(".remember/remember.md", f"# Handoff\nSession: {SESSION_A}\n\n## State\n")
        d = self.claim(SESSION_B)
        self.assertTrue(d["existing"].startswith("other"), d["existing"])
        self.assertIn(SESSION_A, d["existing"])
        self.assertEqual(d["write"], os.path.join(self.repo.root, ".remember", f"remember-{SESSION_B}.md"))

    def test_a_handoff_with_no_stamp_is_treated_as_someone_elses(self):
        self.repo.write(".remember/remember.md", "# Handoff\n\n## State\n")
        d = self.claim()
        self.assertTrue(d["existing"].startswith("unstamped"), d["existing"])
        self.assertNotEqual(d["write"], self.canonical)

    def test_the_sibling_is_replaced_in_place_by_its_own_session(self):
        self.repo.write(".remember/remember.md", f"# Handoff\nSession: {SESSION_A}\n")
        self.repo.write(f".remember/remember-{SESSION_B}.md", f"# Handoff\nSession: {SESSION_B}\n")
        d = self.claim(SESSION_B)
        self.assertEqual(d["write"], os.path.join(self.repo.root, ".remember", f"remember-{SESSION_B}.md"))

    def test_without_a_session_variable_a_token_is_generated_and_existing_handoffs_are_kept(self):
        self.repo.write(".remember/remember.md", f"# Handoff\nSession: {SESSION_A}\n")
        d = self.claim(session=None)
        self.assertRegex(d["session"], r"^anon-[0-9a-f]{8}$")
        self.assertNotEqual(d["write"], self.canonical)

    def test_the_host_variable_is_used_when_the_session_variable_is_missing(self):
        d = self.claim(session=None, host_session="local_host-session-9")
        self.assertEqual(d["session"], "local_host-session-9")

    def test_claim_honours_the_configured_handoff_path(self):
        cfg = os.path.join(self.repo.root, "cfg.md")
        with open(cfg, "w") as fh:
            fh.write("---\nhandoff_path: notes/handoff.md\n---\n")
        self.repo.write("notes/handoff.md", f"# Handoff\nSession: {SESSION_A}\n")
        rc, lines, err = run_flag(self.repo.root, "--claim", SESSION_B, None, "--config", cfg)
        d = dict(l.split(": ", 1) for l in lines)
        self.assertEqual(d["write"], os.path.join(self.repo.root, "notes", f"remember-{SESSION_B}.md"))

    def test_list_names_every_handoff_with_its_owner_and_skips_files_that_only_look_like_one(self):
        self.repo.write(".remember/remember.md", f"# Handoff\nSession: {SESSION_A}\n")
        self.repo.write(".remember/remember-bbbbbbbb.md", f"# Handoff\nSession: {SESSION_B}\n")
        self.repo.write(".remember/remember-notes.md", "my own notes, not a handoff\n")
        self.repo.write(".remember/journal.md", "not a handoff\n")
        rc, lines, err = run_flag(self.repo.root, "--list")
        self.assertEqual(rc, 0, err)
        by_name = {os.path.basename(l.split(" | ")[0]): l.split(" | ") for l in lines}
        self.assertEqual(sorted(by_name), ["remember-bbbbbbbb.md", "remember.md"])
        self.assertEqual(by_name["remember.md"][1], f"session {SESSION_A}")
        self.assertEqual(by_name["remember-bbbbbbbb.md"][1], f"session {SESSION_B}")
        self.assertRegex(by_name["remember.md"][2], r"^\d+ min$")

    def test_list_with_no_handoff_prints_nothing_and_exits_0(self):
        rc, lines, err = run_flag(self.repo.root, "--list")
        self.assertEqual((rc, lines), (0, []))

    def test_the_verifier_accepts_a_sibling_that_names_the_other_sessions_draft(self):
        self.repo.write(".remember/drafts/2026-10-05-reply.md", "Target: x\n\ntext\n")
        self.repo.write(".remember/remember-bbbbbbbb.md",
                        "# Handoff\nSession: bbbbbbbb\n\nDrafts: `.remember/drafts/2026-10-05-reply.md`\n")
        r = subprocess.run([sys.executable, SCRIPT, os.path.join(self.repo.root, ".remember/remember-bbbbbbbb.md")],
                           capture_output=True, text=True, cwd="/")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)

    def test_bad_arguments_to_claim_and_list_exit_2(self):
        for flag in ("--claim", "--list"):
            r = subprocess.run([sys.executable, SCRIPT, flag, "--bogus"],
                               capture_output=True, text=True, cwd=self.repo.root)
            self.assertEqual(r.returncode, 2, flag)
            self.assertIn("usage", r.stderr)

    def test_claiming_reserves_the_path_so_a_second_claim_before_any_write_cannot_take_it(self):
        a = self.claim(SESSION_A)
        self.assertEqual(a["write"], self.canonical)
        self.assertEqual(handoff_text(self.canonical).splitlines()[:2], ["# Handoff", f"Session: {SESSION_A}"])
        b = self.claim(SESSION_B)
        self.assertTrue(b["existing"].startswith("other"), b["existing"])
        self.assertEqual(b["write"], os.path.join(self.repo.root, ".remember", f"remember-{SESSION_B}.md"))

    def test_claiming_twice_as_the_same_session_keeps_the_same_file_and_its_text(self):
        self.claim(SESSION_A)
        with open(self.canonical, "a") as fh:
            fh.write("## State\nwork\n")
        d = self.claim(SESSION_A)
        self.assertTrue(d["existing"].startswith("own"), d["existing"])
        self.assertIn("work", handoff_text(self.canonical))

    def test_a_sibling_already_held_by_someone_else_is_never_returned(self):
        self.repo.write(".remember/remember.md", f"# Handoff\nSession: {SESSION_A}\n")
        self.repo.write(f".remember/remember-{SESSION_B}.md", "# Handoff\nSession: somebody-else\nkeep me\n")
        d = self.claim(SESSION_B)
        self.assertEqual(d["write"], os.path.join(self.repo.root, ".remember", f"remember-{SESSION_B}-2.md"))
        self.assertIn("keep me", handoff_text(os.path.join(self.repo.root, ".remember", f"remember-{SESSION_B}.md")))

    def test_a_token_passed_back_with_session_is_recognised_as_this_session(self):
        rc, lines, err = run_flag(self.repo.root, "--claim", None, None)
        first = dict(l.split(": ", 1) for l in lines)
        token = first["session"]
        self.assertRegex(token, r"^anon-[0-9a-f]{8}$")
        rc, lines, err = run_flag(self.repo.root, "--claim", None, None, "--session", token)
        again = dict(l.split(": ", 1) for l in lines)
        self.assertEqual(again["session"], token)
        self.assertTrue(again["existing"].startswith("own"), again["existing"])
        self.assertEqual(again["write"], self.canonical)

    def test_session_flag_beats_the_environment(self):
        rc, lines, err = run_flag(self.repo.root, "--claim", SESSION_A, None, "--session", "typed-by-hand")
        self.assertEqual(dict(l.split(": ", 1) for l in lines)["session"], "typed-by-hand")

    def test_two_claims_started_at_the_same_instant_never_get_the_same_path(self):
        for round_ in range(25):
            repo = Repo()
            self.addCleanup(repo.tmp.cleanup)
            procs = []
            for sid in (SESSION_A, SESSION_B):
                env = {k: v for k, v in os.environ.items() if k not in ("CLAUDE_CODE_SESSION_ID", "CLAUDE_CODE_HOST_SESSION_ID")}
                env["CLAUDE_CODE_SESSION_ID"] = sid
                procs.append(subprocess.Popen([sys.executable, SCRIPT, "--claim"], cwd=repo.root, env=env,
                                              stdout=subprocess.PIPE, text=True))
            writes = []
            for proc in procs:
                out, _ = proc.communicate()
                writes.append(dict(l.split(": ", 1) for l in out.splitlines())["write"])
            self.assertEqual(len(set(writes)), 2, f"round {round_}: {writes}")
            owners = sorted(handoff_text(w).splitlines()[1] for w in writes)
            self.assertEqual(owners, [f"Session: {SESSION_A}", f"Session: {SESSION_B}"])


class ClaimDrift(unittest.TestCase):
    """A park that replaces its own earlier handoff must be told how far the project has moved
    since that handoff was written, so it re-derives claims instead of retyping stale ones."""

    def setUp(self):
        self.repo = Repo()
        self.addCleanup(self.repo.tmp.cleanup)
        # The first commit predates every handoff these tests write, so it is never drift.
        self.repo.write("a.txt", "a\n")
        self.repo.git("add", "a.txt")
        when = time.strftime("%Y-%m-%d %H:%M:%S %z", time.localtime(time.time() - 3 * 3600))
        subprocess.run(GIT + ["commit", "-q", "-m", "first"], cwd=self.repo.root, check=True,
                       env={**os.environ, "GIT_AUTHOR_DATE": when, "GIT_COMMITTER_DATE": when})
        old = time.time() - 3 * 3600
        os.utime(os.path.join(self.repo.root, "a.txt"), (old, old))
        self.handoff = os.path.join(self.repo.root, ".remember", "remember.md")

    def write_own_handoff(self, minutes_ago):
        self.repo.write(".remember/remember.md", f"# Handoff\nSession: {SESSION_A}\n")
        then = time.time() - minutes_ago * 60
        os.utime(self.handoff, (then, then))

    def drift(self, session=SESSION_A):
        rc, lines, err = run_flag(self.repo.root, "--claim", session)
        self.assertEqual(rc, 0, err)
        return dict(l.split(": ", 1) for l in lines)["drift"]

    def test_no_handoff_has_no_drift(self):
        self.assertEqual(self.drift(), "none")

    def test_own_handoff_with_nothing_changed_since_has_no_drift(self):
        self.write_own_handoff(minutes_ago=0)
        self.assertEqual(self.drift(), "none")

    def test_commits_since_the_handoff_are_counted(self):
        self.write_own_handoff(minutes_ago=120)
        self.repo.commit("b.txt", "b\n", "later one")
        self.repo.commit("c.txt", "c\n", "later two")
        d = self.drift()
        self.assertIn("2 commits", d)
        self.assertIn("120 min", d)

    def test_a_file_changed_since_the_handoff_is_counted(self):
        self.write_own_handoff(minutes_ago=60)
        self.repo.write("a.txt", "changed\n")
        self.assertIn("1 file", self.drift())

    def test_files_older_than_the_handoff_are_not_drift(self):
        self.repo.write("untracked.txt", "x\n")
        old = time.time() - 7200
        os.utime(os.path.join(self.repo.root, "untracked.txt"), (old, old))
        self.write_own_handoff(minutes_ago=60)
        self.assertEqual(self.drift(), "none")

    def test_another_sessions_handoff_is_not_drift_to_report(self):
        self.write_own_handoff(minutes_ago=60)
        self.repo.commit("b.txt", "b\n", "later")
        self.assertEqual(self.drift(SESSION_B), "none")

    def test_outside_git_drift_is_unknown_not_none(self):
        repo = Repo(git=False)
        self.addCleanup(repo.tmp.cleanup)
        repo.write(".remember/remember.md", f"# Handoff\nSession: {SESSION_A}\n")
        rc, lines, err = run_flag(repo.root, "--claim", SESSION_A)
        self.assertEqual(rc, 0, err)
        self.assertTrue(dict(l.split(": ", 1) for l in lines)["drift"].startswith("unknown"))


class HandoffStampCheck(unittest.TestCase):
    """park verifies the file it wrote carries this session's stamp, so a handoff that lost its
    Session line cannot pass and then vanish from sitrep."""

    def setUp(self):
        self.repo = Repo()
        self.addCleanup(self.repo.tmp.cleanup)

    def verify(self, text, *flags, name="remember-bbbbbbbb.md"):
        self.repo.write(f".remember/{name}", text)
        path = os.path.join(self.repo.root, ".remember", name)
        r = subprocess.run([sys.executable, SCRIPT, *flags, path], capture_output=True, text=True, cwd="/")
        return r.returncode, r.stdout, r.stderr

    def test_a_handoff_carrying_the_expected_session_passes(self):
        rc, out, err = self.verify(f"# Handoff\nSession: {SESSION_B}\n\n## State\n", "--session", SESSION_B)
        self.assertEqual(rc, 0, out + err)

    def test_a_handoff_with_no_session_line_fails_and_says_so(self):
        rc, out, err = self.verify("# Handoff\n\n## State\nwork\n", "--session", SESSION_B)
        self.assertEqual(rc, 1, out + err)
        self.assertIn("STAMP-MISMATCH", out)
        self.assertIn("no Session line", out)

    def test_a_handoff_stamped_for_another_session_fails(self):
        rc, out, err = self.verify(f"# Handoff\nSession: {SESSION_A}\n", "--session", SESSION_B)
        self.assertEqual(rc, 1, out + err)
        self.assertIn("STAMP-MISMATCH", out)
        self.assertIn(SESSION_A, out)

    def test_without_the_flag_an_unstamped_handoff_still_passes(self):
        rc, out, err = self.verify("# Handoff\n\n## State\n")
        self.assertEqual(rc, 0, out + err)

    def test_root_and_session_can_come_in_either_order(self):
        text = f"# Handoff\nSession: {SESSION_B}\n"
        for flags in (["--root", self.repo.root, "--session", SESSION_B],
                      ["--session", SESSION_B, "--root", self.repo.root]):
            rc, out, err = self.verify(text, *flags)
            self.assertEqual(rc, 0, f"{flags}: {out}{err}")

    def test_session_flag_with_no_value_exits_2(self):
        r = subprocess.run([sys.executable, SCRIPT, "--session"], capture_output=True, text=True, cwd="/")
        self.assertEqual(r.returncode, 2)
        self.assertIn("usage", r.stderr)


class HandoffPrune(unittest.TestCase):
    """Handoff files must not pile up: stale ones are moved into pruned/, live ones never are.
    Nothing is deleted; pruned/ is never read or cleaned by pitstop."""

    def setUp(self):
        self.repo = Repo()
        self.addCleanup(self.repo.tmp.cleanup)
        self.rem = os.path.join(self.repo.root, ".remember")

    def make(self, name, days_old, text="# Handoff\nSession: some-session\n"):
        self.repo.write(f".remember/{name}", text)
        t = time.time() - days_old * 86400
        os.utime(os.path.join(self.rem, name), (t, t))

    def prune(self, *extra):
        r = subprocess.run([sys.executable, SCRIPT, "--prune", *extra], capture_output=True,
                           text=True, cwd=self.repo.root)
        return r.returncode, r.stdout.splitlines(), r.stderr

    def exists(self, name):
        return os.path.exists(os.path.join(self.rem, name))

    def test_moves_handoffs_older_than_the_default_thirty_days_and_keeps_newer_ones(self):
        self.make("remember.md", 31, "# Handoff\nSession: s1\nfirst\n")
        self.make("remember-old.md", 60, "# Handoff\nSession: s2\nsecond\n")
        self.make("remember-recent.md", 29)
        rc, out, err = self.prune()
        self.assertEqual(rc, 0, err)
        self.assertFalse(self.exists("remember.md"))
        self.assertFalse(self.exists("remember-old.md"))
        self.assertTrue(self.exists("remember-recent.md"))
        self.assertEqual(len(out), 2)
        self.assertTrue(all(l.startswith("pruned: ") and " -> " in l for l in out), out)
        with open(os.path.join(self.rem, "pruned", "remember.md")) as fh:
            self.assertIn("first", fh.read())
        with open(os.path.join(self.rem, "pruned", "remember-old.md")) as fh:
            self.assertIn("second", fh.read())

    def test_a_name_already_in_pruned_is_not_overwritten(self):
        self.make("pruned/remember.md", 5, "# Handoff\nSession: earlier\nearlier text\n")
        self.make("remember.md", 40, "# Handoff\nSession: later\nlater text\n")
        rc, out, err = self.prune()
        self.assertEqual(rc, 0, err)
        with open(os.path.join(self.rem, "pruned", "remember.md")) as fh:
            self.assertIn("earlier text", fh.read())
        with open(os.path.join(self.rem, "pruned", "remember-2.md")) as fh:
            self.assertIn("later text", fh.read())

    def test_files_already_in_pruned_are_never_moved_again_or_listed(self):
        self.make("pruned/remember-old.md", 90)
        rc, out, err = self.prune()
        self.assertEqual((rc, out), (0, []))
        self.assertTrue(self.exists("pruned/remember-old.md"))
        r = subprocess.run([sys.executable, SCRIPT, "--list"], capture_output=True, text=True, cwd=self.repo.root)
        self.assertEqual(r.stdout, "")

    def test_days_sets_the_cutoff(self):
        self.make("remember-a.md", 2)
        rc, out, err = self.prune("--days", "1")
        self.assertFalse(self.exists("remember-a.md"))
        self.make("remember-b.md", 2)
        rc, out, err = self.prune("--days", "3")
        self.assertTrue(self.exists("remember-b.md"))

    def test_never_touches_drafts_the_journal_or_other_files(self):
        self.make("journal.md", 90)
        self.make("drafts/2026-09-01-reply.md", 90, "text\n")
        self.make("remember-notes.txt", 90)
        self.make("notes.md", 90)
        rc, out, err = self.prune()
        self.assertEqual((rc, out), (0, []))
        for name in ("journal.md", "drafts/2026-09-01-reply.md", "remember-notes.txt", "notes.md"):
            self.assertTrue(self.exists(name), name)

    def test_a_remember_dash_file_without_a_session_stamp_is_never_moved(self):
        self.make("remember-notes.md", 90, "my own notes\n")
        self.make("remember-draft.md", 90, "# Handoff\nwritten by hand, no stamp\n")
        rc, out, err = self.prune()
        self.assertEqual((rc, out), (0, []))
        self.assertTrue(self.exists("remember-notes.md"))
        self.assertTrue(self.exists("remember-draft.md"))

    def test_the_configured_handoff_file_is_moved_even_without_a_stamp(self):
        self.make("remember.md", 60, "# Handoff\nwritten before handoffs carried a stamp\n")
        rc, out, err = self.prune()
        self.assertFalse(self.exists("remember.md"))
        self.assertEqual(len(out), 1)

    def test_a_symlink_named_like_a_handoff_is_not_followed(self):
        target = os.path.join(self.repo.root, "precious.txt")
        with open(target, "w") as fh:
            fh.write("keep\n")
        os.makedirs(self.rem, exist_ok=True)
        os.symlink(target, os.path.join(self.rem, "remember-link.md"))
        t = time.time() - 90 * 86400
        os.utime(target, (t, t))
        rc, out, err = self.prune()
        self.assertTrue(os.path.exists(target))
        self.assertEqual(out, [])

    def test_with_no_handoffs_it_prints_nothing_and_exits_0(self):
        rc, out, err = self.prune()
        self.assertEqual((rc, out), (0, []))

    def test_honours_a_configured_handoff_directory(self):
        cfg = os.path.join(self.repo.root, "cfg.md")
        with open(cfg, "w") as fh:
            fh.write("---\nhandoff_path: notes/handoff.md\n---\n")
        self.repo.write("notes/handoff.md", "# Handoff\n")
        os.utime(os.path.join(self.repo.root, "notes", "handoff.md"), (1, 1))
        self.make("remember-x.md", 90)
        rc, out, err = self.prune("--config", cfg)
        self.assertFalse(os.path.exists(os.path.join(self.repo.root, "notes", "handoff.md")))
        self.assertTrue(os.path.exists(os.path.join(self.repo.root, "notes", "pruned", "handoff.md")))
        self.assertTrue(self.exists("remember-x.md"))

    def test_bad_days_or_arguments_exit_2_and_move_nothing(self):
        self.make("remember-a.md", 90)
        for args in (["--days", "0"], ["--days", "x"], ["--days"], ["--bogus", "1"]):
            rc, out, err = self.prune(*args)
            self.assertEqual(rc, 2, args)
            self.assertIn("usage", err)
        self.assertTrue(self.exists("remember-a.md"))


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
