#!/usr/bin/env bash
# Export VIP Platform database via VIP-CLI and import into local DDEV.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="${ROOT}/config/vip-sync.yaml"

SKIP_CONFIRM=false
DRY_RUN=false
GENERATE_BACKUP=""

# Populated by build_search_replace_plan: one "from" domain/URL per line.
SEARCH_REPLACE_FROM=()

usage() {
	cat <<EOF
Usage: $(basename "$0") [options]

Export a VIP Platform database and import it into this DDEV project.

Options:
  -y, --yes              Skip confirmation prompt
  --generate-backup      Request a fresh VIP backup before export
  --dry-run              Show what would run without making changes
  -h, --help             Show this help

Configure app/env in config/vip-sync.yaml (see config/vip-sync.yaml.example).
Search-replace uses config/.vip.<app>.<env>.yml when present, else VIP-CLI siteurl/home.
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

find_vip_data_sync_config() {
	local app="$1" env="$2"
	local exact="${ROOT}/config/.vip.${app}.${env}.yml"
	local match

	if [[ -f "${exact}" ]]; then
		echo "${exact}"
		return 0
	fi

	match="$(find "${ROOT}/config" -maxdepth 1 -name ".vip.${app}.${env}.*.yml" 2>/dev/null | head -1 || true)"
	if [[ -n "${match}" ]]; then
		echo "${match}"
		return 0
	fi

	return 1
}

# Print domain_map pairs (from<TAB>to) in file order.
parse_domain_map() {
	local file="$1"
	ruby -ryaml -rpathname -e '
		path = Pathname.new(ARGV[0])
		data = YAML.load_file(path)
		map = data&.dig("data_sync", "domain_map")
		unless map.is_a?(Hash) && !map.empty?
			warn "ERROR: #{path} missing data_sync.domain_map"
			exit 1
		end
		map.each { |from, to| puts "#{from}\t#{to}" }
	' "${file}"
}

vip_wp() {
	local app="$1" env="$2"
	shift 2
	vip "@${app}.${env}" --yes -- wp "$@"
}

# Add unique entry to SEARCH_REPLACE_FROM.
add_replace_from() {
	local candidate="$1"
	local existing
	candidate="${candidate%/}"
	[[ -z "${candidate}" ]] && return 0
	if [[ ${#SEARCH_REPLACE_FROM[@]} -gt 0 ]]; then
		for existing in "${SEARCH_REPLACE_FROM[@]}"; do
			if [[ "${existing}" == "${candidate}" ]]; then
				return 0
			fi
		done
	fi
	SEARCH_REPLACE_FROM+=("${candidate}")
}

infer_urls_from_vip_cli() {
	local app="$1" env="$2"
	local siteurl home url

	echo "Querying VIP-CLI for site URLs on @${app}.${env} ..." >&2

	siteurl="$(vip_wp "${app}" "${env}" option get siteurl 2>/dev/null | tr -d '\r' || true)"
	home="$(vip_wp "${app}" "${env}" option get home 2>/dev/null | tr -d '\r' || true)"

	add_replace_from "${siteurl}"
	add_replace_from "${home}"

	while IFS= read -r url; do
		add_replace_from "${url}"
	done < <(vip_wp "${app}" "${env}" site list --field=url --format=csv 2>/dev/null | tr -d '\r' || true)

	if [[ ${#SEARCH_REPLACE_FROM[@]} -eq 0 ]]; then
		echo "ERROR: Could not infer site URLs from VIP-CLI for @${app}.${env}."
		echo "Add config/.vip.${app}.${env}.yml or check VIP-CLI access."
		return 1
	fi
}

build_search_replace_plan() {
	local app="$1" env="$2"
	local sync_config from to

	SEARCH_REPLACE_FROM=()

	if sync_config="$(find_vip_data_sync_config "${app}" "${env}")"; then
		echo "Using VIP data sync config: ${sync_config#"${ROOT}/"}" >&2
		while IFS=$'\t' read -r from to; do
			[[ -z "${from}" || -z "${to}" ]] && continue
			if [[ "${env}" == "production" ]]; then
				add_replace_from "${from}"
			else
				add_replace_from "${to}"
				add_replace_from "${from}"
			fi
		done < <(parse_domain_map "${sync_config}")
	fi

	if [[ ${#SEARCH_REPLACE_FROM[@]} -eq 0 ]]; then
		if [[ -f "${ROOT}/config/.vip.${app}.${env}.yml" ]] || compgen -G "${ROOT}/config/.vip.${app}.${env}.*.yml" >/dev/null 2>&1; then
			echo "ERROR: Found a data sync config but could not parse domain_map."
			return 1
		fi
		echo "WARN: No config/.vip.${app}.${env}.yml found." >&2
		echo "      Falling back to VIP-CLI siteurl/home inference." >&2
		echo "      For multisite, add a data sync config:" >&2
		echo "      https://docs.wpvip.com/databases/data-sync/config-file/" >&2
		infer_urls_from_vip_cli "${app}" "${env}" || return 1
	fi
}

apply_search_replace() {
	local from="$1" to="$2"
	local variants=() variant http_to http_from

	variants+=("${from}")

	if [[ "${from}" != http* ]]; then
		variants+=("https://${from}" "http://${from}")
	fi

	if [[ "${from}" == https://* ]]; then
		variants+=("${from/https:\/\//http://}")
	fi

	for variant in "${variants[@]}"; do
		[[ -z "${variant}" ]] && continue
		if [[ "${variant}" == http://* ]]; then
			http_from="${variant}"
			http_to="${to/https:\/\//http://}"
			ddev wp search-replace "${http_from}" "${http_to}" --skip-columns=guid --all-tables
		else
			ddev wp search-replace "${variant}" "${to}" --skip-columns=guid --all-tables
		fi
	done
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

if [[ -z "${APP}" || -z "${ENV}" ]]; then
	echo "ERROR: config/vip-sync.yaml must set app and env."
	exit 1
fi

if [[ -z "${GENERATE_BACKUP}" ]] && yaml_bool generate_backup "${CONFIG}"; then
	GENERATE_BACKUP=true
fi

LOCAL_URL="$(local_ddev_url)"
LOCAL_URL="${LOCAL_URL%/}"

if ! build_search_replace_plan "${APP}" "${ENV}"; then
	exit 1
fi

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
DUMP_DIR="${ROOT}/private/vip-sync"
DUMP_FILE="${DUMP_DIR}/vip-${APP}-${ENV}-${TIMESTAMP}.sql.gz"
VIP_TARGET="@${APP}.${ENV}"

echo "=== VIP database sync ==="
echo ""
echo "Source:         vip ${VIP_TARGET} export sql"
echo "Export file:    ${DUMP_FILE}"
echo "Import target:  DDEV project $(grep -E '^name:' "${ROOT}/.ddev/config.yaml" | awk '{print $2}')"
echo "Local URL:      ${LOCAL_URL}"
echo "Search-replace (in order):"
for from in "${SEARCH_REPLACE_FROM[@]}"; do
	echo "  ${from} -> ${LOCAL_URL}"
done
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

echo "Ensuring WordPress core is present ..."
"${ROOT}/bin/ensure-wordpress-core.sh"

echo "Updating URLs ..."
for from in "${SEARCH_REPLACE_FROM[@]}"; do
	apply_search_replace "${from}" "${LOCAL_URL}"
done

echo "Flushing cache ..."
ddev wp cache flush

echo ""
echo "=== Sync complete ==="
echo "Site: ${LOCAL_URL}"
echo "Dump: ${DUMP_FILE}"
echo ""
echo "Optional: reindex Enterprise Search"
echo "  ddev wp vip-search index --setup --skip-confirm"
echo ""
echo "Updating media proxy (missing uploads -> VIP) ..."
"${ROOT}/bin/update-vip-media-proxy.sh"
echo "Run ddev restart if the project was already running."
