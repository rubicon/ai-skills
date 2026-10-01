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
            The bare word "draft" is not a trigger, so draft PRs pass.

A failing path or SHA on a line containing "(unverified)" is reported as
ACKNOWLEDGED and does not fail: that is how an identifier from another repo is
carried honestly. The marker covers the whole line, and a missing or empty
draft file is never acknowledgeable.

Usage:  handoff-verify.py [HANDOFF]      (default: .remember/remember.md)
Exit:   0 = clean, 1 = findings, 2 = cannot read the handoff
Used by /pitstop:park (after writing the handoff) and /pitstop:sitrep (before
repeating it).
"""
import os, re, subprocess, sys

TOKEN = re.compile(r"`([^`\n]+)`")
# ponytail: a path must contain "/" and end in an extension with a letter.
# Bare filenames, directories and branch names are not checked; widen this
# only with a test proving domains and versions still pass.
PATH = re.compile(r"^(~?/?[\w.@+-]+(?:/[\w.@+-]+)+\.[A-Za-z][A-Za-z0-9]{0,7})(?::(\d+)(?:-(\d+))?)?$")
SHA = re.compile(r"^[0-9a-f]{7,40}$")
DRAFT = re.compile(r"\b(drafted|unposted|unsent|not (?:yet )?(?:posted|sent)|awaiting\b.{0,20}\bapproval)\b", re.I)
ACK = "(unverified)"


def git(root, *args):
    r = subprocess.run(["git", "-C", root, *args], capture_output=True, text=True)
    return r.returncode, r.stdout.strip()


def find_path(rel, root, worktrees, is_git):
    """Return the on-disk location, "history" if only a ref has it, or None."""
    if rel.startswith(("~", "/")):
        full = os.path.expanduser(rel)
        return full if os.path.exists(full) else None
    for base in [root] + worktrees:
        full = os.path.join(base, rel)
        if os.path.exists(full):
            return full
    if is_git:
        rc, out = git(root, "rev-list", "--all", "-1", "--", rel)
        if rc == 0 and out:
            return "history"
    return None


def main(argv):
    handoff = os.path.abspath(argv[1] if len(argv) > 1 else ".remember/remember.md")
    try:
        with open(handoff) as fh:
            lines = fh.read().splitlines()
    except OSError as exc:
        print(f"handoff-verify: cannot read {handoff}: {exc.strerror}", file=sys.stderr)
        return 2

    hdir = os.path.dirname(handoff)
    drafts_dir = os.path.join(hdir, "drafts")
    rc, top = git(hdir, "rev-parse", "--show-toplevel")
    is_git = rc == 0
    root = top if is_git else os.path.dirname(hdir)
    worktrees = []
    if is_git:
        _, out = git(root, "worktree", "list", "--porcelain")
        worktrees = [l[9:] for l in out.splitlines() if l.startswith("worktree ") and l[9:] != root]

    findings, acknowledged, checked = [], [], 0
    drafts_real = os.path.realpath(drafts_dir) + os.sep

    def draft_file(rel):
        """The on-disk location if rel names a file inside the handoff's drafts dir, else None."""
        full = os.path.realpath(os.path.expanduser(rel) if rel.startswith(("~", "/"))
                                else os.path.join(root, rel))
        return full if full.startswith(drafts_real) else None

    def report(n, kind, detail):
        if ACK in lines[n]:
            acknowledged.append(f"ACKNOWLEDGED line {n + 1}: {kind} {detail}")
        else:
            findings.append(f"{kind} line {n + 1}: {detail}")

    for n, line in enumerate(lines):
        for tok in TOKEN.findall(line):
            m = PATH.match(tok)
            if m and "://" not in tok:
                checked += 1
                rel, start, end = m.group(1), m.group(2), m.group(3)
                draft = draft_file(rel)
                if draft:
                    # A draft must be on disk now, in the drafts dir. Another worktree or a
                    # ref's history does not count, and neither finding is acknowledgeable:
                    # a named draft that is not there is lost text.
                    if not os.path.isfile(draft):
                        findings.append(f"MISSING-DRAFT line {n + 1}: {rel}")
                    elif os.path.getsize(draft) == 0:
                        findings.append(f"EMPTY-DRAFT line {n + 1}: {rel}")
                    continue
                where = find_path(rel, root, worktrees, is_git)
                if where is None:
                    report(n, "MISSING-PATH", rel)
                elif start and where != "history" and os.path.isfile(where):
                    with open(where, errors="replace") as fh:
                        count = sum(1 for _ in fh)
                    first, last = int(start), int(end or start)
                    if not 1 <= first <= last <= count:
                        anchor = start + (f"-{end}" if end else "")
                        report(n, "LINE-OUT-OF-RANGE", f"{rel}:{anchor} (file has {count} lines)")
            elif SHA.match(tok) and is_git:
                found = git(root, "cat-file", "-e", tok + "^{commit}")[0] == 0
                if re.search(r"[a-f]", tok):
                    checked += 1
                    if not found:
                        report(n, "MISSING-SHA", f"{tok} is not a commit in this repo")

        if DRAFT.search(line):
            checked += 1
            window = " ".join(lines[n:n + 3])
            named = [m.group(1) for m in map(PATH.match, TOKEN.findall(window)) if m]
            # A named draft that is missing or empty is reported by the path check above.
            if not any(draft_file(p) for p in named):
                findings.append(f"DRAFT-WITHOUT-FILE line {n + 1}: says \"{DRAFT.search(line).group(0)}\" "
                                f"but names no file under {os.path.relpath(drafts_dir, root)}/")

    on_disk = sorted(f for f in os.listdir(drafts_dir) if not f.startswith(".")) \
        if os.path.isdir(drafts_dir) else []

    for msg in findings + acknowledged:
        print(msg)
    if not is_git:
        print("note: not a git repo, SHAs and ref history were not checked")
    print(f"drafts on disk: {len(on_disk)}" + (" (" + ", ".join(on_disk[:10]) + ")" if on_disk else ""))
    print(f"handoff-verify: {checked} checked, {len(findings)} failed, {len(acknowledged)} acknowledged")
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
