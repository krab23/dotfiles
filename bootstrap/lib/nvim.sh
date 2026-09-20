#!/usr/bin/env bash

# Release pins shared by installation and integration tests. Neovim/Tree-sitter
# digests are GitHub release asset SHA256s; Node is from official SHASUMS256.txt.
NVIM_RELEASE=0.12.5
NVIM_SHA256=bce0f56eda1f1b1db6eee8f4133d7a38813ea07933837dd1777411ca384c6875
NVIM_URL="https://github.com/neovim/neovim/releases/download/v$NVIM_RELEASE/nvim-linux-x86_64.tar.gz"
NVIM_TS_RELEASE=0.26.9
NVIM_TS_SHA256=9ce82137caa65864e7ca8b869fd391cef88c9bd2a01c4371b9c4dd26c2585efb
NVIM_TS_URL="https://github.com/tree-sitter/tree-sitter/releases/download/v$NVIM_TS_RELEASE/tree-sitter-linux-x64.gz"
NVIM_NODE_RELEASE=24.21.0
NVIM_NODE_SHA256=6e1db87ef58b8819e5d5402eff1536491b18edd8eb7bee5ef7897876e88dc5ff
NVIM_NODE_URL="https://nodejs.org/dist/v$NVIM_NODE_RELEASE/node-v$NVIM_NODE_RELEASE-linux-x64.tar.gz"

# Shared by the distro hooks; all non-package files belong to the invoking user.
nvim_require_arch() {
  if [ "$(uname -s)" != Linux ] || [ "$(uname -m)" != x86_64 ]; then
    log_error "Neovim provisioning supports Linux x86_64 only (found $(uname -sm))."
    return 1
  fi
}

nvim_version_ok() {
  local output major minor patch want_major want_minor want_patch
  output="$("$1" --version 2>/dev/null)" || return 1
  [[ "$output" =~ ([0-9]+)\.([0-9]+)\.([0-9]+) ]] || return 1
  major=${BASH_REMATCH[1]} minor=${BASH_REMATCH[2]} patch=${BASH_REMATCH[3]}
  IFS=. read -r want_major want_minor want_patch <<< "$2"
  (( major > want_major || (major == want_major && minor > want_minor) ||
    (major == want_major && minor == want_minor && patch >= want_patch) ))
}

# npm and npx must actually run under the selected Node, not merely exist.
nvim_node_ok() {
  nvim_version_ok node 22.0.0 && nvim_version_ok npm 10.0.0 && nvim_version_ok npx 10.0.0
}

nvim_link_archive() {
  local kind="$1" target="$2" binary
  link_with_backup "$target/bin/$kind" "$HOME/.local/bin/$kind" || return 1
  if [ "$kind" = node ]; then
    # Keep the archive layout: npm's own symlinks resolve into ../lib/node_modules.
    for binary in npm npx; do
      link_with_backup "$target/bin/$binary" "$HOME/.local/bin/$binary" || return 1
    done
  fi
}

# Checksums are pinned with their versions above.
# Stage on the destination filesystem and publish only after verification.
nvim_install_archive() (
  set -euo pipefail
  local kind="$1" version="$2" digest="$3" url="$4"
  local root="$HOME/.local/opt" stage target
  target="$root/$kind-$version"
  if [ "${DRY_RUN:-0}" = 1 ]; then
    log_info "Would download/check SHA256 $url and install $target; link ~/.local/bin/$kind"
    return 0
  fi
  # Recover a completed installation whose link was removed/interrupted.
  if nvim_version_ok "$target/bin/$kind" "$version"; then
    if [ "$kind" = node ]; then
      PATH="$target/bin:$PATH" nvim_node_ok || return 1
    fi
    nvim_link_archive "$kind" "$target"
    return
  fi
  mkdir -p "$root" "$HOME/.local/bin" || return 1
  stage="$(mktemp -d "$root/.$kind.XXXXXXXX")" || return 1
  trap 'rm -rf "$stage"' EXIT
  curl --fail --location --retry 3 --proto '=https' --tlsv1.2 -o "$stage/archive" "$url" || return 1
  if ! printf '%s  %s\n' "$digest" "$stage/archive" | sha256sum --check --status; then
    log_error "SHA256 mismatch for $url"
    return 1
  fi
  mkdir "$stage/install" || return 1
  if [ "$kind" = nvim ] || [ "$kind" = node ]; then
    tar -xzf "$stage/archive" --strip-components=1 -C "$stage/install" || return 1
  elif [ "$kind" = tree-sitter ]; then
    mkdir "$stage/install/bin" || return 1
    gzip -dc "$stage/archive" > "$stage/install/bin/tree-sitter" || return 1
    chmod 755 "$stage/install/bin/tree-sitter" || return 1
  else
    log_error "Unknown Neovim provisioning archive: $kind"
    return 1
  fi
  nvim_version_ok "$stage/install/bin/$kind" "$version" || return 1
  if [ "$kind" = node ]; then
    PATH="$stage/install/bin:$PATH" nvim_node_ok || return 1
  fi
  # Do not overwrite an unrelated/partial installation silently.
  if [ -e "$target" ]; then
    log_error "$target already exists but was not selected as compatible; move it aside and retry."
    return 1
  fi
  mv "$stage/install" "$target" || return 1
  nvim_link_archive "$kind" "$target"
)

