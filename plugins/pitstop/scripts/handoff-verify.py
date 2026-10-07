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

Usage:  handoff-verify.py [--root DIR] [--session ID] [HANDOFF]   (default: .remember/remember.md)
                --root sets the project root outside git; pass the root: --where printed
                --session ID also requires the file to carry "Session: ID", so a handoff that
                lost its stamp fails here instead of becoming invisible to --list and --prune
        handoff-verify.py --where [--config FILE]
                prints root, config, handoff, drafts and journal, one
                "key: value" line each, resolved from the working directory
        handoff-verify.py --claim [--session ID] [--config FILE]
                reserves this session's handoff file and prints session, existing and write.
                park writes the handoff to "write:", which already holds a "Session: <id>"
                stub. "write:" is the handoff path unless another session (or an unstamped
                file) owns it, then a sibling named for this session. The reservation is
                created exclusively, so two sessions cannot be given the same path.
                --session passes back the "session:" value an earlier claim printed, for a
                session that has no id in its environment
        handoff-verify.py --list [--config FILE]
                one line per handoff in the handoff directory:
                "path | session <id or none> | <N> min"
        handoff-verify.py --prune [--days N] [--config FILE]
                moves handoffs older than N days (default 30) into pruned/ beside them and
                prints "pruned: <path> -> <new path>" for each. Nothing is deleted, and pruned/
                is never read or cleaned. Only the handoff file and its stamped remember-*.md
                siblings move; never drafts, the journal, a symlink, or a remember-*.md file
                with no Session line
Exit:   0 = clean, 1 = findings, 2 = cannot read the handoff or could not verify
Used by /pitstop:park (after writing the handoff) and /pitstop:sitrep (before
repeating it).
"""
import glob, os, re, subprocess, sys, time

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
STAMP = re.compile(r"^Session:[ \t]*(\S+)[ \t]*$", re.M)
# The desktop app and the CLI both set the first; only the desktop app sets the second.
SESSION_VARS = ("CLAUDE_CODE_SESSION_ID", "CLAUDE_CODE_HOST_SESSION_ID")
PRUNE_DAYS = 30
MODES = {"--where": {"--config"}, "--list": {"--config"},
         "--claim": {"--config", "--session"}, "--prune": {"--config", "--days"}}
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


def session_id():
    """This session's id from the environment. Without one, a fresh token: it never matches an
    existing stamp, so park writes a sibling rather than replacing anything."""
    for var in SESSION_VARS:
        if os.environ.get(var):
            return os.environ[var]
    return "anon-" + os.urandom(4).hex()


def handoff_owner(path):
    """The id in the file's Session line, or None if it has none or cannot be read."""
    try:
        with open(path, errors="replace") as fh:
            m = STAMP.search(fh.read())
    except OSError:
        return None
    return m.group(1) if m else None


