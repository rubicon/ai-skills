# Changelog — cache-money

All notable changes to this skill are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
The version tracks the `version:` field in `SKILL.md`.

## [1.1.1](https://github.com/rubicon/ai-skills/compare/cache-money-v1.1.0...cache-money-v1.1.1) (2026-08-24)


### Bug Fixes

* restore canonical contents overwritten by mirror snapshot, port cache-money ([#7](https://github.com/rubicon/ai-skills/issues/7)) ([4c32275](https://github.com/rubicon/ai-skills/commit/4c32275c02459353e56f7ee365e7f1f166284b97)), closes [#6](https://github.com/rubicon/ai-skills/issues/6)

## [Unreleased]

## [1.1.0] — 2026-08-05
### Added
- Native `/autocompact [auto|<tokens>]` command (Claude Code v2.1.221+), `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE`, and `CLAUDE_CODE_AUTO_COMPACT_WINDOW` as ways to move auto-compaction earlier without watching `/context` manually
- Guidance to set a `# Compact instructions` section in the project's root `CLAUDE.md` so every compaction (manual or automatic) applies preservation rules automatically
- Note that `/cache-money` is already a manual slash command once the skill is installed, no plugin/commands needed

### Fixed
- Corrected the Tier 1 claim that a connected MCP server always loads ~17,600 tokens/message regardless of use — Tool Search now defers most tool definitions by default, so only actually-used servers carry that cost; repeated the same fix in the Common Mistakes table

## [1.0.0] — 2026-07-31
- Initial release: 18 Claude Code token/context-management practices across three tiers
  (session hygiene, project-level hygiene, advanced cost control), sourced from the AI
  Automation Society "18 Token Management Hacks" deck.
