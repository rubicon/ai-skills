#!/usr/bin/env bash
# create_wp_lab.sh — create an isolated Docker-only WordPress version lab on an
# SSH-reachable host (e.g. a Synology NAS) via docker compose.
#
# Connection/identity defaults come from the local config (config_wp_lab.sh).
# Any value can be overridden per-run with a flag. Secrets are generated here,
# transferred inside a private per-run staging dir, and never appear on a
# command line.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
REMOTE_SETUP_SRC="$SCRIPT_DIR/remote_setup.sh"

wplab_load_config

# Effective defaults: config value, else built-in default (SSH/ACCESS required).
SSH_HOST="${CFG_SSH_HOST}"
ACCESS_HOST="${CFG_ACCESS_HOST}"
BASE_PARENT="${CFG_BASE_PARENT:-$wplab_default_BASE_PARENT}"
NETWORK_NAME="${CFG_NETWORK_NAME:-$wplab_default_NETWORK_NAME}"
ADMIN_USER="${CFG_ADMIN_USER:-$wplab_default_ADMIN_USER}"
ADMIN_EMAIL="${CFG_ADMIN_EMAIL:-$wplab_default_ADMIN_EMAIL}"
TZ_VALUE="${CFG_TZ:-$wplab_default_TZ}"
UMASK_VALUE="${CFG_UMASK:-$wplab_default_UMASK}"

SITE_NAME=""
WP_VERSION=""
PHP_VERSION="auto"
PORT="auto"
TITLE="WordPress Version Lab"
FORCE="0"

usage() {
  cat <<'USAGE'
Usage:
  create_wp_lab.sh --site-name <slug> --wp-version <version> [options]

Required:
  --site-name <slug>       Lowercase slug; container/project prefix
  --wp-version <version>   Exact WordPress version, e.g. 6.4.5, 5.9.10, 4.9.26

Options:
  --php-version <v|auto>   PHP version (e.g. 8.1) or auto-recommend.  Default: auto
  --port <port|auto>       Published port, or auto-find 8080-8999.    Default: auto
  --ssh-host <host>        Override saved SSH target
  --access-host <host>     Override saved browse host (WordPress site URL)
  --base-parent <path>     Override saved NAS parent dir
  --admin-user <user>      Override saved WordPress admin user
  --admin-email <email>    Override saved WordPress admin email
  --title <title>          WordPress site title.        Default: WordPress Version Lab
  --force                  Back up and overwrite an existing compose.yaml
  -h, --help               Show help

Connection/identity defaults are read from the config managed by
config_wp_lab.sh. Run "config_wp_lab.sh --show" to inspect them.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --site-name)    SITE_NAME="$2"; shift 2 ;;
    --wp-version)   WP_VERSION="$2"; shift 2 ;;
    --php-version)  PHP_VERSION="$2"; shift 2 ;;
    --port)         PORT="$2"; shift 2 ;;
    --ssh-host)     SSH_HOST="$2"; shift 2 ;;
    --access-host)  ACCESS_HOST="$2"; shift 2 ;;
    --base-parent)  BASE_PARENT="$2"; shift 2 ;;
    --admin-user)   ADMIN_USER="$2"; shift 2 ;;
    --admin-email)  ADMIN_EMAIL="$2"; shift 2 ;;
    --title)        TITLE="$2"; shift 2 ;;
    --force)        FORCE="1"; shift ;;
    -h|--help)      usage; exit 0 ;;
    *)              wplab_die "Unknown argument: $1" ;;
  esac
done

# --- Validate inputs -------------------------------------------------------

[[ -n "$SITE_NAME" && -n "$WP_VERSION" ]] || { usage; wplab_die "Missing --site-name or --wp-version."; }
wplab_valid_site_name "$SITE_NAME" \
  || wplab_die "site-name must be lowercase letters, numbers, and hyphens (no leading/trailing hyphen)."
wplab_valid_wp_version "$WP_VERSION" \
  || wplab_die "wp-version must look like 6.4.5 or 5.9."

if [[ -z "$SSH_HOST" || -z "$ACCESS_HOST" ]]; then
  wplab_die "SSH_HOST and ACCESS_HOST are required. Set them once with:
  config_wp_lab.sh --set --ssh-host <host> --access-host <host>
or pass --ssh-host/--access-host for this run."
fi
wplab_valid_token "$SSH_HOST"    || wplab_die "ssh-host must not contain whitespace."
wplab_valid_token "$ACCESS_HOST" || wplab_die "access-host must not contain whitespace."
wplab_valid_email "$ADMIN_EMAIL" || wplab_die "admin-email does not look like an email: '$ADMIN_EMAIL'"

# --- PHP recommendation (matches references/wordpress-php-compatibility.md) --

