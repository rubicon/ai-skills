import json
import subprocess
import sys
import unittest
from collections import Counter
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SCRIPTS))
import draw  # noqa: E402

DRAW = SCRIPTS / "draw.py"


def valid(result, people, exclusions=(), no_mutual_pairs=False):
    pairs = {a["giver"]: a["recipient"] for a in result["assignments"]}
    if sorted(pairs) != sorted(people) or sorted(pairs.values()) != sorted(people):
        return False
    banned = {frozenset(p) for p in exclusions}
    for giver, recipient in pairs.items():
        if giver == recipient or frozenset((giver, recipient)) in banned:
            return False
        if no_mutual_pairs and pairs[recipient] == giver:
            return False
    return True


def key(result):
    return tuple(sorted((a["giver"], a["recipient"]) for a in result["assignments"]))


class TestValidDraws(unittest.TestCase):
    def test_simple_draw_is_valid(self):
        people = ["Alice", "Bob", "Carol", "Dave"]
        result = draw.run({"participants": people, "exclusions": [["Bob", "Carol"]]})
        self.assertEqual(result["status"], "ok")
        self.assertTrue(valid(result, people, [("Bob", "Carol")]))

    def test_two_people_without_rules_is_a_mutual_pair(self):
        result = draw.run({"participants": ["Alice", "Bob"]})
        self.assertEqual(result["status"], "ok")
        self.assertTrue(valid(result, ["Alice", "Bob"]))

    def test_summary_counts(self):
        result = draw.run({"participants": ["A", "B", "C", "D"], "exclusions": [["A", "B"]]})
        self.assertEqual(result["summary"]["participants"], 4)
        self.assertEqual(result["summary"]["pairings"], 4)
        self.assertEqual(result["summary"]["exclusions"], 1)
        self.assertFalse(result["summary"]["no_mutual_pairs"])

    def test_no_mutual_pairs_draws_never_contain_a_two_cycle(self):
        people = ["A", "B", "C", "D", "E", "F"]
        for seed in range(200):
            result = draw.run({"participants": people, "no_mutual_pairs": True, "seed": seed})
            self.assertEqual(result["status"], "ok")
            self.assertTrue(valid(result, people, no_mutual_pairs=True))

    def test_exclusion_names_match_case_insensitively(self):
        people = ["Alice", "Bob", "Carol", "Dave"]
        result = draw.run({"participants": people, "exclusions": [[" alice ", "BOB"]]})
        self.assertEqual(result["status"], "ok")
        self.assertTrue(valid(result, people, [("Alice", "Bob")]))


class TestUniformity(unittest.TestCase):
    def assert_uniform(self, people, expected, draws, **options):
        counts = Counter()
        for seed in range(draws):
            result = draw.run({"participants": people, "seed": seed, **options})
            self.assertEqual(result["status"], "ok")
            counts[key(result)] += 1
        self.assertEqual(len(counts), expected)
        mean = draws / expected
        for n in counts.values():
            self.assertGreater(n, mean * 0.75)
            self.assertLess(n, mean * 1.25)

    def test_four_people_all_nine_derangements(self):
        self.assert_uniform(["A", "B", "C", "D"], 9, 9000)

    def test_four_people_no_mutual_pairs_six_cycles(self):
        self.assert_uniform(["A", "B", "C", "D"], 6, 6000, no_mutual_pairs=True)

    def test_five_people_no_mutual_pairs_twenty_four(self):
        self.assert_uniform(["A", "B", "C", "D", "E"], 24, 12000, no_mutual_pairs=True)

    def test_three_people_no_mutual_pairs_two(self):
        self.assert_uniform(["A", "B", "C"], 2, 2000, no_mutual_pairs=True)


