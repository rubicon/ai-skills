# Rubicon WordPress Version Lab

Create and manage isolated Docker-only WordPress version test labs on an SSH-reachable host (e.g. a Synology NAS) via `docker compose`. See [SKILL.md](SKILL.md) for the full behavior and trigger phrases.

## Configure first

Connection/identity values are stored locally (outside the repo), not committed:

```bash
scripts/config_wp_lab.sh --set --ssh-host <host> --access-host <host>
```

See [config.example.env](config.example.env) for all keys.

## Install

```bash
skillshare install github.com/rubicon/ai-skills -s rubicon-wordpress-version-lab
```

## Changelog

See [CHANGELOG.md](CHANGELOG.md).
