# backup-before-troubleshooting

A Claude Code plugin that stands up a dated, self-documenting **recovery workspace** before
you change system, app, or config state — so every change is reversible and the whole effort
can be forensically reconstructed later, including regressions introduced by your own fixes.
Program-agnostic, macOS-first. See the bundled skill
[skills/backup-before-troubleshooting/SKILL.md](skills/backup-before-troubleshooting/SKILL.md)
for the full discipline and trigger phrases.

## Commands

- `/backup-before-troubleshooting:new-recovery-effort` — start a recovery effort (seed a dated folder + docs)
- `/backup-before-troubleshooting:recovery-status` — resume briefing for an in-flight effort
- `/backup-before-troubleshooting:cleanup` — gated, deliberate cleanup of an effort's backups

## Install

```bash
/plugin marketplace add rubicon/ai-skills
/plugin install backup-before-troubleshooting@rubicon
```

## Configuration

Optional. The only setting is `RECOVERY_ROOT` — where recovery workspaces are created
(default `~/Recovery`). See [config.example.env](config.example.env).

## Changelog

See [CHANGELOG.md](CHANGELOG.md).