class TestImpossible(unittest.TestCase):
    def test_two_people_excluded(self):
        result = draw.run({"participants": ["A", "B"], "exclusions": [["A", "B"]]})
        self.assertEqual(result["status"], "impossible")
        self.assertIn("reason", result)

    def test_two_people_no_mutual_pairs(self):
        result = draw.run({"participants": ["A", "B"], "no_mutual_pairs": True})
        self.assertEqual(result["status"], "impossible")

    def test_person_excluded_from_everyone(self):
        result = draw.run({"participants": ["A", "B", "C"], "exclusions": [["A", "B"], ["A", "C"]]})
        self.assertEqual(result["status"], "impossible")

    def test_matching_exists_but_only_as_mutual_pairs(self):
        # Only valid assignments are A<->B and C<->D.
        people = ["A", "B", "C", "D"]
        exclusions = [["A", "C"], ["A", "D"], ["B", "C"], ["B", "D"]]
        self.assertEqual(draw.run({"participants": people, "exclusions": exclusions})["status"], "ok")
        result = draw.run({"participants": people, "exclusions": exclusions, "no_mutual_pairs": True})
        self.assertEqual(result["status"], "impossible")

    def test_three_people_with_one_exclusion(self):
        # Three people can only form a 3-cycle, and every 3-cycle uses A-C.
        for mode in (False, True):
            result = draw.run({"participants": ["A", "B", "C"], "exclusions": [["A", "C"]], "no_mutual_pairs": mode})
            self.assertEqual(result["status"], "impossible")


class TestTooConstrained(unittest.TestCase):
    def test_reports_instead_of_returning_a_biased_draw(self):
        saved = draw.MAX_TRIES
        draw.MAX_TRIES = 0
        try:
            result = draw.run({"participants": ["A", "B", "C", "D"]})
        finally:
            draw.MAX_TRIES = saved
        self.assertEqual(result["status"], "too_constrained")
        self.assertNotIn("assignments", result)


class TestErrors(unittest.TestCase):
    def assert_error(self, payload, fragment):
        result = draw.run(payload)
        self.assertEqual(result["status"], "error")
        self.assertIn(fragment, result["error"])

    def test_fewer_than_two(self):
        self.assert_error({"participants": ["A"]}, "at least two")

    def test_blank_names_ignored_before_counting(self):
        self.assert_error({"participants": ["A", "  ", ""]}, "at least two")

    def test_duplicates_case_insensitive(self):
        self.assert_error({"participants": ["Alice", "alice ", "Bob"]}, "Duplicate")

    def test_unknown_exclusion_name(self):
        self.assert_error({"participants": ["John", "Sue", "Ann"], "exclusions": [["Jon", "Sue"]]}, "Jon")

    def test_self_exclusion(self):
        self.assert_error({"participants": ["A", "B", "C"], "exclusions": [["A", "a"]]}, "itself")

    def test_exclusion_must_be_a_pair(self):
        self.assert_error({"participants": ["A", "B", "C"], "exclusions": [["A", "B", "C"]]}, "pair")

    def test_participants_required(self):
        self.assert_error({}, "participants")


class TestRandomness(unittest.TestCase):
    def test_without_seed_uses_system_random(self):
        self.assertIsInstance(draw.make_rng(None), draw.random.SystemRandom)

    def test_with_seed_is_reproducible(self):
        payload = {"participants": ["A", "B", "C", "D", "E"], "seed": 7}
        self.assertEqual(key(draw.run(payload)), key(draw.run(payload)))


class TestCli(unittest.TestCase):
    def call(self, payload):
        proc = subprocess.run(
            [sys.executable, str(DRAW)], input=json.dumps(payload),
            capture_output=True, text=True,
        )
        return proc.returncode, json.loads(proc.stdout)

    def test_ok_exit_zero(self):
        code, out = self.call({"participants": ["A", "B", "C"]})
        self.assertEqual((code, out["status"]), (0, "ok"))

    def test_impossible_exit_two(self):
        code, out = self.call({"participants": ["A", "B"], "exclusions": [["A", "B"]]})
        self.assertEqual((code, out["status"]), (2, "impossible"))

    def test_error_exit_one(self):
        code, out = self.call({"participants": ["A"]})
        self.assertEqual((code, out["status"]), (1, "error"))

    def test_bad_json_exit_one(self):
        proc = subprocess.run([sys.executable, str(DRAW)], input="not json", capture_output=True, text=True)
        self.assertEqual(proc.returncode, 1)
        self.assertEqual(json.loads(proc.stdout)["status"], "error")


if __name__ == "__main__":
    unittest.main()
