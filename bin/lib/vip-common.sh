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
