#!/usr/bin/env bash

set -euo pipefail

module_nvim() {
  CONFIG_ONLY=${CONFIG_ONLY:-0}
  if [ "$CONFIG_ONLY" != "1" ]; then
    distro_install_nvim
  fi
  link_with_backup "$DOTFILES_ROOT/nvim" "${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
  if [ "$CONFIG_ONLY" != "1" ]; then
    source "$DOTFILES_ROOT/bootstrap/lib/nvim.sh"
    nvim_provision
  fi
}
