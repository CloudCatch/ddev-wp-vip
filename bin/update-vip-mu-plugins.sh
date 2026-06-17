#!/usr/bin/env bash
# Update VIP platform mu-plugins from Automattic/vip-go-mu-plugins-built (idempotent).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MU_PLUGINS="${ROOT}/mu-plugins"
REPO="${VIP_MU_PLUGINS_REPO:-https://github.com/Automattic/vip-go-mu-plugins-built.git}"

if [[ ! -d "${MU_PLUGINS}/.git" ]]; then
	echo "ERROR: ${MU_PLUGINS} is not a git checkout."
	echo "Run: ./bin/vip-setup.sh"
	exit 1
fi

cd "${MU_PLUGINS}"

if [[ -n "$(git status --porcelain)" ]]; then
	echo "WARN: mu-plugins has local changes; update will discard them."
fi

echo "Repository: ${REPO}"
echo "Before:     $(git rev-parse --short HEAD) ($(git log -1 --format='%cs %s'))"
echo "Fetching latest ..."

git fetch --depth 1 origin
git reset --hard FETCH_HEAD

echo "After:      $(git rev-parse --short HEAD) ($(git log -1 --format='%cs %s'))"
echo "Done."
