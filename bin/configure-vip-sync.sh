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
read -r -p "Remote site URL (production/staging): " REMOTE_URL

ENV="${ENV:-develop}"
APP="$(echo "${APP}" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9-]+/-/g; s/^-+|-+$//g')"
REMOTE_URL="${REMOTE_URL%/}"

if [[ -z "${APP}" || -z "${REMOTE_URL}" ]]; then
	echo "ERROR: app and remote_url are required."
	exit 1
fi

cat >"${CONFIG}" <<EOF
# VIP Platform database sync source (gitignored).
# Used by: ddev vip-db-sync

app: ${APP}
env: ${ENV}
remote_url: ${REMOTE_URL}

# Optional: request a fresh backup before export (slower).
# generate_backup: false
EOF

echo ""
echo "Wrote ${CONFIG}"
echo ""
echo "Review the file, then run:"
echo "  ddev vip-db-sync"
