#!/usr/bin/env bash
# common.sh — shared helpers for the rubicon-wordpress-version-lab scripts.
# This file is sourced, never executed directly.
#
# It loads the local, out-of-repo config (identity/infrastructure only — never
# secrets) and exposes validation helpers. Personal values live at
# $XDG_CONFIG_HOME/rubicon-wp-lab/config.env (default ~/.config/...), mode 600.

# --- Config location -------------------------------------------------------

wplab_config_dir()  { printf '%s/rubicon-wp-lab' "${XDG_CONFIG_HOME:-$HOME/.config}"; }
wplab_config_file() { printf '%s/config.env' "$(wplab_config_dir)"; }

# Recognised config keys. SSH_HOST and ACCESS_HOST have no safe default and are
# therefore required before a lab can be created.
wplab_keys="SSH_HOST ACCESS_HOST BASE_PARENT NETWORK_NAME ADMIN_USER ADMIN_EMAIL TZ UMASK"

# Built-in defaults for keys that have a sensible generic value.
wplab_default_BASE_PARENT="/volume1/docker"
wplab_default_NETWORK_NAME="wordpress_lab_default"
wplab_default_ADMIN_USER="admin"
wplab_default_ADMIN_EMAIL="admin@example.com"
wplab_default_TZ="UTC"
wplab_default_UMASK="002"

# --- Config loading --------------------------------------------------------

# Populate CFG_<KEY> for every recognised key. Unset keys become empty strings.
# Parses KEY=value lines (no code execution); strips surrounding quotes and CR.
wplab_load_config() {
  local f key val line
  f="$(wplab_config_file)"
  for key in $wplab_keys; do eval "CFG_$key=''"; done
  [[ -f "$f" ]] || return 0
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"
    [[ "$line" =~ ^[[:space:]]*(#|$) ]] && continue
    [[ "$line" =~ ^([A-Z_]+)=(.*)$ ]] || continue
    key="${BASH_REMATCH[1]}"; val="${BASH_REMATCH[2]}"
    [[ "$val" =~ ^\"(.*)\"$ ]] && val="${BASH_REMATCH[1]}"
    [[ "$val" =~ ^\'(.*)\'$ ]] && val="${BASH_REMATCH[1]}"
    case " $wplab_keys " in *" $key "*) eval "CFG_$key=\$val" ;; esac
  done < "$f"
}

# --- Validation ------------------------------------------------------------

wplab_die() { echo "Error: $*" >&2; exit 1; }

wplab_valid_site_name() { [[ "$1" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]]; }
wplab_valid_wp_version() { [[ "$1" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]; }
wplab_valid_php_version() { [[ "$1" =~ ^[0-9]+\.[0-9]+$ ]]; }
wplab_valid_port() { [[ "$1" =~ ^[0-9]+$ ]] && (( $1 >= 1 && $1 <= 65535 )); }
wplab_valid_token() { [[ -n "$1" && "$1" != *[[:space:]]* ]]; }  # no whitespace
wplab_valid_email() { [[ "$1" == *@*.* && "$1" != *[[:space:]]* ]]; }
wplab_valid_umask() { [[ "$1" =~ ^[0-7]{3,4}$ ]]; }
