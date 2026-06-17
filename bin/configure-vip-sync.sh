#!/usr/bin/env bash
# Create config/vip-sync.yaml interactively from the example template.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="${ROOT}/config/vip-sync.yaml"
EXAMPLE="${ROOT}/config/vip-sync.yaml.example"

if [[ -f "${CONFIG}" ]]; then
	read -r -p "config/vip-sync.yaml already exists. Overwrite? [y/N] " reply
	if [[ ! "${reply}" =~ ^[Yy]$ ]]; then
		echo "Aborted."
		exit 0
	fi
fi

if [[ ! -f "${EXAMPLE}" ]]; then
	echo "ERROR: Missing ${EXAMPLE}"
	exit 1
fi

read -r -p "VIP application slug (app): " APP
read -r -p "VIP environment [develop]: " ENV

ENV="${ENV:-develop}"
APP="$(echo "${APP}" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9-]+/-/g; s/^-+|-+$//g')"

if [[ -z "${APP}" ]]; then
	echo "ERROR: app is required."
	exit 1
fi

cat >"${CONFIG}" <<EOF
# VIP Platform database sync source (gitignored).
# Used by: ddev vip-db-sync

app: ${APP}
env: ${ENV}

# Optional: request a fresh backup before export (slower).
# generate_backup: false
EOF

echo ""
echo "Wrote ${CONFIG}"
echo ""
echo "Add a VIP data sync config for search-replace (recommended for multisite):"
echo "  config/.vip.${APP}.${ENV}.yml"
echo "  See config/.vip.example.develop.yml.example"
echo ""
echo "Then run:"
echo "  ddev vip-db-sync"
echo ""
echo "Media proxy (optional, after vip-sync.yaml exists):"
echo "  ddev vip-media-proxy-update && ddev restart"
