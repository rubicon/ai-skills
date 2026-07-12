# Architecture

How this repository is laid out and why. This rarely changes; read it once to
orient.

## Purpose

A curated collection of **AI skills** — reusable prompt templates that Claude
Code (and compatible agents such as OpenAI Codex) load on demand — plus Claude
Code **plugins**. It is compatible with
[skillshare](https://github.com/runkids/skillshare).

## Layout

```text
skills/<name>/            # one skill per directory
  SKILL.md                # required — model-facing definition (YAML frontmatter: name, description; SemVer version)
  README.md               # required — human-facing overview + install
  CHANGELOG.md            # required — per-skill history (Keep a Changelog)
  references/ scripts/    # optional — supporting files and tools

plugins/<name>/           # Claude Code plugins (self-contained; no ../ refs)
  .claude-plugin/plugin.json
  README.md  CHANGELOG.md
  skills/ commands/ agents/ scripts/   # optional bundled components

.claude-plugin/marketplace.json   # plugin marketplace manifest (name: rubicon)
scripts/validate-skills.sh        # repo convention checker (structure, frontmatter, SemVer)
.github/workflows/ci.yaml         # CI: structure + gates + PR policy
```

Skills are **directories**, never flat `.md` files — that is what makes them
discoverable by Claude Code's `Skill` tool and by skillshare. Each skill's
`version:` uses full SemVer; the root `CHANGELOG.md` is a one-line-per-skill
summary while per-skill changelogs hold the detail.

## The `identity-theft` skill

The largest skill is worth understanding as a pattern: a **personality-agnostic
engine** plus **data-driven personalities**.

- `SKILL.md` — the engine. It classifies source content into three classes
  (protected / conservatively transformed / freely transformed), voices only
  the eligible prose, and runs a fail-closed validation gate before writing
  output.
- `references/personalities/<id>.md` — one dossier per character, all following
  `references/dossier-contract.md`. Adding a personality is pure data; the
  engine does not change.
- `scripts/validate_output.py` — the structural output gate: protected regions
  must stay byte-identical, links and anchors must be preserved, line endings
  and final-newline state must match. Output that fails is never shipped.
- `scripts/validate_dossier.py` — the roster gate: every dossier must satisfy
  the contract (header fields, required sections, unique ids/suffixes/aliases,
  per-mode examples).

Both scripts are Python standard library only and are exercised by a unittest
suite under `scripts/tests/`, run in CI.

## Conventions

- Issue-first, `dev/<issue>-<slug>` branches, PRs into `main`, no direct pushes.
- Conventional Commits; Keep a Changelog; SemVer.
- CI validates skill/plugin structure, the `identity-theft` gates, and PR
  policy (branch naming, semantic commits).

See [CONTRIBUTING.md](CONTRIBUTING.md) to add a skill or a personality.
