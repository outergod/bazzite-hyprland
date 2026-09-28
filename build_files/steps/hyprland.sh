#!/bin/bash
# Hyprland stack (compositor, locker, idle daemon, portal, polkit agent, uwsm).
# Sourced by build.sh.

# Everything Hyprland comes from this one COPR, enabled only for this install.
# Bazzite disables weak dependencies, so Hyprland's dialog helper
# (hyprland-guiutils) and the uwsm session entry (hyprland-uwsm) are listed
# explicitly.
dnf5 -y copr enable lionheartp/Hyprland
dnf5 -y install \
    hyprland \
    hyprland-guiutils \
    hyprland-uwsm \
    hyprlock \
    hypridle \
    xdg-desktop-portal-hyprland \
    hyprpolkitagent \
    uwsm
dnf5 -y copr disable lionheartp/Hyprland
