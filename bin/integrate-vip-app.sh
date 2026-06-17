#!/usr/bin/env bash
# Integrate DDEV + VIP local tooling into an existing VIP application repository.
set -euo pipefail

TEMPLATE_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=lib/vip-common.sh
source "${TEMPLATE_ROOT}/bin/lib/vip-common.sh"

TARGET=""
SOURCE=""
OVERLAY_ONLY=false
SKIP_CONFIRM=false

usage() {
	cat <<EOF
Usage: $(basename "$0") [options] [target_directory]

Bring DDEV local development into a WordPress VIP application repo.

Options:
  --source <git-url|path>   Import application code from a VIP repo (clone or copy)
  --overlay-only            Only add DDEV tooling; do not import application code
  -y, --yes                 Skip confirmation prompts
  -h, --help                Show this help

Examples:
  # Add DDEV to an existing checkout (e.g. compliancetrainingpartners-com):
  $(basename "$0") ~/Projects/compliancetrainingpartners-com

  # Start from this template, pull in a VIP app repo, then bootstrap:
  $(basename "$0") --source https://github.com/wpcomvip/example.git .

Never overwrites: vip-config/vip-config.php, client-mu-plugins/plugin-loader.php
EOF
}

prompt_source() {
	local reply
	if [[ -n "${SOURCE}" ]]; then
		return 0
	fi
	read -r -p "VIP application repo (git URL, local path, or Enter to skip): " reply
	SOURCE="${reply}"
}

is_vip_app_repo() {
	vip_common_is_vip_app_repo "$1"
}