recommend_php() {
  local major minor rest key
  major="${WP_VERSION%%.*}"; rest="${WP_VERSION#*.}"; minor="${rest%%.*}"
  key=$(( major * 100 + minor ))
  if   (( major >= 7 )); then echo "8.2"   # future-proofing; no WP 7.x today
  elif (( key >= 606 )); then echo "8.2"   # 6.6+
  elif (( key >= 603 )); then echo "8.1"   # 6.3 - 6.5
  elif (( key >= 506 )); then echo "7.4"   # 5.6 - 6.2
  elif (( key >= 502 )); then echo "7.3"   # 5.2 - 5.5
  elif (( key >= 409 )); then echo "7.2"   # 4.9 - 5.1
  elif (( key >= 407 )); then echo "7.1"   # 4.7 - 4.8
  elif (( key >= 404 )); then echo "7.0"   # 4.4 - 4.6
  else                        echo "5.6"   # older than 4.4 (best effort)
  fi
}
[[ "$PHP_VERSION" == "auto" ]] && PHP_VERSION="$(recommend_php)"
wplab_valid_php_version "$PHP_VERSION" || wplab_die "php-version must look like 8.1, 7.4, or auto."

[[ "$PORT" == "auto" ]] || wplab_valid_port "$PORT" || wplab_die "port must be a number 1-65535 or auto."

# --- Derived values --------------------------------------------------------

