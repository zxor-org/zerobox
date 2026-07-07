#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/build_common.sh"

init_build "$@"
log_info "Building ZeroBox release packages for version ${VERSION}"

clean_release_dir

BUILD_ARGS=()
if [[ "${DEV_MODE}" == "true" ]]; then
  BUILD_ARGS+=(--dev)
fi

"${SCRIPT_DIR}/build_android.sh" "${BUILD_ARGS[@]}"
"${SCRIPT_DIR}/build_web.sh" "${BUILD_ARGS[@]}"

case "$(host_os)" in
  linux)
    "${SCRIPT_DIR}/build_linux.sh" "${BUILD_ARGS[@]}"
    ;;
  macos)
    "${SCRIPT_DIR}/build_macos.sh" "${BUILD_ARGS[@]}"
    ;;
  windows)
    log_warn "Use tool\\build_windows.bat for Windows desktop packages"
    ;;
  *)
    log_warn "Skipping desktop package: unsupported host OS"
    ;;
esac

generate_checksums "${RELEASE_DIR}"

log_info "All requested builds complete. See ${RELEASE_DIR}"
ls -lh "${RELEASE_DIR}"
