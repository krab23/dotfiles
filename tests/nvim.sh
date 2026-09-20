#!/usr/bin/env bash
set -euo pipefail

DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export DOTFILES_ROOT
source "$DOTFILES_ROOT/bootstrap/lib/common.sh"
source "$DOTFILES_ROOT/bootstrap/lib/nvim.sh"

for file in "$DOTFILES_ROOT"/bootstrap/{lib/nvim,modules/nvim,distros/arch,distros/debian,distros/ubuntu}.sh; do
  bash -n "$file"
done

fake_version() { printf '%s\n' "$VERSION"; }
for VERSION in 'NVIM v0.12.0' 'NVIM v0.12.5' 'NVIM v0.13.0' 'NVIM v1.0.0'; do
  nvim_version_ok fake_version 0.12.0
done
for VERSION in 'NVIM v0.11.6' 'NVIM v0.9.5' 'not a version'; do
  if nvim_version_ok fake_version 0.12.0; then
    log_error "Accepted incompatible version: $VERSION"; exit 1
  fi
done
VERSION='tree-sitter 0.26.0'
! nvim_version_ok fake_version 0.26.1
VERSION='tree-sitter 0.26.1'
nvim_version_ok fake_version 0.26.1
(
  uname() { printf 'aarch64\n'; }
  ! nvim_require_arch
)

# Config-only must work with no package manager, sudo or Neovim.
(
  source "$DOTFILES_ROOT/bootstrap/modules/nvim.sh"
  CONFIG_ONLY=1
  distro_install_nvim() { log_error 'Unexpected installation'; exit 1; }
  nvim_provision() { log_error 'Unexpected provisioning'; exit 1; }
  linked=0
  XDG_CONFIG_HOME=/isolated/config
  link_with_backup() {
    [ "$1" = "$DOTFILES_ROOT/nvim" ] && [ "$2" = /isolated/config/nvim ]
    linked=1
  }
  module_nvim
  [ "$linked" = 1 ]
  for distro in arch debian ubuntu; do
    source "$DOTFILES_ROOT/bootstrap/distros/$distro.sh"
    pkg_install() { log_error 'Unexpected package installation'; exit 1; }
    distro_install_nvim
  done
)

# Dry-run never downloads, creates directories, or runs Neovim.
(
  DRY_RUN=1
  curl() { exit 1; }
  mkdir() { exit 1; }
  nvim() { exit 1; }
  nvim_install_archive nvim test bad https://example.invalid/archive
  nvim_provision
)

scratch="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-nvim-test.XXXXXXXX")"
trap 'rm -rf "$scratch"' EXIT
export HOME="$scratch/home"
export XDG_CONFIG_HOME="$HOME/.config" XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state" XDG_CACHE_HOME="$HOME/.cache"
export XDG_RUNTIME_DIR="$scratch/run"
unset NVIM_APPNAME VIMINIT EXINIT NVIM_BOOTSTRAP_BIN
mkdir -p "$XDG_CONFIG_HOME" "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"
cp -R "$DOTFILES_ROOT/nvim" "$XDG_CONFIG_HOME/nvim"

fake_binary() {
  mkdir -p "$(dirname "$1")"
  printf '#!/bin/sh\nprintf "%%s\\n" "%s"\n' "$2" > "$1"
  chmod +x "$1"
}

# Model a fresh Debian 13 Node 20/npm 9 install plus a stale local Neovim.
# Exercise the real selection/link logic; only apt and archive transport mocked.
(
  export HOME="$scratch/debian20"
  system_bin="$scratch/debian-bin"
  fake_binary "$system_bin/node" v20.19.2
  fake_binary "$system_bin/npm" 9.2.0
  fake_binary "$system_bin/npx" 9.2.0
  fake_binary "$system_bin/nvim" 'NVIM v0.13.0'
  fake_binary "$system_bin/tree-sitter" 'tree-sitter 0.26.9'
  fake_binary "$HOME/.local/bin/nvim" 'NVIM v0.11.6'
  export PATH="$system_bin:$PATH"
  pkg_install() { :; }
  downloads=0
  nvim_install_archive() {
    [ "$1" = node ] && [ "$2" = "$NVIM_NODE_RELEASE" ] &&
      [ "$3" = "$NVIM_NODE_SHA256" ] && [ "$4" = "$NVIM_NODE_URL" ] || return 1
    downloads=$((downloads + 1))
    local target="$HOME/.local/opt/node-$2"
    fake_binary "$target/bin/node" "v$2"
    fake_binary "$target/bin/npm" 11.19.0
    fake_binary "$target/bin/npx" 11.19.0
    nvim_link_archive node "$target"
  }
  nvim_install_debian
  [ "$downloads" = 1 ]
  [ "$(type -P node)" = "$HOME/.local/bin/node" ]
  [ "$(readlink -f "$HOME/.local/bin/nvim")" = "$system_bin/nvim" ]
  [ "$(nvim --version)" = 'NVIM v0.13.0' ]
  nvim_node_ok
  # Future-shell ordering and a repeat install select the same complete bundle.
  PATH="$HOME/.local/bin:$system_bin:$PATH" nvim_check_tools
  nvim_install_debian
  [ "$downloads" = 1 ]
  fake_binary "$HOME/.local/bin/npx" 0.1.0
  nvim_install_debian
  [ "$downloads" = 2 ]
  nvim_node_ok
)

