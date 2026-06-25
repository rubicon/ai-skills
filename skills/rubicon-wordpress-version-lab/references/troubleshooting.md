# Troubleshooting

## "SSH_HOST and ACCESS_HOST are required"

No config yet (or those fields are empty). Set them once:

```bash
scripts/config_wp_lab.sh --set --ssh-host <host> --access-host <host>
scripts/config_wp_lab.sh --show
```

`config_wp_lab.sh --path` prints where the config lives.

## "cannot reach the Docker daemon as user ..."

The SSH user can log in but can't use Docker. On Synology, give the user Docker
access (Container Manager / docker group). Verify by hand:

```bash
ssh <host> 'docker info'
```

## Docker image fails to pull

Try a newer PHP tag first. Ancient PHP/CLI tags may not exist for the NAS CPU
architecture. See `wordpress-php-compatibility.md`.

## WordPress shows the wrong version

The lab pre-populates `/var/www/html` with WP-CLI before starting the web
container. Check from the lab directory on the NAS:

```bash
docker compose run --rm wpcli wp core version
```

## Site redirects to the wrong host

WordPress bakes its `siteurl`/`home` from `ACCESS_HOST` at install time. Browse
to the same host you set as `ACCESS_HOST`. To change it, update the config and
recreate, or fix `siteurl`/`home` via WP-CLI in the running lab.

## "could not chown wordpress/ to 33:33"

The SSH user isn't root, so files stay owned by the SSH user instead of
`www-data`. `UMASK=002` keeps the tree group-writable, so this is usually fine
for a lab. If WordPress can't write uploads, fix ownership for that one lab
folder on the NAS rather than broadening permissions across `BASE_PARENT`.

## Database is not ready

The setup waits for MariaDB via `mysqladmin ping`. If it times out:

```bash
docker compose logs db
```

## Port already in use

Use `--port auto` or pass a specific `--port`. Auto scans 8080–8999.

## First lab is slow to create

The first `create` pulls the MariaDB, WordPress, and WP-CLI images (hundreds of
MB) and downloads WordPress core — this can take several minutes on a NAS.
Later labs reuse the cached images and are much faster.

## Security warning

Do not expose old WordPress labs to the public internet. Published ports bind to
all interfaces on the NAS — keep router/firewall rules closed and use the labs
only for local compatibility testing.
