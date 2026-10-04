# Rubicon AI Skills

A collection of AI skill prompts for Claude Code and other AI assistants.

Compatible with [skillshare](https://github.com/runkids/skillshare) — a CLI for managing and syncing skills across AI agents.

## Usage

### Claude Code

Skills are loaded on demand via the `Skill` tool. Each skill lives at `skills/<skill-name>/SKILL.md`.

**A skill in this repository is not available to Claude Code until it is installed.** Claude Code
loads skills from `~/.claude/skills/` (personal) and `<project>/.claude/skills/` (project) — not
from this repository's top-level `skills/` directory, which is the layout skillshare expects.
Install with the commands below, then start a new session.

### skillshare CLI

```bash
# Install all skills (tracked — stays updatable)
skillshare install github.com/rubicon/ai-skills --track

# Install one skill
skillshare install github.com/rubicon/ai-skills -s relocate-session

# Install several (-s accepts a comma-separated list)
skillshare install github.com/rubicon/ai-skills -s cache-money,codebase-memory

# Every skill published here
skillshare install github.com/rubicon/ai-skills -s cache-money,codebase-memory,goalpost,grand-tour,identity-theft,relocate-session,rubicon-wordpress-version-lab,second-look,secret-santa-generator,showdown,work-evidence-research
```

## Skills

| Skill | Description |
|-------|-------------|
| [secret-santa-generator](skills/secret-santa-generator/SKILL.md) | Generate secret Santa gift exchange assignments |
| [work-evidence-research](skills/work-evidence-research/SKILL.md) | Forensic, source-grounded research for reconstructing work history and client proof from connected files (discovery, targeted verification, final assembly) |
| [rubicon-wordpress-version-lab](skills/rubicon-wordpress-version-lab/SKILL.md) | Create and manage isolated Docker-only WordPress version test labs on an SSH-reachable host (e.g. a Synology NAS) via docker compose |
| [identity-theft](skills/identity-theft/SKILL.md) | Steals fictional identities, not personal data — rewrites your text, Markdown, or HTML in a character's voice (Ron Swanson, Yoda, pirate, and 48 more) while code, links, and facts survive untouched |
| [cache-money](skills/cache-money/SKILL.md) | Keep Claude Code sessions cheap and sharp — session hygiene, `CLAUDE.md` discipline, native auto-compaction controls, model selection, and context-cost habits |
| [codebase-memory](skills/codebase-memory/SKILL.md) | Query a codebase knowledge graph via MCP instead of grep — callers, impact radius, architecture, dead code, and tiered evidence standards |
| [relocate-session](skills/relocate-session/SKILL.md) | Move a session or a whole project directory to a new path without silently orphaning auto-memory — carries it across, verifies it, and reports what stays behind |
| [second-look](skills/second-look/SKILL.md) | An intent-first review by a fresh agent — checks the change against what you finally asked for, including later changes and deferrals, then runs the bug hunt |
| [grand-tour](skills/grand-tour/SKILL.md) | An onboarding tour of a codebase — what it is, its main parts, one real flow traced through the code, the traps a newcomer hits, and where to start |
| [goalpost](skills/goalpost/SKILL.md) | Write a Claude Code `/goal` line a long unattended run can finish — observable outcome, evidence shown in the conversation, constraints, and an escape clause so an impossible goal stops instead of looping |
| [showdown](skills/showdown/SKILL.md) | Put two or three genuinely different approaches head to head on the same terms, pick one argued from the goal, and name what would flip it — a decision, not a plan |

## Plugins

Install from this repository's marketplace (`rubicon`):

```bash
/plugin marketplace add rubicon/ai-skills
/plugin install <plugin-name>@rubicon
```

| Plugin | Description |
|--------|-------------|
| [salience](plugins/salience/README.md) | Executive presence system for LinkedIn — profile intelligence, positioning, voice, content, relationships, executive career search, and consulting development, behind one entry point and a verified-fact ledger |
| [backup-before-troubleshooting](plugins/backup-before-troubleshooting/README.md) | Stand up a dated, self-documenting recovery workspace before changing system, app, or config state |
| [session-messaging](plugins/session-messaging/README.md) | Cross-session messaging for Claude Code Desktop — how sessions message each other and report their own address |
| [pitstop](plugins/pitstop/README.md) | Save what a compact or clear would destroy, then rebuild status after it, with a verified handoff |
| [loadout](plugins/loadout/README.md) | Audit which plugins and skills a project loads, recommend a per-project set, apply it after approval, and verify it from fresh sessions |
| [rubicon-marketing-board](https://github.com/rubicon/rubicon-marketing-board) | A nine-seat marketing advisory board for Claude Code (external source) |


## Contributing

Contributions are welcome — especially new **personalities** for the
[identity-theft](skills/identity-theft/SKILL.md) skill, which is the easiest way
to contribute (one self-contained file). See [CONTRIBUTING.md](CONTRIBUTING.md)
to get started, and [ARCHITECTURE.md](ARCHITECTURE.md) for how the repo is laid
out. By participating you agree to the [Code of Conduct](CODE_OF_CONDUCT.md).

![Contributors](https://contrib.rocks/image?repo=rubicon/ai-skills)
