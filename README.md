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
| [identity-theft](skills/identity-theft/SKILL.md) | Steals fictional identities, not personal data — rewrites your text, Markdown, or HTML in a character's voice (Ron Swanson, Yoda, pirate, and 48 more) while code, links, and facts survive untouched |

## Contributing

Contributions are welcome — especially new **personalities** for the
[identity-theft](skills/identity-theft/SKILL.md) skill, which is the easiest way
to contribute (one self-contained file). See [CONTRIBUTING.md](CONTRIBUTING.md)
to get started, and [ARCHITECTURE.md](ARCHITECTURE.md) for how the repo is laid
out. By participating you agree to the [Code of Conduct](CODE_OF_CONDUCT.md).

![Contributors](https://contrib.rocks/image?repo=rubicon/ai-skills)
