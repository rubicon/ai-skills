---
name: rubicon-wordpress-version-lab
version: 1.0.0
description: >-
  Use when the user wants to create, list, stop, remove, or troubleshoot
  isolated Docker-only WordPress version test labs on an SSH-reachable host
  (such as a Synology NAS) — older WordPress installs, side-by-side WordPress
  containers, or WordPress/PHP compatibility checks run with docker compose.
  Also use to set or change the saved connection/identity config the skill uses.
---

# Rubicon WordPress Version Lab

Create and manage isolated Docker Compose WordPress test labs on an SSH-reachable host. Each lab is its own Compose project (separate WordPress + MariaDB + WP-CLI containers) on a shared external network, so multiple WordPress versions run side by side.

## First-run configuration

The skill keeps no infrastructure details in its files. Connection and identity values live in a local config outside the repo at `~/.config/rubicon-wp-lab/config.env` (mode 600), managed by `scripts/config_wp_lab.sh`.

On first use, if `config_wp_lab.sh --show` reports no config, gather **SSH host** (an ssh alias or `user@host`) and **access host** (the hostname/IP the user browses to — it becomes the WordPress site URL), then save them:

```bash
scripts/config_wp_lab.sh --set --ssh-host <host> --access-host <host>
```

Optional saved defaults: `--base-parent` (default `/volume1/docker`), `--network` (default `wordpress_lab_default`), `--admin-user` (default `admin`), `--admin-email`, `--tz` (default `UTC`), `--umask` (default `002`). Change any later with another `--set`; inspect with `--show`; remove with `--reset --confirm`.

## Required workflow (create)

1. Ensure config exists (above). Any saved value can be overridden per run with the matching flag.
2. Gather or infer:
   - `--site-name`: short lowercase slug (container/project prefix).
   - `--wp-version`: exact WordPress version, e.g. `6.4.5`, `5.9.10`, `4.9.26`.
   - `--php-version`: pass `auto` to recommend from `references/wordpress-php-compatibility.md`, or set explicitly.
   - `--port`: pass `auto` to find a free port (8080–8999), or set explicitly.
3. Run `scripts/create_wp_lab.sh`. It returns the lab URL, the credentials path on the NAS, and management commands.

## Commands

| Action | Command |
|---|---|
| Configure / reconfigure | `scripts/config_wp_lab.sh --set ...` · `--show` · `--path` · `--reset --confirm` |
| Create a lab | `scripts/create_wp_lab.sh --site-name <slug> --wp-version <ver> [--php-version auto] [--port auto]` |
| List labs | `scripts/list_wp_labs.sh` |
| Stop a lab | `scripts/stop_wp_lab.sh --site-name <slug>` |
| Remove a lab | `scripts/remove_wp_lab.sh --site-name <slug> --confirm` |

`create_wp_lab.sh --help` lists every override flag.

## Safety rules

- Never delete or overwrite an existing lab unless the user explicitly asks. `create` refuses to overwrite an existing `compose.yaml` without `--force`, and backs it up (timestamped) before overwriting.
- `remove` deletes the lab's containers, database, and files; it requires `--confirm`.
- Passwords are generated randomly (unless overridden), transferred inside a private per-run staging directory (never on a command line), and stored only in the lab's `credentials.txt` on the NAS at mode 600.
- Published ports bind to all interfaces on the NAS. Never expose old WordPress labs publicly — warn the user to keep router/firewall rules closed. These are local compatibility labs.
- Treat very old WordPress/PHP combinations as best effort: old official Docker tags may be missing for the host's CPU architecture. Note such deviations as Needs Verification.

## Troubleshooting

Use `references/troubleshooting.md` for config, SSH/Docker access, image-pull, WP-CLI, permission, port, and site-URL issues.
