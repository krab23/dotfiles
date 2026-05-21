#!/usr/bin/env bash

set -euo pipefail

module_starship() {
  if ! command_exists starship; then
    log_info "Installing Starship."
    local installer
    if [ "${DRY_RUN:-0}" = "1" ]; then
      installer="${TMPDIR:-/tmp}/starship-install.sh"
    else
      installer="$(mktemp)"
    fi
    run_cmd curl -fsSL -o "$installer" "https://starship.rs/install.sh"
    run_cmd sh "$installer" -y
    run_cmd rm -f "$installer"
  else
    log_info "Starship already installed; skipping binary install."
  fi

  link_with_backup "$DOTFILES_ROOT/starship/starship.toml" "$HOME/.config/starship.toml"
}
