#!/usr/bin/env bash
# list_wp_labs.sh — list WordPress labs created by this skill on the NAS.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
wplab_load_config

SSH_HOST="${CFG_SSH_HOST}"
BASE_PARENT="${CFG_BASE_PARENT:-$wplab_default_BASE_PARENT}"
NETWORK_NAME="${CFG_NETWORK_NAME:-$wplab_default_NETWORK_NAME}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ssh-host)    SSH_HOST="$2"; shift 2 ;;
    --base-parent) BASE_PARENT="$2"; shift 2 ;;
    -h|--help)     echo "Usage: list_wp_labs.sh [--ssh-host <host>] [--base-parent <path>]"; exit 0 ;;
    *)             wplab_die "Unknown argument: $1" ;;
  esac
done

[[ -n "$SSH_HOST" ]] || wplab_die "No SSH host configured. Run: config_wp_lab.sh --set --ssh-host <host> --access-host <host>"

ssh "$SSH_HOST" "find '$BASE_PARENT' -maxdepth 3 -name compose.yaml -path '*/config/compose.yaml' -print 2>/dev/null | sort | while read -r f; do d=\$(dirname \"\$f\"); if grep -q '$NETWORK_NAME' \"\$f\"; then echo \"\$d\"; fi; done"
