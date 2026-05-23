#!/usr/bin/env bash

set -euo pipefail

distro_setup_locale() {
  local locale_name="${BOOTSTRAP_LOCALE:-en_US.UTF-8}"
  local locale_entry="${BOOTSTRAP_LOCALE_GEN_ENTRY:-${locale_name} UTF-8}"
  local locale_gen="/etc/locale.gen"
  local locale_conf="/etc/locale.conf"

  log_info "Configuring locale: $locale_name"

  if [ "${DRY_RUN:-0}" = "1" ]; then
    printf "[dry-run] ensure %s contains: %s\n" "$locale_gen" "$locale_entry"
    printf "[dry-run] locale-gen\n"
    printf "[dry-run] write %s: LANG=%s\n" "$locale_conf" "$locale_name"
    return 0
  fi

  if grep -Eq "^[#[:space:]]*${locale_entry//./\\.}$" "$locale_gen"; then
    run_sudo sed -i "s|^[#[:space:]]*${locale_entry//./\\.}$|${locale_entry}|" "$locale_gen"
  elif ! grep -Fxq "$locale_entry" "$locale_gen"; then
    printf "%s\n" "$locale_entry" | run_sudo tee -a "$locale_gen" >/dev/null
  fi

  run_sudo locale-gen
  printf "LANG=%s\n" "$locale_name" | run_sudo tee "$locale_conf" >/dev/null
}

distro_install_base_packages() {
  pkg_install base-devel ca-certificates curl git ripgrep zsh
}

distro_install_docker() {
  if command_exists docker; then
    log_info "Docker already installed; skipping engine install."
    return 0
  fi

  log_info "Installing Docker packages (Arch family)."
  pkg_install docker docker-compose
  log_warn "If needed, enable Docker manually: sudo systemctl enable --now docker"
}

distro_install_nvim() {
  log_info "Installing Neovim packages (Arch family)."
  pkg_install neovim tree-sitter-cli
}
