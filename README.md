# Rubicon AI Skills

A collection of AI skill prompts for Claude Code and other AI assistants.

Compatible with [skillshare](https://github.com/runkids/skillshare) — a CLI for managing and syncing skills across AI agents.

## Usage

### Claude Code

Skills are loaded on demand via the `Skill` tool. Each skill lives at `skills/<skill-name>/SKILL.md`.

### skillshare CLI

```bash
# Install all skills (tracked — stays updatable)
skillshare install github.com/rubicon/ai-skills --track

# Install specific skills (-s accepts a comma-separated list)
skillshare install github.com/rubicon/ai-skills -s secret-santa-generator
skillshare install github.com/rubicon/ai-skills -s work-evidence-research
skillshare install github.com/rubicon/ai-skills -s rubicon-wordpress-version-lab
```

## Skills

| Skill | Description |
|-------|-------------|
| [secret-santa-generator](skills/secret-santa-generator/SKILL.md) | Generate secret Santa gift exchange assignments |
| [work-evidence-research](skills/work-evidence-research/SKILL.md) | Forensic, source-grounded research for reconstructing work history and client proof from connected files (discovery, targeted verification, final assembly) |
| [rubicon-wordpress-version-lab](skills/rubicon-wordpress-version-lab/SKILL.md) | Create and manage isolated Docker-only WordPress version test labs on an SSH-reachable host (e.g. a Synology NAS) via docker compose |
