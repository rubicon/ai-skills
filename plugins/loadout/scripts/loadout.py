#!/usr/bin/env python3
"""loadout: record and compare what Claude Code loads in a directory.

  capture DIR --out SNAP [--stream FILE]
      Start a headless session in DIR (`claude -p "reply ok" --output-format
      stream-json --verbose`), keep its init event, and write a snapshot of the
      loaded skills, slash commands, and plugins to SNAP. The raw stream is kept
      beside it as SNAP.stream.jsonl. With --stream, parse that saved stream
      instead of starting a session. The session runs your hooks and is billed.

  inventory SNAP [--skills-dir DIR ...]
      Group a snapshot's plugins and skills by where they come from, list plugin
      slash commands, and find skills that share a base name. With --skills-dir,
      a skill whose directory is found there is standalone, and a bare name found
      in none of them is unlocated (usually built into Claude Code).

  verify --before SNAP --after SNAP --empty-before SNAP --empty-after SNAP
         --user FILE [--project FILE] --local FILE [--skills-dir DIR ...]
      Compare the plugins expected from the settings files with the plugins that
      loaded, in the project and in an empty directory, and classify every
      skillOverrides entry. --skills-dir names directories holding standalone
      skills, so an override that already hid a skill is not reported as a typo.
      Override findings in the user file are reported but do not set exit 1.

Output is JSON on stdout. Exit 0: clean. Exit 1: findings. Exit 2: bad input.
"""
import argparse, json, os, re, subprocess, sys

FAILING = {"still-loaded", "no-effect-plugin-skill", "no-effect-plugin-command", "not-found"}


def die(msg):
    print(f"loadout: {msg}", file=sys.stderr)
    sys.exit(2)


def read_json(path, required=True):
    if not os.path.exists(path):
        if required:
            die(f"{path}: not found")
        return {}
    try:
        with open(path) as fh:
            return json.load(fh)
    except (OSError, ValueError) as e:
        die(f"{path}: {e}")


def snapshot_from_stream(lines):
    for line in lines:
        line = line.strip()
        if not line:
            continue
        try:
            ev = json.loads(line)
        except ValueError:
            continue
        if ev.get("type") == "system" and ev.get("subtype") == "init":
            return {"cwd": ev.get("cwd"), "version": ev.get("claude_code_version"),
                    "skills": ev.get("skills", []), "slash_commands": ev.get("slash_commands", []),
                    "plugins": [{"name": p.get("name"), "source": p.get("source")} for p in ev.get("plugins", [])]}
    return None


def cmd_capture(a):
    if a.stream:
        with open(a.stream) as fh:
            text = fh.read()
    else:
        try:
            r = subprocess.run(["claude", "-p", "reply ok", "--output-format", "stream-json", "--verbose"],
                               cwd=a.dir, capture_output=True, text=True, timeout=600)
        except FileNotFoundError:
            die("claude is not on PATH")
        text = r.stdout
        with open(a.out + ".stream.jsonl", "w") as fh:
            fh.write(text)
        if r.returncode != 0:
            print(f"loadout: claude exited {r.returncode}: {r.stderr.strip()[:500]}", file=sys.stderr)
    snap = snapshot_from_stream(text.splitlines())
    if snap is None:
        die("no init event in the stream")
    with open(a.out, "w") as fh:
        json.dump(snap, fh, indent=2)
    print(json.dumps({"out": a.out, "version": snap["version"], "skills": len(snap["skills"]),
                      "slash_commands": len(snap["slash_commands"]), "plugins": len(snap["plugins"])}))


def is_builtin(source):
    return (source or "").endswith("@builtin")


def plugin_names(snap):
    return {p["name"]: p["source"] for p in snap["plugins"] if not is_builtin(p["source"])}


def prefix(name):
    return name.split(":", 1)[0] if ":" in name else None


def base_name(name):
    # A namespaced skill's last segment; a flattened copy such as
    # "_owner__skills__name" keeps only the part after "__skills__".
    return re.sub(r"^_.*__skills__", "", name.rsplit(":", 1)[-1])


