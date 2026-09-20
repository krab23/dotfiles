#!/usr/bin/env bash

set -euo pipefail

distro_install_docker() {
  log_info "Installing Docker Engine (Ubuntu family)."
  pkg_install ca-certificates curl gnupg lsb-release

  run_sudo install -m 0755 -d /etc/apt/keyrings

  if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
    if [ "${DRY_RUN:-0}" = "1" ]; then
      printf "[dry-run] curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg\n"
    else
      local armored_key key_file
      make_temp
      armored_key="$TEMP_FILE"
      make_temp
      key_file="$TEMP_FILE"
      curl -fsSL -o "$armored_key" https://download.docker.com/linux/ubuntu/gpg
      gpg --batch --dearmor < "$armored_key" > "$key_file"
      run_sudo install -m 0644 "$key_file" /etc/apt/keyrings/docker.gpg
    fi
    run_sudo chmod a+r /etc/apt/keyrings/docker.gpg
  fi

  local arch
  local codename
  local repo_line
  arch="$(ubuntu_package_arch)"
  codename="$(
    . /etc/os-release
    if [ "${DRY_RUN:-0}" = 1 ] && [ "${ID:-}" != ubuntu ] && [ -z "${UBUNTU_CODENAME:-}" ]; then
      printf '<ubuntu-codename>'
      exit 0
    fi
    printf "%s" "${UBUNTU_CODENAME:-${VERSION_CODENAME:?Missing VERSION_CODENAME in /etc/os-release}}"
  )"
  repo_line="deb [arch=${arch} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${codename} stable"

  if [ "${DRY_RUN:-0}" = "1" ]; then
    printf "[dry-run] write /etc/apt/sources.list.d/docker.list: %s\n" "$repo_line"
  else
    printf "%s\n" "$repo_line" | run_sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
  fi

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

ubuntu_package_arch() {
  if command_exists dpkg; then
    dpkg --print-architecture
  elif [ "${DRY_RUN:-0}" = "1" ]; then
    printf "<dpkg-architecture>\n"
  else
    log_error "dpkg not found; cannot determine Ubuntu package architecture."
    exit 1
  fi
}
