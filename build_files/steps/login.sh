#!/bin/bash
# Display manager: SDDM with a Wayland (weston) greeter replaces GDM.
# Sourced by build.sh.

# Qt6 modules imported by the theme's QML
dnf5 -y install \
    sddm \
    sddm-wayland-generic \
    qt6-qtsvg \
    qt6-qtvirtualkeyboard \
    qt6-qtmultimedia

SDDM_THEME_REF=abb3163c724935af888ba5ea9ac0c4f22afd8048
SDDM_THEME_DIR=/usr/share/sddm/themes/sddm-astronaut-theme
mkdir -p "${SDDM_THEME_DIR}"
curl -fsSL "https://github.com/Keyitdev/sddm-astronaut-theme/archive/${SDDM_THEME_REF}.tar.gz" |
    tar -xz --strip-components=1 -C "${SDDM_THEME_DIR}"
# The theme's fonts must be installed system-wide for the greeter to find them
mkdir -p /usr/share/fonts/sddm-astronaut-theme
mv "${SDDM_THEME_DIR}/Fonts"/* /usr/share/fonts/sddm-astronaut-theme/
rmdir "${SDDM_THEME_DIR}/Fonts"
rm -rf "${SDDM_THEME_DIR}/.github" "${SDDM_THEME_DIR}/setup.sh"

# Disabling GDM removes its display-manager.service alias so SDDM can take it
systemctl disable gdm.service
systemctl enable sddm.service
