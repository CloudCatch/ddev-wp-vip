#!/usr/bin/env bash
# Set DDEV project name (and optional local site ID) from argument or directory name.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RAW_NAME="${1:-$(basename "${ROOT}")}"

# DDEV names: lowercase alphanumeric and hyphens.
NAME="$(echo "${RAW_NAME}" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9-]+/-/g; s/^-+|-+$//g')"

if [[ -z "${NAME}" ]]; then
	echo "ERROR: Could not derive a valid DDEV project name from '${RAW_NAME}'"
	exit 1
fi

CONFIG="${ROOT}/.ddev/config.yaml"
if [[ ! -f "${CONFIG}" ]]; then
	echo "ERROR: Missing ${CONFIG}"
	exit 1
fi

if [[ "${OSTYPE}" == darwin* ]]; then
	sed -i '' "s/^name: .*/name: ${NAME}/" "${CONFIG}"
else
	sed -i "s/^name: .*/name: ${NAME}/" "${CONFIG}"
fi

# Stable per-project site ID for VIP Search index names (vip-{id}-*).
SITE_ID="$(( 200000 + $(echo -n "${NAME}" | cksum | awk '{print $1}') % 800000 ))"
VIP_CONFIG="${ROOT}/vip-config/vip-config.php"
if [[ -f "${VIP_CONFIG}" ]]; then
	if [[ "${OSTYPE}" == darwin* ]]; then
		sed -i '' "s/define( 'FILES_CLIENT_SITE_ID', [0-9]* );/define( 'FILES_CLIENT_SITE_ID', ${SITE_ID} );/" "${VIP_CONFIG}"
	else
		sed -i "s/define( 'FILES_CLIENT_SITE_ID', [0-9]* );/define( 'FILES_CLIENT_SITE_ID', ${SITE_ID} );/" "${VIP_CONFIG}"
	fi
fi

echo "DDEV project name: ${NAME}"
echo "Site URL:          https://${NAME}.ddev.site"
echo "VIP site ID:       ${SITE_ID} (FILES_CLIENT_SITE_ID)"
