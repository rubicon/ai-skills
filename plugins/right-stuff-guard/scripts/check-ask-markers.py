#!/usr/bin/env python3
"""PreToolUse hook for AskUserQuestion: deny a call whose option labels break the right-stuff marker rules.

Reads the hook input JSON on stdin. A well-formed call, any other tool, and any input this script
cannot read produce no output and exit 0, so the normal pop-up appears and a bug here never blocks
asking the user. A malformed call prints a PreToolUse deny decision whose reason the model sees.
"""
import json, re, sys

RT, REC = "(Right Thing)", "(Recommended)"
MARKER_LIKE = re.compile(r"\((?:right thing|recommended)\)", re.IGNORECASE)
MAX_PROBLEMS = 4
MAX_LABEL_ECHO = 80


def parse_label(label):
    """Return (right_thing, recommended, base) after stripping markers from the end, Recommended last."""
    s = label.rstrip()
    rec = s.endswith(REC)
    if rec:
        s = s[: -len(REC)].rstrip()
    rt = s.endswith(RT)
    if rt:
        s = s[: -len(RT)].rstrip()
    return rt, rec, s


def echo(label):
    """The label as quoted back to the model: whitespace collapsed, long labels cut."""
    flat = " ".join(label.split())
    return flat if len(flat) <= MAX_LABEL_ECHO else flat[: MAX_LABEL_ECHO - 3] + "..."


def swapped_suffix(label):
    """True when the label ends in the two markers in the wrong order."""
    s = label.rstrip()
    return s.endswith(RT) and s[: -len(RT)].rstrip().endswith(REC)


def check_question(n, qn):
    problems = []
    opts = [o["label"] for o in qn["options"]]
    multi = qn.get("multiSelect") is True
    q = f"Q{n}"

    if MARKER_LIKE.search(qn.get("question") or ""):
        problems.append(f"{q} question text contains a marker; markers go only at the end of labels")
    if MARKER_LIKE.search(qn.get("header") or ""):
        problems.append(f"{q} header contains a marker; markers go only at the end of labels")

    parsed = []
    for i, o in enumerate(qn["options"], 1):
        rt, rec, base = parse_label(o["label"])
        parsed.append((rt, rec))
        if MARKER_LIKE.search(base):
            hint = f"in the order {RT} {REC}, at the very end" if swapped_suffix(o["label"]) else "only at the very end"
            problems.append(f'{q} option {i} "{echo(o["label"])}": markers must come {hint}, exactly as spelled')
        if MARKER_LIKE.search(o.get("description") or ""):
            problems.append(f"{q} option {i} description contains a marker; markers go only at the end of labels")

    n_rt = sum(p[0] for p in parsed)
    n_rec = sum(p[1] for p in parsed)
    if multi:
        if n_rt < 1:
            problems.append(f"{q}: at least one option must end in {RT}")
        if len(opts) >= 3 and all(p[0] or p[1] for p in parsed):
            problems.append(f"{q}: with three or more options, leave at least one unmarked")
    else:
        if n_rt != 1:
            problems.append(f"{q}: exactly one option must end in {RT}, found {n_rt}")
        if n_rec > 1:
            problems.append(f"{q}: at most one option may end in {REC}, found {n_rec}")

    if n_rec and not parsed[0][1]:
        problems.append(f"{q}: option 1 must end in {REC}")
    elif not n_rec and n_rt and not parsed[0][0]:
        problems.append(f"{q}: option 1 must end in {RT} when no option ends in {REC}")
    return problems


def valid_shape(tool_input):
    qs = tool_input.get("questions") if isinstance(tool_input, dict) else None
    if not isinstance(qs, list) or not qs:
        return False
    for qn in qs:
        if not isinstance(qn, dict) or not isinstance(qn.get("options"), list) or not qn["options"]:
            return False
        for o in qn["options"]:
            if not isinstance(o, dict) or not isinstance(o.get("label"), str):
                return False
    return True


def main():
    try:
        data = json.load(sys.stdin)
        if not isinstance(data, dict) or data.get("tool_name") != "AskUserQuestion":
            return
        tool_input = data.get("tool_input")
        if not valid_shape(tool_input):
            return
        problems = []
        for n, qn in enumerate(tool_input["questions"], 1):
            problems += check_question(n, qn)
    except Exception:
        return
    if not problems:
        return
    shown = "; ".join(problems[:MAX_PROBLEMS])
    more = f" (+{len(problems) - MAX_PROBLEMS} more)" if len(problems) > MAX_PROBLEMS else ""
    reason = (f"right-stuff-guard: {shown}{more}.\n"
              f"Fix the labels and call AskUserQuestion again. A label ends in {RT} (the responsible choice), "
              f"{REC} (the option advised), {RT} {REC}, or no marker; see the right-stuff skill.")
    json.dump({"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny",
                                      "permissionDecisionReason": reason}}, sys.stdout)


if __name__ == "__main__":
    main()
