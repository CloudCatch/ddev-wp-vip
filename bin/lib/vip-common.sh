#!/usr/bin/env bash
# Shared helpers for VIP + DDEV scripts.
# shellcheck shell=bash

vip_common_detect_sync_from_configs() {
	local config_dir="$1"
	local file base

	shopt -s nullglob
	local files=( "${config_dir}"/.vip.*.yml )
	shopt -u nullglob

	[[ ${#files[@]} -gt 0 ]] || return 1

	file="$(printf '%s\n' "${files[@]}" | sort | head -1)"
	base="$(basename "${file}")"

	if [[ "${base}" =~ ^\.vip\.([^.]+)\.([^.]+)\.([^.]+)\.yml$ ]]; then
		echo "${BASH_REMATCH[1]} ${BASH_REMATCH[2]}"
	elif [[ "${base}" =~ ^\.vip\.([^.]+)\.([^.]+)\.yml$ ]]; then
		echo "${BASH_REMATCH[1]} ${BASH_REMATCH[2]}"
	else
		return 1
	fi
}

vip_common_write_sync_config() {
	local target="$1" app="$2" env="$3"
	local out="${target}/config/vip-sync.yaml"

	mkdir -p "${target}/config"
	cat >"${out}" <<EOF
# VIP Platform database sync (gitignored). Used by: ddev vip-db-sync
app: ${app}
env: ${env}
EOF
}

vip_common_normalize_name() {
	echo "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9-]+/-/g; s/^-+|-+$//g'
}

vip_common_abs_path() {
	local path="$1"

	path="${path/#\~/${HOME}}"
	case "${path}" in
		/*) printf '%s\n' "${path}" ;;
		*) printf '%s\n' "$(pwd)/${path#./}" ;;
	esac
}

# Always run ddev from the project root (never rely on caller cwd).
vip_common_ddev() {
	local root="$1"
	shift
	(cd "${root}" && ddev "$@")
}

# Start DDEV at root; if the name is registered elsewhere, unlist and retry.
vip_common_ddev_start() {
	local root="$1"
	local name="${2:-}"

	if vip_common_ddev "${root}" start; then
		return 0
	fi

	if [[ -n "${name}" ]]; then
		echo "WARN: DDEV name '${name}' may be registered at another path; re-registering ..." >&2
		ddev stop --unlist "${name}" 2>/dev/null || true
		vip_common_ddev "${root}" start
		return $?
	fi

	return 1
}

vip_common_is_vip_app_repo() {
	local dir="$1"
	[[ -d "${dir}/plugins" || -d "${dir}/vip-config" || -d "${dir}/client-mu-plugins" ]]
}

# curl ... | bash leaves stdin on the pipe; reattach the controlling terminal for prompts.
vip_common_attach_tty() {
	if [[ -t 0 ]]; then
		return 0
	fi
	if [[ -e /dev/tty ]]; then
		exec </dev/tty
		return 0
	fi
	echo "ERROR: Interactive wizard requires a terminal." >&2
	echo "       Clone the repo and run: ./bin/new-project.sh" >&2
	exit 1
}

# macOS cp exits 1 when source and dest are identical; safe under set -e.
vip_common_copy_if_missing() {
	local src="$1" dest="$2"

	[[ -f "${src}" ]] || return 0
	if [[ ! -e "${dest}" ]]; then
		cp "${src}" "${dest}"
	fi
}

vip_common_prompt_choice() {
	local prompt="$1" default="$2"
	local reply
	read -r -p "${prompt} [${default}]: " reply
	echo "${reply:-${default}}"
}

vip_common_prompt_yes_no() {
	local prompt="$1" default="${2:-y}"
	local reply hint="Y/n"
	[[ "${default}" == "n" ]] && hint="y/N"
	read -r -p "${prompt} [${hint}]: " reply
	reply="${reply:-${default}}"
	[[ "${reply}" =~ ^[Yy] ]]
}
