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

SUDO="sudo"

initialize_target_user() {
  if [ "$(id -u)" -eq 0 ]; then
    log_error "Run bootstrap as your normal login user, without sudo. It uses sudo only for system installation; running as root would configure root's home."
    exit 1
  fi
  local entry password uid gid gecos account_home
  TARGET_USER="$(id -un)"
  if ! entry="$(getent passwd "$TARGET_USER")"; then
    log_error "Cannot resolve the current user's passwd entry: $TARGET_USER"
    exit 1
  fi
  IFS=: read -r TARGET_USER password uid gid gecos account_home TARGET_SHELL <<< "$entry"
  if [ -z "$account_home" ] || [ "$account_home" != "${HOME:-}" ] || [ "$uid" != "$(id -u)" ]; then
    log_error "HOME must match the current user's passwd home ($account_home). Run from a normal login session."
    exit 1
  fi
  USER="$TARGET_USER"
  LOGNAME="$TARGET_USER"
  export TARGET_USER TARGET_SHELL HOME USER LOGNAME
}

validate_module_csv() {
  local csv="$1" item
  local -a items
  [ -n "$csv" ] || return 0
  if [[ ! "$csv" =~ ^[a-z]+(,[a-z]+)*$ ]]; then
    log_error "Invalid module CSV: $csv (use comma-separated module names without empty entries or whitespace)"
    exit 1
  fi
  IFS=, read -r -a items <<< "$csv"
  for item in "${items[@]}"; do
    case "$item" in
      git|zsh|starship|nvim|docker) ;;
      *) log_error "Unknown module: $item (choose git,zsh,starship,nvim,docker)"; exit 1 ;;
    esac
  done
}

# Call directly (not through command substitution), so EXIT retains the list.
BOOTSTRAP_TEMPS=()
cleanup_bootstrap_temps() {
  if [ "${#BOOTSTRAP_TEMPS[@]}" -gt 0 ]; then
    rm -f -- "${BOOTSTRAP_TEMPS[@]}"
  fi
}
trap cleanup_bootstrap_temps EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

make_temp() {
  if [ "${DRY_RUN:-0}" = 1 ]; then
    TEMP_FILE="${TMPDIR:-/tmp}/bootstrap-planned-temp"
  else
    TEMP_FILE="$(mktemp)"
    BOOTSTRAP_TEMPS+=("$TEMP_FILE")
  fi
}

run_cmd() {
  if [ "${DRY_RUN:-0}" = "1" ]; then
    printf "[dry-run] %s\n" "$*"
    return 0
  fi
  "$@"
}

run_sudo() {
  [ "${CONFIG_ONLY:-0}" = 0 ] || return 0
  if [ -n "$SUDO" ]; then
    run_cmd "$SUDO" "$@"
  else
    run_cmd "$@"
  fi
}

abs_path() {
  local src="$1"
  if command_exists realpath; then
    realpath "$src" || return 1
    return
  fi
  local dir
  dir="$(cd "$(dirname "$src")" && pwd)" || return 1
  printf "%s/%s\n" "$dir" "$(basename "$src")"
}

ensure_dir() {
  run_cmd mkdir -p "$1"
}

link_with_backup() {
  local src
  local dest="$2"
  local backup backup_base suffix=0
  src="$(abs_path "$1")" || return 1
  if [ ! -e "$src" ]; then
    log_error "Cannot link missing source: $src"
    return 1
  fi

  ensure_dir "$(dirname "$dest")" || return 1

  if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
    log_info "Symlink already correct: $dest -> $src"
    return 0
  fi

  if [ -e "$dest" ] || [ -L "$dest" ]; then
    backup_base="${dest}.backup.$(date +%Y%m%d%H%M%S)"
    backup="$backup_base"
    while [ -e "$backup" ] || [ -L "$backup" ]; do
      suffix=$((suffix + 1))
      backup="${backup_base}.${suffix}"
    done
    log_warn "Backing up existing target: $dest -> $backup"
    run_cmd mv -T -- "$dest" "$backup" || return 1
  fi

  log_info "Linking: $dest -> $src"
  run_cmd ln -sT -- "$src" "$dest"
}

csv_contains() {
  local csv="$1"
  local needle="$2"
  local item
  local -a items

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
