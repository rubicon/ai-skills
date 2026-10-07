# ai-skills Repository Overlay

## Purpose

This document applies the general repository process policy to the ai-skills skill collection.

Where this overlay is more specific, this overlay governs. Where it is silent, the general policy governs.

## Canonical Host

GitHub is the canonical host for ai-skills: `github.com/rubicon/ai-skills` (public).

- `origin` points to `git@github.com:rubicon/ai-skills.git`.
- A private archive of the pre-migration history is retained on Forgejo (`git.daxdavis.com`) as a backup only, not a working host. The old force-pushed mirror model is retired; see `docs/runbooks/github-migration.md`.

## Mainline Rule

- No direct pushes to `main`.
- All meaningful work starts with an issue.
- All issue work happens on a `dev/...` branch.
- All merges to `main` happen through GitHub pull requests.

## Branch Naming

Use:

- `dev/<issue-number>-<short-kebab-description>`

Examples for this repository:

- `dev/1-add-code-review-skill`
- `dev/2-add-git-workflow-skill`
- `dev/3-rename-secret-santa-skill`

## Skill Structure Rule

Skills must use the directory-based format:

```text
skills/<skill-name>/SKILL.md        # required — skill definition
skills/<skill-name>/README.md       # required — thin human-facing overview + install
skills/<skill-name>/CHANGELOG.md    # required — per-skill version history (Keep a Changelog)
```

Flat `.md` files directly in `skills/` are not valid — they are invisible to the skillshare CLI and must not be committed.

The `version:` field in `SKILL.md` uses full SemVer (`MAJOR.MINOR.PATCH`). The root `CHANGELOG.md` records short, skill-level summaries; per-skill changelogs hold the detail.

## Plugin Structure Rule

Claude Code plugins use the plugin format and are an independent tree from `skills/`:

```text
plugins/<plugin-name>/.claude-plugin/plugin.json   # required — manifest (name; SemVer version when present)
plugins/<plugin-name>/README.md                    # required — thin human-facing overview + install
plugins/<plugin-name>/CHANGELOG.md                 # required — per-plugin version history (Keep a Changelog)
plugins/<plugin-name>/skills/<skill>/SKILL.md      # optional — bundled skills (self-contained)
plugins/<plugin-name>/commands/<name>.md           # optional — slash commands
```

Plugins must be self-contained: the install cache copies the plugin directory and forbids `../` references outside it, so bundled skills, agents, and scripts live inside the plugin, never in the repo-root `skills/` tree.

Each plugin is listed in the repo-root marketplace manifest `.claude-plugin/marketplace.json` (marketplace name `rubicon`, owner `Rubicon AI`) with a relative source, for example `{ "name": "<plugin-name>", "source": "./plugins/<plugin-name>" }`. The plugin `version` and any bundled skill `version:` use full SemVer. The root `CHANGELOG.md` records short, plugin-level summaries; per-plugin changelogs hold the detail.

## Verification

The baseline check is `bash scripts/validate-skills.sh` (structure + frontmatter + SemVer); it also runs in CI on pull requests via `.github/workflows/ci.yaml`. Before merging a change that adds or modifies a skill, also confirm by hand:

- Confirm the skill lives at `skills/<skill-name>/SKILL.md`, with a `README.md` and `CHANGELOG.md` alongside it.
- Confirm `SKILL.md` has valid YAML frontmatter with `name` and `description`, and a SemVer `version`.
- Confirm the root README skills table and root `CHANGELOG.md` summary are updated when a skill is added or renamed.

## Versioning and Changelogs (release-please)

Every directory under `skills/` and `plugins/` is a release-please package: it has an entry in `release-please-config.json` and in `.release-please-manifest.json`, and `scripts/validate-skills.sh` fails, locally and in CI, when either is missing. release-please bumps the version from Conventional Commits PR titles and writes the release heading into the package's `CHANGELOG.md`, so nobody hand-bumps `version:` in `SKILL.md` or `version` in `plugin.json`. Where this section and Release and Tagging below disagree for a package under release-please (for example, updating `CHANGELOG.md` by hand before tagging), this section governs.

**Changelog rule: a package's `CHANGELOG.md` carries no hand-written `## [Unreleased]` section.**

- Describe an unreleased change in the Conventional Commits title and body of the PR that makes it. release-please turns that into the changelog entry at release time.
- release-please inserts each new release heading above the first `##` or `###` heading that begins with a version number or `[`, and `## [Unreleased]` matches. A hand-written `[Unreleased]` therefore ends up stranded beneath the new release, which already happened in `skills/cache-money/CHANGELOG.md` (1.1.1) and `skills/rubicon-wordpress-version-lab/CHANGELOG.md` (1.0.1).
- Headings written by hand before a package joined release-please (`## [1.0.0] — 2026-09-03`) stay as history. A new package's first entry is written by hand once, at its starting version, and the manifest starts at that same version.
- Do not add new `[Unreleased]` stubs. Delete an existing empty one the next time you edit that file by hand.

## Release and Tagging

This repository does not produce distributable artifacts on the private side. Release discipline applies in simplified form:

- Use `vX.Y.Z` tags for meaningful milestones.
- Release titles use version-only: `X.Y.Z`.
- Product name (for release notes): **Rubicon AI Skills**.
- Release notes begin with: `Rubicon AI Skills vX.Y.Z (YYYY-MM-DD)`.
- Update `CHANGELOG.md` before tagging.
- No release zip or checksum artifact is required.
- Public GitHub releases are appropriate only when public skill content changes.
- Do not cut GitHub releases for private doc-only changes or local workflow updates.

## Trivial Exception

The following may skip issue creation if they do not change skill behavior:

- README typo fixes
- CHANGELOG formatting cleanup
- Frontmatter metadata-only updates (e.g., adding `author` or `version` fields)

All other changes follow the standard branch and PR workflow.
