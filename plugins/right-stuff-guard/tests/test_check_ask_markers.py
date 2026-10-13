#!/usr/bin/env python3
"""Tests for check-ask-markers.py. Real hook-input JSON on stdin, real subprocess runs, no mocks.

Run:  python3 plugins/right-stuff-guard/tests/test_check_ask_markers.py
"""
import json, os, subprocess, sys, unittest

PLUGIN = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPT = os.path.join(PLUGIN, "scripts", "check-ask-markers.py")

RT, REC = "(Right Thing)", "(Recommended)"


def q(options, multi=False, question="Which database should the migration run against?", header="Database"):
    return {"question": question, "header": header, "multiSelect": multi,
            "options": [o if isinstance(o, dict) else {"label": o, "description": "Runs it there."} for o in options]}


def hook_input(*questions, tool="AskUserQuestion"):
    return {"session_id": "s", "cwd": "/tmp", "permission_mode": "default", "hook_event_name": "PreToolUse",
            "tool_name": tool, "tool_input": {"questions": list(questions)}, "tool_use_id": "toolu_x"}


def run(payload):
    raw = payload if isinstance(payload, (str, bytes)) else json.dumps(payload)
    if isinstance(raw, str):
        raw = raw.encode()
    r = subprocess.run([sys.executable, SCRIPT], input=raw, capture_output=True)
    return r.returncode, r.stdout.decode(), r.stderr.decode()


def deny_reason(payload):
    code, out, err = run(payload)
    assert code == 0, (code, out, err)
    assert out.strip(), "expected a deny decision, got no output"
    d = json.loads(out)["hookSpecificOutput"]
    assert d["hookEventName"] == "PreToolUse" and d["permissionDecision"] == "deny", d
    return d["permissionDecisionReason"]


class Passes(unittest.TestCase):
    def assertPasses(self, payload):
        code, out, err = run(payload)
        self.assertEqual((code, out, err), (0, "", ""))

    def test_single_select_both_markers_on_one_option(self):
        self.assertPasses(hook_input(q([f"Pin the version {RT} {REC}", "Float the version"])))

    def test_single_select_markers_on_different_options(self):
        self.assertPasses(hook_input(q([f"Run it now {REC}", f"Back up first {RT}", "Skip it"])))

    def test_single_select_no_recommended_right_thing_first(self):
        self.assertPasses(hook_input(q([f"staging database {RT}", "production database"])))

    def test_multi_select_valid(self):
        self.assertPasses(hook_input(q([f"Lint {RT} {REC}", f"Type-check {RT}", "Format"], multi=True)))

    def test_multi_select_two_options_may_all_be_marked(self):
        self.assertPasses(hook_input(q([f"Lint {RT} {REC}", f"Type-check {RT}"], multi=True)))

    def test_several_valid_questions(self):
        self.assertPasses(hook_input(q([f"A {RT} {REC}", "B"]), q([f"C {RT}", "D"])))

    def test_trailing_whitespace_in_label(self):
        self.assertPasses(hook_input(q([f"Pin it {RT} {REC}  ", "Float it"])))

    def test_other_tools_are_ignored(self):
        self.assertPasses(hook_input(q(["no markers", "at all"]), tool="Bash"))

    def test_fail_open_on_garbage(self):
        for raw in ("", "not json", "[]", "null", '{"tool_name": "AskUserQuestion"}',
                    '{"tool_name": "AskUserQuestion", "tool_input": {"questions": "x"}}',
                    '{"tool_name": "AskUserQuestion", "tool_input": {"questions": [{"options": 5}]}}',
                    '{"tool_name": "AskUserQuestion", "tool_input": {"questions": [{"options": [{"label": 7}]}]}}'):
            with self.subTest(raw=raw):
                self.assertPasses(raw)


