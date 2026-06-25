#!/usr/bin/env bash
# config_wp_lab.sh — manage the local connection/identity config for the
# rubicon-wordpress-version-lab skill.
#
# The config holds only non-secret infrastructure/identity values (SSH host,
# browse host, base path, network, admin user/email, timezone, umask). It lives
# OUTSIDE the repo at $XDG_CONFIG_HOME/rubicon-wp-lab/config.env (mode 600) so
# nothing personal is ever committed or published.
#
# First-run setup and later edits both go through this one command.
# Written for bash 3.2 (macOS default): no associative arrays.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

usage() {
  cat <<'USAGE'
Usage:
  config_wp_lab.sh --show
  config_wp_lab.sh --path
  config_wp_lab.sh --set [field flags...]
  config_wp_lab.sh --reset --confirm

Set fields (any subset; omitted fields keep their current/default value):
  --ssh-host <host>        SSH target: an ssh alias (e.g. myNAS) or user@host
  --access-host <host>     Host you browse to; used for the WordPress site URL
  --base-parent <path>     Parent dir for labs on the NAS  (default /volume1/docker)
  --network <name>         Shared docker network           (default wordpress_lab_default)
  --admin-user <user>      Default WordPress admin user     (default admin)
  --admin-email <email>    Default WordPress admin email    (default admin@example.com)
  --tz <tz>                Container timezone               (default UTC)
  --umask <octal>          Container UMASK                  (default 002)

Examples:
  config_wp_lab.sh --set --ssh-host myNAS --access-host nas.example.lan
  config_wp_lab.sh --set --access-host 10.0.0.10      # change just the browse host
  config_wp_lab.sh --show
USAGE
}

ACTION=""
CONFIRM="0"
PROVIDED=""   # space-separated list of keys supplied via flags this run

# Record a field override: sets NEW_<KEY> and marks it provided.
want_set() { ACTION="set"; eval "NEW_$1=\$2"; PROVIDED="$PROVIDED $1"; }

[[ $# -eq 0 ]] && { usage; exit 1; }
while [[ $# -gt 0 ]]; do
  case "$1" in
    --show)         ACTION="show"; shift ;;
    --path)         ACTION="path"; shift ;;
    --reset)        ACTION="reset"; shift ;;
    --confirm)      CONFIRM="1"; shift ;;
    --set)          [[ "$ACTION" == "set" ]] || ACTION="set"; shift ;;
    --ssh-host)     want_set SSH_HOST "$2"; shift 2 ;;
    --access-host)  want_set ACCESS_HOST "$2"; shift 2 ;;
    --base-parent)  want_set BASE_PARENT "$2"; shift 2 ;;
    --network)      want_set NETWORK_NAME "$2"; shift 2 ;;
    --admin-user)   want_set ADMIN_USER "$2"; shift 2 ;;
    --admin-email)  want_set ADMIN_EMAIL "$2"; shift 2 ;;
    --tz)           want_set TZ "$2"; shift 2 ;;
    --umask)        want_set UMASK "$2"; shift 2 ;;
    -h|--help)      usage; exit 0 ;;
    *)              wplab_die "Unknown argument: $1" ;;
  esac
done

CONFIG_FILE="$(wplab_config_file)"
eff() { local v="EFF_$1"; printf '%s' "${!v}"; }   # read computed value

case "$ACTION" in
  path)
    echo "$CONFIG_FILE"
    ;;

  show)
    if [[ -f "$CONFIG_FILE" ]]; then
      echo "# $CONFIG_FILE"
      cat "$CONFIG_FILE"
    else
      echo "No config yet at $CONFIG_FILE"
      echo "Create it with: config_wp_lab.sh --set --ssh-host <host> --access-host <host>"
      exit 1
    fi
    ;;

  reset)
    [[ "$CONFIRM" == "1" ]] || wplab_die "Refusing to reset without --confirm."
    rm -f "$CONFIG_FILE"
    echo "Removed $CONFIG_FILE"
    ;;

  set)
    wplab_load_config
    # Effective value per key: new flag > existing config > built-in default.
    for key in $wplab_keys; do
      newvar="NEW_$key"; curvar="CFG_$key"; defvar="wplab_default_$key"
      case " $PROVIDED " in
        *" $key "*) val="${!newvar}" ;;
        *) val="${!curvar}"; [[ -n "$val" ]] || val="${!defvar:-}" ;;
      esac
      eval "EFF_$key=\$val"
    done

    # Validate only non-empty values (SSH/ACCESS may be filled in later).
    for key in SSH_HOST ACCESS_HOST BASE_PARENT NETWORK_NAME ADMIN_USER TZ; do
      v="$(eff "$key")"
      [[ -z "$v" ]] || wplab_valid_token "$v" || wplab_die "$key must not contain whitespace: '$v'"
    done
    v="$(eff ADMIN_EMAIL)"
    [[ -z "$v" ]] || wplab_valid_email "$v" || wplab_die "admin-email does not look like an email: '$v'"
    v="$(eff UMASK)"
    [[ -z "$v" ]] || wplab_valid_umask "$v" || wplab_die "umask must be 3-4 octal digits: '$v'"

    mkdir -p "$(wplab_config_dir)"
    umask 077
    {
      echo "# rubicon-wordpress-version-lab config — non-secret infrastructure/identity only."
      echo "# Managed by config_wp_lab.sh. Mode 600. Never commit this file."
      for key in $wplab_keys; do
        printf '%s=%s\n' "$key" "$(eff "$key")"
      done
    } > "$CONFIG_FILE"
    chmod 600 "$CONFIG_FILE"

    echo "Wrote $CONFIG_FILE"
    [[ -n "$(eff SSH_HOST)" ]]    || echo "Note: SSH_HOST is still empty — set it before creating a lab."
    [[ -n "$(eff ACCESS_HOST)" ]] || echo "Note: ACCESS_HOST is still empty — set it before creating a lab."
    ;;

  *)
    usage; exit 1 ;;
esac
