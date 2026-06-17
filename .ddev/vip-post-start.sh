#!/usr/bin/env bash
## Description: VIP post-start (object cache symlink, mu-plugins check)
## Usage: vip-post-start
## ExecRaw: true

set -euo pipefail

CONTENT="/var/www/html/wordpress/wp-content"
CACHE_LINK="${CONTENT}/object-cache.php"
# Same router VIP uses on hosted environments (loads wp-memcached when php-memcached is available).
CACHE_TARGET="mu-plugins/drop-ins/object-cache.php"

if [[ -f "${CONTENT}/${CACHE_TARGET}" ]] && php -m 2>/dev/null | grep -q '^memcached$'; then
  ln -sf "${CACHE_TARGET}" "${CACHE_LINK}"
  echo "Linked object-cache.php -> ${CACHE_TARGET} (wp-memcached via php-memcached)"
elif [[ -f "${CONTENT}/mu-plugins/drop-ins/object-cache/object-cache-stable.php" ]]; then
  rm -f "${CACHE_LINK}"
  echo "WARN: php-memcached extension missing; using WordPress default object cache."
  echo "      Install add-on: ddev add-on get ddev/ddev-memcached && ddev restart"
else
  echo "WARN: Platform mu-plugins not found. Run: ./bin/vip-setup.sh"
fi

if [[ ! -f "${CONTENT}/mu-plugins/000-vip-init.php" ]] && [[ ! -f "${CONTENT}/mu-plugins/000-pre-vip-config/requires.php" ]]; then
  echo "WARN: VIP platform mu-plugins missing at ${CONTENT}/mu-plugins"
fi
