#!/usr/bin/env bash

set -euo pipefail

timestamp() {
  date +"%Y-%m-%d %H:%M:%S"
}

log_info() {
  printf "[%s] [INFO] %s\n" "$(timestamp)" "$*"
}

log_warn() {
  printf "[%s] [WARN] %s\n" "$(timestamp)" "$*"
}

log_error() {
  printf "[%s] [ERROR] %s\n" "$(timestamp)" "$*" >&2
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

require_option_value() {
  local option="$1"
  local value="${2:-}"

  if [ -z "$value" ] || [ "${value#--}" != "$value" ]; then
    log_error "Option requires a value: $option"
    exit 1
  fi
}

if [ "$(id -u)" -eq 0 ]; then
  SUDO=""
else
  SUDO="sudo"
fi

run_cmd() {
  if [ "${DRY_RUN:-0}" = "1" ]; then
    printf "[dry-run] %s\n" "$*"
    return 0
  fi
  "$@"
}

run_sudo() {
  if [ -n "$SUDO" ]; then
    run_cmd "$SUDO" "$@"
  else
    run_cmd "$@"
  fi
}

abs_path() {
  local src="$1"
  if command_exists realpath; then
    realpath "$src"
    return 0
  fi
  local dir
  dir="$(cd "$(dirname "$src")" && pwd)"
  printf "%s/%s\n" "$dir" "$(basename "$src")"
}

ensure_dir() {
  run_cmd mkdir -p "$1"
}

link_with_backup() {
  local src
  local dest="$2"
  local backup
  src="$(abs_path "$1")"

  ensure_dir "$(dirname "$dest")"

  if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
    log_info "Symlink already correct: $dest -> $src"
    return 0
  fi

  if [ -e "$dest" ] || [ -L "$dest" ]; then
    backup="${dest}.backup.$(date +%Y%m%d%H%M%S)"
    log_warn "Backing up existing target: $dest -> $backup"
    run_cmd mv "$dest" "$backup"
  fi

  log_info "Linking: $dest -> $src"
  run_cmd ln -s "$src" "$dest"
}

csv_contains() {
  local csv="$1"
  local needle="$2"
  local item

  if [ -z "$csv" ]; then
    return 1
  fi

  IFS=',' read -r -a items <<< "$csv"
  for item in "${items[@]}"; do
    if [ "$item" = "$needle" ]; then
      return 0
    fi
  done
  return 1
}

module_selected() {
  local mod="$1"

  if [ -n "${ONLY_MODULES:-}" ] && ! csv_contains "$ONLY_MODULES" "$mod"; then
    return 1
  fi

  if csv_contains "${SKIP_MODULES:-}" "$mod"; then
    return 1
  fi

  return 0
}
