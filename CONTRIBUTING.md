# Contributing to Rubicon AI Skills

Thanks for your interest. This repository is a curated collection of AI skills
(reusable prompt templates for Claude Code and compatible agents) and Claude
Code plugins. The most common contribution is a **new personality** for the
[`identity-theft`](skills/identity-theft/) skill, and this guide leads with that.

## Ways to contribute

- **Add a personality** to `identity-theft` (most common — see below).
- Fix a bug in a skill's tooling or docs.
- Improve an existing skill.
- Propose a new skill (open an issue first to discuss scope).

## Propose a personality (identity-theft)

`identity-theft` converts text, Markdown, or HTML into a fictional character's
voice while protecting code, commands, links, and facts. Each personality is a
single dossier file. Adding one is self-contained.

1. **Open an issue** using the "Propose a personality" template so we can agree
   the character is a good fit before you write it.
2. **Fork** and branch: `dev/<issue-number>-add-<personality-id>`.
3. **Read the contract:**
   [`skills/identity-theft/references/dossier-contract.md`](skills/identity-theft/references/dossier-contract.md).
   It defines the required YAML header and sections exactly; the roster
   validator enforces them.
4. **Write the dossier** at
   `skills/identity-theft/references/personalities/<id>.md`. Study an existing
   one — [`ron-swanson.md`](skills/identity-theft/references/personalities/ron-swanson.md)
   is the depth exemplar. Capture the character through concrete speech-pattern
   rules, vocabulary, and structures — not a bag of adjectives.
5. **Validate locally:**
   ```bash
   python3 skills/identity-theft/scripts/validate_dossier.py \
     skills/identity-theft/references/personalities/
   ```
6. **Open a PR.** CI runs the roster gate and the output-gate test suite
   automatically.

### Hard rules for personalities

- **No copyrighted dialogue.** Do not copy canonical quotes or catchphrases
  into the dossier or its examples. Capture the character's *style* as abstract
  structures; write all examples yourself. This keeps the collection legally
  clean and, in practice, makes the output better (catchphrase banks produce
  repetitive, lifeless conversions).
- **Facts are sacred.** A personality changes *tone*, never *content*. It must
  not invent claims, alter instructions, or make code/commands unfollowable.
- **Anti-caricature.** Give signature tics explicit per-document caps. Clarity
  always wins over voice.
- **Keep it publishable.** No slurs, no targeting real individuals or groups,
  no written profanity (implied intensity is fine).

## General process

This repo follows an issue-first, PR-based workflow:

- **Open an issue** before non-trivial work.
- Branch as `dev/<issue-number>-<short-kebab-description>`.
- Use [Conventional Commits](https://www.conventionalcommits.org/) for commit
  and PR titles: `feat:`, `fix:`, `docs:`, `chore:`, `test:`, `ci:`, `refactor:`.
- Reference the issue in the PR body (`Closes #123`).
- All CI checks must pass. No direct pushes to `main`.
- See [ARCHITECTURE.md](ARCHITECTURE.md) for how the repository is laid out.

## Skill structure

Every skill is a directory under `skills/<name>/` containing `SKILL.md`
(the model-facing definition, with `name` + `description` frontmatter and a
SemVer `version`), `README.md`, and `CHANGELOG.md`. Run
`bash scripts/validate-skills.sh` to check structure before opening a PR.

## Questions

See [SUPPORT.md](SUPPORT.md). To report a security issue, see
[SECURITY.md](SECURITY.md).
