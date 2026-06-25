# WordPress/PHP Compatibility Starting Points

Use this as a practical lab starting point, not a warranty from the heavens. Old WordPress versions plus modern PHP are where dignity goes to time out.

| WordPress version range | Recommended lab PHP | Notes |
|---|---:|---|
| 6.6 and newer | 8.2 | Good modern default. |
| 6.3 to 6.5 | 8.1 | Conservative compatibility choice. |
| 5.9 to 6.2 | 7.4 | Good downgrade-safe starting point. |
| 5.6 to 5.8 | 7.4 | Often works better than PHP 8.x. |
| 5.2 to 5.5 | 7.3 | Use 7.4 if tags are easier to pull and testing allows warnings. |
| 4.9 to 5.1 | 7.2 | PHP 7.4 may work with warnings; plugins/themes may fail. |
| 4.7 to 4.8 | 7.1 | Best effort. |
| 4.4 to 4.6 | 7.0 | Best effort. |
| Older than 4.4 | 5.6 | Best effort; old official Docker tags may be unavailable or unsupported on current hardware. |

`create_wp_lab.sh --php-version auto` implements exactly this table. Pass an explicit `--php-version` to override.

When the exact WordPress/PHP combination fails to pull, use the nearest newer available `wordpress:phpX.Y-apache` and `wordpress:cli-phpX.Y` images, then document the deviation as Needs Verification.
