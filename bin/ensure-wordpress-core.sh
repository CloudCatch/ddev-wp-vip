#!/usr/bin/env bash
# Ensure wordpress/wp-config.php and WordPress core exist (no wp core install).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT}"

if ! command -v ddev >/dev/null 2>&1; then
	echo "ERROR: ddev not found in PATH" >&2
	exit 1
fi

if [[ ! -d "${ROOT}/.ddev" ]]; then
	echo "ERROR: No .ddev directory. Run this from the project root." >&2
	exit 1
fi

if ! ddev describe >/dev/null 2>&1; then
	echo "ERROR: DDEV project not running. Run: ddev start" >&2
	exit 1
fi

if [[ ! -f "${ROOT}/config/wp-config.php.sample" ]]; then
	echo "ERROR: Missing config/wp-config.php.sample" >&2
	exit 1
fi

mkdir -p "${ROOT}/wordpress"

if [[ ! -f "${ROOT}/wordpress/wp-config.php" ]]; then
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
fi
