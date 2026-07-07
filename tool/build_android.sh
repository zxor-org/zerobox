#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/build_common.sh"

init_build "$@"
log_info "Building Android release packages for version ${VERSION}"

require_flutter
setup_android_signing
ensure_release_dir

mapfile -t DART_DEFINES < <(flutter_release_defines)
BUILD_NUMBER="$(build_number_or_default)"

run_cmd flutter build apk \
  --release \
  --split-per-abi \
  --obfuscate \
  --split-debug-info=symbols/android-apk \
  --build-name="${VERSION}" \
  --build-number="${BUILD_NUMBER}" \
  "${DART_DEFINES[@]}"

ANDROID_APK_DIR="${PROJECT_ROOT}/build/app/outputs/flutter-apk"
for abi in arm64-v8a armeabi-v7a x86_64; do
  copy_artifact \
    "${ANDROID_APK_DIR}/app-${abi}-release.apk" \
    "${RELEASE_DIR}/${APP_NAME}-${VERSION}-android-${abi}.apk"
done

run_cmd flutter build appbundle \
  --release \
  --obfuscate \
  --split-debug-info=symbols/android-appbundle \
  --build-name="${VERSION}" \
  --build-number="${BUILD_NUMBER}" \
  "${DART_DEFINES[@]}"

copy_artifact \
  "${PROJECT_ROOT}/build/app/outputs/bundle/release/app-release.aab" \
  "${RELEASE_DIR}/${APP_NAME}-${VERSION}-android-appbundle.aab"

archive_symbols_if_present \
  "${PROJECT_ROOT}/symbols/android-apk" \
  "${RELEASE_DIR}/${APP_NAME}-${VERSION}-android-apk.symbols.tar.gz"
archive_symbols_if_present \
  "${PROJECT_ROOT}/symbols/android-appbundle" \
  "${RELEASE_DIR}/${APP_NAME}-${VERSION}-android-appbundle.symbols.tar.gz"

log_info "Android build complete"
