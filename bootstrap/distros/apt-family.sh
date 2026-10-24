#!/usr/bin/env bash

set -euo pipefail

apt_family_package_arch() {
  local distro_label="$1"
  if command_exists dpkg; then
    dpkg --print-architecture
  elif [ "${DRY_RUN:-0}" = "1" ]; then
    printf "<dpkg-architecture>\n"
  else
    log_error "dpkg not found; cannot determine ${distro_label} package architecture."
    return 1
  fi
}

# Arguments describe the wrapper-specific codename policy. Ubuntu permits its
# UBUNTU_CODENAME to identify the base release even on a derivative; Debian does
# not have an equivalent cross-distro field.
apt_family_docker_codename() {
  local native_id="$1"
  local cross_distro_var="$2"
  local fallback_var="$3"
  local placeholder="$4"
  local os_release_file="${APT_FAMILY_OS_RELEASE_FILE:-/etc/os-release}"
  # Codename variables are read indirectly through the wrapper's field names.
  # shellcheck disable=SC2034
  local ID="" VERSION_CODENAME="" UBUNTU_CODENAME=""
  local codename=""

  # Production uses /etc/os-release; tests override it.
  # shellcheck source=/dev/null
  . "$os_release_file"

  if [ "${DRY_RUN:-0}" = 1 ] && [ "$ID" != "$native_id" ]; then
    if [ -z "$cross_distro_var" ] || [ -z "${!cross_distro_var:-}" ]; then
      printf '%s' "$placeholder"
      return 0
    fi
  fi

  if [ -n "$cross_distro_var" ]; then
    codename="${!cross_distro_var:-}"
  fi
  if [ -z "$codename" ]; then
    codename="${!fallback_var:-}"
  fi
  if [ -z "$codename" ]; then
    log_error "Missing $fallback_var in $os_release_file"
    return 1
  fi
  printf '%s' "$codename"
}

distro_install_opencode() {
  [ "${CONFIG_ONLY:-0}" != 1 ] || return 0
  source "$DOTFILES_ROOT/bootstrap/lib/opencode.sh"
  if ! command_exists opencode && [ ! -x "$HOME/.opencode/bin/opencode" ]; then
    pkg_install curl ca-certificates tar gzip
  fi
  opencode_install_upstream
}

distro_install_docker() {
  log_info "Installing Docker Engine (${APT_FAMILY_LABEL} family)."
  pkg_install ca-certificates curl gnupg lsb-release

  run_sudo install -m 0755 -d /etc/apt/keyrings

  if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
    if [ "${DRY_RUN:-0}" = "1" ]; then
      printf '[dry-run] curl -fsSL https://download.docker.com/linux/%s/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg\n' "$APT_FAMILY_DOCKER_DISTRO"
    else
      local armored_key key_file
      make_temp
      armored_key="$TEMP_FILE"
      make_temp
      key_file="$TEMP_FILE"
      curl -fsSL -o "$armored_key" "https://download.docker.com/linux/${APT_FAMILY_DOCKER_DISTRO}/gpg"
      gpg --batch --dearmor < "$armored_key" > "$key_file"
      run_sudo install -m 0644 "$key_file" /etc/apt/keyrings/docker.gpg
    fi
    run_sudo chmod a+r /etc/apt/keyrings/docker.gpg
  fi

  local arch codename repo_line
  arch="$(distro_package_arch)"
  codename="$(distro_docker_codename)"
  repo_line="deb [arch=${arch} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${APT_FAMILY_DOCKER_DISTRO} ${codename} stable"

  if [ "${DRY_RUN:-0}" = "1" ]; then
    printf '[dry-run] write /etc/apt/sources.list.d/docker.list: %s\n' "$repo_line"
  else
    printf '%s\n' "$repo_line" | run_sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
  fi

  # Invalidate the cache owned by bootstrap/lib/packages.sh after adding a repo.
  # shellcheck disable=SC2034
  PKG_DB_UPDATED=0
  pkg_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}

distro_install_nvim() {
  [ "${CONFIG_ONLY:-0}" != "1" ] || return 0
  source "$DOTFILES_ROOT/bootstrap/lib/nvim.sh"
  nvim_require_arch || return 1
  pkg_install ca-certificates curl git ripgrep build-essential nodejs npm python3 python3-pip python3-venv python3-pynvim tar gzip unzip xz-utils libtinfo6 libstdc++6 zlib1g libzstd1 libxml2 libedit2
  nvim_install_debian
}
