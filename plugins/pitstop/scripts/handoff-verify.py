#!/usr/bin/env python3
"""handoff-verify - check that a handoff's identifiers exist and its drafts are on disk.

A handoff is relayed by the next session as though everything in it were
located. This refuses to let an invented path, an unknown SHA, or a draft that
was described but never saved pass as fact.

Checks, over backticked tokens in the handoff:
  path      `dir/file.ext`, `dir/file.ext:LINE` or `dir/file.ext:FROM-TO` must
            exist in the project, a git worktree, or the history of any ref;
            the line or range must lie inside the file.
  sha       7-40 hex chars containing a letter      must be a commit here.
  draft     a line saying drafted, unposted, unsent, not posted, not sent, or
            awaiting approval must name a file inside <handoff dir>/drafts/ on
            that line or the two after it. That file must be on disk there now
            and non-empty; a copy elsewhere or in git history does not count.
            The bare word "draft" is not a trigger, so draft PRs pass, and
            "none unsent" or "no unposted ..." reports an absence, not a claim.
  unlisted  every file directly in <handoff dir>/drafts/ (not hidden, not in
            done/) must be named in the handoff. Reported as line 0.
  done      a draft claim must not name a file in drafts/done/.

A failing path or SHA on a line containing "(unverified)" is reported as
ACKNOWLEDGED and does not fail: that is how an identifier from another repo is
carried honestly. The marker covers the whole line, and a missing or empty
draft file is never acknowledgeable.

Usage:  handoff-verify.py [--root DIR] [HANDOFF]   (default: .remember/remember.md)
                --root sets the project root outside git; pass the root: --where printed
        handoff-verify.py --where [--config FILE]
                prints root, config, handoff, drafts and journal, one
                "key: value" line each, resolved from the working directory
Exit:   0 = clean, 1 = findings, 2 = cannot read the handoff or could not verify
Used by /pitstop:park (after writing the handoff) and /pitstop:sitrep (before
repeating it).
"""
import os, re, subprocess, sys, time

TOKEN = re.compile(r"`([^`\n]+)`")
# ponytail: a path must contain "/" and end in an extension with a letter.
# Bare filenames, directories and branch names are not checked; widen this
# only with a test proving domains and versions still pass.
PATH = re.compile(r"^(~?/?[\w.@+-]+(?:/[\w.@+-]+)+\.[A-Za-z][A-Za-z0-9]{0,7})(?::(\d+)(?:-(\d+))?)?$")
SHA = re.compile(r"^[0-9a-f]{7,40}$")
DRAFT = re.compile(r"\b(drafted|unposted|unsent|not (?:yet )?(?:posted|sent)|awaiting\b.{0,20}\bapproval)\b", re.I)
# "none unsent" or "no unposted replies" reports an absence; it is not a claim that a draft exists.
ANCHOR = re.compile(r":\d+(?:-\d+)?$")
NO_DRAFTS = re.compile(r"\b(?:none|no)\s+(?:\w+\s+)?(?:drafted|unposted|unsent)\b", re.I)
ACK = "(unverified)"
DEFAULT_HANDOFF = ".remember/remember.md"
# A hung git (stale lock, slow network filesystem) must end as exit 2 through run(),
# not block park or sitrep forever.
GIT_TIMEOUT = 60


def read_header(path):
    """The integrations file's header as a dict. {} if the file is absent; None if it does not parse."""
    try:
        with open(path, newline="", errors="replace") as fh:
            text = fh.read()
    except FileNotFoundError:
        return {}
    except OSError:
        return None
    # newline="" keeps any \r; every comparison below strips it, so CRLF files parse too.
    lines = text.split("\n")
    if lines[0].strip() != "---":
        return None
    header = {}
    for line in lines[1:]:
        if line.strip() == "---":
            return header
        if not line.strip():
            continue
        key, sep, value = line.partition(":")
        if not sep or not key.strip():
            return None
        header[key.strip()] = value.strip()
    return None


def git(root, *args):
    try:
        r = subprocess.run(["git", "-C", root, *args], capture_output=True, text=True,
                           timeout=GIT_TIMEOUT)
    except FileNotFoundError:
        return 127, ""  # git is optional; without it every repo check is skipped
    return r.returncode, r.stdout.strip()


