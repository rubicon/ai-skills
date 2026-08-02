#!/usr/bin/env python3
"""Structural output gate for the identity-theft skill.

Usage: validate_output.py SOURCE_FILE OUTPUT_FILE
Exit 0 = pass. Exit 1 = fail, with a per-region report on stdout.

Guarantees STRUCTURAL invariants only: protected regions (type, order,
count, exact contents), link classes, same-document anchor resolution,
line-ending style, and final-newline state. Factual integrity and voice
quality are review-enforced, not script-enforced.

Documented limits (v0.1.0): recognizes CommonMark/GFM fenced and indented
code, inline code spans, a single leading YAML frontmatter block, HTML
comments, <script>/<style>/<textarea>/<template> contents, inline Markdown
link destinations, reference-style definitions, autolinks, bare http(s)
URLs, and HTML href/src. The GFM slug function is vendored because no
stdlib implementation exists.
"""
import re
import sys
from html.parser import HTMLParser
from pathlib import Path

HTML_PROTECTED_TEXT = ("pre", "code", "kbd", "samp")

FRONTMATTER_RE = re.compile(r"\A---\n.*?\n---[ \t]*\n", re.S)
FENCE_RE = re.compile(r"^(```|~~~)[^\n]*\n.*?\n\1[ \t]*$", re.S | re.M)
HTMLBLOCK_RE = re.compile(r"<(script|style|textarea|template)\b[^>]*>.*?</\1>", re.S | re.I)
COMMENT_RE = re.compile(r"<!--.*?-->", re.S)
INLINE_CODE_RE = re.compile(r"(?<!`)(`+)(?!`)(.+?)(?<!`)\1(?!`)", re.S)
INDENTED_RE = re.compile(r"(?:^\n)((?:^(?: {4}|\t)[^\n]*\n?)+)", re.M)
INLINE_LINK_RE = re.compile(r"\]\(\s*(<[^>]*>|[^)\s]+)(?:\s+\"[^\"]*\")?\s*\)")
REF_DEF_RE = re.compile(r"^\[[^\]]+\]:\s*(\S+)", re.M)
AUTOLINK_RE = re.compile(r"<(https?://[^>\s]+)>")
BARE_URL_RE = re.compile(r"(?<![(<\"'])\bhttps?://[^\s)\]>\"']+")
HREF_SRC_RE = re.compile(r"\b(?:href|src)\s*=\s*[\"']([^\"']+)[\"']", re.I)
HEADING_RE = re.compile(r"^#{1,6}[ \t]+(.+?)[ \t]*#*[ \t]*$", re.M)


class _StructureParser(HTMLParser):
    """Collect an HTML structural signature: the ordered sequence of tags with
    their attributes, plus the verbatim text/entities inside protected elements
    (<pre>/<code>/<kbd>/<samp>). Text nodes outside protected elements are voice
    -eligible and deliberately excluded, so prose may change but tags, attribute
    values, and protected-element contents may not."""

    def __init__(self):
        super().__init__(convert_charrefs=False)
        self.events = []
        self._protect_depth = 0

    def handle_starttag(self, tag, attrs):
        self.events.append(("tag", tag, tuple(attrs)))
        if tag in HTML_PROTECTED_TEXT:
            self._protect_depth += 1

    def handle_startendtag(self, tag, attrs):
        self.events.append(("void", tag, tuple(attrs)))

    def handle_endtag(self, tag):
        self.events.append(("endtag", tag))
        if tag in HTML_PROTECTED_TEXT and self._protect_depth > 0:
            self._protect_depth -= 1

    def handle_data(self, data):
        if self._protect_depth:
            self.events.append(("data", data))

    def handle_entityref(self, name):
        if self._protect_depth:
            self.events.append(("entref", name))

    def handle_charref(self, name):
        if self._protect_depth:
            self.events.append(("charref", name))


def html_signature(text):
    """Ordered structural signature of any HTML present in text. Markdown with
    no raw HTML yields an empty (or tag-free) signature, so this check is inert
    for pure Markdown and only bites when tags/attributes/protected contents
    change."""
    parser = _StructureParser()
    parser.feed(text)
    parser.close()
    return parser.events


def _strip_leading_preamble_blockquote(src_sig, out_sig):
    """Tolerate the one <blockquote> preamble the engine is required to insert.

    SKILL.md mandates a preamble rendered as a <blockquote>, placed as the first
    child of <body> (HTML documents) or before the first convertible node (HTML
    fragments). That inserted element legitimately makes the output tag sequence
    differ from the source. If out_sig differs from src_sig only by a single,
    balanced <blockquote>...</blockquote> element at the first point of
    divergence, return out_sig with exactly that element removed; otherwise
    return out_sig unchanged (so genuinely altered structure still fails).

    Deliberately narrow: strips at most ONE element, only when it is a
    blockquote opening at the divergence point, honoring nested blockquotes to
    find its matching close. Arbitrary added tags, non-blockquote insertions,
    injected tags elsewhere, or a second added element are left in place and
    still fail the structure check."""
    i = 0
    n = min(len(src_sig), len(out_sig))
    while i < n and src_sig[i] == out_sig[i]:
        i += 1
    if i >= len(out_sig):
        return out_sig
    if out_sig[i][0] != "tag" or out_sig[i][1] != "blockquote":
        return out_sig
    depth = 0
    for j in range(i, len(out_sig)):
        ev = out_sig[j]
        if ev[0] == "tag" and ev[1] == "blockquote":
            depth += 1
        elif ev[0] == "endtag" and ev[1] == "blockquote":
            depth -= 1
            if depth == 0:
                return out_sig[:i] + out_sig[j + 1:]
    return out_sig


def _blank(m):
    return "\x00" * len(m.group(0))


