#!/usr/bin/env bash

set -euo pipefail

distro_install_base_packages() {
  pkg_install base-devel ca-certificates curl git ripgrep zsh
}

distro_install_docker() {
  if command_exists docker; then
    log_info "Docker already installed; skipping engine install."
    return 0
  fi

  log_info "Installing Docker packages (Arch family)."
  pkg_install docker docker-compose
  log_warn "If needed, enable Docker manually: sudo systemctl enable --now docker"
}

distro_install_nvim() {
  log_info "Installing Neovim packages (Arch family)."
  pkg_install neovim tree-sitter-cli
}
