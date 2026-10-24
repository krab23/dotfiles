#!/usr/bin/env bash

set -euo pipefail

# Consumed by the shared adapter sourced below.
# shellcheck disable=SC2034
APT_FAMILY_LABEL="Debian"
# shellcheck disable=SC2034
APT_FAMILY_DOCKER_DISTRO="debian"
APT_FAMILY_CODENAME_PLACEHOLDER="<debian-codename>"

_apt_family_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$_apt_family_dir/apt-family.sh"
unset _apt_family_dir

debian_package_arch() {
  apt_family_package_arch "Debian"
}

distro_package_arch() {
  debian_package_arch
}

distro_docker_codename() {
  apt_family_docker_codename debian "" VERSION_CODENAME "$APT_FAMILY_CODENAME_PLACEHOLDER"
}
