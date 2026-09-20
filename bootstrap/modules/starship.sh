#!/usr/bin/env bash

set -euo pipefail

module_starship() {
  if [ "${CONFIG_ONLY:-0}" = 1 ]; then
    :
  elif [ "$DISTRO_FAMILY" = arch ]; then
    pkg_install starship
  elif ! command_exists starship; then
    pkg_install curl ca-certificates tar gzip
    log_info "Installing Starship."
    local installer
    make_temp
    installer="$TEMP_FILE"
    run_cmd curl -fsSL -o "$installer" "https://starship.rs/install.sh"
    run_sudo sh "$installer" -y --bin-dir /usr/local/bin
  else
    log_info "Starship already installed; skipping binary install."
  fi

  link_with_backup "$DOTFILES_ROOT/starship/starship.toml" "${XDG_CONFIG_HOME:-$HOME/.config}/starship.toml"
}
