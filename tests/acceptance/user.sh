#!/usr/bin/env bash
set -euo pipefail
if [ "${HOME:-}" != /home/tester ] || [ ! -f /.dockerenv ] || [ "$(id -u)" = 0 ]; then
  printf 'This script is only for the disposable acceptance user.\n' >&2
  exit 1
fi
cd "$HOME/dotfiles"
export PATH="$HOME/.local/bin:$HOME/.opencode/bin:$PATH"
export DOTFILES_ROOT="$PWD"
printf 'original shell config\n' > "$HOME/.zshrc"
printf '[user]\n  name = Acceptance\n  email = acceptance@example.invalid\n' > "$HOME/.gitconfig.local"
cp "$HOME/.gitconfig.local" "$HOME/identity.expected"
lock_before="$(sha256sum nvim/lazy-lock.json)"
for phase in first rerun; do
  printf '\n=== %s install ===\n' "$phase"
  # Container acceptance covers real packages/provisioning, not Docker services.
  bash bootstrap/install.sh --skip docker
  cmp "$HOME/.gitconfig.local" "$HOME/identity.expected"
  [ "$(readlink "$HOME/.zshrc")" = "$PWD/zsh/zshrc" ]
  [ "$(sha256sum nvim/lazy-lock.json)" = "$lock_before" ]
  backups=("$HOME/.zshrc.backup."*)
  [ "${#backups[@]}" = 1 ]
  [ "$(cat "${backups[0]}")" = 'original shell config' ]
  zsh -ic '[[ $EDITOR == nvim ]]'
  git --version
  starship --version
  opencode_version="$(opencode --version)"
  printf '%s\n' "$opencode_version"
  if [[ ! "$opencode_version" =~ ^(opencode[[:space:]]+)?v?2\.[0-9]+\.[0-9]+ ]]; then
    printf 'Expected OpenCode V2, got: %s\n' "$opencode_version" >&2
    exit 1
  fi
  nvim --version
  DOTFILES_NVIM_PROVISION=1 nvim --headless -i NONE \
    '+lua dofile(vim.env.DOTFILES_ROOT .. "/nvim/tests/smoke.lua")'
done
printf 'PASS: real package install/rerun, config preservation, LSP and debugger startup.\n'
printf 'Docker services, login sessions and WSL interop require VM/WSL acceptance.\n'
