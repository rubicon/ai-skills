#!/usr/bin/env python3
"""Roster gate: validates identity-theft personality dossiers.

Usage: validate_dossier.py PERSONALITIES_DIR
Exit 0 = all dossiers valid. Exit 1 = violations, reported on stdout.

Parses a deliberate YAML subset in the header: `key: scalar` and
`key: [a, b]` inline lists only (stdlib-only constraint; PyYAML not used).
"""
import re
import sys
from pathlib import Path

REQUIRED_FIELDS = ("id", "display_name", "suffix", "aliases")
REQUIRED_SECTIONS = ("Identity", "Speech Patterns", "Vocabulary",
                     "Riff Themes", "Anti-Patterns", "Preamble", "Examples")


def parse_header(text):
    m = re.match(r"\A---\n(.*?)\n---\n", text, re.S)
    if not m:
        return {}
    header = {}
    for line in m.group(1).splitlines():
        kv = re.match(r"^(\w+):\s*(.*)$", line)
        if not kv:
            continue
        key, val = kv.group(1), kv.group(2).strip()
        if val.startswith("[") and val.endswith("]"):
            header[key] = [x.strip() for x in val[1:-1].split(",") if x.strip()]
        else:
            header[key] = val
    return header


def check_dossier(path):
    path = Path(path)
    errors = []
    text = path.read_text()
    h = parse_header(text)
    if not h:
        return [f"{path.name}: missing or malformed YAML header"]
    for field in REQUIRED_FIELDS:
        if not h.get(field):
            errors.append(f"{path.name}: missing required header field '{field}'")
    if isinstance(h.get("aliases"), str):
        errors.append(f"{path.name}: 'aliases' must be a list")
    modes = h.get("modes") or []
    if "modes" in h:
        if isinstance(modes, str):
            errors.append(f"{path.name}: 'modes' must be a list")
            modes = []
        elif not modes:
            errors.append(f"{path.name}: 'modes' present but empty")
        elif h.get("default_mode") not in modes:
            errors.append(f"{path.name}: default_mode must be one of modes, got {h.get('default_mode')!r}")
    sections = set(re.findall(r"^##\s+(.+?)\s*$", text, re.M))
    required = REQUIRED_SECTIONS + (("Modes",) if modes else ())
    for s in required:
        if s not in sections:
            errors.append(f"{path.name}: missing required section '## {s}'")
    examples = re.findall(r"^###\s+Example \(([^)]+)\)", text, re.M)
    expected = modes if modes else ["default"]
    for mode in expected:
        if mode not in examples:
            errors.append(f"{path.name}: missing '### Example ({mode})'")
    for block in re.split(r"^###\s+Example", text, flags=re.M)[1:]:
        if "**Before:**" not in block or "**After:**" not in block:
            errors.append(f"{path.name}: an example lacks **Before:**/**After:**")
    return errors


def check_roster(dirpath):
    errors, seen_ids, seen_suffixes, seen_aliases = [], {}, {}, {}
    for path in sorted(Path(dirpath).glob("*.md")):
        errors += check_dossier(path)
        h = parse_header(path.read_text())
        for store, key in ((seen_ids, "id"), (seen_suffixes, "suffix")):
            v = h.get(key)
            if v in store:
                errors.append(f"{path.name}: duplicate {key} {v!r} (also in {store[v]})")
            elif v:
                store[v] = path.name
        for a in (h.get("aliases") or []):
            if a in seen_aliases:
                errors.append(f"{path.name}: duplicate alias {a!r} (also in {seen_aliases[a]})")
            else:
                seen_aliases[a] = path.name
    return errors


def main(argv):
    if len(argv) != 2:
        print(__doc__)
        return 2
    errors = check_roster(argv[1])
    if errors:
        print(f"FAIL: {len(errors)} dossier violation(s):")
        for e in errors:
            print(f"  - {e}")
        return 1
    print("PASS: all dossiers valid")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