resolve_source_dir() {
	local src="$1"
	local temp=""

	if [[ "${src}" == git@* || "${src}" == http://* || "${src}" == https://* ]]; then
		temp="$(mktemp -d)"
		echo "Cloning ${src} ..." >&2
		git clone --depth 1 "${src}" "${temp}/repo"
		echo "${temp}/repo"
		return 0
	fi

	if [[ ! -d "${src}" ]]; then
		echo "ERROR: Source path not found: ${src}" >&2
		return 1
	fi

	cd "${src}" && pwd
}

detect_vip_sync_from_data_sync_configs() {
	vip_common_detect_sync_from_configs "$1"
}

write_vip_sync_config() {
	vip_common_write_sync_config "$@"
}

merge_gitignore() {
	local target="$1"
	local snippet="${TEMPLATE_ROOT}/config/gitignore.ddev.snippet"
	local gitignore="${target}/.gitignore"

	if [[ ! -f "${snippet}" ]]; then
		return 0
	fi

	if [[ -f "${gitignore}" ]] && grep -q 'ddev-wp-vip local' "${gitignore}" 2>/dev/null; then
		return 0
	fi

	{
		echo ""
		cat "${snippet}"
	} >>"${gitignore}"
	echo "Merged DDEV .gitignore entries"
}

overlay_ddev_tooling() {
	local target="$1"

	echo "Adding DDEV tooling to ${target} ..."

	rsync -a "${TEMPLATE_ROOT}/.ddev/" "${target}/.ddev/"
	rsync -a "${TEMPLATE_ROOT}/bin/" "${target}/bin/"
	chmod +x "${target}"/bin/*.sh 2>/dev/null || true
	rsync -a "${TEMPLATE_ROOT}/.ddev/commands/" "${target}/.ddev/commands/" 2>/dev/null || true

	mkdir -p "${target}/config" "${target}/private/vip-sync" "${target}/.ddev/nginx"

	for f in wp-config.php.sample wp-config-ddev.php vip-sync.yaml.example ddev-elasticsearch.php \
		.vip.example.develop.yml.example gitignore.ddev.snippet; do
		if [[ -f "${TEMPLATE_ROOT}/config/${f}" ]]; then
			cp -n "${TEMPLATE_ROOT}/config/${f}" "${target}/config/" 2>/dev/null || true
		fi
	done

	cp -n "${TEMPLATE_ROOT}/wp-cli.yml" "${target}/wp-cli.yml" 2>/dev/null || cp "${TEMPLATE_ROOT}/wp-cli.yml" "${target}/wp-cli.yml"

	mkdir -p "${target}/client-mu-plugins"
	cp -n "${TEMPLATE_ROOT}/client-mu-plugins/ddev-elasticsearch.php" "${target}/client-mu-plugins/" 2>/dev/null \
		|| cp "${TEMPLATE_ROOT}/client-mu-plugins/ddev-elasticsearch.php" "${target}/client-mu-plugins/"

	mkdir -p "${target}/vip-config"
	if [[ ! -f "${target}/vip-config/vip-config-ddev.php" ]]; then
		cp "${TEMPLATE_ROOT}/vip-config/vip-config-ddev.php" "${target}/vip-config/vip-config-ddev.php"
		echo "Added vip-config/vip-config-ddev.php (does not replace vip-config.php)"
	elif [[ ! -f "${target}/vip-config/vip-config.php" ]]; then
		cp "${TEMPLATE_ROOT}/vip-config/vip-config.php" "${target}/vip-config/vip-config.php"
	fi

	cp -n "${TEMPLATE_ROOT}/.ddev/nginx/README.txt" "${target}/.ddev/nginx/" 2>/dev/null || true
	cp -n "${TEMPLATE_ROOT}/private/vip-sync/.gitkeep" "${target}/private/vip-sync/" 2>/dev/null || true

	merge_gitignore "${target}"
}

import_application_code() {
	local source="$1"
	local target="$2"

	if ! is_vip_app_repo "${source}"; then
		echo "ERROR: Source does not look like a VIP application repo: ${source}" >&2
		return 1
	fi

	echo "Importing application code from ${source} ..."

	mkdir -p "${target}/config"
	shopt -s nullglob
	for f in "${source}"/config/.vip.*.yml; do
		cp -n "${f}" "${target}/config/" 2>/dev/null || cp "${f}" "${target}/config/"
	done
	shopt -u nullglob

	for dir in plugins themes client-mu-plugins images private languages; do
		if [[ -d "${source}/${dir}" ]]; then
			mkdir -p "${target}/${dir}"
			rsync -a "${source}/${dir}/" "${target}/${dir}/"
		fi
	done

	if [[ -d "${source}/vip-config" ]]; then
		mkdir -p "${target}/vip-config"
		rsync -a --exclude='vip-config-ddev.php' "${source}/vip-config/" "${target}/vip-config/"
		if [[ -f "${target}/vip-config/vip-config.php" ]]; then
			echo "Kept/merged vip-config/vip-config.php from application repo"
		fi
	fi
}

while [[ $# -gt 0 ]]; do
	case "$1" in
		--source)
			SOURCE="${2:-}"
			shift 2
			;;
		--overlay-only)
			OVERLAY_ONLY=true
			shift
			;;
		-y | --yes)
			SKIP_CONFIRM=true
			shift
			;;
		-h | --help)
			usage
			exit 0
			;;
		-*)
			echo "ERROR: Unknown option: $1"
			usage
			exit 1
			;;
		*)
			TARGET="$1"
			shift
			;;
	esac
done

TARGET="$(cd "${TARGET:-${TEMPLATE_ROOT}}" && pwd)"

if [[ "${TARGET}" != "${TEMPLATE_ROOT}" ]] && [[ ! -d "${TARGET}" ]]; then
	mkdir -p "${TARGET}"
fi

prompt_source

SOURCE_DIR=""
SOURCE_TEMP=""
if [[ -n "${SOURCE}" ]]; then
	SOURCE_DIR="$(resolve_source_dir "${SOURCE}")"
	if [[ "${SOURCE_DIR}" == /tmp/* || "${SOURCE_DIR}" == /var/folders/* ]]; then
		SOURCE_TEMP="$(dirname "${SOURCE_DIR}")"
	fi
fi

trap '[[ -n "${SOURCE_TEMP}" ]] && rm -rf "${SOURCE_TEMP}"' EXIT

if [[ -n "${SOURCE_DIR}" && "${OVERLAY_ONLY}" != true ]]; then
	if [[ "${SKIP_CONFIRM}" != true ]]; then
		echo ""
		echo "Target: ${TARGET}"
		echo "Source: ${SOURCE_DIR}"
		read -r -p "Import VIP application code and add DDEV tooling? [y/N] " reply
		if [[ ! "${reply}" =~ ^[Yy]$ ]]; then
			echo "Aborted."
			exit 0
		fi
	fi
	import_application_code "${SOURCE_DIR}" "${TARGET}"
elif [[ -n "${SOURCE_DIR}" && "${OVERLAY_ONLY}" == true ]]; then
	echo "WARN: --source ignored with --overlay-only"
fi

if is_vip_app_repo "${TARGET}" || [[ -f "${TARGET}/.ddev/config.yaml" ]]; then
	overlay_ddev_tooling "${TARGET}"
else
	echo "ERROR: Target is not a VIP application repo and no --source was provided." >&2
	echo "       Clone a VIP repo first or pass --source <git-url|path>" >&2
	exit 1
fi

if detected="$(detect_vip_sync_from_data_sync_configs "${TARGET}/config")"; then
	read -r APP ENV <<<"${detected}"
	write_vip_sync_config "${TARGET}" "${APP}" "${ENV}"
fi

echo ""
echo "Integration complete: ${TARGET}"
echo ""
echo "Next steps:"
echo "  cd ${TARGET}"
echo "  ./bin/configure-project.sh \$(basename ${TARGET})"
echo "  ./bin/vip-setup.sh"
echo "  ddev start"
echo "  ./bin/install-wordpress.sh   # or: ddev vip-db-sync"
