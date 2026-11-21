#!/usr/bin/env bash

set -euo pipefail

module_opencode() {
  if [ "${CONFIG_ONLY:-0}" != 1 ]; then
    distro_install_opencode
  fi

  local config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"
  # Do not shadow an existing JSONC config or replace provider/auth settings.
  if [ -e "$config_dir/opencode.jsonc" ] || [ -L "$config_dir/opencode.jsonc" ]; then
    log_info "Preserving existing OpenCode JSONC config: $config_dir/opencode.jsonc"
  else
    opencode_link_if_missing "$DOTFILES_ROOT/opencode/opencode.json" "$config_dir/opencode.json"
  fi
  opencode_link_if_missing "$DOTFILES_ROOT/opencode/cli.json" "$config_dir/cli.json"
}

opencode_link_if_missing() {
  local source="$1" target="$2"
  if [ -e "$target" ] || [ -L "$target" ]; then
    if [ -L "$target" ] && [ "$(readlink "$target")" = "$(abs_path "$source")" ]; then
      log_info "Symlink already correct: $target -> $source"
    else
      log_info "Preserving existing OpenCode config: $target (review repository defaults manually)"
    fi
    return 0
  fi
  link_with_backup "$source" "$target"
}
