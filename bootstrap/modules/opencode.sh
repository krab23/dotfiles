#!/usr/bin/env bash

set -euo pipefail

module_opencode() {
  if [ "${CONFIG_ONLY:-0}" != 1 ]; then
    distro_install_opencode
  fi

  link_with_backup "$DOTFILES_ROOT/opencode/opencode.json" "${XDG_CONFIG_HOME:-$HOME/.config}/opencode/opencode.json"
}
