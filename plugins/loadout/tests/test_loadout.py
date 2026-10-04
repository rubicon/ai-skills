#!/usr/bin/env python3
"""Tests for loadout.py. Real files in temp directories, no mocks.

Run:  python3 plugins/loadout/tests/test_loadout.py

`capture` is tested through --stream, which parses a saved stream-json file
instead of starting a session. The init events below are invented examples in
the shape Claude Code emits.
"""
import json, os, subprocess, sys, tempfile, unittest

SCRIPT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "scripts", "loadout.py")

BUILTIN = {"name": "cc-plugin-telemetry", "source": "cc-plugin-telemetry@builtin"}
TOOLBELT = {"name": "toolbelt", "source": "toolbelt@acme"}
NOTES = {"name": "notes", "source": "notes@synced"}
GARDEN = {"name": "garden", "source": "garden@acme"}


def init_event(skills=(), commands=(), plugins=()):
    return {"type": "system", "subtype": "init", "cwd": "/work/demo",
            "claude_code_version": "9.9.9", "skills": list(skills),
            "slash_commands": sorted(set(skills) | set(commands)),
            "plugins": [dict(p, path="/plugins/" + p["name"]) for p in plugins]}


class Workspace:
    def __init__(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = os.path.realpath(self.tmp.name)

    def path(self, rel):
        return os.path.join(self.root, rel)

    def write(self, rel, text):
        p = self.path(rel)
        os.makedirs(os.path.dirname(p), exist_ok=True)
        with open(p, "w") as fh:
            fh.write(text)
        return p

    def write_json(self, rel, obj):
        return self.write(rel, json.dumps(obj))

    def stream(self, rel, *events):
        return self.write(rel, "".join(json.dumps(e) + "\n" for e in events))

    def snapshot(self, rel, **kw):
        stream = self.stream(rel + ".jsonl", init_event(**kw))
        rc, out, err = run("capture", self.root, "--stream", stream, "--out", self.path(rel))
        assert rc == 0, out + err
        return self.path(rel)


def run(*args):
    r = subprocess.run([sys.executable, SCRIPT, *args], capture_output=True, text=True, cwd="/")
    return r.returncode, r.stdout, r.stderr


class Capture(unittest.TestCase):
    def setUp(self):
        self.ws = Workspace()
        self.addCleanup(self.ws.tmp.cleanup)

    def test_extracts_init_event_among_other_events(self):
        stream = self.ws.stream("s.jsonl",
                                {"type": "system", "subtype": "hook_started"},
                                init_event(skills=["wordsmith"], plugins=[TOOLBELT, BUILTIN]),
                                {"type": "result", "subtype": "success"})
        rc, out, err = run("capture", self.ws.root, "--stream", stream, "--out", self.ws.path("snap.json"))
        self.assertEqual(rc, 0, out + err)
        with open(self.ws.path("snap.json")) as fh:
            snap = json.load(fh)
        self.assertEqual(snap["skills"], ["wordsmith"])
        self.assertEqual(snap["version"], "9.9.9")
        self.assertEqual([p["source"] for p in snap["plugins"]], ["toolbelt@acme", "cc-plugin-telemetry@builtin"])
        self.assertEqual(err, "")

    def test_stream_without_init_event_is_an_error(self):
        stream = self.ws.stream("s.jsonl", {"type": "result", "subtype": "error_during_execution"})
        rc, out, err = run("capture", self.ws.root, "--stream", stream, "--out", self.ws.path("snap.json"))
        self.assertEqual(rc, 2)
        self.assertIn("no init event", err)
        self.assertFalse(os.path.exists(self.ws.path("snap.json")))


class Inventory(unittest.TestCase):
    def setUp(self):
        self.ws = Workspace()
        self.addCleanup(self.ws.tmp.cleanup)

    def test_groups_skills_by_origin_and_finds_duplicates(self):
        snap = self.ws.snapshot("snap.json",
                                skills=["wordsmith", "toolbelt:lint", "toolbelt:review", "acct:review", "notes:jot"],
                                commands=["toolbelt:fmt", "clear"],
                                plugins=[TOOLBELT, NOTES, BUILTIN])
        rc, out, err = run("inventory", snap)
        self.assertEqual(rc, 0, out + err)
        inv = json.loads(out)
        self.assertEqual(inv["plugins"], {"toolbelt@acme": "marketplace", "notes@synced": "synced"})
        self.assertEqual(inv["skills"]["standalone"], ["wordsmith"])
        self.assertEqual(inv["skills"]["plugin:toolbelt@acme"], ["toolbelt:lint", "toolbelt:review"])
        self.assertEqual(inv["skills"]["plugin:notes@synced"], ["notes:jot"])
        self.assertEqual(inv["skills"]["account-synced:acct"], ["acct:review"])
        self.assertEqual(inv["plugin_commands"], {"toolbelt@acme": ["toolbelt:fmt"]})
        self.assertEqual(inv["duplicates"], {"review": ["acct:review", "toolbelt:review"]})

    def test_skills_dirs_separate_standalone_from_unlocated(self):
        # A directory whose name contains a colon is still a standalone skill.
        self.ws.write("skills/wordsmith/SKILL.md", "---\nname: wordsmith\ndescription: x\n---\n")
        self.ws.write("skills/acct:quill/SKILL.md", "---\nname: quill\ndescription: x\n---\n")
        snap = self.ws.snapshot("snap.json", skills=["wordsmith", "acct:quill", "simplify"], plugins=[])
        rc, out, err = run("inventory", snap, "--skills-dir", self.ws.path("skills"))
        self.assertEqual(rc, 0, out + err)
        inv = json.loads(out)
        self.assertEqual(inv["skills"]["standalone"], ["acct:quill", "wordsmith"])
        self.assertEqual(inv["skills"]["unlocated"], ["simplify"])

    def test_builtin_plugins_are_left_out(self):
        snap = self.ws.snapshot("snap.json", skills=[], plugins=[BUILTIN])
        rc, out, err = run("inventory", snap)
        self.assertEqual(json.loads(out)["plugins"], {})


class Verify(unittest.TestCase):
    """Default scene: toolbelt is on globally; garden is off globally and turned
    on for the project; notes is a synced plugin that loads with no settings key."""

    def setUp(self):
        self.ws = Workspace()
        self.addCleanup(self.ws.tmp.cleanup)
        self.user = {"enabledPlugins": {"toolbelt@acme": True, "garden@acme": False}}
        self.local = {"enabledPlugins": {"garden@acme": True}, "skillOverrides": {}}
        self.empty_before = dict(skills=["wordsmith", "toolbelt:lint", "notes:jot"],
                                 plugins=[TOOLBELT, NOTES, BUILTIN])
        self.before = self.empty_before
        self.after = dict(skills=["wordsmith", "toolbelt:lint", "notes:jot", "garden:prune"],
                          plugins=[TOOLBELT, NOTES, GARDEN, BUILTIN])
        self.empty_after = self.empty_before

    def verify(self, *extra):
        args = ["verify",
                "--before", self.ws.snapshot("before.json", **self.before),
                "--after", self.ws.snapshot("after.json", **self.after),
                "--empty-before", self.ws.snapshot("empty-before.json", **self.empty_before),
                "--empty-after", self.ws.snapshot("empty-after.json", **self.empty_after),
                "--user", self.ws.write_json("user.json", self.user),
                "--local", self.ws.write_json("local.json", self.local), *extra]
        rc, out, err = run(*args)
        return rc, (json.loads(out) if out.strip().startswith("{") else out), err

    def overrides(self, report):
        return {o["name"]: o["result"] for o in report["overrides"]}

    def test_project_override_loads_and_nothing_leaks(self):
        rc, rep, err = self.verify()
        self.assertEqual(rc, 0, f"{rep}{err}")
        self.assertEqual(rep["project"]["missing"], [])
        self.assertEqual(rep["project"]["unexpected"], [])
        self.assertEqual(rep["empty"]["missing"], [])
        self.assertEqual(rep["empty"]["unexpected"], [])
        self.assertEqual(rep["project"]["expected_count"], 3)

    def test_synced_plugin_with_no_settings_key_is_expected(self):
        rc, rep, err = self.verify()
        self.assertNotIn("notes@synced", rep["project"]["unexpected"])

    def test_plugin_set_false_but_still_loaded_fails(self):
        self.local["enabledPlugins"]["notes@synced"] = False
        rc, rep, err = self.verify()
        self.assertEqual(rc, 1)
        self.assertEqual(rep["project"]["unexpected"], ["notes@synced"])

    def test_plugin_set_true_but_not_loaded_fails(self):
        self.after = dict(self.empty_before)
        rc, rep, err = self.verify()
        self.assertEqual(rc, 1)
        self.assertEqual(rep["project"]["missing"], ["garden@acme"])

    def test_project_plugin_leaking_into_empty_directory_fails(self):
        self.empty_after = self.after
        rc, rep, err = self.verify()
        self.assertEqual(rc, 1)
        self.assertEqual(rep["empty"]["unexpected"], ["garden@acme"])

    def test_project_settings_file_sits_between_user_and_local(self):
        project = self.ws.write_json("project.json", {"enabledPlugins": {"garden@acme": False}})
        rc, rep, err = self.verify("--project", project)
        self.assertEqual(rc, 0, f"{rep}{err}")
        self.local["enabledPlugins"] = {}
        rc, rep, err = self.verify("--project", project)
        self.assertEqual(rc, 1)
        self.assertEqual(rep["project"]["unexpected"], ["garden@acme"])

    def test_standalone_override_that_hides_its_skill(self):
        self.local["skillOverrides"] = {"wordsmith": "off"}
        self.after = dict(self.after, skills=[s for s in self.after["skills"] if s != "wordsmith"])
        rc, rep, err = self.verify()
        self.assertEqual(rc, 0, f"{rep}{err}")
        self.assertEqual(self.overrides(rep), {"wordsmith": "hidden"})

    def test_override_on_a_plugin_skill_has_no_effect(self):
        self.local["skillOverrides"] = {"toolbelt:lint": "off"}
        rc, rep, err = self.verify()
        self.assertEqual(rc, 1)
        self.assertEqual(self.overrides(rep), {"toolbelt:lint": "no-effect-plugin-skill"})

    def test_override_on_a_plugin_command_has_no_effect(self):
        self.local["skillOverrides"] = {"toolbelt:fmt": "off"}
        self.after = dict(self.after, commands=["toolbelt:fmt"])
        rc, rep, err = self.verify()
        self.assertEqual(rc, 1)
        self.assertEqual(self.overrides(rep), {"toolbelt:fmt": "no-effect-plugin-command"})

    def test_standalone_override_that_did_not_hide_fails(self):
        self.local["skillOverrides"] = {"wordsmith": "off"}
        rc, rep, err = self.verify()
        self.assertEqual(rc, 1)
        self.assertEqual(self.overrides(rep), {"wordsmith": "still-loaded"})

    def test_override_for_skill_of_a_disabled_plugin_is_not_a_typo(self):
        self.local["skillOverrides"] = {"notes:jot": "off"}
        self.local["enabledPlugins"]["notes@synced"] = False
        self.after = dict(skills=["wordsmith", "toolbelt:lint", "garden:prune"], plugins=[TOOLBELT, GARDEN, BUILTIN])
        rc, rep, err = self.verify()
        self.assertEqual(rc, 0, f"{rep}{err}")
        self.assertEqual(self.overrides(rep), {"notes:jot": "covered-by-plugin-disable"})

    def test_override_for_a_plugin_that_is_off_everywhere_cannot_be_checked(self):
        self.local["skillOverrides"] = {"orchard:pick": "off"}
        self.user["enabledPlugins"]["orchard@acme"] = False
        rc, rep, err = self.verify()
        self.assertEqual(rc, 0, f"{rep}{err}")
        self.assertEqual(self.overrides(rep), {"orchard:pick": "plugin-off-unverifiable"})

    def test_override_matching_nothing_is_flagged(self):
        self.local["skillOverrides"] = {"wordsmtih": "off"}
        rc, rep, err = self.verify()
        self.assertEqual(rc, 1)
        self.assertEqual(self.overrides(rep), {"wordsmtih": "not-found"})

    def test_override_already_hiding_a_skill_on_disk_is_not_a_typo(self):
        # Hidden before and after, so neither init event lists it; the skill
        # directory proves the name is real.
        self.ws.write("skills/quill/SKILL.md", "---\nname: quill\ndescription: x\n---\n")
        self.local["skillOverrides"] = {"quill": "off"}
        rc, rep, err = self.verify("--skills-dir", self.ws.path("skills"))
        self.assertEqual(rc, 0, f"{rep}{err}")
        self.assertEqual(self.overrides(rep), {"quill": "hidden"})

    def test_user_file_findings_are_reported_but_do_not_fail_a_project_audit(self):
        self.user["skillOverrides"] = {"wordsmtih": "off"}
        rc, rep, err = self.verify()
        self.assertEqual(rc, 0, f"{rep}{err}")
        self.assertEqual(rep["overrides"], [{"name": "wordsmtih", "value": "off", "file": "user",
                                             "result": "not-found", "fails": False}])

    def test_values_other_than_off_are_reported_unchecked(self):
        self.local["skillOverrides"] = {"wordsmith": "name-only"}
        rc, rep, err = self.verify()
        self.assertEqual(rc, 0, f"{rep}{err}")
        self.assertEqual(self.overrides(rep), {"wordsmith": "not-checked"})

    def test_missing_optional_settings_file_counts_as_empty(self):
        rc, rep, err = self.verify("--project", self.ws.path("no-such.json"))
        self.assertEqual(rc, 0, f"{rep}{err}")

    def test_invalid_settings_json_is_an_error(self):
        bad = self.ws.write("bad.json", "{ not json")
        rc, rep, err = self.verify("--project", bad)
        self.assertEqual(rc, 2)
        self.assertIn("bad.json", err)


if __name__ == "__main__":
    unittest.main(verbosity=2)