def extract_regions(text):
    """Ordered (type, content) protected regions; returns list of tuples."""
    regions = []
    work = text
    for kind, rx in (("frontmatter", FRONTMATTER_RE), ("fence", FENCE_RE),
                     ("htmlblock", HTMLBLOCK_RE), ("comment", COMMENT_RE)):
        for m in rx.finditer(work):
            regions.append((m.start(), kind, m.group(0)))
        work = rx.sub(_blank, work)
    for m in INDENTED_RE.finditer(work):
        regions.append((m.start(1), "indented", m.group(1)))
    work = INDENTED_RE.sub(lambda m: m.group(0).replace(m.group(1), "\x00" * len(m.group(1))), work)
    for m in INLINE_CODE_RE.finditer(work):
        regions.append((m.start(), "inline", m.group(2)))
    regions.sort(key=lambda r: r[0])
    return [(kind, content) for _, kind, content in regions]


def _masked(text):
    """Text with protected regions blanked, for link/heading scanning."""
    work = text
    for rx in (FRONTMATTER_RE, FENCE_RE, HTMLBLOCK_RE, COMMENT_RE):
        work = rx.sub(_blank, work)
    work = INDENTED_RE.sub(lambda m: m.group(0).replace(m.group(1), "\x00" * len(m.group(1))), work)
    work = INLINE_CODE_RE.sub(_blank, work)
    return work


def extract_links(text):
    """(externals, fragments) from masked text. Fragments are same-doc '#x'."""
    work = _masked(text)
    dests = []
    for m in INLINE_LINK_RE.finditer(work):
        dests.append(m.group(1).strip("<>"))
    dests += REF_DEF_RE.findall(work) + AUTOLINK_RE.findall(work)
    dests += BARE_URL_RE.findall(work) + HREF_SRC_RE.findall(work)
    fragments = [d for d in dests if d.startswith("#")]
    externals = [d for d in dests if not d.startswith("#")]
    return externals, fragments


def gfm_slug(text):
    """GitHub-compatible heading slug (vendored; no stdlib alternative)."""
    text = re.sub(r"[!-/:-@\[-`{-~]", lambda m: m.group(0) if m.group(0) in "-_" else "", text.lower())
    return text.strip().replace(" ", "-")


def heading_slugs(text):
    seen, slugs = {}, set()
    for m in HEADING_RE.finditer(_masked(text)):
        base = gfm_slug(m.group(1))
        n = seen.get(base, 0)
        seen[base] = n + 1
        slugs.add(base if n == 0 else f"{base}-{n}")
    for m in re.finditer(r"\bid\s*=\s*[\"']([^\"']+)[\"']", text, re.I):
        slugs.add(m.group(1))
    return slugs


def validate(source_text, output_text):
    errors = []
    src, out = extract_regions(source_text), extract_regions(output_text)
    if len(src) != len(out):
        errors.append(f"region count mismatch: source has {len(src)} protected regions, output has {len(out)}")
    for i, (s, o) in enumerate(zip(src, out)):
        if s != o:
            errors.append(
                f"protected region mismatch at occurrence {i + 1}: "
                f"expected {s[0]} {s[1][:60]!r}, found {o[0]} {o[1][:60]!r}")
    src_sig, out_sig = html_signature(source_text), html_signature(output_text)
    if src_sig != out_sig:
        out_sig = _strip_leading_preamble_blockquote(src_sig, out_sig)
    if src_sig != out_sig:
        for i, (s, o) in enumerate(zip(src_sig, out_sig)):
            if s != o:
                errors.append(
                    f"HTML structure/protected-content mismatch at node {i + 1}: "
                    f"expected {s!r}, found {o!r}")
                break
        else:
            errors.append(
                f"HTML node count mismatch: source has {len(src_sig)} "
                f"structural nodes, output has {len(out_sig)}")
    src_ext, src_frag = extract_links(source_text)
    out_ext, out_frag = extract_links(output_text)
    missing = list(src_ext)
    for d in out_ext:
        if d in missing:
            missing.remove(d)
    for d in missing:
        errors.append(f"link destination missing or altered: {d!r}")
    slugs = heading_slugs(output_text)
    for frag in out_frag:
        if frag[1:] not in slugs:
            errors.append(f"unresolved same-document anchor: {frag!r}")
    if len(src_frag) != len(out_frag):
        errors.append(
            f"same-document link count changed: source has {len(src_frag)}, "
            f"output has {len(out_frag)} (fragments may change only to repair a "
            f"renamed heading's anchor)")
    remaining = list(out_frag)
    for frag in src_frag:
        if frag in remaining:
            remaining.remove(frag)
        elif frag[1:] in slugs:
            errors.append(
                f"same-document link retargeted or dropped without anchor "
                f"repair: {frag!r} still resolves in output but is no longer "
                f"linked")
    if ("\r\n" in source_text) != ("\r\n" in output_text):
        errors.append("line-ending style changed between source and output")
    if source_text.endswith("\n") != output_text.endswith("\n"):
        errors.append("final-newline state changed between source and output")
    return errors


def main(argv):
    if len(argv) != 3:
        print(__doc__)
        return 2
    # Read bytes and decode without newline translation: Path.read_text() uses
    # universal-newline mode, which silently rewrites CRLF to LF and would make
    # the line-ending check in validate() blind to a real CRLF source file.
    source = Path(argv[1]).read_bytes().decode("utf-8")
    output = Path(argv[2]).read_bytes().decode("utf-8")
    errors = validate(source, output)
    if errors:
        print(f"FAIL: {len(errors)} structural violation(s):")
        for e in errors:
            print(f"  - {e}")
        return 1
    print("PASS: structural invariants hold")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
