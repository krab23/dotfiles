#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

export DOTFILES_ROOT
export DRY_RUN=0
export ONLY_MODULES=""
export SKIP_MODULES=""
export ENABLE_DOCKER_PRUNE=0
export FORCED_DISTRO_FAMILY=""

source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/distro_detect.sh"
source "$SCRIPT_DIR/lib/packages.sh"

usage() {
  cat <<'EOF'
Usage: bootstrap/install.sh [options]

Options:
  --only <csv>               Run only selected modules (zsh,starship,nvim,docker)
  --skip <csv>               Skip selected modules
  --distro <debian|arch>     Override distro detection
  --enable-docker-prune      Add daily docker prune cron job (opt-in)
  --dry-run                  Print planned actions without running commands
  --help                     Show this help message
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --only)
      ONLY_MODULES="$2"
      shift 2
      ;;
    --skip)
      SKIP_MODULES="$2"
      shift 2
      ;;
    --distro)
      FORCED_DISTRO_FAMILY="$2"
      shift 2
      ;;
    --enable-docker-prune)
      ENABLE_DOCKER_PRUNE=1
      shift 1
      ;;
    --dry-run)
      DRY_RUN=1
      shift 1
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      log_error "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
done

detect_distro_family
require_supported_distro
log_info "Detected distro family: $DISTRO_FAMILY"

source "$SCRIPT_DIR/distros/${DISTRO_FAMILY}.sh"
source "$SCRIPT_DIR/modules/zsh.sh"
source "$SCRIPT_DIR/modules/starship.sh"
source "$SCRIPT_DIR/modules/nvim.sh"
source "$SCRIPT_DIR/modules/docker.sh"

run_module() {
  local module="$1"
  if module_selected "$module"; then
    log_info "Running module: $module"
    "module_${module}"
  else
    log_info "Skipping module: $module"
  fi
}

run_module zsh
run_module starship
run_module nvim
run_module docker

log_info "Bootstrap complete."
