# Changelog

All notable changes to the identity-theft skill are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [0.1.0] - 2026-07-11

### Added

- Personality-agnostic conversion engine (`SKILL.md`): classifies source into
  protected / conservative / free content, transforms prose in a selected
  character's voice, and preserves format, code, links, anchors, quotes, and
  facts.
- Fifty-one personalities, one dossier each under `references/personalities/`:
  Ron Swanson, Yoda, Pirate Captain, Shakespeare, Julius Caesar, Darth Vader,
  and 45 more drawn from film, television, books, history, archetypes, and
  fictional AIs (Deadpool through Marvin the Paranoid Android). Every dossier
  passes the roster gate, a structural spot-check conversion, and a 14-point
  voice rubric.
- Codex/ChatGPT compatibility: the skill directory works as-is when installed
  under `~/.agents/skills/` (OpenAI's documented skill format shares the
  `SKILL.md` name/description contract).
- Ron Swanson's three modes: The Full Swanson (default), Brief & Blunt, and
  Duke Silver.
- Structural output gate (`scripts/validate_output.py`): every conversion is
  written to a temp file and validated (protected regions, link classes,
  same-document anchors, line endings, final-newline state) before the sibling
  file is created; failed output is never shipped.
- Dossier roster gate (`scripts/validate_dossier.py`): validates each
  personality dossier against the contract in `references/dossier-contract.md`.
