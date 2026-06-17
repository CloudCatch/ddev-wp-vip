#!/usr/bin/env bash
# Export VIP Platform database via VIP-CLI and import into local DDEV.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="${ROOT}/config/vip-sync.yaml"
CONFIG_EXAMPLE="${ROOT}/config/vip-sync.yaml.example"

SKIP_CONFIRM=false
DRY_RUN=false
GENERATE_BACKUP=""

usage() {
	cat <<EOF
Usage: $(basename "$0") [options]

Export a VIP Platform database and import it into this DDEV project.

Options:
  -y, --yes              Skip confirmation prompt
  --generate-backup      Request a fresh VIP backup before export
  --dry-run              Show what would run without making changes
  -h, --help             Show this help

Configure app/env/remote_url in config/vip-sync.yaml (see config/vip-sync.yaml.example).
EOF
}

yaml_value() {
	local key="$1" file="$2"
	local line
	line="$(grep -E "^${key}:" "${file}" | head -1 || true)"
	if [[ -z "${line}" ]]; then
		return 1
	fi
	echo "${line#*:}" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//; s/^["'\''](.*)["'\'']$/\1/'
}

yaml_bool() {
	local value
	value="$(yaml_value "$1" "$2" || echo "false")"
	value="$(echo "${value}" | tr '[:upper:]' '[:lower:]')"
	case "${value}" in
		true | yes | 1) return 0 ;;
		*) return 1 ;;
	esac
}

local_ddev_url() {
	local url name
	url="$(ddev exec printenv DDEV_PRIMARY_URL 2>/dev/null | tr -d '\r' || true)"
	if [[ -n "${url}" ]]; then
		echo "${url%/}"
		return 0
	fi
	name="$(grep -E '^name:' "${ROOT}/.ddev/config.yaml" | awk '{print $2}' | tr -d '\r')"
	echo "https://${name:-localhost}.ddev.site"
}

while [[ $# -gt 0 ]]; do
	case "$1" in
		-y | --yes)
			SKIP_CONFIRM=true
			shift
			;;
		--generate-backup)
			GENERATE_BACKUP=true
			shift
			;;
		--dry-run)
			DRY_RUN=true
			shift
			;;
		-h | --help)
			usage
			exit 0
			;;
		*)
			echo "ERROR: Unknown option: $1"
			usage
			exit 1
			;;
	esac
done

if [[ ! -f "${CONFIG}" ]]; then
	echo "ERROR: Missing ${CONFIG}"
	echo "Run: ./bin/configure-vip-sync.sh"
	echo "Or:  cp config/vip-sync.yaml.example config/vip-sync.yaml"
	exit 1
fi

if ! command -v vip >/dev/null 2>&1; then
	echo "ERROR: vip (VIP-CLI) not found in PATH."
	echo "Install: npm install -g @automattic/vip"
	exit 1
fi

if ! command -v ddev >/dev/null 2>&1; then
	echo "ERROR: ddev not found in PATH."
	exit 1
fi

if ! ddev describe >/dev/null 2>&1; then
	echo "ERROR: DDEV project is not running. Run: ddev start"
	exit 1
fi

APP="$(yaml_value app "${CONFIG}")"
ENV="$(yaml_value env "${CONFIG}")"
REMOTE_URL="$(yaml_value remote_url "${CONFIG}")"

if [[ -z "${APP}" || -z "${ENV}" || -z "${REMOTE_URL}" ]]; then
	echo "ERROR: config/vip-sync.yaml must set app, env, and remote_url."
	exit 1
fi

if [[ -z "${GENERATE_BACKUP}" ]] && yaml_bool generate_backup "${CONFIG}"; then
	GENERATE_BACKUP=true
fi

LOCAL_URL="$(local_ddev_url)"
REMOTE_URL="${REMOTE_URL%/}"
LOCAL_URL="${LOCAL_URL%/}"

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
DUMP_DIR="${ROOT}/private/vip-sync"
DUMP_FILE="${DUMP_DIR}/vip-${APP}-${ENV}-${TIMESTAMP}.sql.gz"
VIP_TARGET="@${APP}.${ENV}"

echo "=== VIP database sync ==="
echo ""
echo "Source:         vip ${VIP_TARGET} export sql"
echo "Export file:    ${DUMP_FILE}"
echo "Import target:  DDEV project $(grep -E '^name:' "${ROOT}/.ddev/config.yaml" | awk '{print $2}')"
echo "Search-replace: ${REMOTE_URL} -> ${LOCAL_URL}"
if [[ "${GENERATE_BACKUP}" == true ]]; then
	echo "Backup:         generate fresh backup on VIP before export"
fi
echo ""
echo "WARNING: This will overwrite the local DDEV database."
echo ""

if [[ "${DRY_RUN}" == true ]]; then
	echo "Dry run — no changes made."
	exit 0
fi

if [[ "${SKIP_CONFIRM}" != true ]]; then
	read -r -p "Proceed? [y/N] " reply
	if [[ ! "${reply}" =~ ^[Yy]$ ]]; then
		echo "Aborted."
		exit 0
	fi
fi

mkdir -p "${DUMP_DIR}"

EXPORT_ARGS=(export sql --output="${DUMP_FILE}")
if [[ "${GENERATE_BACKUP}" == true ]]; then
	EXPORT_ARGS+=(--generate-backup)
fi

echo "Exporting from VIP ..."
vip "${VIP_TARGET}" "${EXPORT_ARGS[@]}"

if [[ ! -f "${DUMP_FILE}" ]]; then
	echo "ERROR: Export file not found: ${DUMP_FILE}"
	exit 1
fi

echo "Importing into DDEV ..."
ddev import-db --file="${DUMP_FILE}"

echo "Updating URLs ..."
ddev wp search-replace "${REMOTE_URL}" "${LOCAL_URL}" --skip-columns=guid --all-tables

if [[ "${REMOTE_URL}" == https://* ]]; then
	REMOTE_HTTP="${REMOTE_URL/https:\/\//http://}"
	LOCAL_HTTP="${LOCAL_URL/https:\/\//http://}"
	if [[ "${REMOTE_HTTP}" != "${REMOTE_URL}" ]]; then
		ddev wp search-replace "${REMOTE_HTTP}" "${LOCAL_HTTP}" --skip-columns=guid --all-tables
	fi
fi

echo "Flushing cache ..."
ddev wp cache flush

echo ""
echo "=== Sync complete ==="
echo "Site: ${LOCAL_URL}"
echo "Dump: ${DUMP_FILE}"
echo ""
echo "Optional: reindex Enterprise Search"
echo "  ddev wp vip-search index --setup --skip-confirm"