def find_path(rel, root, worktrees, is_git):
    """Return ("file", full path), ("history", commit that contains it), or None."""
    if rel.startswith(("~", "/")):
        full = os.path.expanduser(rel)
        return ("file", full) if os.path.exists(full) else None
    for base in [root] + worktrees:
        full = os.path.join(base, rel)
        if os.path.exists(full):
            return ("file", full)
    if is_git:
        # The newest commit that added, modified, or renamed-in the path still contains it,
        # unlike a plain rev-list, which can return the commit that deleted it.
        rc, out = git(root, "log", "--all", "-1", "--format=%H", "--diff-filter=AMR", "--", rel)
        if rc == 0 and out:
            return ("history", out)
    return None


def line_count(found, rel, root):
    """Lines in the file on disk, or in the blob at the commit that holds it. None if unknowable."""
    kind, value = found
    if kind == "file":
        try:
            with open(value, "rb") as fh:
                return len(fh.read().splitlines())
        except OSError:
            return None
    try:
        r = subprocess.run(["git", "-C", root, "show", f"{value}:{rel}"], capture_output=True,
                           timeout=GIT_TIMEOUT)
    except FileNotFoundError:
        return None
    return len(r.stdout.splitlines()) if r.returncode == 0 else None


def where(cwd, config):
    """The five locations every pitstop skill uses, as (key, value) pairs in fixed order."""
    rc, top = git(cwd, "rev-parse", "--show-toplevel")
    root = top if rc == 0 else os.path.abspath(cwd)
    header = read_header(config) if config else {}
    if header is None:
        shown, header = f"invalid {config}", {}
    elif not config or not os.path.exists(config):
        shown = "none"
    else:
        shown = config
    handoff = os.path.normpath(os.path.join(root, header.get("handoff_path") or DEFAULT_HANDOFF))
    hdir = os.path.dirname(handoff)
    return [("root", root), ("config", shown), ("handoff", handoff),
            ("drafts", os.path.join(hdir, "drafts")), ("journal", os.path.join(hdir, "journal.md"))]


