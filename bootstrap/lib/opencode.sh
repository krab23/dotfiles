#!/usr/bin/env bash

set -euo pipefail

opencode_install_upstream() {
  [ "${CONFIG_ONLY:-0}" != 1 ] || return 0
  local existing="" version
  if command_exists opencode; then
    existing=opencode
  elif [ -x "$HOME/.opencode/bin/opencode" ]; then
    existing="$HOME/.opencode/bin/opencode"
  fi
  if [ -n "$existing" ]; then
    log_info "OpenCode already installed; skipping binary install."
    # Even --version may initialize OpenCode's user directories on first use.
    [ "${DRY_RUN:-0}" != 1 ] || return 0
    version="$("$existing" --version 2>/dev/null || true)"
    if [[ "$version" =~ (^|[[:space:]])v?1\. ]]; then
      log_warn "Existing OpenCode V1 is retained. To migrate, follow https://opencode.ai/v2/docs/migrate-v1 (remove package-managed V1 before using the V2 installer)."
    fi
    return 0
  fi

  log_info "Installing OpenCode into $HOME/.opencode/bin."
  local installer
  make_temp
  installer="$TEMP_FILE"
  run_cmd curl -fsSL -o "$installer" https://opencode.ai/v2/install
  run_cmd env SHELL="${SHELL:-/bin/bash}" bash "$installer" --no-modify-path
}
