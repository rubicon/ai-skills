# loadout

Decide which Claude Code plugins and skills a project loads, then prove the change took effect.

`/loadout:audit` reads the project, captures what a fresh session actually loads, and recommends a per-project set in a table you edit. After you approve it, it writes the project's `.claude/settings.local.json` and checks the result against new headless sessions in the project and in an empty directory.

## Install

```bash
/plugin marketplace add rubicon/ai-skills
/plugin install loadout@rubicon
```

Requires `python3` and `claude` on your PATH.

## What it knows that is easy to get wrong

- `skillOverrides` cannot turn off a skill or slash command that comes from a plugin. Only disabling the plugin does.
- A skill override can stop matching because its plugin was disabled. That is not a typo, and the verifier reports it separately.
- Account-synced plugins (`name@synced`) are controlled with `enabledPlugins` like any other.

## Limits

- Each capture starts a headless session. It runs your hooks and is billed.
- Results describe the headless CLI. The desktop app can load account-synced plugins that the settings turn off.
- Only `skillOverrides` `"off"` is verified.

See [skills/audit/SKILL.md](skills/audit/SKILL.md) and [CHANGELOG.md](CHANGELOG.md).