class Denies(unittest.TestCase):
    def test_no_right_thing_single(self):
        r = deny_reason(hook_input(q([f"Run it {REC}", "Skip it"])))
        self.assertIn("Q1", r)
        self.assertIn(RT, r)

    def test_two_right_things_single(self):
        r = deny_reason(hook_input(q([f"Run it {RT} {REC}", f"Back up {RT}", "Skip"])))
        self.assertIn("exactly one", r)

    def test_two_recommended_single(self):
        r = deny_reason(hook_input(q([f"Run it {RT} {REC}", f"Back up {REC}", "Skip"])))
        self.assertIn(REC, r)

    def test_recommended_not_first(self):
        r = deny_reason(hook_input(q([f"Back up {RT}", f"Run it {REC}", "Skip"])))
        self.assertIn("option 1", r)
        self.assertIn(REC, r)

    def test_no_recommended_and_right_thing_not_first(self):
        r = deny_reason(hook_input(q(["production database", f"staging database {RT}"])))
        self.assertIn("option 1", r)
        self.assertIn(RT, r)

    def test_marker_in_the_middle_of_a_label(self):
        r = deny_reason(hook_input(q([f"Run {REC} it now {RT}", "Skip"])))
        self.assertIn("Run", r)

    def test_wrong_marker_order(self):
        r = deny_reason(hook_input(q([f"Pin it {REC} {RT}", "Float it"])))
        self.assertIn("order", r)

    def test_lowercase_marker(self):
        r = deny_reason(hook_input(q([f"Pin it {RT}", "Float it (recommended)"])))
        self.assertIn("Float it (recommended)", r)

    def test_marker_in_question_text(self):
        r = deny_reason(hook_input(q([f"A {RT} {REC}", "B"], question=f"Pick one {REC}?")))
        self.assertIn("question", r)

    def test_marker_in_header(self):
        r = deny_reason(hook_input(q([f"A {RT} {REC}", "B"], header=RT)))
        self.assertIn("header", r)

    def test_marker_in_description(self):
        opts = [{"label": f"A {RT} {REC}", "description": f"This is the {RT} choice."}, {"label": "B", "description": "d"}]
        r = deny_reason(hook_input(q(opts)))
        self.assertIn("description", r)

    def test_multi_select_no_right_thing(self):
        r = deny_reason(hook_input(q([f"Lint {REC}", "Format", "Type-check"], multi=True)))
        self.assertIn("at least one", r)

    def test_multi_select_three_options_all_marked(self):
        r = deny_reason(hook_input(q([f"Lint {RT} {REC}", f"Format {RT}", f"Type-check {REC}"], multi=True)))
        self.assertIn("unmarked", r)

    def test_second_question_named(self):
        r = deny_reason(hook_input(q([f"A {RT} {REC}", "B"]), q(["C", "D"])))
        self.assertIn("Q2", r)
        self.assertNotIn("Q1", r)

    def test_reason_is_short_and_lists_every_problem_on_one_line(self):
        r = deny_reason(hook_input(q(["A", "B"]), q(["C", "D"])))
        self.assertLessEqual(len(r.splitlines()), 3)
        self.assertIn("Q1", r)
        self.assertIn("Q2", r)

    def test_decision_goes_to_stdout_with_empty_stderr(self):
        code, out, err = run(hook_input(q(["A", "B"])))
        self.assertEqual((code, err), (0, ""))
        json.loads(out)


class PluginFiles(unittest.TestCase):
    def test_hooks_json_wires_the_script_to_ask_user_question(self):
        with open(os.path.join(PLUGIN, "hooks", "hooks.json")) as f:
            hooks = json.load(f)["hooks"]["PreToolUse"]
        self.assertEqual([g["matcher"] for g in hooks], ["AskUserQuestion"])
        h = hooks[0]["hooks"][0]
        self.assertEqual(h["type"], "command")
        self.assertIn("${CLAUDE_PLUGIN_ROOT}/scripts/check-ask-markers.py", " ".join([h["command"]] + h.get("args", [])))
        self.assertTrue(os.path.isfile(SCRIPT))


if __name__ == "__main__":
    unittest.main(verbosity=2)
