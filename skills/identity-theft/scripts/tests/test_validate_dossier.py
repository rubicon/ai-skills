import sys, tempfile, unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from validate_dossier import parse_header, check_dossier, check_roster

GOOD = """---
id: test-guy
display_name: Test Guy
suffix: test
default_mode: main
aliases: [test guy, testify]
modes: [main, other]
---

## Identity
A test personality.

## Speech Patterns
- Short sentences.

## Vocabulary
- Says: verily. Never: synergy.

## Riff Themes
- Testing.

## Anti-Patterns
- Hype.

## Preamble
Opens dry.

## Modes
- main (default): full liberty.
- other: restrained.

## Examples

### Example (main)
**Before:** Hello world.
**After:** Hello, world. I suppose.

### Example (other)
**Before:** Hello world.
**After:** Hello.
"""


def write_tmp(dirpath, name, text):
    p = Path(dirpath) / name
    p.write_text(text)
    return p


class TestHeader(unittest.TestCase):
    def test_parses_scalars_and_lists(self):
        h = parse_header(GOOD)
        self.assertEqual(h["id"], "test-guy")
        self.assertEqual(h["aliases"], ["test guy", "testify"])
        self.assertEqual(h["modes"], ["main", "other"])


class TestDossier(unittest.TestCase):
    def test_good_dossier_passes(self):
        with tempfile.TemporaryDirectory() as d:
            self.assertEqual(check_dossier(write_tmp(d, "test-guy.md", GOOD)), [])

    def test_missing_field_fails(self):
        with tempfile.TemporaryDirectory() as d:
            p = write_tmp(d, "t.md", GOOD.replace("suffix: test\n", ""))
            self.assertTrue(any("suffix" in e for e in check_dossier(p)))

    def test_bad_default_mode_fails(self):
        with tempfile.TemporaryDirectory() as d:
            p = write_tmp(d, "t.md", GOOD.replace("default_mode: main", "default_mode: bogus"))
            self.assertTrue(any("default_mode" in e for e in check_dossier(p)))

    def test_missing_section_fails(self):
        with tempfile.TemporaryDirectory() as d:
            p = write_tmp(d, "t.md", GOOD.replace("## Riff Themes\n- Testing.\n\n", ""))
            self.assertTrue(any("Riff Themes" in e for e in check_dossier(p)))

    def test_missing_mode_example_fails(self):
        with tempfile.TemporaryDirectory() as d:
            p = write_tmp(d, "t.md", GOOD.split("### Example (other)")[0])
            self.assertTrue(any("other" in e for e in check_dossier(p)))

    def test_scalar_modes_fails(self):
        with tempfile.TemporaryDirectory() as d:
            p = write_tmp(d, "t.md", GOOD.replace("modes: [main, other]", "modes: fallback")
                          .replace("default_mode: main", "default_mode: fall"))
            self.assertTrue(any("modes" in e and "list" in e for e in check_dossier(p)))

    def test_scalar_aliases_fails(self):
        with tempfile.TemporaryDirectory() as d:
            p = write_tmp(d, "t.md", GOOD.replace("aliases: [test guy, testify]", "aliases: test guy"))
            self.assertTrue(any("aliases" in e for e in check_dossier(p)))


class TestRoster(unittest.TestCase):
    def test_duplicate_suffix_fails(self):
        with tempfile.TemporaryDirectory() as d:
            write_tmp(d, "a.md", GOOD)
            write_tmp(d, "b.md", GOOD.replace("id: test-guy", "id: other-guy")
                      .replace("aliases: [test guy, testify]", "aliases: [other guy]"))
            self.assertTrue(any("suffix" in e for e in check_roster(d)))


if __name__ == "__main__":
    unittest.main()
