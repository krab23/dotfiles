#!/usr/bin/env bash

set -euo pipefail

module_git() {
  link_with_backup "$DOTFILES_ROOT/git/gitconfig" "$HOME/.gitconfig"

  if [[ ! -e "$HOME/.gitconfig.local" ]]; then
    run_cmd touch "$HOME/.gitconfig.local"
    run_cmd chmod 600 "$HOME/.gitconfig.local"
  fi
}
