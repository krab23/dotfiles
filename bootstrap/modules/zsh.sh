#!/usr/bin/env bash

set -euo pipefail

module_zsh() {
  if [ "${CONFIG_ONLY:-0}" = 1 ]; then
    link_with_backup "$DOTFILES_ROOT/zsh/zshrc" "$HOME/.zshrc"
    return 0
  fi
  pkg_install zsh git curl ca-certificates

  if [ ! -d "$HOME/.oh-my-zsh" ]; then
    log_info "Installing Oh My Zsh."
    local installer
    make_temp
    installer="$TEMP_FILE"
    run_cmd curl -fsSL -o "$installer" "https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh"
    run_cmd env ZSH="$HOME/.oh-my-zsh" CHSH=no RUNZSH=no KEEP_ZSHRC=yes sh "$installer" --unattended
  else
    log_info "Oh My Zsh already installed; skipping."
  fi

  link_with_backup "$DOTFILES_ROOT/zsh/zshrc" "$HOME/.zshrc"

  local target_user
  local current_shell
  local zsh_shell
  target_user="$TARGET_USER"

  zsh_shell="$(preferred_zsh_login_shell)"
  current_shell="$TARGET_SHELL"
  if [ -z "$current_shell" ]; then
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
  if [ "${DRY_RUN:-0}" = 1 ]; then
    printf '%s\n' /usr/bin/zsh
    return 0
  fi
  local candidate
  for candidate in /usr/bin/zsh /bin/zsh "$(command -v zsh || true)"; do
    if [ -x "$candidate" ] && grep -Fxq "$candidate" /etc/shells; then
      printf "%s\n" "$candidate"
      return 0
    fi
  done

  log_error "No zsh login shell found in /etc/shells"
  exit 1
}
