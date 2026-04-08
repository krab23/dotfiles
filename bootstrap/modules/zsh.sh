#!/usr/bin/env bash

set -euo pipefail

module_zsh() {
  distro_install_base_packages

  if [ ! -d "$HOME/.oh-my-zsh" ]; then
    log_info "Installing Oh My Zsh."
    local installer
    installer="$(mktemp)"
    run_cmd curl -fsSL -o "$installer" "https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh"
    run_cmd sh "$installer" --unattended
    run_cmd rm -f "$installer"
  else
    log_info "Oh My Zsh already installed; skipping."
  fi

  link_with_backup "$DOTFILES_ROOT/zsh/zshrc" "$HOME/.zshrc"

  if [ "${SHELL:-}" != "$(command -v zsh)" ]; then
    log_warn "Default shell is not zsh. Run: chsh -s $(command -v zsh)"
  fi
}
