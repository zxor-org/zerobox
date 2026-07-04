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
log_info "Building Android release packages for version ${VERSION}"

require_flutter
setup_android_signing
ensure_release_dir

FLUTTER_BUILD_ARGS=(
  build
  apk
  --release
  --split-per-abi
)

log_info "Running: flutter ${FLUTTER_BUILD_ARGS[*]}"
flutter "${FLUTTER_BUILD_ARGS[@]}"

ANDROID_BUILD_DIR="${PROJECT_ROOT}/build/app/outputs/flutter-apk"

# Flutter names APKs like app-arm64-v8a-release.apk
abi_mapping=(
  "arm64-v8a:arm64-v8a"
  "armeabi-v7a:armeabi-v7a"
  "x86_64:x86_64"
)

for mapping in "${abi_mapping[@]}"; do
  abi="${mapping%%:*}"
  flutter_abi="${mapping##*:}"
  src="${ANDROID_BUILD_DIR}/app-${flutter_abi}-release.apk"
  dst="${RELEASE_DIR}/${APP_NAME}-${VERSION}-android-${abi}.apk"

  if [[ ! -f "${src}" ]]; then
    log_warn "Expected APK not found: ${src}"
    continue
  fi

  cp "${src}" "${dst}"
  log_info "Produced ${dst}"
done

log_info "Running: flutter build appbundle --release"
flutter build appbundle --release

AAB_SRC="${PROJECT_ROOT}/build/app/outputs/bundle/release/app-release.aab"
AAB_DST="${RELEASE_DIR}/${APP_NAME}-${VERSION}-android-appbundle.aab"

if [[ -f "${AAB_SRC}" ]]; then
  cp "${AAB_SRC}" "${AAB_DST}"
  log_info "Produced ${AAB_DST}"
else
  log_warn "Expected AAB not found: ${AAB_SRC}"
fi

log_info "Android build complete."
