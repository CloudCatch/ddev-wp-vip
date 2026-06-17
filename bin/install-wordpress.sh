#!/usr/bin/env bash
# Download WordPress core into wordpress/ and run a minimal install (requires ddev start).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT}"

WP_ADMIN_USER="${WP_ADMIN_USER:-vipgo}"
WP_ADMIN_PASSWORD="${WP_ADMIN_PASSWORD:-password}"
WP_ADMIN_EMAIL="${WP_ADMIN_EMAIL:-vipgo@example.com}"

if ! command -v ddev >/dev/null 2>&1; then
	echo "ERROR: ddev not found in PATH"
	exit 1
fi

if [[ ! -d "${ROOT}/.ddev" ]]; then
	echo "ERROR: No .ddev directory. Run this from the project root."
	exit 1
fi

if ! ddev describe >/dev/null 2>&1; then
	echo "ERROR: DDEV project not running. Run: ddev start"
	exit 1
fi

if [[ ! -f "${ROOT}/config/wp-config.php.sample" ]]; then
	echo "ERROR: Missing config/wp-config.php.sample"
	exit 1
fi

if [[ ! -f "${ROOT}/wordpress/wp-config.php" ]]; then
	mkdir -p "${ROOT}/wordpress"
	cp "${ROOT}/config/wp-config.php.sample" "${ROOT}/wordpress/wp-config.php"
	echo "Copied config/wp-config.php.sample -> wordpress/wp-config.php"
fi

if [[ -f "${ROOT}/config/wp-config-ddev.php" ]] && [[ ! -f "${ROOT}/wordpress/wp-config-ddev.php" ]]; then
	cp "${ROOT}/config/wp-config-ddev.php" "${ROOT}/wordpress/wp-config-ddev.php"
	echo "Copied config/wp-config-ddev.php -> wordpress/wp-config-ddev.php"
fi

if grep -q "change-me-auth-key" "${ROOT}/wordpress/wp-config.php" 2>/dev/null; then
	echo "Generating WordPress salts ..."
	ddev wp config shuffle-salts
fi

if [[ ! -f "${ROOT}/wordpress/wp-settings.php" ]]; then
	echo "Downloading WordPress core into wordpress/ ..."
	ddev wp core download
else
	echo "WordPress core already present in wordpress/"
fi

if ddev wp core is-installed 2>/dev/null; then
	echo "WordPress is already installed."
	exit 0
fi

URL="$(ddev exec printenv DDEV_PRIMARY_URL 2>/dev/null | tr -d '\r' || true)"
if [[ -z "${URL}" ]]; then
	DDEV_NAME="$(grep -E '^name:' "${ROOT}/.ddev/config.yaml" | awk '{print $2}' | tr -d '\r')"
	URL="https://${DDEV_NAME:-localhost}.ddev.site"
fi

echo "Installing WordPress (site URL: ${URL}) ..."
ddev wp core install \
	--url="${URL}" \
	--title="VIP Local" \
	--admin_user="${WP_ADMIN_USER}" \
	--admin_password="${WP_ADMIN_PASSWORD}" \
	--admin_email="${WP_ADMIN_EMAIL}" \
	--skip-email

echo ""
echo "Installed. Log in at ${URL}/wp-admin/ (${WP_ADMIN_USER} / ${WP_ADMIN_PASSWORD})"
