#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/build_common.sh"

init_build "$@"
log_info "Building Linux release packages for version ${VERSION}"

require_flutter
require_command tar
require_command dpkg-deb
ensure_release_dir

mapfile -t DART_DEFINES < <(flutter_release_defines)

run_cmd flutter build linux \
  --release \
  --obfuscate \
  --split-debug-info=symbols/linux \
  "${DART_DEFINES[@]}"

BUNDLE_DIR="${PROJECT_ROOT}/build/linux/x64/release/bundle"
SYMBOLS_DIR="${PROJECT_ROOT}/symbols/linux"
if [[ ! -d "${BUNDLE_DIR}" ]]; then
  log_error "Linux build bundle not found: ${BUNDLE_DIR}"
  exit 1
fi

TAR_DST="${RELEASE_DIR}/${APP_NAME}-${VERSION}-linux-amd64.tar.gz"
rm -f "${TAR_DST}"
(
  cd "$(dirname "${BUNDLE_DIR}")"
  tar czf "${TAR_DST}" "$(basename "${BUNDLE_DIR}")"
)
log_info "Produced ${TAR_DST}"

archive_symbols_if_present \
  "${SYMBOLS_DIR}" \
  "${RELEASE_DIR}/${APP_NAME}-${VERSION}-linux-amd64.symbols.tar.gz"

STAGING_ROOT="${PROJECT_ROOT}/build/linux_staging"
INSTALL_PREFIX="/opt/${APP_NAME}"
DESKTOP_FILE="${PACKAGE_NAME}.desktop"
rm -rf "${STAGING_ROOT}"
mkdir -p "${STAGING_ROOT}"

prepare_desktop_file() {
  local dst="$1"
  local exec_path="${2:-${INSTALL_PREFIX}/zerobox}"
  mkdir -p "$(dirname "${dst}")"
  cp "${PROJECT_ROOT}/linux/${DESKTOP_FILE}.in" "${dst}"
  sed -i "s|@CMAKE_INSTALL_PREFIX@/zerobox|${exec_path}|g" "${dst}"
}

copy_bundle_to() {
  local root="$1"
  mkdir -p "${root}${INSTALL_PREFIX}"
  cp -a "${BUNDLE_DIR}/." "${root}${INSTALL_PREFIX}/"
  chmod +x "${root}${INSTALL_PREFIX}/${APP_NAME}"
  find "${root}${INSTALL_PREFIX}" -type f \( -name '*.so' -o -name "${APP_NAME}" \) \
    -exec strip --strip-unneeded {} \; 2>/dev/null || true
}

copy_system_icons_to() {
  local root="$1"
  mkdir -p "${root}/usr/share/icons"
  cp -a "${PROJECT_ROOT}/linux/icons/hicolor" "${root}/usr/share/icons/"
}

build_deb() {
  local deb_root="${STAGING_ROOT}/deb"
  rm -rf "${deb_root}"
  copy_bundle_to "${deb_root}"
  prepare_desktop_file "${deb_root}/usr/share/applications/${DESKTOP_FILE}"
  copy_system_icons_to "${deb_root}"
  mkdir -p "${deb_root}/DEBIAN"

  cat > "${deb_root}/DEBIAN/control" <<EOF
Package: ${APP_NAME}
Version: ${VERSION}
Section: utils
Priority: optional
Architecture: amd64
Depends: libgtk-3-0, libblkid1, liblzma5, libwebkit2gtk-4.1-0, bluez
Maintainer: ${MAINTAINER}
Description: ${DESCRIPTION}
EOF

  local deb_out="${RELEASE_DIR}/${APP_NAME}_${VERSION}_amd64.deb"
  rm -f "${deb_out}"
  run_cmd dpkg-deb --root-owner-group --build "${deb_root}" "${deb_out}"
  log_info "Produced ${deb_out}"
}

