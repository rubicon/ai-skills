# Relocate Session

Move a Claude Code session — or a whole project directory — to a new path without silently
orphaning auto-memory, which is keyed to the old working-directory path. Copies memory across
without overwriting, verifies the result, and reports what stays behind. See
[SKILL.md](SKILL.md) for the full procedure and trigger conditions.

## Install

```bash
skillshare install github.com/rubicon/ai-skills -s relocate-session
```

## Changelog

See [CHANGELOG.md](CHANGELOG.md).
