#!/usr/bin/env bash
# Bootstrap VIP platform mu-plugins, DDEV add-ons, and wordpress/wp-config.php (idempotent).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT}"

MU_PLUGINS="${ROOT}/mu-plugins"
WORDPRESS="${ROOT}/wordpress"
WP_CONFIG_SAMPLE="${ROOT}/config/wp-config.php.sample"
REPO="${VIP_MU_PLUGINS_REPO:-https://github.com/Automattic/vip-go-mu-plugins-built.git}"

install_ddev_addon() {
	local addon_repo="$1"
	local compose_file="$2"

	if [[ -f "${ROOT}/.ddev/${compose_file}" ]]; then
		echo "DDEV add-on already installed: ${addon_repo}"
		return 0
	fi

	if ! command -v ddev >/dev/null 2>&1; then
		echo "WARN: ddev not in PATH. Install manually: ddev add-on get ${addon_repo}"
		return 0
	fi

	echo "Installing DDEV add-on ${addon_repo} ..."
	ddev add-on get "${addon_repo}" -y
}

install_wp_config() {
	if [[ ! -f "${WP_CONFIG_SAMPLE}" ]]; then
		echo "WARN: Missing ${WP_CONFIG_SAMPLE}"
		return 0
	fi

	mkdir -p "${WORDPRESS}"

	if [[ ! -f "${WORDPRESS}/wp-config.php" ]]; then
		cp "${WP_CONFIG_SAMPLE}" "${WORDPRESS}/wp-config.php"
		echo "Copied config/wp-config.php.sample -> wordpress/wp-config.php"
		echo "      Run 'ddev wp config shuffle-salts' after ddev start to generate keys."
	else
		echo "wordpress/wp-config.php already present"
	fi

	WP_CONFIG_DDEV="${ROOT}/config/wp-config-ddev.php"
	if [[ -f "${WP_CONFIG_DDEV}" ]] && [[ ! -f "${WORDPRESS}/wp-config-ddev.php" ]]; then
		cp "${WP_CONFIG_DDEV}" "${WORDPRESS}/wp-config-ddev.php"
		echo "Copied config/wp-config-ddev.php -> wordpress/wp-config-ddev.php"
	fi
}

if [[ -d "${MU_PLUGINS}/.git" ]] || [[ -f "${MU_PLUGINS}/000-vip-init.php" ]] || [[ -f "${MU_PLUGINS}/000-pre-vip-config/requires.php" ]]; then
	echo "VIP platform mu-plugins already present at ${MU_PLUGINS}"
else
	echo "Cloning VIP platform mu-plugins (built) into ${MU_PLUGINS} ..."
	git clone --depth 1 "${REPO}" "${MU_PLUGINS}"
fi

install_ddev_addon "ddev/ddev-memcached" "docker-compose.memcached.yaml"
install_ddev_addon "ddev/ddev-elasticsearch" "docker-compose.elasticsearch.yaml"
install_wp_config

echo ""
echo "Done."
echo "  1. ddev start"
echo "  2. ./bin/install-wordpress.sh   # download core if wordpress/ is empty"