def main(argv):
    args = argv[1:]
    if args[:1] == ["--where"]:
        if len(args) == 1:
            config = None
        elif len(args) == 3 and args[1] == "--config":
            config = args[2]
        else:
            print("usage: handoff-verify.py --where [--config FILE]", file=sys.stderr)
            return 2
        for key, value in where(os.getcwd(), config):
            print(f"{key}: {value}")
        return 0
    root_arg = None
    if args[:1] == ["--root"]:
        if len(args) < 2:
            print("usage: handoff-verify.py [--root DIR] [HANDOFF]", file=sys.stderr)
            return 2
        root_arg, args = os.path.abspath(args[1]), args[2:]
    handoff = os.path.abspath(args[0] if args else DEFAULT_HANDOFF)
    try:
        with open(handoff, errors="replace") as fh:
            lines = fh.read().splitlines()
    except OSError as exc:
        print(f"handoff-verify: cannot read {handoff}: {exc.strerror}", file=sys.stderr)
        return 2

    hdir = os.path.dirname(handoff)
    drafts_dir = os.path.join(hdir, "drafts")
    rc, top = git(hdir, "rev-parse", "--show-toplevel")
    is_git = rc == 0
    # Outside git the caller passes the root --where printed; the old guess assumed a
    # handoff exactly one directory below the project root.
    root = top if is_git else (root_arg or os.path.dirname(hdir))
    if not is_git and not root_arg:
        print(f"note: no --root given, assuming project root {root}", file=sys.stderr)
    worktrees = []
    if is_git:
        _, out = git(root, "worktree", "list", "--porcelain")
        worktrees = [l[9:] for l in out.splitlines() if l.startswith("worktree ") and l[9:] != root]

    findings, acknowledged, checked = [], [], 0
    drafts_real = os.path.realpath(drafts_dir) + os.sep
    done_real = os.path.realpath(os.path.join(drafts_dir, "done")) + os.sep
    named_drafts = set()

    def draft_file(rel):
        """The on-disk location if rel names a file inside the handoff's drafts dir, else None."""
        full = os.path.realpath(os.path.expanduser(rel) if rel.startswith(("~", "/"))
                                else os.path.join(root, rel))
        return full if full.startswith(drafts_real) else None

    def draft_ref(tok):
        """The draft file a backticked token names, judged before the strict path pattern
        so that spaces, parentheses, or a line anchor in a draft path still count."""
        loose = ANCHOR.sub("", tok)
        if "/" not in loose or "://" in loose:
            return None, loose
        return draft_file(loose), loose

    def drafts_named(text):
        return [d for d in (draft_ref(t)[0] for t in TOKEN.findall(text)) if d]

    def is_claim(text):
        # Remove "none unsent" style absences first, so they neither count as a claim
        # nor hide a real claim later on the same line.
        return DRAFT.search(NO_DRAFTS.sub("", text))

    def report(n, kind, detail):
        if ACK in lines[n]:
            acknowledged.append(f"ACKNOWLEDGED line {n + 1}: {kind} {detail}")
        else:
            findings.append(f"{kind} line {n + 1}: {detail}")

    for n, line in enumerate(lines):
        for tok in TOKEN.findall(line):
            draft, loose = draft_ref(tok)
            if draft:
                checked += 1
                named_drafts.add(draft)
                # A draft must be on disk now, in the drafts dir. Another worktree or a
                # ref's history does not count, and neither finding is acknowledgeable:
                # a named draft that is not there is lost text.
                if not os.path.isfile(draft):
                    findings.append(f"MISSING-DRAFT line {n + 1}: {loose}")
                elif os.path.getsize(draft) == 0:
                    findings.append(f"EMPTY-DRAFT line {n + 1}: {loose}")
                continue
            m = PATH.match(tok)
            if m and "://" not in tok:
                checked += 1
                rel, start, end = m.group(1), m.group(2), m.group(3)
                found = find_path(rel, root, worktrees, is_git)
                if found is None:
                    report(n, "MISSING-PATH", rel)
                elif start:
                    count = line_count(found, rel, root)
                    first, last = int(start), int(end or start)
                    if count is not None and not 1 <= first <= last <= count:
                        anchor = start + (f"-{end}" if end else "")
                        report(n, "LINE-OUT-OF-RANGE", f"{rel}:{anchor} (file has {count} lines)")
            elif SHA.match(tok) and is_git:
                found = git(root, "cat-file", "-e", tok + "^{commit}")[0] == 0
                if re.search(r"[a-f]", tok):
                    checked += 1
                    if not found:
                        report(n, "MISSING-SHA", f"{tok} is not a commit in this repo")

        claim = is_claim(line)
        if claim:
            checked += 1
            # Prefer the claim's own line, so a done/ file mentioned on the next line does not
            # count against a live claim. Look ahead at most two lines, and stop at a line that
            # is a claim of its own, so one saved file cannot cover two drafts.
            window = [line]
            for nxt in lines[n + 1:n + 3]:
                if is_claim(nxt):
                    break
                window.append(nxt)
            named = drafts_named(line) or drafts_named(" ".join(window))
            said = claim.group(0)
            if not named:
                findings.append(f"DRAFT-WITHOUT-FILE line {n + 1}: says \"{said}\" "
                                f"but names no file under {os.path.relpath(drafts_dir, root)}/")
            elif any(d.startswith(done_real) for d in named):
                findings.append(f"DONE-DRAFT-CLAIMED line {n + 1}: says \"{said}\" "
                                f"but names a file in {os.path.relpath(drafts_dir, root)}/done/")

    on_disk = sorted(f for f in os.listdir(drafts_dir)
                     if not f.startswith(".") and os.path.isfile(os.path.join(drafts_dir, f))) \
        if os.path.isdir(drafts_dir) else []
    for f in on_disk:
        full = os.path.join(drafts_dir, f)
        if os.path.realpath(full) not in named_drafts:
            # Never acknowledgeable: an unnamed draft is text the next session will not see.
            findings.append(f"UNLISTED-DRAFT line 0: {os.path.relpath(full, root)}")

    for msg in findings + acknowledged:
        print(msg)
    if not is_git:
        print("note: not a git repo, SHAs and ref history were not checked")
    print(f"handoff age: {int((time.time() - os.path.getmtime(handoff)) // 60)} min")
    print(f"drafts on disk: {len(on_disk)}" + (" (" + ", ".join(on_disk[:10]) + ")" if on_disk else ""))
    print(f"handoff-verify: {checked} checked, {len(findings)} failed, {len(acknowledged)} acknowledged")
    return 1 if findings else 0


def run(argv):
    """Exit 2 on anything unexpected, so a crash is never mistaken for findings (exit 1)."""
    try:
        return main(argv)
    except Exception as exc:  # noqa: BLE001 - every failure must surface as "could not verify"
        print(f"handoff-verify: could not verify: {type(exc).__name__}: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(run(sys.argv))
