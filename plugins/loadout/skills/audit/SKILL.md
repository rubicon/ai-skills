---
name: audit
description: Use when deciding which Claude Code plugins and skills a project should load, when sessions carry skills for unrelated domains or duplicate copies of the same skill, or when an enabledPlugins or skillOverrides change seems to have had no effect.
version: 0.1.0
---

# loadout audit

Decide which plugins and skills this project loads, get approval, apply it, and prove it from fresh sessions.

Default posture: plugins are lean. A short core set is on globally, anything domain-specific is off globally and turned on per project. If the user states a different policy, follow theirs.

**Write no settings before the user approves the tables in step 3.** Steps 1 to 3 do start headless sessions, which run the user's hooks and are billed; say so before the first one. Hooks may write their own files, such as a memory folder, in the directory a session starts in.

## How the levers work

Verified on Claude Code 2.1.289 with headless `claude -p`:

| Item | Lever that works | Lever that does nothing |
|---|---|---|
| Plugin, including `name@synced` | `enabledPlugins` `"name@source": true/false` in `.claude/settings.local.json` overrides the user file in both directions | |
| Skill inside a plugin (`plugin:skill`) | Disable the whole plugin | `skillOverrides`: plugin skills are always on |
| Slash command inside a plugin | Disable the whole plugin | `skillOverrides` |
| Standalone skill (`~/.claude/skills`, project `.claude/skills`) | `skillOverrides` `"name": "off"` | |
| Account-synced skill (`prefix:name` with no matching plugin, such as `anthropic-skills:docx`) | `skillOverrides` `"prefix:name": "off"` | |

Only `"off"` is verified. Write only the project's `.claude/settings.local.json`: it is per machine and normally git-ignored, so the result does not follow the repo to other clones.

## Script

`S="${CLAUDE_PLUGIN_ROOT}/scripts/loadout.py"`. Run it as `python3 "$S" ...`. `--help` lists the subcommands. Exit 1 from `verify` means findings, not a broken tool.

Keep snapshots in a temporary work directory `W=$(mktemp -d)`. Each empty-directory capture gets its own new directory from `mktemp -d`, because hooks can leave files in one. Never paste a snapshot into the conversation; read the script's JSON.

## 1. Understand the project

`<root>` below is the project root. Read its `CLAUDE.md` files, README, and manifests (`package.json`, `pyproject.toml`, and so on). Note the stack and the kind of work: code, content, design, ops. Note anything the project's docs say it needs.

From `~/.claude/settings.json`, `.claude/settings.json`, and `.claude/settings.local.json` read only `enabledPlugins` and `skillOverrides`, with python, printing only those keys.

## 2. Capture what loads

```bash
python3 "$S" capture "<root>" --out "$W/before.json"
python3 "$S" capture "$(mktemp -d)" --out "$W/empty-before.json"
python3 "$S" inventory "$W/before.json" --skills-dir ~/.claude/skills --skills-dir "<root>/.claude/skills"
```

The empty-directory snapshot is the global baseline. Ignore `@builtin` plugins.

## 3. Recommend, then stop

Present exactly these three tables, then stop and wait for approval or edits.

**Plugins**, one row per loaded plugin plus each plugin you recommend changing: `Plugin key | Now | Recommend | Reason | Notes`

**Skills**, grouped by the inventory's source groups: `Skill | Source | Recommend | Lever | Reason | Notes`

`Lever` is required in every skill row. Take it from the skill's inventory group, never from the shape of its name: a standalone directory can be named `x:y`. It is one of:

- `skillOverrides`: standalone or account-synced skills only.
- `plugin`: any skill from a plugin. If its plugin stays on, the skill stays on; recommend `on (plugin)` or move the decision to the plugin row. Never write a `skillOverrides` entry for it.
- `none`: the inventory's `unlocated` group (usually built into Claude Code), or anything else no setting can turn off.

**Existing overrides**, one row per `skillOverrides` key already in any settings file: `Key | File | Result | Meaning`. Get the results from the existing-overrides check below.

Rules for the recommendation:

- Before recommending a plugin on, check that any program it needs (a language server, a CLI) is on PATH; if not, say so in Notes and mark `Confirm`.
- Judge by the project's real stack and work. Recommend off for unrelated domains. For a duplicate the project needs, keep exactly one copy, preferring the copy whose lever lets the others go off; a duplicate the project does not need goes off in every copy.
- Keep general workflow skills (debugging, planning, verification, review).
- Never recommend turning off what the project's docs say they need.
- When unsure, still give a value and write `Confirm` in Notes.
- Existing overrides: run the step 5 `verify` command with `before.json` as both `--before` and `--after`, and `empty-before.json` as both `--empty-before` and `--empty-after`. Put each result in the Existing overrides table. `not-found` is a probable typo. `no-effect-plugin-skill` and `no-effect-plugin-command` do nothing. `plugin-off-unverifiable` cannot be checked while its plugin is off; it is not a typo.

## 4. Apply, after approval

1. Back up `.claude/settings.local.json` to `.claude/settings.local.json.bak-<YYYYMMDD-HHMMSS>` if it exists, and give the user the path.
2. Merge the approved keys into it with python, keeping every existing key except ones the user approved removing (such as a typo). Names exactly as loaded, no wildcards.
   If the user approves a change no lever can make, such as a `skillOverrides` entry for a plugin skill, do not write it. Say why, and offer the plugin-level choice instead.
3. Validate the JSON by loading it back.
4. Name any plugin slash commands that stay because their plugin stays on.

Edit `~/.claude/settings.json` only if the user explicitly asks. Then back it up first and prove every key other than `enabledPlugins` and `skillOverrides` is unchanged by comparing against the backup.

## 5. Verify from fresh sessions

```bash
python3 "$S" capture "<root>" --out "$W/after.json"
python3 "$S" capture "$(mktemp -d)" --out "$W/empty-after.json"
python3 "$S" verify --before "$W/before.json" --after "$W/after.json" \
  --empty-before "$W/empty-before.json" --empty-after "$W/empty-after.json" \
  --user ~/.claude/settings.json --project "<root>/.claude/settings.json" \
  --local "<root>/.claude/settings.local.json" \
  --skills-dir ~/.claude/skills --skills-dir "<root>/.claude/skills"
```

Report the counts, `missing` and `unexpected` for the project and the empty directory (all four must be empty), and every override with its result. Findings in the user file (`"fails": false`) do not fail a project audit; list them separately as something the user may want to fix. If anything fails, find the cause in the settings files and fix it or report it. Only `verify` output counts as success, never the written file. The current session keeps its old set; changes apply to new sessions.

## Limits

- Snapshots come from the headless CLI. The Claude desktop app has been seen loading account-synced (`@synced`) plugins that are set `false` in `~/.claude/settings.json`, so the desktop set can differ. Say so when the user works in the desktop app.
- An override for a skill whose plugin is off everywhere cannot be proven correct until the plugin loads.
- User commands in `~/.claude/commands` are outside this audit.
