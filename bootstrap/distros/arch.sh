#!/usr/bin/env bash

set -euo pipefail

distro_install_opencode() {
  [ "${CONFIG_ONLY:-0}" != 1 ] || return 0
  pkg_install opencode
}

distro_install_docker() {
  log_info "Installing Docker packages (Arch family)."
  pkg_install docker docker-compose docker-buildx
}

distro_install_nvim() {
  [ "${CONFIG_ONLY:-0}" != "1" ] || return 0
  source "$DOTFILES_ROOT/bootstrap/lib/nvim.sh"
  nvim_require_arch || return 1
  log_info "Installing Neovim packages (Arch family)."
  pkg_install ca-certificates curl git ripgrep base-devel nodejs npm python python-pip python-pynvim tar gzip unzip xz tree-sitter-cli
  if ! nvim_version_ok nvim 0.12.0; then
    pkg_install neovim
  fi
  nvim_check_tools
}
