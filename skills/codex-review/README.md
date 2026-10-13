# Codex Review

Get an independent code review from the Codex CLI with `codex review` invocations that work. See [SKILL.md](SKILL.md) for the commands, the scope-flag constraint, what to check before the first run, and the rules for reporting findings.

## Install

```bash
skillshare install github.com/rubicon/ai-skills -s codex-review
```

## Credits

Adapted from the [codex-review skill](https://github.com/jezweb/claude-skills/blob/1260fa7439b36b18dbf16648ccc7fb44783f6c23/plugins/dev-tools/skills/codex-review/SKILL.md) in jezweb/claude-skills.

- **Shared with the original:** the different-model-family rationale; the intent-to-scope-flag table; the timestamped `tee` report; letting a long review run; the advisory-only and report-what-Codex-said rules; one report per run; keeping reports out of `.claude/`; keeping your own reasoning out of the prompt; and the preflight.
- **New here:** the scope-flag constraint; how a bare prompt behaves; the data and sandbox notes; the git-ignored report folder; the base-branch check; background runs; and the `AGENTS.md` guidance.

The original is licensed as follows:

```text
MIT License

Copyright (c) 2025 Jeremy Dawes (Jezweb)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## Changelog

See [CHANGELOG.md](CHANGELOG.md).
