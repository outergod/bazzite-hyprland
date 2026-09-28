#!/bin/bash

set -ouex pipefail

# Copy the contents of system_files/ of the git repo to /
cp -avf "/ctx/system_files"/. /

# Each step handles one concern and is sourced in order, sharing this shell's options.
for step in hyprland login nix; do
    # shellcheck source=/dev/null
    source "/ctx/steps/${step}.sh"
done

# Leave no build-time state in runtime-only directories or untracked /var content
dnf5 clean all
rm -rf /run/dnf /run/sddm /var/lib/dnf/repos
