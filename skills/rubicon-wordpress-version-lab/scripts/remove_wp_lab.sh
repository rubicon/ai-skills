#!/usr/bin/env bash
# remove_wp_lab.sh — tear down a lab: stop containers AND delete its directory
# (compose, .env, credentials, database, and WordPress files). Irreversible.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
wplab_load_config

SSH_HOST="${CFG_SSH_HOST}"
BASE_PARENT="${CFG_BASE_PARENT:-$wplab_default_BASE_PARENT}"
SITE_NAME=""
CONFIRM="0"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ssh-host)    SSH_HOST="$2"; shift 2 ;;
    --base-parent) BASE_PARENT="$2"; shift 2 ;;
    --site-name)   SITE_NAME="$2"; shift 2 ;;
    --confirm)     CONFIRM="1"; shift ;;
    -h|--help)     echo "Usage: remove_wp_lab.sh --site-name <slug> --confirm [--ssh-host <host>]"; exit 0 ;;
    *)             wplab_die "Unknown argument: $1" ;;
  esac
done

[[ -n "$SITE_NAME" ]] || wplab_die "Missing --site-name."
wplab_valid_site_name "$SITE_NAME" || wplab_die "Invalid --site-name."
[[ "$CONFIRM" == "1" ]] || wplab_die "Refusing to remove without --confirm."
[[ -n "$SSH_HOST" ]] || wplab_die "No SSH host configured. Run config_wp_lab.sh --set ..."

PROJECT_NAME="${SITE_NAME//-/_}"
REMOTE_PARENT="${BASE_PARENT}/${SITE_NAME}"
REMOTE_DIR="${REMOTE_PARENT}/config"

# Bind-mounted db/wordpress files are owned by the containers' internal UIDs
# (mysql, www-data), so the SSH user can't rm them directly. Delete the lab's
# contents from inside a throwaway root container, then remove the now-empty dir.
# The busybox rm must succeed (errors are NOT suppressed) before the dir is removed.
ssh "$SSH_HOST" "export PATH=/usr/local/bin:/usr/local/sbin:\$PATH; \
{ cd '$REMOTE_DIR' 2>/dev/null && docker compose -p '$PROJECT_NAME' down -v; } ; \
docker run --rm -v '$REMOTE_PARENT':/target busybox rm -rf /target/config && rmdir '$REMOTE_PARENT'"
echo "Removed lab '$SITE_NAME' and its directory $REMOTE_PARENT"
