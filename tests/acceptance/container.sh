#!/usr/bin/env bash
set -euo pipefail
if [ "${DOTFILES_DISPOSABLE_ACCEPTANCE:-}" != 1 ] || [ ! -f /.dockerenv ] || [ "$(id -u)" != 0 ]; then
  printf 'Run through tests/acceptance.sh in a disposable Docker container.\n' >&2
  exit 1
fi
source /etc/os-release
printf 'Acceptance target: %s; kernel: %s\n' "$PRETTY_NAME" "$(uname -srmo)"
case "$ID" in
  debian)
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y sudo git ca-certificates
    ;;
  arch)
    pacman -Syu --noconfirm --needed sudo git ca-certificates
    ;;
  *) exit 1 ;;
esac
useradd --create-home --shell /bin/bash tester
printf 'tester ALL=(ALL) NOPASSWD: ALL\n' > /etc/sudoers.d/tester
chmod 440 /etc/sudoers.d/tester
mkdir /home/tester/dotfiles
# Exclude local caches, .git, and agent dependencies from the disposable copy.
tar -C /input --exclude=.git --exclude=node_modules -cf - \
  bootstrap git nvim opencode starship zsh tests | tar -C /home/tester/dotfiles -xf -
chown -R tester:tester /home/tester/dotfiles
sudo -iu tester bash /home/tester/dotfiles/tests/acceptance/user.sh