def age_minutes(path):
    return int((time.time() - os.path.getmtime(path)) // 60)


def reserve(path, me):
    """Create path stamped for me unless it exists. Returns (owner state, True if created).
    Exclusive creation is what makes two simultaneous claims land on different files."""
    try:
        fd = os.open(path, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o644)
    except FileExistsError:
        owner = handoff_owner(path)
        age = f"{age_minutes(path)} min"
        if owner == me:
            return f"own ({age})", False
        return (f"other {owner} ({age})" if owner else f"unstamped ({age})"), False
    with os.fdopen(fd, "w") as fh:
        fh.write(f"# Handoff\nSession: {me}\n")
    return "none", True


def claim_handoff(cwd, config, session=None):
    """session, existing and write for a park that is about to write a handoff. `existing` is
    what the configured handoff path held before the claim; `write` is a file now reserved."""
    handoff = dict(where(cwd, config))["handoff"]
    me = session or session_id()
    os.makedirs(os.path.dirname(handoff), exist_ok=True)
    existing, created = reserve(handoff, me)
    target = handoff
    if not created and not existing.startswith("own"):
        safe = re.sub(r"[^A-Za-z0-9._-]", "_", me)
        n = 1
        while True:
            target = os.path.join(os.path.dirname(handoff), f"remember-{safe}" + (f"-{n}" if n > 1 else "") + ".md")
            state, created = reserve(target, me)
            if created or state.startswith("own"):
                break
            n += 1
    return [("session", me), ("existing", existing), ("write", target)]


def handoff_files(cwd, config):
    """The configured handoff file, if present, and its remember-*.md siblings in the same
    directory. A sibling counts only if it carries a Session stamp, because park is what writes
    those; a file someone else named remember-notes.md is not a handoff and is never touched."""
    handoff = dict(where(cwd, config))["handoff"]
    found = [handoff] if os.path.isfile(handoff) else []
    siblings = glob.glob(os.path.join(glob.escape(os.path.dirname(handoff)), "remember-*.md"))
    return found + sorted(p for p in siblings if handoff_owner(p))


def handoffs(cwd, config):
    return [(p, handoff_owner(p) or "none", age_minutes(p)) for p in handoff_files(cwd, config)]


def prune(cwd, config, days):
    """Move handoff files not touched for `days` days into pruned/ beside them, never overwriting
    a name already there. Nothing is deleted, and pruned/ is never read or cleaned. Symlinks stay."""
    cutoff = time.time() - days * 86400
    moved = []
    for path in handoff_files(cwd, config):
        if os.path.islink(path) or not os.path.isfile(path) or os.path.getmtime(path) >= cutoff:
            continue
        old = int((time.time() - os.path.getmtime(path)) // 86400)
        pruned_dir = os.path.join(os.path.dirname(path), "pruned")
        os.makedirs(pruned_dir, exist_ok=True)
        stem, ext = os.path.splitext(os.path.basename(path))
        dest, n = os.path.join(pruned_dir, stem + ext), 1
        while os.path.lexists(dest):
            n += 1
            dest = os.path.join(pruned_dir, f"{stem}-{n}{ext}")
        os.rename(path, dest)
        moved.append((path, dest, old))
    return moved


def main(argv):
    args = argv[1:]
    if args[:1] and args[0] in MODES:
        flag, rest = args[0], args[1:]
        opts = {}
        ok = len(rest) % 2 == 0
        for i in range(0, len(rest) - 1, 2):
            if rest[i] not in MODES[flag] or rest[i] in opts:
                ok = False
            opts[rest[i]] = rest[i + 1]
        days = PRUNE_DAYS
        if ok and "--days" in opts:
            if opts["--days"].isdigit() and int(opts["--days"]) >= 1:
                days = int(opts["--days"])
            else:
                ok = False
        if not ok:
            shown = " ".join(f"[{o} {o[2:].upper()}]" for o in sorted(MODES[flag]))
            print(f"usage: handoff-verify.py {flag} {shown}", file=sys.stderr)
            return 2
        config = opts.get("--config")
        if flag == "--list":
            for path, owner, age in handoffs(os.getcwd(), config):
                print(f"{path} | session {owner} | {age} min")
        elif flag == "--prune":
            for path, dest, old in prune(os.getcwd(), config, days):
                print(f"pruned: {path} -> {dest} ({old} days old)")
        elif flag == "--claim":
            for key, value in claim_handoff(os.getcwd(), config, opts.get("--session")):
                print(f"{key}: {value}")
        else:
            for key, value in where(os.getcwd(), config):
                print(f"{key}: {value}")
        return 0
    root_arg = session_arg = None
    while args[:1] in (["--root"], ["--session"]):
        if len(args) < 2:
            print("usage: handoff-verify.py [--root DIR] [--session ID] [HANDOFF]", file=sys.stderr)
            return 2
        if args[0] == "--root":
            root_arg = os.path.abspath(args[1])
        else:
            session_arg = args[1]
        args = args[2:]
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

    if session_arg:
        owner = handoff_owner(handoff)
        if owner != session_arg:
            found = f"Session: {owner}" if owner else "no Session line"
            # Never acknowledgeable: an unstamped or mis-stamped handoff is invisible to --list.
            findings.append(f"STAMP-MISMATCH line 0: expected Session: {session_arg}, found {found}")

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
