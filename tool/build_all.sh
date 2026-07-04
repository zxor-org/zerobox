#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/build_common.sh"

DEV_MODE="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dev)
      DEV_MODE="true"
      shift
      ;;
    *)
      log_error "Unknown option: $1"
      exit 1
      ;;
  esac
done

VERSION="$(compute_version "${DEV_MODE}")"
log_info "Building all ZeroBox release packages for version ${VERSION}"

clean_release_dir

"${SCRIPT_DIR}/build_android.sh" "$([[ "${DEV_MODE}" == "true" ]] && echo --dev)"
"${SCRIPT_DIR}/build_web.sh" "$([[ "${DEV_MODE}" == "true" ]] && echo --dev)"
"${SCRIPT_DIR}/build_linux.sh" "$([[ "${DEV_MODE}" == "true" ]] && echo --dev)"

generate_checksums "${RELEASE_DIR}"

log_info "All builds complete. See ${RELEASE_DIR}"
ls -lh "${RELEASE_DIR}"