nvim_install_pinned() {
  case "$1" in
    nvim) nvim_install_archive nvim "$NVIM_RELEASE" "$NVIM_SHA256" "$NVIM_URL" ;;
    tree-sitter) nvim_install_archive tree-sitter "$NVIM_TS_RELEASE" "$NVIM_TS_SHA256" "$NVIM_TS_URL" ;;
    node) nvim_install_archive node "$NVIM_NODE_RELEASE" "$NVIM_NODE_SHA256" "$NVIM_NODE_URL" ;;
    *) return 1 ;;
  esac
}

# After local/bin is prepended, keep a previously selected compatible executable
# visible to future shells too. Canonicalize before linking to avoid link cycles.
nvim_align_binary() {
  local binary="$1" selected="$2" resolved
  [ -n "$selected" ] || return 0
  if [ "$(type -P "$binary" || true)" != "$selected" ]; then
    resolved="$(readlink -f "$selected")" || return 1
    link_with_backup "$resolved" "$HOME/.local/bin/$binary"
  fi
}

nvim_install_debian() {
  nvim_require_arch || return 1
  local selected_nvim='' selected_ts='' selected_node='' selected_npm='' selected_npx=''
  if nvim_version_ok nvim 0.12.0; then selected_nvim="$(type -P nvim)"; fi
  if nvim_version_ok tree-sitter 0.26.1; then selected_ts="$(type -P tree-sitter)"; fi
  if nvim_node_ok; then
    selected_node="$(type -P node)" selected_npm="$(type -P npm)" selected_npx="$(type -P npx)"
  fi
  export PATH="$HOME/.local/bin:$PATH"
  nvim_align_binary nvim "$selected_nvim" || return 1
  nvim_align_binary tree-sitter "$selected_ts" || return 1
  nvim_align_binary node "$selected_node" || return 1
  nvim_align_binary npm "$selected_npm" || return 1
  nvim_align_binary npx "$selected_npx" || return 1
  if ! nvim_version_ok nvim 0.12.0; then nvim_install_pinned nvim || return 1; fi
  if ! nvim_version_ok tree-sitter 0.26.1; then nvim_install_pinned tree-sitter || return 1; fi
  if ! nvim_node_ok; then nvim_install_pinned node || return 1; fi
  hash -r
  nvim_check_tools
}

nvim_check_tools() {
  [ "${DRY_RUN:-0}" != 1 ] || return 0
  local entry binary minimum
  for entry in 'nvim 0.12.0' 'tree-sitter 0.26.1' 'node 22.0.0'; do
    read -r binary minimum <<< "$entry"
    if ! nvim_version_ok "$binary" "$minimum"; then
      log_error "$binary >= $minimum required by this Neovim setup; check PATH and distro updates."
      return 1
    fi
  done
  if ! nvim_node_ok; then
    log_error "Working Node >= 22 with npm/npx >= 10 required; check PATH."
    return 1
  fi
}

nvim_provision() {
  [ "${CONFIG_ONLY:-0}" != 1 ] || return 0
  log_info "Restoring locked Neovim plugins, then installing parsers, LSP servers and DAP adapters."
  run_cmd env -u NVIM_APPNAME -u VIMINIT -u EXINIT DOTFILES_NVIM_PROVISION=1 nvim --headless -i NONE \
    '+lua local ok, err = pcall(function() require("provision").plugins() end); if not ok then print(err); vim.cmd("cquit 1") end' || return 1
  run_cmd env -u NVIM_APPNAME -u VIMINIT -u EXINIT DOTFILES_NVIM_PROVISION=1 nvim --headless -i NONE \
    '+lua local ok, err = pcall(function() require("provision").tools() end); if not ok then print(err); vim.cmd("cquit 1") end'
}
