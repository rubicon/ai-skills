# Right Stuff

Ask the user for a decision through the AskUserQuestion pop-up with two judgments marked on the option labels: `(Recommended)` for the option the agent would choose, and `(Right Thing)` for the option a careful senior expert would choose even when it is slower or costlier. See [SKILL.md](SKILL.md) for the rules.

## Install

```bash
skillshare install github.com/rubicon/ai-skills -s right-stuff
```

## Optional always-on line

The skill loads when an agent decides to ask. In testing, the description alone loaded it before every pop-up in a clean setup, but not reliably in a crowded one, and it never helps an agent that runs an ordered risky step without asking. One line in your global instructions file (for Claude Code, `CLAUDE.md`) covers both:

```text
Before every AskUserQuestion call, and before any production deploy, deletion, force-push, or other destructive or outward-facing step, invoke the `right-stuff` skill and follow it.
```

## Changelog

See [CHANGELOG.md](CHANGELOG.md).
