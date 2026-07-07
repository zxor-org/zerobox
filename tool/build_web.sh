#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/build_common.sh"

init_build "$@"
log_info "Building Web release package for version ${VERSION}"

require_flutter
require_command zip
ensure_release_dir

mapfile -t DART_DEFINES < <(flutter_release_defines)

run_cmd flutter build web \
  --release \
  "${DART_DEFINES[@]}"

WEB_BUILD_DIR="${PROJECT_ROOT}/build/web"
if [[ ! -d "${WEB_BUILD_DIR}" ]]; then
  log_error "Web build output not found: ${WEB_BUILD_DIR}"
  exit 1
fi

archive_zip "${WEB_BUILD_DIR}" "${RELEASE_DIR}/${APP_NAME}-${VERSION}-web.zip"
log_info "Web build complete"