build_rpm() {
  if ! command -v rpmbuild >/dev/null 2>&1; then
    log_warn "rpmbuild not found; skipped RPM package"
    return 0
  fi

  local rpm_top="${STAGING_ROOT}/rpm"
  local rpm_version="${VERSION//-/.}"
  local release_num="1"
  rm -rf "${rpm_top}"
  mkdir -p "${rpm_top}"/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
  mkdir -p "${rpm_top}/rpmdb"
  prepare_desktop_file "${STAGING_ROOT}/rpm-desktop/${DESKTOP_FILE}"

  cat > "${rpm_top}/SPECS/${APP_NAME}.spec" <<EOF
Name:           ${APP_NAME}
Version:        ${rpm_version}
Release:        ${release_num}%{?dist}
Summary:        ${DESCRIPTION}
License:        ${LICENSE}
URL:            ${HOMEPAGE}
BuildArch:      x86_64

%description
${DESCRIPTION}

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}${INSTALL_PREFIX}
cp -a ${BUNDLE_DIR}/* %{buildroot}${INSTALL_PREFIX}/
mkdir -p %{buildroot}/usr/share/applications
cp ${STAGING_ROOT}/rpm-desktop/${DESKTOP_FILE} %{buildroot}/usr/share/applications/
mkdir -p %{buildroot}/usr/share/icons
cp -a ${PROJECT_ROOT}/linux/icons/hicolor %{buildroot}/usr/share/icons/

%files
${INSTALL_PREFIX}
/usr/share/applications/${DESKTOP_FILE}
/usr/share/icons/hicolor

%changelog
* $(LC_ALL=C date +"%a %b %d %Y") ${MAINTAINER} - ${rpm_version}-${release_num}
- Package release
EOF

  run_cmd rpmbuild \
    --define "_topdir ${rpm_top}" \
    --define "_dbpath ${rpm_top}/rpmdb" \
    -bb "${rpm_top}/SPECS/${APP_NAME}.spec"
  local rpm_src
  rpm_src="$(find "${rpm_top}/RPMS" -name '*.rpm' | head -n 1)"
  if [[ -z "${rpm_src}" ]]; then
    log_error "RPM build failed: no .rpm file produced"
    exit 1
  fi
  copy_artifact "${rpm_src}" "${RELEASE_DIR}/${APP_NAME}-${VERSION}-${release_num}.x86_64.rpm"
}

build_arch() {
  if ! command -v makepkg >/dev/null 2>&1; then
    log_warn "makepkg not found; skipped Arch package"
    return 0
  fi

  local arch_root="${STAGING_ROOT}/arch"
  rm -rf "${arch_root}"
  mkdir -p "${arch_root}"
  prepare_desktop_file "${STAGING_ROOT}/arch-desktop/${DESKTOP_FILE}"

  cat > "${arch_root}/PKGBUILD" <<EOF
# Maintainer: ${MAINTAINER}
pkgname=${APP_NAME}
pkgver=${VERSION}
pkgrel=1
pkgdesc="${DESCRIPTION}"
arch=('x86_64')
url="${HOMEPAGE}"
license=('${LICENSE}')
depends=('gtk3' 'libblockdev' 'xz' 'webkit2gtk-4.1' 'bluez')
options=('!debug')
source=()

package() {
  mkdir -p "\${pkgdir}${INSTALL_PREFIX}"
  cp -a "${BUNDLE_DIR}"/* "\${pkgdir}${INSTALL_PREFIX}/"
  mkdir -p "\${pkgdir}/usr/share/applications"
  cp "${STAGING_ROOT}/arch-desktop/${DESKTOP_FILE}" "\${pkgdir}/usr/share/applications/"
  mkdir -p "\${pkgdir}/usr/share/icons"
  cp -a "${PROJECT_ROOT}/linux/icons/hicolor" "\${pkgdir}/usr/share/icons/"
}
EOF

  (
    cd "${arch_root}"
    run_cmd makepkg -f --skipchecksums
  )

  local arch_src
  arch_src="$(find "${arch_root}" -maxdepth 1 -name '*.pkg.tar.zst' ! -name '*-debug-*' | head -n 1)"
  if [[ -z "${arch_src}" ]]; then
    log_error "Arch package build failed: no .pkg.tar.zst file produced"
    exit 1
  fi
  copy_artifact "${arch_src}" "${RELEASE_DIR}/${APP_NAME}-${VERSION}-1-x86_64.pkg.tar.zst"
}

build_appimage() {
  local tool=""
  if command -v linuxdeploy >/dev/null 2>&1; then
    tool="linuxdeploy"
  elif command -v appimagetool >/dev/null 2>&1; then
    tool="appimagetool"
  else
    log_warn "linuxdeploy/appimagetool not found; skipped AppImage package"
    return 0
  fi

  local appdir="${STAGING_ROOT}/appimage/AppDir"
  rm -rf "${appdir}"
  copy_bundle_to "${appdir}"
  mkdir -p "${appdir}/usr/bin"
  cat > "${appdir}/usr/bin/${APP_NAME}" <<EOF
#!/usr/bin/env bash
HERE="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
exec "\${HERE}/../../opt/${APP_NAME}/${APP_NAME}" "\$@"
EOF
  chmod +x "${appdir}/usr/bin/${APP_NAME}"
  prepare_desktop_file "${appdir}/usr/share/applications/${DESKTOP_FILE}" "${APP_NAME}"
  mkdir -p "${appdir}/usr/share/icons/hicolor/512x512/apps"
  cp "${PROJECT_ROOT}/linux/icons/hicolor/512x512/apps/${PACKAGE_NAME}.png" \
    "${appdir}/usr/share/icons/hicolor/512x512/apps/${PACKAGE_NAME}.png"
  cp "${appdir}/usr/share/applications/${DESKTOP_FILE}" "${appdir}/${DESKTOP_FILE}"
  cp "${PROJECT_ROOT}/linux/icons/hicolor/512x512/apps/${PACKAGE_NAME}.png" \
    "${appdir}/${PACKAGE_NAME}.png"
  cat > "${appdir}/AppRun" <<EOF
#!/usr/bin/env bash
HERE="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
exec "\${HERE}/opt/${APP_NAME}/${APP_NAME}" "\$@"
EOF
  chmod +x "${appdir}/AppRun"

  local output="${RELEASE_DIR}/${APP_NAME}-${VERSION}-linux-amd64.AppImage"
  rm -f "${output}"
  if [[ "${tool}" == "linuxdeploy" ]]; then
    (
      cd "${PROJECT_ROOT}"
      OUTPUT="${output}" run_cmd linuxdeploy \
        --appdir "${appdir}" \
        --desktop-file "${appdir}/usr/share/applications/${DESKTOP_FILE}" \
        --icon-file "${PROJECT_ROOT}/linux/icons/hicolor/512x512/apps/${PACKAGE_NAME}.png" \
        --output appimage
    )
  else
    run_cmd appimagetool "${appdir}" "${output}"
  fi

  if [[ -f "${output}" ]]; then
    log_info "Produced ${output}"
  else
    log_error "AppImage build failed: no AppImage produced"
    exit 1
  fi
}

build_flatpak() {
  if ! command -v flatpak-builder >/dev/null 2>&1; then
    log_warn "flatpak-builder not found; skipped Flatpak package"
    return 0
  fi

  local manifest="${PROJECT_ROOT}/tool/flatpak/${PACKAGE_NAME}.yml"
  local runtime_version
  runtime_version="$(awk -F'"' '/^runtime-version:/ { print $2; exit }' "${manifest}")"
  if ! flatpak info "org.gnome.Sdk//${runtime_version}" >/dev/null 2>&1; then
    log_warn "Flatpak SDK org.gnome.Sdk//${runtime_version} not installed; skipped Flatpak package"
    log_warn "Install it with: flatpak install flathub org.gnome.Sdk//${runtime_version} org.gnome.Platform//${runtime_version}"
    return 0
  fi
  if ! flatpak info "org.gnome.Platform//${runtime_version}" >/dev/null 2>&1; then
    log_warn "Flatpak runtime org.gnome.Platform//${runtime_version} not installed; skipped Flatpak package"
    log_warn "Install it with: flatpak install flathub org.gnome.Sdk//${runtime_version} org.gnome.Platform//${runtime_version}"
    return 0
  fi

  local flatpak_stage="${STAGING_ROOT}/flatpak"
  local flatpak_build="${STAGING_ROOT}/flatpak-build"
  local flatpak_repo="${STAGING_ROOT}/flatpak-repo"
  local output="${RELEASE_DIR}/${APP_NAME}-${VERSION}-linux-amd64.flatpak"
  rm -rf "${flatpak_stage}" "${flatpak_build}" "${flatpak_repo}"
  mkdir -p "${flatpak_stage}"
  prepare_desktop_file "${flatpak_stage}/${DESKTOP_FILE}" "${APP_NAME}"
  rm -f "${output}"

  run_cmd flatpak-builder \
    --force-clean \
    --default-branch=stable \
    --repo="${flatpak_repo}" \
    "${flatpak_build}" \
    "${manifest}"

  run_cmd flatpak build-bundle \
    "${flatpak_repo}" \
    "${output}" \
    "${PACKAGE_NAME}" \
    stable
  log_info "Produced ${output}"
}

build_deb
build_rpm
build_arch
build_appimage
build_flatpak

log_info "Linux build complete"
