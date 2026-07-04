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
log_info "Building Web release package for version ${VERSION}"

require_flutter
ensure_release_dir

log_info "Running: flutter build web --release"
flutter build web --release

WEB_BUILD_DIR="${PROJECT_ROOT}/build/web"
if [[ ! -d "${WEB_BUILD_DIR}" ]]; then
  log_error "Web build output not found: ${WEB_BUILD_DIR}"
  exit 1
fi

OUTPUT="${RELEASE_DIR}/${APP_NAME}-${VERSION}-web.zip"
rm -f "${OUTPUT}"

(
  cd "${PROJECT_ROOT}/build"
  zip -r "${OUTPUT}" web/
)

log_info "Produced ${OUTPUT}"
log_info "Web build complete."
