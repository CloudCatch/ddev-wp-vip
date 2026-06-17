#!/usr/bin/env bash
# Download WordPress core into wordpress/ and run a minimal install (requires ddev start).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT}"

WP_ADMIN_USER="${WP_ADMIN_USER:-vipgo}"
WP_ADMIN_PASSWORD="${WP_ADMIN_PASSWORD:-password}"
WP_ADMIN_EMAIL="${WP_ADMIN_EMAIL:-vipgo@example.com}"

"${ROOT}/bin/ensure-wordpress-core.sh"

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
