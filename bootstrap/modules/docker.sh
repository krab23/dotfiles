#!/usr/bin/env bash

set -euo pipefail

setup_docker_prune_cron() {
  local prune_command="/usr/bin/docker system prune -f"
  local schedule="0 3 * * *"
  local entry="${schedule} ${prune_command}"
  local tmp

  if [ "${DRY_RUN:-0}" = 1 ]; then
    printf '[dry-run] ensure user crontab contains: %s\n' "$entry"
    return 0
  fi

  if ! command_exists crontab; then
    log_warn "crontab not found; cannot configure prune job."
    return 0
  fi

  make_temp
  tmp="$TEMP_FILE"
  (crontab -l 2>/dev/null || true) >"$tmp"

  if grep -Fq "$prune_command" "$tmp"; then
    log_info "Docker prune cron already present; skipping."
    return 0
  fi

  log_info "Adding docker prune cron: $entry"
  run_cmd bash -c "printf '%s\n' \"\$1\" >>\"\$2\"" -- "$entry" "$tmp"
  run_cmd crontab "$tmp"
}

docker_uses_local_engine() {
  local context endpoint="${DOCKER_HOST:-}"
  if [ -n "${DOCKER_CONTEXT:-}" ]; then
    context="$DOCKER_CONTEXT"
  elif [ -z "$endpoint" ] && command_exists docker; then
    context="$(docker context show 2>/dev/null || true)"
  else
    context=""
  fi
  case "$context" in
    desktop*|rootless) return 1 ;;
  esac
  if [ -n "$context" ]; then
    command_exists docker || return 1
    endpoint="$(docker context inspect "$context" --format '{{.Endpoints.docker.Host}}' 2>/dev/null || true)"
    # An uninspectable explicit context must not be treated as local.
    [ -n "$endpoint" ] || return 1
  fi
  case "$endpoint" in
    ""|unix:///var/run/docker.sock|unix:///run/docker.sock) ;;
    *) return 1 ;;
  esac
  if [ -S /var/run/docker.sock ] && [[ "$(readlink -f /var/run/docker.sock)" == /mnt/wsl/* ]]; then
    return 1
  fi
  return 0
}

module_docker() {
  if [ "${CONFIG_ONLY:-0}" = 1 ]; then
    log_info "Docker has no dotfile links; skipping system configuration."
    return 0
  fi
  if ! docker_uses_local_engine; then
    log_info "Docker uses a remote, rootless, or Desktop engine; manage its components/service there. Skipping local engine, group and prune setup."
    return 0
  fi
  distro_install_docker

  if [ -d /run/systemd/system ] && command_exists systemctl; then
    run_sudo systemctl enable --now docker.service
  else
    log_warn "systemd is not running. Start the local Docker daemon using your init system; on WSL2 enable systemd and restart WSL, or use Docker Desktop integration."
  fi

  if id -nG "$TARGET_USER" | grep -qw docker; then
    log_info "User '$TARGET_USER' already belongs to docker group."
  else
    log_info "Adding '$TARGET_USER' to docker group (root-equivalent access to the local engine)."
    run_sudo usermod -aG docker "$TARGET_USER"
    log_warn "Log out and back in for docker group membership to apply."
  fi

  if [ "${ENABLE_DOCKER_PRUNE:-0}" = "1" ]; then
    setup_docker_prune_cron
  else
    log_info "Docker prune cron disabled by default. Use --enable-docker-prune to opt in."
  fi
}