def cmd_inventory(a):
    snap = read_json(a.snap)
    plugins = plugin_names(snap)
    groups, by_base = {}, {}
    for s in snap["skills"]:
        p = prefix(s)
        if on_disk(s, a.skills_dir):
            key = "standalone"
        elif p is None:
            # Without --skills-dir every bare name counts as standalone. With it,
            # a bare name found in none of them is unlocated: usually built in.
            key = "unlocated" if a.skills_dir else "standalone"
        elif p in plugins:
            key = "plugin:" + plugins[p]
        else:
            key = "account-synced:" + p
        groups.setdefault(key, []).append(s)
        by_base.setdefault(base_name(s), []).append(s)
    skills = set(snap["skills"])
    commands = {}
    for c in snap["slash_commands"]:
        if c not in skills and prefix(c) in plugins:
            commands.setdefault(plugins[prefix(c)], []).append(c)
    print(json.dumps({
        "plugins": {src: ("synced" if src.endswith("@synced") else "marketplace") for src in plugins.values()},
        "skills": {k: sorted(v) for k, v in sorted(groups.items())},
        "plugin_commands": {k: sorted(v) for k, v in sorted(commands.items())},
        "duplicates": {k: sorted(v) for k, v in sorted(by_base.items()) if len(v) > 1},
    }, indent=2))


def sources(snap):
    return {p["source"] for p in snap["plugins"] if not is_builtin(p["source"])}


def apply_settings(start, enabled):
    on = {k for k, v in enabled.items() if v is True}
    off = {k for k, v in enabled.items() if v is False}
    return (set(start) | on) - off


def compare(expected, loaded):
    return {"expected_count": len(expected), "loaded_count": len(loaded),
            "missing": sorted(expected - loaded), "unexpected": sorted(loaded - expected)}


def on_disk(name, skills_dirs):
    return any(os.path.isfile(os.path.join(d, name, "SKILL.md")) for d in skills_dirs)


def classify(name, value, before_names, before_plugins, after, merged_enabled, skills_dirs):
    if value != "off":
        return "not-checked"
    p = prefix(name)
    after_plugins = plugin_names(after)
    if name in after["skills"] or name in after["slash_commands"]:
        if p in after_plugins:
            return "no-effect-plugin-skill" if name in after["skills"] else "no-effect-plugin-command"
        return "still-loaded"
    if name in before_names or on_disk(name, skills_dirs):
        if p is not None and p in before_plugins and p not in after_plugins:
            return "covered-by-plugin-disable"
        return "hidden"
    if p is not None and p in before_plugins and p not in after_plugins:
        return "covered-by-plugin-disable"
    if p is not None and any(k.split("@", 1)[0] == p and v is False for k, v in merged_enabled.items()):
        return "plugin-off-unverifiable"
    return "not-found"


def cmd_verify(a):
    before, after = read_json(a.before), read_json(a.after)
    empty_before, empty_after = read_json(a.empty_before), read_json(a.empty_after)
    layers = [("user", read_json(a.user, required=False)),
              ("project", read_json(a.project, required=False) if a.project else {}),
              ("local", read_json(a.local, required=False))]
    merged = {}
    for _, s in layers:
        merged.update(s.get("enabledPlugins") or {})
    user_enabled = layers[0][1].get("enabledPlugins") or {}

    project = compare(apply_settings(sources(empty_before), merged), sources(after))
    empty = compare(apply_settings(sources(empty_before), user_enabled), sources(empty_after))

    before_names = set()
    before_plugins = set()
    for snap in (before, empty_before):
        before_names |= set(snap["skills"]) | set(snap["slash_commands"])
        before_plugins |= set(plugin_names(snap))
    overrides = []
    for layer, s in layers:
        for name, value in (s.get("skillOverrides") or {}).items():
            result = classify(name, value, before_names, before_plugins, after, merged, a.skills_dir)
            # A project audit cannot edit the user file, so findings there are
            # reported without failing the run.
            overrides.append({"name": name, "value": value, "file": layer, "result": result,
                              "fails": result in FAILING and layer != "user"})

    report = {"project": project, "empty": empty, "overrides": overrides}
    print(json.dumps(report, indent=2))
    failed = (project["missing"] or project["unexpected"] or empty["missing"] or empty["unexpected"]
              or any(o["fails"] for o in overrides))
    sys.exit(1 if failed else 0)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    c = sub.add_parser("capture")
    c.add_argument("dir")
    c.add_argument("--out", required=True)
    c.add_argument("--stream")
    i = sub.add_parser("inventory")
    i.add_argument("snap")
    i.add_argument("--skills-dir", action="append", default=[])
    v = sub.add_parser("verify")
    for flag in ("--before", "--after", "--empty-before", "--empty-after", "--user", "--local"):
        v.add_argument(flag, required=True)
    v.add_argument("--project")
    v.add_argument("--skills-dir", action="append", default=[])
    a = ap.parse_args()
    {"capture": cmd_capture, "inventory": cmd_inventory, "verify": cmd_verify}[a.cmd](a)


if __name__ == "__main__":
    main()
