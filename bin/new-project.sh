#!/usr/bin/env bash
# Interactive wizard: spin up a new VIP + DDEV local project.
#
# One-liner (from anywhere):
#   curl -fsSL https://raw.githubusercontent.com/CloudCatch/ddev-wp-vip/main/bin/install.sh | bash
#
# Or from a template clone:
#   ./bin/new-project.sh
set -euo pipefail

TEMPLATE_REPO="${DDEV_VIP_TEMPLATE_REPO:-https://github.com/CloudCatch/ddev-wp-vip.git}"

# curl ... | bash runs from stdin — no script path. Clone template and re-exec from disk.
if [[ -z "${BASH_SOURCE[0]:-}" ]] || [[ ! -f "${BASH_SOURCE[0]}" ]]; then
	echo "Fetching DDEV VIP template ..."
	_bootstrap_temp="$(mktemp -d)"
	git clone --depth 1 "${TEMPLATE_REPO}" "${_bootstrap_temp}/ddev-wp-vip"
	chmod +x "${_bootstrap_temp}/ddev-wp-vip/bin/"*.sh 2>/dev/null || true
	exec "${_bootstrap_temp}/ddev-wp-vip/bin/new-project.sh"
fi

ensure_template() {
	local script_dir="$1"
	if [[ -f "${script_dir}/../.ddev/config.yaml" ]]; then
		cd "${script_dir}/.." && pwd
		return 0
	fi

	echo "Fetching DDEV VIP template ..." >&2
	local temp clone
	temp="$(mktemp -d)"
	clone="${temp}/ddev-wp-vip"
	git clone --depth 1 "${TEMPLATE_REPO}" "${clone}"
	chmod +x "${clone}"/bin/*.sh 2>/dev/null || true
	echo "${clone}"
}

run_wizard() {
	local template_root="$1"
	# shellcheck source=lib/vip-common.sh
	source "${template_root}/bin/lib/vip-common.sh"
	vip_common_attach_tty

	local project_name project_dir source_mode git_url local_path
	local vip_app vip_env db_mode default_app default_env detected target

	echo ""
	echo "=== VIP + DDEV — new project wizard ==="
	echo ""

	project_name="$(vip_common_prompt_choice "DDEV project name (e.g. ctp-local)" "$(basename "$(pwd)")")"
	project_name="$(vip_common_normalize_name "${project_name}")"

	project_dir="$(vip_common_prompt_choice "Project directory" "$(pwd)/${project_name}")"
	project_dir="${project_dir/#\~/${HOME}}"

	echo ""
	echo "VIP application code:"
	echo "  1) Clone from git"
	echo "  2) Already on disk (add DDEV to existing checkout)"
	echo "  3) Empty skeleton (no app code yet)"
	source_mode="$(vip_common_prompt_choice "Choice" "1")"

	case "${source_mode}" in
		1)
			git_url="$(vip_common_prompt_choice "Git URL (VIP application repo)" "")"
			if [[ -z "${git_url}" ]]; then
				echo "ERROR: Git URL is required." >&2
				exit 1
			fi
			;;
		2)
			local_path="$(vip_common_prompt_choice "Path to existing VIP repo" "")"
			local_path="${local_path/#\~/${HOME}}"
			if [[ ! -d "${local_path}" ]]; then
				echo "ERROR: Directory not found: ${local_path}" >&2
				exit 1
			fi
			project_dir="$(cd "${local_path}" && pwd)"
			;;
		3) ;;
		*)
			echo "ERROR: Invalid choice." >&2
			exit 1
			;;
	esac

	default_app=""
	default_env="develop"
	if [[ -d "${project_dir}/config" ]] && detected="$(vip_common_detect_sync_from_configs "${project_dir}/config" 2>/dev/null || true)"; then
		read -r default_app default_env <<<"${detected}"
		echo ""
		echo "Detected from config/.vip.*.yml: app=${default_app}, env=${default_env}"
	fi

	echo ""
	vip_app="$(vip_common_prompt_choice "VIP application slug (for vip @app.env)" "${default_app}")"
	vip_app="$(vip_common_normalize_name "${vip_app}")"
	vip_env="$(vip_common_prompt_choice "VIP environment (develop, staging, production)" "${default_env}")"

	if [[ -z "${vip_app}" ]]; then
		echo "ERROR: VIP application slug is required for database sync and VIP-CLI." >&2
		exit 1
	fi

	echo ""
	echo "Database after setup:"
	echo "  1) Sync from VIP Platform (vip export sql — needs VIP-CLI)"
	echo "  2) Fresh empty WordPress install"
	db_mode="$(vip_common_prompt_choice "Choice" "1")"

	echo ""
	echo "Summary"
	echo "  Directory:   ${project_dir}"
	echo "  DDEV name:   ${project_name}"
	echo "  VIP target:  @${vip_app}.${vip_env}"
	case "${source_mode}" in
		1) echo "  App source:  clone ${git_url}" ;;
		2) echo "  App source:  existing ${project_dir}" ;;
		3) echo "  App source:  empty skeleton" ;;
	esac
	case "${db_mode}" in
		1) echo "  Database:    sync from VIP" ;;
		*) echo "  Database:    fresh install" ;;
	esac
	echo ""

	if ! vip_common_prompt_yes_no "Proceed?" "y"; then
		echo "Aborted."
		exit 0
	fi

	echo ""
	mkdir -p "$(dirname "${project_dir}")"

	case "${source_mode}" in
		1)
			if [[ ! -d "${project_dir}/.ddev" ]]; then
				echo "Creating project from template ..."
				git clone --depth 1 "${TEMPLATE_REPO}" "${project_dir}"
				rm -rf "${project_dir}/.git"
			fi
			"${project_dir}/bin/integrate-vip-app.sh" --source "${git_url}" --yes "${project_dir}"
			;;
		2)
			"${template_root}/bin/integrate-vip-app.sh" --overlay-only --yes "${project_dir}"
			;;
		3)
			if [[ -d "${project_dir}" ]] && [[ -n "$(ls -A "${project_dir}" 2>/dev/null || true)" ]]; then
				echo "ERROR: ${project_dir} exists and is not empty." >&2
				exit 1
			fi
			echo "Creating empty skeleton ..."
			git clone --depth 1 "${TEMPLATE_REPO}" "${project_dir}"
			rm -rf "${project_dir}/.git"
			;;
	esac

	target="$(cd "${project_dir}" && pwd)"
	vip_common_write_sync_config "${target}" "${vip_app}" "${vip_env}"
	echo "Wrote config/vip-sync.yaml"

	cd "${target}"
	"${target}/bin/configure-project.sh" "${project_name}"
	"${target}/bin/vip-setup.sh"

	if ! command -v ddev >/dev/null 2>&1; then
		echo "ERROR: ddev not found in PATH." >&2
		exit 1
	fi

	ddev start

	case "${db_mode}" in
		1)
			if command -v vip >/dev/null 2>&1; then
				"${target}/bin/ensure-wordpress-core.sh"
				"${target}/bin/sync-vip-db.sh" --yes
				"${target}/bin/update-vip-media-proxy.sh" || true
				echo "Restarting DDEV to load media proxy nginx ..."
				ddev restart
			else
				echo "WARN: vip CLI not found — skipped database sync."
				echo "      Install: npm install -g @automattic/vip"
				echo "      Then run: ddev vip-db-sync"
				"${target}/bin/install-wordpress.sh"
			fi
			;;
		*)
			"${target}/bin/install-wordpress.sh"
			;;
	esac

	local url
	url="$(ddev exec printenv DDEV_PRIMARY_URL 2>/dev/null | tr -d '\r' || true)"
	url="${url:-https://${project_name}.ddev.site}"

	echo ""
	echo "=== Done ==="
	echo "  cd ${target}"
	echo "  Site:  ${url}"
	if [[ "${db_mode}" != "1" ]]; then
		echo "  Admin: ${url}/wp-admin/  (vipgo / password)"
	fi
	echo ""
	echo "Useful commands:"
	echo "  ddev vip-db-sync              # re-sync database from VIP"
	echo "  ddev vip-mu-plugins-update    # update platform mu-plugins"
	echo "  ddev wp vip-search index --setup --skip-confirm"
}

main() {
	local script_dir template_root

	script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

	if [[ -f "${script_dir}/../.ddev/config.yaml" ]]; then
		template_root="$(cd "${script_dir}/.." && pwd)"
	else
		template_root="$(ensure_template "${script_dir}")"
	fi

	run_wizard "${template_root}"
}

main "$@"
