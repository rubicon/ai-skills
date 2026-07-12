#!/usr/bin/env bash
# remote_setup.sh — runs ON the NAS to stand up a WordPress lab.
#
# Contains no secrets and no personal data: every parameter is read from the
# params.env that create_wp_lab.sh placed in the private staging dir. The
# staging dir (and the admin secret inside it) is removed on exit.
#
# Argument 1: the staging directory (holds params.env, compose.yaml, .env,
# credentials.txt). Persistent files are moved into the lab dir; the rest is
# cleaned up.
set -euo pipefail

# Non-interactive SSH on Synology gets a minimal PATH that omits /usr/local/bin,
# where Container Manager installs the docker CLI. Prepend it (harmless on
# generic Linux, where /usr/local/bin is already present).
export PATH="/usr/local/bin:/usr/local/sbin:$PATH"

REMOTE_TMP="${1:?usage: remote_setup.sh <staging-dir>}"
# shellcheck source=/dev/null
source "${REMOTE_TMP}/params.env"
trap 'rm -rf "$REMOTE_TMP"' EXIT

# --- Preflight: Docker must be usable by this user --------------------------

command -v docker >/dev/null 2>&1 || { echo "Error: docker not found on PATH." >&2; exit 1; }
if ! docker info >/dev/null 2>&1; then
  echo "Error: cannot reach the Docker daemon as user '$(id -un)'." >&2
  echo "Grant this user Docker access on the NAS (docker group / Container Manager) and retry." >&2
  exit 1
fi
docker compose version >/dev/null 2>&1 || { echo "Error: 'docker compose' plugin not available." >&2; exit 1; }

# --- Resolve port ----------------------------------------------------------

find_port() {
  local candidate
  for candidate in $(seq 8080 8999); do
    docker ps --format '{{.Ports}}' | grep -q ":${candidate}->" && continue
    if command -v netstat >/dev/null 2>&1 && netstat -tuln 2>/dev/null | grep -q ":${candidate} "; then
      continue
    fi
    echo "$candidate"; return 0
  done
  echo "Error: no free port found in 8080-8999." >&2; return 1
}
if [[ "$PORT" == "auto" ]]; then PORT_VALUE="$(find_port)"; else PORT_VALUE="$PORT"; fi
[[ "$PORT_VALUE" =~ ^[0-9]+$ ]] || { echo "Error: invalid port '$PORT_VALUE'." >&2; exit 1; }

# --- Lay down the lab directory --------------------------------------------

mkdir -p "$REMOTE_DIR" "$REMOTE_DIR/wordpress" "$REMOTE_DIR/db"
chmod 775 "$REMOTE_DIR" "$REMOTE_DIR/wordpress" "$REMOTE_DIR/db"

if [[ -f "$REMOTE_DIR/compose.yaml" && "$FORCE" != "1" ]]; then
  echo "Error: a lab already exists at $REMOTE_DIR. Re-run with --force to overwrite." >&2
  exit 1
fi
if [[ -f "$REMOTE_DIR/compose.yaml" ]]; then
  cp "$REMOTE_DIR/compose.yaml" "$REMOTE_DIR/compose.yaml.backup.$(date +%Y%m%d-%H%M%S)"
fi

mv "$REMOTE_TMP/compose.yaml"   "$REMOTE_DIR/compose.yaml"
mv "$REMOTE_TMP/.env"           "$REMOTE_DIR/.env"
mv "$REMOTE_TMP/credentials.txt" "$REMOTE_DIR/credentials.txt"
chmod 600 "$REMOTE_DIR/.env" "$REMOTE_DIR/credentials.txt"

sed -i "s/__PORT__/${PORT_VALUE}/g" "$REMOTE_DIR/compose.yaml" "$REMOTE_DIR/credentials.txt"

# --- Shared external network -----------------------------------------------

docker network inspect "$NETWORK_NAME" >/dev/null 2>&1 || docker network create "$NETWORK_NAME" >/dev/null

cd "$REMOTE_DIR"
DB_ROOT_PW="$(grep -E '^MYSQL_ROOT_PASSWORD=' .env | cut -d= -f2-)"
WP_DB_PW="$(grep -E '^WORDPRESS_DB_PASSWORD=' .env | cut -d= -f2-)"

docker compose -p "$PROJECT_NAME" pull db wpcli wordpress
docker compose -p "$PROJECT_NAME" up -d db

# Wait for MariaDB. First-time init on a NAS (slow I/O, io_uring disabled) can
# take several minutes, so allow ~6 min — but fail fast if the container dies.
ready=0
for _ in $(seq 1 180); do
  status="$(docker inspect -f '{{.State.Status}}' "${SITE_NAME}-db" 2>/dev/null || echo missing)"
  if [[ "$status" == "exited" || "$status" == "dead" ]]; then
    echo "Error: database container '${SITE_NAME}-db' exited during startup." >&2
    docker compose -p "$PROJECT_NAME" logs db
    exit 1
  fi
  if docker compose -p "$PROJECT_NAME" exec -T db \
       mysqladmin ping -h 127.0.0.1 -uroot -p"$DB_ROOT_PW" --silent >/dev/null 2>&1; then
    ready=1; break
  fi
  sleep 2
done
if [[ "$ready" != "1" ]]; then
  echo "Error: database did not become ready within ~6 minutes." >&2
  docker compose -p "$PROJECT_NAME" logs db
  exit 1
fi

if [[ ! -f wordpress/wp-settings.php ]]; then
  docker compose -p "$PROJECT_NAME" run --rm wpcli wp core download --version="$WP_VERSION" --force --allow-root
fi

docker compose -p "$PROJECT_NAME" run --rm wpcli wp config create \
  --allow-root --dbname=wordpress --dbuser=wordpress --dbpass="$WP_DB_PW" \
  --dbhost=db:3306 --skip-check --force

docker compose -p "$PROJECT_NAME" run --rm wpcli wp core install \
  --allow-root \
  --url="http://${ACCESS_HOST}:${PORT_VALUE}" \
  --title="$TITLE" \
  --admin_user="$ADMIN_USER" \
  --admin_password="$ADMIN_PASSWORD" \
  --admin_email="$ADMIN_EMAIL" \
  --skip-email

# Apache (www-data) ownership. Needs root; non-fatal so labs still come up on
# hosts where the SSH user can't chown (UMASK keeps the tree group-writable).
if ! chown -R 33:33 wordpress 2>/dev/null; then
  echo "Warning: could not chown wordpress/ to 33:33 (needs root). Relying on UMASK=${UMASK:-002}." >&2
fi

docker compose -p "$PROJECT_NAME" up -d wordpress

echo "Created WordPress lab: $SITE_NAME"
echo "Remote path: $REMOTE_DIR"
echo "URL: http://${ACCESS_HOST}:${PORT_VALUE}"
echo "Credentials (on NAS, mode 600): $REMOTE_DIR/credentials.txt"
