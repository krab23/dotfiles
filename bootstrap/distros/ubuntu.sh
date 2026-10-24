#!/usr/bin/env bash

set -euo pipefail

# Consumed by the shared adapter sourced below.
# shellcheck disable=SC2034
APT_FAMILY_LABEL="Ubuntu"
# shellcheck disable=SC2034
APT_FAMILY_DOCKER_DISTRO="ubuntu"
APT_FAMILY_CODENAME_PLACEHOLDER="<ubuntu-codename>"

_apt_family_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$_apt_family_dir/apt-family.sh"
unset _apt_family_dir

ubuntu_package_arch() {
  apt_family_package_arch "Ubuntu"
}

distro_package_arch() {
  ubuntu_package_arch
}

distro_docker_codename() {
  apt_family_docker_codename ubuntu UBUNTU_CODENAME VERSION_CODENAME "$APT_FAMILY_CODENAME_PLACEHOLDER"
}
