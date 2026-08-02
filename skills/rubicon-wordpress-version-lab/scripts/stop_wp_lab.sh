#!/usr/bin/env bash
# stop_wp_lab.sh — stop a lab's containers (data and config are preserved).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
wplab_load_config

SSH_HOST="${CFG_SSH_HOST}"
BASE_PARENT="${CFG_BASE_PARENT:-$wplab_default_BASE_PARENT}"
SITE_NAME=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ssh-host)    SSH_HOST="$2"; shift 2 ;;
    --base-parent) BASE_PARENT="$2"; shift 2 ;;
    --site-name)   SITE_NAME="$2"; shift 2 ;;
    -h|--help)     echo "Usage: stop_wp_lab.sh --site-name <slug> [--ssh-host <host>]"; exit 0 ;;
    *)             wplab_die "Unknown argument: $1" ;;
  esac
done

[[ -n "$SITE_NAME" ]] || wplab_die "Missing --site-name."
wplab_valid_site_name "$SITE_NAME" || wplab_die "Invalid --site-name."
[[ -n "$SSH_HOST" ]] || wplab_die "No SSH host configured. Run config_wp_lab.sh --set ..."

PROJECT_NAME="${SITE_NAME//-/_}"
REMOTE_DIR="${BASE_PARENT}/${SITE_NAME}/config"
ssh "$SSH_HOST" "export PATH=/usr/local/bin:/usr/local/sbin:\$PATH; cd '$REMOTE_DIR' && docker compose -p '$PROJECT_NAME' stop"
