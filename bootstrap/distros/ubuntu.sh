#!/usr/bin/env bash

set -euo pipefail

distro_install_base_packages() {
  pkg_install ca-certificates curl git gnupg lsb-release ripgrep zsh
}

distro_install_docker() {
  if command_exists docker; then
    log_info "Docker already installed; skipping engine install."
    return 0
  fi

  log_info "Installing Docker Engine (Ubuntu family)."
  pkg_install ca-certificates curl gnupg lsb-release

  run_sudo install -m 0755 -d /etc/apt/keyrings

  if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
    if [ "${DRY_RUN:-0}" = "1" ]; then
      printf "[dry-run] curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg\n"
    else
      curl -fsSL https://download.docker.com/linux/ubuntu/gpg | run_sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    fi
    run_sudo chmod a+r /etc/apt/keyrings/docker.gpg
  fi

  local arch
  local codename
  local repo_line
  arch="$(ubuntu_package_arch)"
  codename="$(
    . /etc/os-release
    printf "%s" "${VERSION_CODENAME:-noble}"
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
  if command_exists nvim; then
    log_info "Neovim already installed; skipping binary install."
    return 0
  fi

  log_info "Installing Neovim AppImage (Ubuntu family)."
  pkg_install fuse libfuse2

  local appimage
  appimage="$DOTFILES_ROOT/bin/nvim.appimage"
  ensure_dir "$DOTFILES_ROOT/bin"

  run_cmd curl -L -o "$appimage" "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.appimage"
  run_cmd chmod u+x "$appimage"
  run_sudo ln -sfn "$appimage" /usr/local/bin/nvim
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
