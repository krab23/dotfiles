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

  local target_user
  local current_shell
  local zsh_shell
  target_user="${SUDO_USER:-${USER:-}}"
  if [ -z "$target_user" ]; then
    target_user="$(id -un)"
  fi

  zsh_shell="$(preferred_zsh_login_shell)"
  if ! current_shell="$(getent passwd "$target_user" | cut -d: -f7)" || [ -z "$current_shell" ]; then
    log_error "Could not determine current shell for user: $target_user"
    exit 1
  fi

  if [ "$current_shell" != "$zsh_shell" ]; then
    log_info "Changing default shell for $target_user: $current_shell -> $zsh_shell"
    run_sudo chsh -s "$zsh_shell" "$target_user"
  else
    log_info "Default shell already zsh: $current_shell"
  fi
}

preferred_zsh_login_shell() {
  local candidate
  for candidate in /usr/bin/zsh /bin/zsh "$(command -v zsh)"; do
    if [ -x "$candidate" ] && grep -Fxq "$candidate" /etc/shells; then
      printf "%s\n" "$candidate"
      return 0
    fi
  done

  log_error "No zsh login shell found in /etc/shells"
  exit 1
}
