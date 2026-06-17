#!/usr/bin/env bash
# One-command setup for a fresh clone: configure name, VIP mu-plugins, DDEV, WordPress.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT}"

PROJECT_NAME="${1:-$(basename "${ROOT}")}"

echo "=== VIP + DDEV bootstrap: ${PROJECT_NAME} ==="
echo ""

"${ROOT}/bin/configure-project.sh" "${PROJECT_NAME}"
"${ROOT}/bin/vip-setup.sh"

if ! command -v ddev >/dev/null 2>&1; then
	echo ""
	echo "ERROR: ddev not found in PATH after vip-setup."
	exit 1
fi

ddev start
"${ROOT}/bin/install-wordpress.sh"

URL="$(ddev exec printenv DDEV_PRIMARY_URL 2>/dev/null | tr -d '\r' || true)"
URL="${URL:-https://${PROJECT_NAME}.ddev.site}"

echo ""
echo "=== Bootstrap complete ==="
echo "  Site:  ${URL}"
echo "  Admin: ${URL}/wp-admin/  (admin / admin)"
echo ""
echo "Optional:"
echo "  ddev wp vip-search index --setup --skip-confirm"
