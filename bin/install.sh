#!/usr/bin/env bash
# Minimal bootstrap for: curl -fsSL .../bin/install.sh | bash
# Safe to pipe — never uses BASH_SOURCE. Clones template from git and runs the wizard.
set -euo pipefail

TEMPLATE_REPO="${DDEV_VIP_TEMPLATE_REPO:-https://github.com/CloudCatch/ddev-wp-vip.git}"

echo "Fetching DDEV VIP template ..."
_temp="$(mktemp -d)"
git clone --depth 1 "${TEMPLATE_REPO}" "${_temp}/ddev-wp-vip"
chmod +x "${_temp}/ddev-wp-vip/bin/"*.sh 2>/dev/null || true
exec "${_temp}/ddev-wp-vip/bin/new-project.sh"
