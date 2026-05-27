#!/usr/bin/env bash

set -euo pipefail

PKG_DB_UPDATED=0

pkg_update() {
  if [ "$PKG_DB_UPDATED" = "1" ]; then
    return 0
  fi

  case "$DISTRO_FAMILY" in
    debian|ubuntu)
      run_sudo apt-get update
      ;;
    arch)
      run_sudo pacman -Sy --noconfirm
      ;;
    *)
      log_error "pkg_update called with unsupported distro: $DISTRO_FAMILY"
      exit 1
      ;;
  esac

  PKG_DB_UPDATED=1
}

pkg_install() {
  if [ "$#" -eq 0 ]; then
    return 0
  fi

  pkg_update

  case "$DISTRO_FAMILY" in
    debian|ubuntu)
      run_sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y "$@"
      ;;
    arch)
      run_sudo pacman -S --noconfirm --needed "$@"
      ;;
    *)
      log_error "pkg_install called with unsupported distro: $DISTRO_FAMILY"
      exit 1
      ;;
  esac
}
