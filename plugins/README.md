# Plugins

Claude Code plugins hosted by this repository. Each plugin is a self-contained directory
listed in the root `.claude-plugin/marketplace.json` (marketplace name `rubicon`).

## Layout

```text
plugins/<plugin-name>/
  .claude-plugin/plugin.json   # required — manifest (name; version in SemVer when present)
  README.md                    # required — human-facing overview + install
  CHANGELOG.md                 # required — per-plugin version history (Keep a Changelog)
  commands/                    # optional — slash commands (commands/<name>.md)
  skills/<skill>/SKILL.md      # optional — bundled skills (self-contained, not repo-root skills/)
  agents/                      # optional — bundled subagents
  hooks/hooks.json             # optional — hooks
  scripts/                     # optional — helper scripts (ref via ${CLAUDE_PLUGIN_ROOT})
```

Plugins must be self-contained: the install cache copies the plugin directory and forbids
`../` references outside it, so bundled skills/agents/scripts live inside the plugin, never in
the repo-root `skills/` tree.

## Adding a plugin

1. Create `plugins/<plugin-name>/` with `.claude-plugin/plugin.json`, `README.md`, and a
   Keep a Changelog `CHANGELOG.md`.
2. Append an entry to `.claude-plugin/marketplace.json`:
   `{ "name": "<plugin-name>", "source": "./plugins/<plugin-name>" }`.
3. Run `bash scripts/validate-skills.sh`.

See `docs/process/ai-skills-repo-overlay.md` (Plugin Structure Rule) for the full convention.
