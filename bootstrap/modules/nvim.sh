#!/usr/bin/env bash

set -euo pipefail

module_nvim() {
  distro_install_nvim
  link_with_backup "$DOTFILES_ROOT/nvim" "$HOME/.config/nvim"
}
