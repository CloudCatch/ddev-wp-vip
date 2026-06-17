#!/usr/bin/env bash
# One-command setup (non-interactive). For the questionnaire wizard use: ./bin/new-project.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT}"

if [[ $# -eq 0 && -t 0 ]]; then
	exec "${ROOT}/bin/new-project.sh"
fi

PROJECT_NAME="${1:-$(basename "${ROOT}")}"
VIP_APP_SOURCE="${VIP_APP_SOURCE:-}"

echo "=== VIP + DDEV bootstrap: ${PROJECT_NAME} ==="
echo ""

if [[ -z "${VIP_APP_SOURCE}" && -t 0 ]]; then
	read -r -p "VIP application repo to import (git URL, local path, or Enter to skip): " VIP_APP_SOURCE || true
fi

if [[ -n "${VIP_APP_SOURCE}" ]]; then
	"${ROOT}/bin/integrate-vip-app.sh" --source "${VIP_APP_SOURCE}" --yes "${ROOT}"
fi

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
echo "  Admin: ${URL}/wp-admin/  (vipgo / password)"
echo ""
echo "Optional:"
echo "  ddev wp vip-search index --setup --skip-confirm"
