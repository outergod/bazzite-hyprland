#!/bin/bash
# Native multi-user Nix; the store lives in /var/nix and is bind-mounted at /nix.
# Sourced by build.sh.

# Bazzite disables weak dependencies, so the packages Fedora's Nix only
# recommends are listed explicitly: busybox is the build sandbox's /bin/sh
# (sandbox-paths), and nix-legacy provides nix-env, nix-store,
# nix-collect-garbage and the other classic commands.
dnf5 -y install \
    busybox \
    nix \
    nix-daemon \
    nix-legacy \
    nix-system \
    nix-filesystem

# system_files already provides /etc/nix/nix.conf, so the RPM's copy lands as .rpmnew
rm -f /etc/nix/nix.conf.rpmnew

# /nix in the image is only the mountpoint that nix.mount covers; the RPM-created
# store and state directories are recreated in /var/nix by tmpfiles at boot.
find /nix -mindepth 1 -delete

systemctl enable nix.mount nix-daemon.socket

# Fedora's policy has no contexts for /nix. /var/nix is labeled like /nix.
semanage import <<'SEMANAGE'
fcontext -a -e /nix /var/nix
fcontext -a -t bin_t '/nix/store/[^/]+/s?bin(/.*)?'
fcontext -a -t lib_t '/nix/store/[^/]+/lib(/.*)?'
fcontext -a -t systemd_unit_file_t '/nix/store/[^/]+/lib/systemd/system(/.*)?'
fcontext -a -t etc_t '/nix/store/[^/]+/etc(/.*)?'
fcontext -a -t usr_t '/nix/store/[^/]+/share(/.*)?'
fcontext -a -t man_t '/nix/store/[^/]+/man(/.*)?'
fcontext -a -t var_run_t '/nix/var/nix/daemon-socket(/.*)?'
fcontext -a -t usr_t '/nix/var/nix/profiles(/per-user/[^/]+)?/[^/]+'
SEMANAGE
