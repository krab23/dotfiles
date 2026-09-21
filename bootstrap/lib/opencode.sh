#!/usr/bin/env bash

set -euo pipefail

opencode_install_upstream() {
  [ "${CONFIG_ONLY:-0}" != 1 ] || return 0
  if command_exists opencode || [ -x "$HOME/.opencode/bin/opencode" ]; then
    log_info "OpenCode already installed; skipping binary install."
    return 0
  fi

  log_info "Installing OpenCode into $HOME/.opencode/bin."
  local installer
  make_temp
  installer="$TEMP_FILE"
  run_cmd curl -fsSL -o "$installer" https://opencode.ai/install
  run_cmd env SHELL="${SHELL:-/bin/bash}" bash "$installer" --no-modify-path
}
