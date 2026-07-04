#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
RELEASE_DIR="${PROJECT_ROOT}/build/release"

APP_NAME="zerobox"
PACKAGE_NAME="org.zxor.zerobox"
DESCRIPTION="A pretty fast wearable management tool for VelaOS and ZeppOS built with Flutter."
MAINTAINER="ZeroBox Team"
LICENSE="MIT"
HOMEPAGE="https://github.com/zxor/zerobox"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
  echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
  echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $*" >&2
}

get_version() {
  grep -E '^version:' "${PROJECT_ROOT}/pubspec.yaml" | sed -E 's/^version:[[:space:]]*([^+]+).*/\1/'
}

get_build_number() {
  grep -E '^version:' "${PROJECT_ROOT}/pubspec.yaml" | sed -E 's/^version:[^+]+\+?//' | head -c 20
}

get_git_hash() {
  git -C "${PROJECT_ROOT}" rev-parse --short HEAD
}

is_git_dirty() {
  ! git -C "${PROJECT_ROOT}" diff-index --quiet HEAD -- 2>/dev/null || \
    [ -n "$(git -C "${PROJECT_ROOT}" ls-files --others --exclude-standard)" ]
}

check_clean_tree() {
  if is_git_dirty; then
    log_error "Git working tree is dirty. Commit or stash changes first, or use --dev."
    exit 1
  fi
}

compute_version() {
  local dev_mode="${1:-false}"
  local version
  version="$(get_version)"

  if [[ "${dev_mode}" == "true" ]]; then
    local suffix="git.$(get_git_hash)"
    if is_git_dirty; then
      suffix="dirty.$(get_git_hash)"
    fi
    version="${version}.${suffix}"
  else
    check_clean_tree
  fi

  echo "${version}"
}

ensure_release_dir() {
  mkdir -p "${RELEASE_DIR}"
}

clean_release_dir() {
  rm -rf "${RELEASE_DIR}"
  mkdir -p "${RELEASE_DIR}"
}

require_command() {
  if ! command -v "$1" &>/dev/null; then
    log_error "Required command not found: $1"
    exit 1
  fi
}

require_flutter() {
  require_command flutter
}

setup_android_signing() {
  local props_file="${PROJECT_ROOT}/android/key.properties"

  if [[ -z "${ZEROBOX_KEYSTORE_PATH:-}" ]]; then
    log_warn "ZEROBOX_KEYSTORE_PATH not set; Android build will use the debug signing config."
    log_warn "Set ZEROBOX_KEYSTORE_PATH, ZEROBOX_KEYSTORE_PASSWORD, ZEROBOX_KEY_ALIAS, and ZEROBOX_KEY_PASSWORD for release signing."
    return 0
  fi

  if [[ ! -f "${ZEROBOX_KEYSTORE_PATH}" ]]; then
    log_error "Keystore file not found: ${ZEROBOX_KEYSTORE_PATH}"
    exit 1
  fi

  if [[ -z "${ZEROBOX_KEYSTORE_PASSWORD:-}" || -z "${ZEROBOX_KEY_ALIAS:-}" || -z "${ZEROBOX_KEY_PASSWORD:-}" ]]; then
    log_error "When ZEROBOX_KEYSTORE_PATH is set, ZEROBOX_KEYSTORE_PASSWORD, ZEROBOX_KEY_ALIAS, and ZEROBOX_KEY_PASSWORD must also be set."
    exit 1
  fi

  log_info "Configuring Android release signing..."
  cat > "${props_file}" <<EOF
storePassword=${ZEROBOX_KEYSTORE_PASSWORD}
keyPassword=${ZEROBOX_KEY_PASSWORD}
keyAlias=${ZEROBOX_KEY_ALIAS}
storeFile=${ZEROBOX_KEYSTORE_PATH}
EOF

  log_info "Wrote ${props_file}"
}

generate_checksums() {
  local dir="$1"
  local checksum_file="${dir}/sha256sums.txt"

  rm -f "${checksum_file}"
  (
    cd "${dir}"
    sha256sum -- * >"${checksum_file}"
  )

  log_info "Wrote ${checksum_file}"
}
