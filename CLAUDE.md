# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

**Global preferences** (identity, communication style, tools, standards, workflow) are defined in `~/.claude/CLAUDE.md` and apply here. This file adds only repo-specific instructions on top of those.

## Repository Purpose

A curated collection of AI skill prompt files for use with Claude Code (and other AI assistants). Skills are structured prompt templates that Claude Code loads on demand via the `Skill` tool to provide specialized, repeatable behaviors.

This repo is compatible with [skillshare](https://github.com/runkids/skillshare), a CLI tool for managing and syncing skills across AI agents.

The canonical repository is public on GitHub at `github.com/rubicon/ai-skills`; a private archive of the pre-migration history is retained on Forgejo. Everything in this repository is public. Skills that cannot be published live in the separate private repository `ai-skills-private`, which is its own repo and not part of this one.

## Structure

```text
skills/
├── secret-santa-generator/
│   ├── SKILL.md
│   ├── README.md
│   └── CHANGELOG.md
└── <skill-name>/
    ├── SKILL.md          # required — the skill definition (model-facing)
    ├── README.md         # required — human-facing overview + install
    ├── CHANGELOG.md      # required — per-skill version history
    └── references/       # optional — supporting files
plugins/
└── <plugin-name>/                       # Claude Code plugin (self-contained)
    ├── .claude-plugin/plugin.json       # required — manifest (SemVer version)
    ├── README.md                        # required
    ├── CHANGELOG.md                     # required — Keep a Changelog
    └── skills/ commands/ agents/ scripts/   # optional plugin components
.claude-plugin/
└── marketplace.json      # plugin marketplace manifest (name: rubicon)
README.md
CHANGELOG.md
CLAUDE.md
```

Each skill is a **directory** inside `skills/` containing a `SKILL.md` file, plus a `README.md` and `CHANGELOG.md` (see Skill File Conventions). This structure satisfies both Claude Code's `Skill` tool and the skillshare CLI. Flat `.md` files in `skills/` are not recognized by skillshare and should not be used.

Claude Code **plugins** live in their own independent tree under `plugins/`, listed in the repo-root `.claude-plugin/marketplace.json`. Plugins are self-contained (no `../` references), so a plugin's bundled skills/agents/scripts live inside the plugin, not in the top-level `skills/`. See the Plugin Structure Rule in `docs/process/ai-skills-repo-overlay.md`.

## Skill File Conventions

- One skill per directory; directory name must be kebab-case (e.g., `secret-santa-generator/`).
- The skill definition lives at `skills/<skill-name>/SKILL.md` — skillshare requires exactly this filename.
- Each `SKILL.md` must begin with YAML frontmatter including at minimum `name` and `description`:

```yaml
---
name: skill-name
description: >-
  One-line (or multi-line) description used by Claude to decide when to
  invoke this skill. Include trigger phrases here.
---
```

- Optional frontmatter fields: `author`, `version`, `targets` (e.g., `[claude, cursor]`). The `version` field uses full **SemVer** (`MAJOR.MINOR.PATCH`, e.g. `1.0.0`).
- Write skill content in plain Markdown. Use headers, bullet lists, and code blocks as needed.
- Keep skills focused on a single task or workflow. Split if a skill grows unwieldy.
- Every skill directory also contains a **`README.md`** (thin, human-facing: a one-line description, the skillshare install command, and links to `SKILL.md` and `CHANGELOG.md` — do not duplicate `SKILL.md`'s behavioral content) and a **`CHANGELOG.md`** ([Keep a Changelog](https://keepachangelog.com/) form; its latest version heading matches the `version:` in `SKILL.md`).

## Documentation & Changelogs

**Root `README.md`** — when adding a new skill, add a row to the skills table:

```markdown
| [skill-name](skills/skill-name/SKILL.md) | One-line description |
```

**Per-skill `README.md`** — a thin, human-facing stub: a one-line description, the skillshare install command, and links to `SKILL.md` and `CHANGELOG.md`. Keep behavior in `SKILL.md`; do not copy it into the README.

**Per-skill `CHANGELOG.md`** — the detailed version history for that skill, in [Keep a Changelog](https://keepachangelog.com/) form. Its latest version heading matches the `version:` field in the skill's `SKILL.md`.

**Root `CHANGELOG.md`** — a short, repo-level summary only: one line per skill added/changed/removed. The per-skill changelog holds the detail; do not duplicate it at the root.

## Adding a Skill

1. Create or reference an issue; note the issue number.
2. Create branch: `dev/<issue-number>-<short-kebab-description>`
3. Create `skills/<skill-name>/SKILL.md` with valid YAML frontmatter (`name` + `description` required; `version` in SemVer).
4. Add `skills/<skill-name>/README.md` (thin stub) and `skills/<skill-name>/CHANGELOG.md` (initial version entry).
5. Update the skills table in root `README.md` and add a one-line summary to root `CHANGELOG.md`.
6. Commit with `feat:` prefix; open a PR on GitHub.

**Pre-merge checklist:**

- [ ] Skill lives at `skills/<skill-name>/SKILL.md` (directory, not flat file)
- [ ] YAML frontmatter is valid and includes `name` and `description`; `version` is SemVer (`MAJOR.MINOR.PATCH`)
- [ ] Skill directory has `README.md` and `CHANGELOG.md`
- [ ] Root `README.md` skills table updated; root `CHANGELOG.md` has a one-line summary

## Adding a Plugin

1. Create or reference an issue; note the issue number.
2. Create branch: `dev/<issue-number>-<short-kebab-description>`
3. Create `plugins/<plugin-name>/.claude-plugin/plugin.json` (`name` required; `version` in SemVer when present).
4. Add `plugins/<plugin-name>/README.md` and `plugins/<plugin-name>/CHANGELOG.md` (Keep a Changelog). Bundled skills/commands/agents/scripts live inside the plugin (self-contained — no `../`).
5. Append the plugin to `.claude-plugin/marketplace.json`: `{ "name": "<plugin-name>", "source": "./plugins/<plugin-name>" }`.
6. Add a one-line summary to root `CHANGELOG.md`.
7. Run `bash scripts/validate-skills.sh`; commit with `feat:` prefix; open a PR on GitHub.

See the Plugin Structure Rule in `docs/process/ai-skills-repo-overlay.md` for the full convention.

## Process Policy

This repo follows the general repository process policy. Repo-specific rules are in `docs/process/ai-skills-repo-overlay.md`.

Key points:

- Issue → `dev/<issue-number>-<short-kebab-description>` branch → PR → merge. No direct pushes to `main`.
- Semantic commit prefixes: `feat:`, `fix:`, `docs:`, `chore:`.
- Update `CHANGELOG.md` before tagging a release.
- Create GitHub releases only when public skill content changes. Releases should reflect skill additions, updates, or removals that affect end users.

## Git Hosting

Canonical host is GitHub — `origin` is `git@github.com:rubicon/ai-skills.git` (SSH; commit signing via the 1Password SSH agent). `main` is protected: PRs only, required CI checks, signed commits, linear history, no force-push. Ask before committing or pushing.

Issues and PRs use the GitHub `gh` CLI:

```bash
gh issue create -t "<plain descriptive title>" -b "<body>"
gh pr create --base main --head dev/<n>-<slug> -t "<conventional-commits title>" -b "<body>"
```

A private archive of the pre-migration history lives on Forgejo (`git.daxdavis.com`); it is a backup only, not the working host. Anything local you do not want published goes in `CLAUDE.local.md` (git-ignored) — do not put personal or machine-specific notes in this committed file.

Migration record: `docs/runbooks/github-migration.md`.
