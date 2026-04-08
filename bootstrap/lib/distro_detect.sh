#!/usr/bin/env bash

set -euo pipefail

detect_distro_family() {
  if [ -n "${FORCED_DISTRO_FAMILY:-}" ]; then
    DISTRO_FAMILY="$FORCED_DISTRO_FAMILY"
    return 0
  fi

  if [ ! -f /etc/os-release ]; then
    DISTRO_FAMILY="unknown"
    return 0
  fi

  local id
  local like
  id="$(. /etc/os-release && printf "%s" "${ID:-}")"
  like="$(. /etc/os-release && printf "%s" "${ID_LIKE:-}")"

  case "$id" in
    debian|ubuntu)
      DISTRO_FAMILY="debian"
      ;;
    arch|manjaro|endeavouros)
      DISTRO_FAMILY="arch"
      ;;
    *)
      case "$like" in
        *debian*)
          DISTRO_FAMILY="debian"
          ;;
        *arch*)
          DISTRO_FAMILY="arch"
          ;;
        *)
          DISTRO_FAMILY="unknown"
          ;;
      esac
      ;;
  esac
}

require_supported_distro() {
  if [ "$DISTRO_FAMILY" != "debian" ] && [ "$DISTRO_FAMILY" != "arch" ]; then
    log_error "Unsupported distro family: $DISTRO_FAMILY (supported: debian, arch)"
    exit 1
  fi
}
