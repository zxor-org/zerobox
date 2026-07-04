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
log_info "Building Linux release packages for version ${VERSION}"

require_flutter
require_command dpkg-deb
require_command rpmbuild
require_command makepkg
ensure_release_dir

log_info "Running: flutter build linux --release --obfuscate --split-debug-info=symbols/"
flutter build linux --release --obfuscate --split-debug-info=symbols/

BUNDLE_DIR="${PROJECT_ROOT}/build/linux/x64/release/bundle"
SYMBOLS_DIR="${PROJECT_ROOT}/build/linux/x64/release/symbols"
if [[ ! -d "${BUNDLE_DIR}" ]]; then
  log_error "Linux build bundle not found: ${BUNDLE_DIR}"
  exit 1
fi

# 1. tar.gz
TAR_DST="${RELEASE_DIR}/${APP_NAME}-${VERSION}-linux-amd64.tar.gz"
rm -f "${TAR_DST}"
(
  cd "${BUNDLE_DIR}/.."
  tar czf "${TAR_DST}" "$(basename "${BUNDLE_DIR}")"
)
log_info "Produced ${TAR_DST}"

# 1b. debug symbols tar.gz
SYMBOLS_DST="${RELEASE_DIR}/${APP_NAME}-${VERSION}-linux-amd64.symbols.tar.gz"
rm -f "${SYMBOLS_DST}"
if [[ -d "${SYMBOLS_DIR}" ]]; then
  (
    cd "${SYMBOLS_DIR}/.."
    tar czf "${SYMBOLS_DST}" "$(basename "${SYMBOLS_DIR}")"
  )
  log_info "Produced ${SYMBOLS_DST}"
fi

STAGING_ROOT="${PROJECT_ROOT}/build/linux_staging"
rm -rf "${STAGING_ROOT}"
INSTALL_PREFIX="/opt/${APP_NAME}"

# Shared staging content
mkdir -p "${STAGING_ROOT}${INSTALL_PREFIX}"
cp -a "${BUNDLE_DIR}"/* "${STAGING_ROOT}${INSTALL_PREFIX}/"

# Make sure the binary is executable
chmod +x "${STAGING_ROOT}${INSTALL_PREFIX}/${APP_NAME}"

# Strip unneeded symbols from native binaries and libraries
find "${STAGING_ROOT}${INSTALL_PREFIX}" -type f \( -name '*.so' -o -name 'zerobox' \) -exec strip --strip-unneeded {} \; 2>/dev/null || true

# Desktop file
mkdir -p "${STAGING_ROOT}/usr/share/applications"
cp "${PROJECT_ROOT}/linux/${PACKAGE_NAME}.desktop.in" "${STAGING_ROOT}/usr/share/applications/${PACKAGE_NAME}.desktop"
sed -i "s|@CMAKE_INSTALL_PREFIX@|${INSTALL_PREFIX}|g" "${STAGING_ROOT}/usr/share/applications/${PACKAGE_NAME}.desktop"

# 2. Debian package
build_deb() {
  local deb_root="${STAGING_ROOT}/deb"
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

  mkdir -p "${deb_root}${INSTALL_PREFIX}"
  cp -a "${BUNDLE_DIR}"/* "${deb_root}${INSTALL_PREFIX}/"
  mkdir -p "${deb_root}/usr/share/applications"
  cp "${STAGING_ROOT}/usr/share/applications/${PACKAGE_NAME}.desktop" "${deb_root}/usr/share/applications/"

  local deb_out="${RELEASE_DIR}/${APP_NAME}_${VERSION}_amd64.deb"
  dpkg-deb --build "${deb_root}" "${deb_out}"
  log_info "Produced ${deb_out}"
}

# 3. RPM package
build_rpm() {
  local rpm_top="${STAGING_ROOT}/rpm"
  mkdir -p "${rpm_top}"/{BUILD,RPMS,SOURCES,SPECS,SRPMS}

  local release_num="1"
  local rpm_version="${VERSION}"
  # RPM versions cannot contain '-'; Debian/Ubuntu uses '.' separators.
  rpm_version="${rpm_version//-/.}"

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
cp ${STAGING_ROOT}/usr/share/applications/${PACKAGE_NAME}.desktop %{buildroot}/usr/share/applications/

%files
${INSTALL_PREFIX}
/usr/share/applications/${PACKAGE_NAME}.desktop

%changelog
* $(date +"%a %b %d %Y") ${MAINTAINER} - ${rpm_version}-${release_num}
- Package release
EOF

  rpmbuild --define "_topdir ${rpm_top}" -bb "${rpm_top}/SPECS/${APP_NAME}.spec"
  local rpm_out_src
  rpm_out_src="$(find "${rpm_top}/RPMS" -name '*.rpm' | head -n 1)"
  if [[ -z "${rpm_out_src}" ]]; then
    log_error "RPM build failed: no .rpm file produced"
    exit 1
  fi
  local rpm_out="${RELEASE_DIR}/${APP_NAME}-${VERSION}-${release_num}.x86_64.rpm"
  cp "${rpm_out_src}" "${rpm_out}"
  log_info "Produced ${rpm_out}"
}

# 4. Arch package
build_arch() {
  local arch_root="${STAGING_ROOT}/arch"
  mkdir -p "${arch_root}"

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
source=()

package() {
  mkdir -p "\${pkgdir}${INSTALL_PREFIX}"
  cp -a "${BUNDLE_DIR}"/* "\${pkgdir}${INSTALL_PREFIX}/"
  mkdir -p "\${pkgdir}/usr/share/applications"
  cp "${STAGING_ROOT}/usr/share/applications/${PACKAGE_NAME}.desktop" "\${pkgdir}/usr/share/applications/"
}
EOF

  (
    cd "${arch_root}"
    makepkg -f --skipchecksums
  )

  local arch_out_src
  arch_out_src="$(find "${arch_root}" -maxdepth 1 -name '*.pkg.tar.zst' ! -name '*-debug-*' | head -n 1)"
  if [[ -z "${arch_out_src}" ]]; then
    log_error "Arch package build failed: no .pkg.tar.zst file produced"
    exit 1
  fi
  local arch_out="${RELEASE_DIR}/${APP_NAME}-${VERSION}-1-x86_64.pkg.tar.zst"
  cp "${arch_out_src}" "${arch_out}"
  log_info "Produced ${arch_out}"
}

build_deb
build_rpm
build_arch

log_info "Linux build complete."