# Preserve a newer, working existing Node toolchain, even with older local files.
(
  export HOME="$scratch/newer-node"
  system_bin="$scratch/newer-bin"
  for binary in node npm npx nvim tree-sitter; do
    case "$binary" in
      node) version=v26.9.0 ;;
      npm|npx) version=11.19.0 ;;
      nvim) version='NVIM v0.13.0' ;;
      tree-sitter) version='tree-sitter 0.26.9' ;;
    esac
    fake_binary "$system_bin/$binary" "$version"
    fake_binary "$HOME/.local/bin/$binary" 0.1.0
  done
  export PATH="$system_bin:$PATH"
  pkg_install() { :; }
  nvim_install_archive() { log_error 'Unexpected downgrade/download'; return 1; }
  nvim_install_debian
  for binary in node npm npx nvim tree-sitter; do
    [ "$(readlink -f "$HOME/.local/bin/$binary")" = "$system_bin/$binary" ]
  done
  [ "$(node --version)" = v26.9.0 ]
)

# Rejected HTTP responses and checksum mismatches must never publish binaries.
(
  curl() { return 22; }
  export -f curl
  if bash -c 'source "$DOTFILES_ROOT/bootstrap/lib/common.sh"; source "$DOTFILES_ROOT/bootstrap/lib/nvim.sh"; nvim_install_archive nvim fail bad https://example.invalid/archive'; then
    exit 1
  fi
  [ ! -e "$HOME/.local/bin/nvim" ]
)
(
  curl() {
    local previous='' arg
    for arg in "$@"; do
      if [ "$previous" = -o ]; then printf 'corrupt\n' > "$arg"; return; fi
      previous="$arg"
    done
    return 1
  }
  export -f curl
  if bash -c 'source "$DOTFILES_ROOT/bootstrap/lib/common.sh"; source "$DOTFILES_ROOT/bootstrap/lib/nvim.sh"; nvim_install_archive nvim corrupt 0000000000000000000000000000000000000000000000000000000000000000 https://example.invalid/archive'; then
    exit 1
  fi
  [ ! -e "$HOME/.local/bin/nvim" ]
)

if command -v nvim >/dev/null; then
  nvim --headless -u NONE -i NONE \
    '+lua for _, f in ipairs(vim.fn.glob(vim.env.DOTFILES_ROOT .. "/nvim/**/*.lua", false, true)) do local fn, err = loadfile(f); if not fn then print(err); vim.cmd("cquit 1") end end' '+qa!'
  # Neovim itself continues after init.lua errors. Both provisioning entry points
  # must return failure before touching plugins/tools, including early require errors.
  (
    export XDG_CONFIG_HOME="$scratch/broken-config"
    mkdir -p "$XDG_CONFIG_HOME/nvim"
    ln -s "$DOTFILES_ROOT/nvim/lua" "$XDG_CONFIG_HOME/nvim/lua"
    printf 'error("injected init failure")\n' > "$XDG_CONFIG_HOME/nvim/init.lua"
    for phase in plugins tools; do
      if DOTFILES_NVIM_PROVISION=1 nvim --headless -i NONE \
        "+lua require('provision').$phase()"; then
        log_error "Provisioning accepted broken init.lua"; exit 1
      fi
    done
    # Failure after the completion marker must still be rejected via v:errmsg.
    printf 'vim.g.dotfiles_nvim_initialized = true\nerror("injected late init failure")\n' > "$XDG_CONFIG_HOME/nvim/init.lua"
    if DOTFILES_NVIM_PROVISION=1 nvim --headless -i NONE \
      '+lua require("provision").plugins()'; then
      log_error 'Accepted late startup error'; exit 1
    fi
    [ ! -e "$XDG_DATA_HOME/nvim/lazy" ]
    # Also verify the shell entry point catches a missing provision module.
    rm "$XDG_CONFIG_HOME/nvim/lua"
    if nvim_provision; then log_error 'Accepted missing provision module'; exit 1; fi
  )
else
  log_warn 'Neovim unavailable: Lua syntax check skipped.'
fi

if [ "${1:-}" = --integration ]; then
  # Network/compiler required. All plugins, npm/pip caches and Mason tools are
  # installed in the disposable HOME, never the user's real Neovim directories.
  nvim_install_pinned nvim
  nvim_install_pinned tree-sitter
  nvim_install_pinned node
  export PATH="$HOME/.local/bin:$PATH"
  [ "$(node --version)" = "v$NVIM_NODE_RELEASE" ]
  for binary in node npm npx; do
    [ "$(type -P "$binary")" = "$HOME/.local/bin/$binary" ]
    "$binary" --version
  done
  # npm/npx's symlinks must resolve the archive's JS entrypoints and selected Node.
  npm exec --yes --package=semver -- semver "$NVIM_NODE_RELEASE"
  npx --yes --package=semver -- semver "$NVIM_NODE_RELEASE"
  npm_config_engine_strict=true npx --yes --package=@github/copilot-language-server -- copilot-language-server --version
  # Repair missing npm/npx links from the verified installed bundle without HTTP.
  (
    rm "$HOME/.local/bin/npm" "$HOME/.local/bin/npx"
    curl() { log_error 'Unexpected repeat download'; return 1; }
    nvim_install_pinned node
    nvim_node_ok
  )
  nvim_check_tools
  nvim_provision
  DOTFILES_NVIM_PROVISION=1 nvim --headless -i NONE \
    '+lua dofile(vim.env.DOTFILES_ROOT .. "/nvim/tests/smoke.lua")'
fi
log_info 'Neovim checks passed.'
