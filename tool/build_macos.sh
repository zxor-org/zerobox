#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/build_common.sh"

init_build "$@"
log_info "Building macOS release package for version ${VERSION}"

if [[ "$(host_os)" != "macos" ]]; then
  log_error "macOS packages can only be built on macOS"
  exit 1
fi

require_flutter
require_command zip
ensure_release_dir

mapfile -t DART_DEFINES < <(flutter_release_defines)

run_cmd flutter build macos \
  --release \
  --obfuscate \
  --split-debug-info=symbols/macos \
  "${DART_DEFINES[@]}"

APP_BUNDLE="${PROJECT_ROOT}/build/macos/Build/Products/Release/${APP_NAME}.app"
if [[ ! -d "${APP_BUNDLE}" ]]; then
  log_error "macOS app bundle not found: ${APP_BUNDLE}"
  exit 1
fi

archive_zip "${APP_BUNDLE}" "${RELEASE_DIR}/${APP_NAME}-${VERSION}-macos-universal.zip"
archive_symbols_if_present \
  "${PROJECT_ROOT}/symbols/macos" \
  "${RELEASE_DIR}/${APP_NAME}-${VERSION}-macos-universal.symbols.tar.gz"

if command -v hdiutil >/dev/null 2>&1; then
  DMG_DST="${RELEASE_DIR}/${APP_NAME}-${VERSION}-macos-universal.dmg"
  rm -f "${DMG_DST}"
  run_cmd hdiutil create \
    -volname "ZeroBox" \
    -srcfolder "${APP_BUNDLE}" \
    -ov \
    -format UDZO \
    "${DMG_DST}"
  log_info "Produced ${DMG_DST}"
else
  log_warn "hdiutil not found; skipped DMG package"
fi

log_info "macOS build complete"
