# Changelog — rubicon-wordpress-version-lab

All notable changes to this skill are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
The version tracks the `version:` field in `SKILL.md`.

## [Unreleased]

## [1.0.0] — 2026-06-20
- Initial release: create, list, stop, remove, and configure Docker-only WordPress version labs on an SSH-reachable host via `docker compose`. Verified end-to-end on a Synology NAS (DSM 7).
- Public, config-driven design: connection/identity values live in a local `~/.config/rubicon-wp-lab/config.env` (mode 600) managed by `config_wp_lab.sh`; no personal infrastructure is committed.
- Auto PHP recommendation from `references/wordpress-php-compatibility.md`; auto port selection (8080–8999).
- Secret handling: per-lab passwords generated locally, transferred inside a private per-run staging directory (never on a command line), stored only in each lab's `credentials.txt` at mode 600.
- Synology compatibility (found during live verification): `mariadb:10.5` (10.6+ wedges on old NAS kernels via io_uring fallback to synchronous I/O); `/usr/local/bin` prepended to PATH for remote Docker; `scp -O` for transfer (Synology's SFTP subsystem is restricted); teardown deletes container-owned bind-mount files via a throwaway root container.
- Remote preflight checks Docker access; ownership fix-up is non-fatal when the SSH user lacks root.