REMOTE_DIR="${BASE_PARENT}/${SITE_NAME}/config"
PROJECT_NAME="${SITE_NAME//-/_}"
# Random secrets. pipefail is disabled inside the subshell so that tr getting
# SIGPIPE when head closes the pipe does not abort the script under set -e.
rand_token() { set +o pipefail; LC_ALL=C tr -dc "$1" </dev/urandom | head -c "$2"; }
DB_PASSWORD="$(rand_token 'A-Za-z0-9' 24)"
DB_ROOT_PASSWORD="$(rand_token 'A-Za-z0-9' 28)"
ADMIN_PASSWORD="$(rand_token 'A-Za-z0-9!@#%^_+=' 24)"
[[ ${#DB_PASSWORD} -eq 24 && ${#DB_ROOT_PASSWORD} -eq 28 && ${#ADMIN_PASSWORD} -eq 24 ]] \
  || wplab_die "failed to generate random secrets"

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/wplab.XXXXXX")"; chmod 700 "$TMP_DIR"
trap 'rm -rf "$TMP_DIR"' EXIT
COMPOSE_FILE="$TMP_DIR/compose.yaml"
ENV_FILE="$TMP_DIR/.env"
CRED_FILE="$TMP_DIR/credentials.txt"
PARAMS_FILE="$TMP_DIR/params.env"

# --- .env (db secrets + container env; consumed by docker compose) ----------

cat > "$ENV_FILE" <<ENVEOF
TZ=${TZ_VALUE}
UMASK=${UMASK_VALUE}
WORDPRESS_DB_HOST=db:3306
WORDPRESS_DB_NAME=wordpress
WORDPRESS_DB_USER=wordpress
WORDPRESS_DB_PASSWORD=${DB_PASSWORD}
MYSQL_DATABASE=wordpress
MYSQL_USER=wordpress
MYSQL_PASSWORD=${DB_PASSWORD}
MYSQL_ROOT_PASSWORD=${DB_ROOT_PASSWORD}
ENVEOF
chmod 600 "$ENV_FILE"

# --- compose.yaml (port is templated; remote resolves __PORT__) -------------

cat > "$COMPOSE_FILE" <<COMPOSEEOF
services:
  db:
    # MariaDB 10.5 (not 10.6+): 10.6 uses io_uring, which is unavailable on older
    # NAS kernels (e.g. Synology DSM 7 / kernel 4.4) and falls back to slow
    # synchronous I/O — making first-time DB init take ~10 minutes. 10.5 uses
    # libaio and initializes in seconds.
    image: mariadb:10.5
    container_name: ${SITE_NAME}-db
    hostname: ${SITE_NAME}-db
    restart: unless-stopped
    environment:
      MYSQL_DATABASE: \${MYSQL_DATABASE}
      MYSQL_USER: \${MYSQL_USER}
      MYSQL_PASSWORD: \${MYSQL_PASSWORD}
      MYSQL_ROOT_PASSWORD: \${MYSQL_ROOT_PASSWORD}
      TZ: \${TZ}
    volumes:
      - ./db:/var/lib/mysql
      - /etc/localtime:/etc/localtime:ro
    networks:
      - ${NETWORK_NAME}

  wordpress:
    image: wordpress:php${PHP_VERSION}-apache
    container_name: ${SITE_NAME}-wordpress
    hostname: ${SITE_NAME}-wordpress
    restart: unless-stopped
    depends_on:
      - db
    ports:
      - "__PORT__:80"
    environment:
      WORDPRESS_DB_HOST: \${WORDPRESS_DB_HOST}
      WORDPRESS_DB_NAME: \${WORDPRESS_DB_NAME}
      WORDPRESS_DB_USER: \${WORDPRESS_DB_USER}
      WORDPRESS_DB_PASSWORD: \${WORDPRESS_DB_PASSWORD}
      TZ: \${TZ}
      UMASK: \${UMASK}
    volumes:
      - ./wordpress:/var/www/html
      - /etc/localtime:/etc/localtime:ro
    networks:
      - ${NETWORK_NAME}

  wpcli:
    image: wordpress:cli-php${PHP_VERSION}
    container_name: ${SITE_NAME}-wpcli
    hostname: ${SITE_NAME}-wpcli
    depends_on:
      - db
    user: "0:0"
    environment:
      WORDPRESS_DB_HOST: \${WORDPRESS_DB_HOST}
      WORDPRESS_DB_NAME: \${WORDPRESS_DB_NAME}
      WORDPRESS_DB_USER: \${WORDPRESS_DB_USER}
      WORDPRESS_DB_PASSWORD: \${WORDPRESS_DB_PASSWORD}
      TZ: \${TZ}
      UMASK: \${UMASK}
    volumes:
      - ./wordpress:/var/www/html
      - /etc/localtime:/etc/localtime:ro
    networks:
      - ${NETWORK_NAME}

networks:
  ${NETWORK_NAME}:
    external: true
COMPOSEEOF

# --- credentials.txt (port templated; lands on NAS at mode 600) -------------

cat > "$CRED_FILE" <<CREDEOF
WordPress Version Lab
Site name: ${SITE_NAME}
WordPress version: ${WP_VERSION}
PHP version: ${PHP_VERSION}
URL: http://${ACCESS_HOST}:__PORT__
Remote path: ${REMOTE_DIR}
Admin user: ${ADMIN_USER}
Admin password: ${ADMIN_PASSWORD}
Admin email: ${ADMIN_EMAIL}
Database user: wordpress
Database password: ${DB_PASSWORD}
Database root password: ${DB_ROOT_PASSWORD}
CREDEOF
chmod 600 "$CRED_FILE"

# --- params.env (orchestration + admin secret; sourced remotely, %q-safe) ---

{
  printf 'REMOTE_DIR=%q\n'      "$REMOTE_DIR"
  printf 'NETWORK_NAME=%q\n'    "$NETWORK_NAME"
  printf 'FORCE=%q\n'           "$FORCE"
  printf 'PORT=%q\n'            "$PORT"
  printf 'SITE_NAME=%q\n'       "$SITE_NAME"
  printf 'PROJECT_NAME=%q\n'    "$PROJECT_NAME"
  printf 'WP_VERSION=%q\n'      "$WP_VERSION"
  printf 'ADMIN_USER=%q\n'      "$ADMIN_USER"
  printf 'ADMIN_PASSWORD=%q\n'  "$ADMIN_PASSWORD"
  printf 'ADMIN_EMAIL=%q\n'     "$ADMIN_EMAIL"
  printf 'TITLE=%q\n'           "$TITLE"
  printf 'ACCESS_HOST=%q\n'     "$ACCESS_HOST"
  printf 'UMASK=%q\n'           "$UMASK_VALUE"
} > "$PARAMS_FILE"
chmod 600 "$PARAMS_FILE"

# --- Transfer into a private per-run staging dir on the NAS, then run -------

echo "Creating lab '${SITE_NAME}' (WordPress ${WP_VERSION}, PHP ${PHP_VERSION}) on ${SSH_HOST}..."
REMOTE_TMP="$(ssh "$SSH_HOST" 'umask 077; mktemp -d "${TMPDIR:-/tmp}/wplab.XXXXXX"')"
[[ -n "$REMOTE_TMP" ]] || wplab_die "Could not create a remote staging directory."

# -O forces the legacy SCP protocol (over the shell channel). Synology's SFTP
# subsystem is restricted and the default SFTP-mode scp can't reach /tmp there.
scp -O -q "$COMPOSE_FILE" "$ENV_FILE" "$CRED_FILE" "$PARAMS_FILE" "$REMOTE_SETUP_SRC" "${SSH_HOST}:${REMOTE_TMP}/"
ssh "$SSH_HOST" "bash '${REMOTE_TMP}/remote_setup.sh' '${REMOTE_TMP}'"

echo
echo "Manage this lab:"
echo "  Stop:   scripts/stop_wp_lab.sh --site-name ${SITE_NAME}"
echo "  Start:  scripts/list_wp_labs.sh   # then docker compose up -d on the NAS"
echo "  Remove: scripts/remove_wp_lab.sh --site-name ${SITE_NAME} --confirm"
