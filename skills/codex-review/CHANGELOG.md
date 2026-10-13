# Changelog — codex-review

All notable changes to this skill are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
The version tracks the `version:` field in `SKILL.md`.

## [1.1.0](https://github.com/rubicon/ai-skills/compare/codex-review-v1.0.0...codex-review-v1.1.0) (2026-10-13)


### Features

* add codex-review, an independent review with the Codex CLI ([#140](https://github.com/rubicon/ai-skills/issues/140)) ([154794a](https://github.com/rubicon/ai-skills/commit/154794a2583a7afcf2769cf4384326b9f6758240))

## [1.0.0] — 2026-10-12

### Added

- Independent code review with the Codex CLI. Covers the `codex review` scope flags (`--base`, `--uncommitted`, `--commit`) and why none of them accepts a custom prompt, which was confirmed on codex-cli 0.162.1.
- What a bare prompt does, and that `--title` is used only with `--commit`.
- A preflight for a missing CLI or login that still allows `CODEX_API_KEY` and non-OpenAI providers.
- Checks before the first run: data leaving for the model provider, the review's sandbox, a git-ignored report folder, and the base branch.
- Timestamped reports with `pipefail`, a background run, and `AGENTS.md` for persistent guidance, plus advisory-only reporting.
- Adapted from the codex-review skill in jezweb/claude-skills (https://github.com/jezweb/claude-skills/blob/1260fa7439b36b18dbf16648ccc7fb44783f6c23/plugins/dev-tools/skills/codex-review/SKILL.md, MIT, Copyright (c) 2025 Jeremy Dawes (Jezweb)). The skill README lists what is shared with the original and what is new.
