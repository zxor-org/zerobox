#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
RELEASE_DIR="${PROJECT_ROOT}/build/release"
DEV_MODE="false"
VERSION=""
GIT_HASH=""

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

print_common_help() {
  cat <<EOF
Usage: $1 [options]

Options:
  --dev       Allow a dirty worktree and append git metadata to the package version
  -h, --help  Show this help
EOF
}

parse_common_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dev)
        DEV_MODE="true"
        shift
        ;;
      -h|--help)
        print_common_help "$(basename "$0")"
        exit 0
        ;;
      *)
        log_error "Unknown option: $1"
        print_common_help "$(basename "$0")" >&2
        exit 1
        ;;
    esac
  done
}

get_version() {
  awk -F'[:+]' '/^version:/ { gsub(/[[:space:]]/, "", $2); print $2; exit }' \
    "${PROJECT_ROOT}/pubspec.yaml"
}

get_build_number() {
  awk -F'+' '/^version:/ { gsub(/[[:space:]]/, "", $2); print $2; exit }' \
    "${PROJECT_ROOT}/pubspec.yaml"
}

get_git_hash() {
  git -C "${PROJECT_ROOT}" rev-parse --short=7 HEAD 2>/dev/null || echo "nogit"
}

is_git_dirty() {
  git -C "${PROJECT_ROOT}" update-index --refresh >/dev/null 2>&1 || true
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
  if [[ -z "${version}" ]]; then
    log_error "Could not read version from pubspec.yaml"
    exit 1
  fi

  if [[ "${dev_mode}" == "true" ]]; then
    local suffix="git.${GIT_HASH:-$(get_git_hash)}"
    if is_git_dirty; then
      suffix="dirty.${GIT_HASH:-$(get_git_hash)}"
    fi
    version="${version}.${suffix}"
  else
    check_clean_tree
  fi

  echo "${version}"
}

init_build() {
  parse_common_args "$@"
  GIT_HASH="$(get_git_hash)"
  VERSION="$(compute_version "${DEV_MODE}")"
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

flutter_release_defines() {
  echo "--dart-define=APP_VERSION=${VERSION}"
  echo "--dart-define=GIT_COMMIT_HASH=${GIT_HASH}"
}

build_number_or_default() {
  local build_number
  build_number="$(get_build_number)"
  if [[ -z "${build_number}" || "${build_number}" == "$(get_version)" ]]; then
    echo "1"
  else
    echo "${build_number}"
  fi
}

run_cmd() {
  log_info "Running: $*"
  "$@"
}

host_os() {
  case "$(uname -s)" in
    Darwin*) echo "macos" ;;
    Linux*) echo "linux" ;;
    MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
    *) echo "unknown" ;;
  esac
}

archive_zip() {
  local src="$1"
  local dst="$2"
  local parent
  local name
  parent="$(dirname "${src}")"
  name="$(basename "${src}")"
  rm -f "${dst}"
  (
    cd "${parent}"
    zip -qry "${dst}" "${name}"
  )
  log_info "Produced ${dst}"
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
    find . -maxdepth 1 -type f ! -name "$(basename "${checksum_file}")" \
      -printf '%f\0' | sort -z | xargs -0 sha256sum -- >"${checksum_file}"
  )

  log_info "Wrote ${checksum_file}"
}

copy_artifact() {
  local src="$1"
  local dst="$2"

  if [[ ! -f "${src}" ]]; then
    log_error "Expected artifact not found: ${src}"
    exit 1
  fi

  cp "${src}" "${dst}"
  log_info "Produced ${dst}"
}

archive_symbols_if_present() {
  local src="$1"
  local dst="$2"

  if [[ ! -d "${src}" ]]; then
    log_warn "Symbols directory not found; skipped symbols package: ${src}"
    return 0
  fi

  rm -f "${dst}"
  (
    cd "$(dirname "${src}")"
    tar czf "${dst}" "$(basename "${src}")"
  )
  log_info "Produced ${dst}"
}
