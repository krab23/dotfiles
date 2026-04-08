#!/usr/bin/env bash

set -euo pipefail

setup_docker_prune_cron() {
  local prune_command="/usr/bin/docker system prune -f"
  local schedule="0 3 * * *"
  local entry="${schedule} ${prune_command}"
  local tmp

  if ! command_exists crontab; then
    log_warn "crontab not found; cannot configure prune job."
    return 0
  fi

  tmp="$(mktemp)"
  (crontab -l 2>/dev/null || true) >"$tmp"

  if grep -Fq "$prune_command" "$tmp"; then
    log_info "Docker prune cron already present; skipping."
    run_cmd rm -f "$tmp"
    return 0
  fi

  log_info "Adding docker prune cron: $entry"
  run_cmd bash -c "printf '%s\n' \"\$1\" >>\"\$2\"" -- "$entry" "$tmp"
  run_cmd crontab "$tmp"
  run_cmd rm -f "$tmp"
}

module_docker() {
  distro_install_docker

  if command_exists docker && [ -n "${USER:-}" ]; then
    if id -nG "$USER" | grep -qw docker; then
      log_info "User '$USER' already belongs to docker group."
    else
      log_info "Adding '$USER' to docker group."
      run_sudo usermod -aG docker "$USER"
      log_warn "Log out and back in for docker group membership to apply."
    fi
  fi

  if [ "${ENABLE_DOCKER_PRUNE:-0}" = "1" ]; then
    setup_docker_prune_cron
  else
    log_info "Docker prune cron disabled by default. Use --enable-docker-prune to opt in."
  fi
}
