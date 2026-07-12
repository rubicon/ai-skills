import subprocess, sys, tempfile, unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from validate_output import extract_regions, gfm_slug, validate

FIX = Path(__file__).parent / "fixtures" / "sample-readme.md"
SRC = FIX.read_text()
HTML_FIX = Path(__file__).parent / "fixtures" / "sample-fragment.html"
HTML_SRC = HTML_FIX.read_text()


class TestExtraction(unittest.TestCase):
    def test_finds_all_protected_region_types(self):
        types = [t for t, _ in extract_regions(SRC)]
        for expected in ("frontmatter", "fence", "indented", "inline", "comment"):
            self.assertIn(expected, types)

    def test_html_regions(self):
        html = '<script>a</script><style>b</style><textarea>c</textarea><template>d</template><!-- e -->'
        types = [t for t, _ in extract_regions(html)]
        self.assertEqual(types.count("htmlblock"), 4)
        self.assertEqual(types.count("comment"), 1)

    def test_fence_not_closed_by_mismatched_marker(self):
        text = "```\ncode line\n~~~\nstill inside the fence\n```\n"
        regions = extract_regions(text)
        fences = [c for t, c in regions if t == "fence"]
        self.assertEqual(len(fences), 1)
        self.assertIn("still inside the fence", fences[0])


class TestSlug(unittest.TestCase):
    def test_basic(self):
        self.assertEqual(gfm_slug("Install"), "install")

    def test_punctuation_and_spaces(self):
        self.assertEqual(gfm_slug("Q&A: How? Why!"), "qa-how-why")


class TestValidate(unittest.TestCase):
    def test_identical_passes(self):
        self.assertEqual(validate(SRC, SRC), [])

    def test_changed_code_fails(self):
        bad = SRC.replace("widgetsync init", "widgetsync initialize")
        errs = validate(SRC, bad)
        self.assertTrue(any("fence" in e or "inline" in e for e in errs))

    def test_dropped_inline_code_fails(self):
        bad = SRC.replace("`widgetsync --version`", "the version flag")
        self.assertTrue(validate(SRC, bad))

    def test_changed_frontmatter_fails(self):
        bad = SRC.replace("version: 2.3.1", "version: 9.9.9")
        self.assertTrue(any("frontmatter" in e for e in errs2) if (errs2 := validate(SRC, bad)) else False)

    def test_renamed_heading_with_repaired_anchor_passes(self):
        good = SRC.replace("## Install", "## How to Acquire This Tool").replace(
            "(#install)", "(#how-to-acquire-this-tool)")
        self.assertEqual(validate(SRC, good), [])

    def test_renamed_heading_with_broken_anchor_fails(self):
        bad = SRC.replace("## Install", "## How to Acquire This Tool")
        self.assertTrue(any("anchor" in e for e in validate(SRC, bad)))

    def test_changed_external_url_fails(self):
        bad = SRC.replace("docs/usage.md#basics", "docs/help.md#basics")
        self.assertTrue(any("link" in e for e in validate(SRC, bad)))

    def test_final_newline_mismatch_fails(self):
        self.assertTrue(any("newline" in e for e in validate(SRC, SRC.rstrip("\n"))))

    def test_deleted_same_document_link_fails(self):
        bad = SRC.replace("[Install](#install)", "Install")
        self.assertTrue(validate(SRC, bad))

    def test_retargeted_same_document_link_fails(self):
        bad = SRC.replace("[Install](#install)", "[Install](#usage)")
        self.assertTrue(validate(SRC, bad))

    def test_added_preamble_blockquote_passes(self):
        with_preamble = SRC.replace("\n# WidgetSync", "\n> I was told to hand you this document.\n\n# WidgetSync")
        self.assertEqual(validate(SRC, with_preamble), [])


class TestHtmlStructure(unittest.TestCase):
    def test_identical_html_passes(self):
        self.assertEqual(validate(HTML_SRC, HTML_SRC), [])

    def test_changed_pre_code_content_fails(self):
        bad = HTML_SRC.replace("widgetsync init", "widgetsync destroy")
        self.assertTrue(validate(HTML_SRC, bad))

    def test_changed_attribute_value_fails(self):
        bad = HTML_SRC.replace('alt="WidgetSync logo"', 'alt="Evil logo"')
        self.assertTrue(validate(HTML_SRC, bad))

    def test_html_text_node_change_passes(self):
        good = HTML_SRC.replace(
            "It synchronizes your configuration files.",
            "This gizmo keeps your configs in lockstep, friend.")
        self.assertEqual(validate(HTML_SRC, good), [])

    def test_inserted_preamble_blockquote_passes(self):
        # HTML document: the engine inserts the preamble as the first child of
        # <body> as a <blockquote>, and voices the <p> prose. Spec-compliant.
        src = ('<html><body><h1>WidgetSync</h1><p>Welcome to it.</p>'
               '<pre><code>widgetsync init</code></pre></body></html>')
        out = ('<html><body><blockquote>Here it is.</blockquote>'
               '<h1>WidgetSync</h1><p>This is the tool.</p>'
               '<pre><code>widgetsync init</code></pre></body></html>')
        self.assertEqual(validate(src, out), [])

    def test_inserted_preamble_fragment_passes(self):
        # HTML fragment (no <body>): the engine prepends the preamble
        # <blockquote> before the first convertible node and voices text nodes.
        src = '<h1 id="top">WidgetSync</h1><p>Welcome to it.</p>'
        out = ('<blockquote>Here it is.</blockquote>'
               '<h1 id="top">WidgetSync</h1><p>This gizmo rocks, friend.</p>')
        self.assertEqual(validate(src, out), [])

    def test_non_preamble_injected_tag_fails(self):
        # A single leading preamble blockquote is tolerated, but a SECOND
        # injected non-preamble tag (a wrapping <div>) must still fail: the
        # fix must not become a blanket "ignore added tags."
        src = '<h1 id="top">WidgetSync</h1><p>Welcome to it.</p>'
        bad = ('<blockquote>Here it is.</blockquote>'
               '<h1 id="top">WidgetSync</h1><div><p>Welcome to it.</p></div>')
        self.assertTrue(validate(src, bad))


class TestCli(unittest.TestCase):
    def test_cli_pass_and_fail(self):
        script = Path(__file__).resolve().parents[1] / "validate_output.py"
        ok = subprocess.run([sys.executable, str(script), str(FIX), str(FIX)], capture_output=True)
        self.assertEqual(ok.returncode, 0)

    def test_cli_crlf_source_lf_output_fails(self):
        script = Path(__file__).resolve().parents[1] / "validate_output.py"
        body = "# Title\n\nHello world.\n"
        with tempfile.TemporaryDirectory() as d:
            src = Path(d) / "src.md"
            out = Path(d) / "out.md"
            src.write_bytes(body.replace("\n", "\r\n").encode("utf-8"))
            out.write_bytes(body.encode("utf-8"))
            res = subprocess.run(
                [sys.executable, str(script), str(src), str(out)],
                capture_output=True, text=True)
        self.assertNotEqual(res.returncode, 0)
        self.assertIn("line-ending", res.stdout)


if __name__ == "__main__":
    unittest.main()
