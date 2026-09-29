## Why

The target desktop runs `bazzite-gnome:stable`, whose GNOME lock screen is unreliable. Because the disk unlocks itself via TPM, the login screen and the lock screen are the only real security barriers, so they have to hold. Separately, home-manager can only be used inside a toolbox container today. On the host, every HM-managed symlink points into a `/nix/store` that only exists inside that container.

This change turns the ublue image template into a Bazzite image with Hyprland as the primary desktop. It gets a lock screen that works and native host Nix, so Nix/home-manager provide the user tooling and desktop userland and the image never needs rebuilding to try a different launcher or bar.

## What Changes

- Rebase the template from `bazzite:stable` (KDE) onto `bazzite-gnome:stable`, the family the target host already runs.
- Add Hyprland, launched through uwsm, as the primary graphical session. GNOME stays installed as a selectable fallback session.
- **BREAKING**: Replace GDM with SDDM as the display manager (the Hyprland wiki lists GDM as crashing Hyprland on first launch). SDDM uses a theme that suits Hyprland. There is no autologin.
- Ship lock-screen infrastructure in the image: hyprlock (authenticating through the system PAM stack) and hypridle. The session locks on idle, on explicit request, and before suspend, and the screen is locked before the machine sleeps.
- Ship the password-authenticating and system-registered pieces of the Hyprland stack in the image: Hyprland, hyprlock, hypridle, xdg-desktop-portal-hyprland, hyprpolkitagent, uwsm.
- Leave desktop userland out of the image: launcher, bar, notification daemon, wallpaper, terminal and all configuration files come from the user's home-manager configuration.
- Add native, multi-user Nix to the host. The Fedora `nix` RPMs are installed at build time, `/nix` is persisted under `/var`, and `nix-daemon` is enabled. `home-manager switch` works on the host against the user's existing flake.
- Make the host's Nix store the single store for the user. Toolbox/distrobox containers that share `$HOME` use the host `/nix` and daemon socket instead of keeping their own store.
- **BREAKING (one-time, user-side)**: The existing single-user store in `~/.local/share/nix` (about 105G, bind-mounted into `nix-toolbox-44`) is superseded by the host store and gets migrated or rebuilt, then removed.
- Homebrew, as shipped by Bazzite, is left untouched.

Non-goals:
- Steam Gaming Mode as a login session, and deck-style session switching (`steamos-session-select`). Steam in gamescope keeps running nested inside Hyprland from the user's home-manager config (`gs.sh`).
- Autologin in any form.
- Hyprland or its userland installed through Nix, or Nix-built binaries that check passwords.
- Shipping a default Hyprland configuration or home-manager template in the image.
- Removing GNOME or Homebrew.

## Capabilities

### New Capabilities
- `desktop-session`: Base image lineage, display manager, the available graphical sessions (Hyprland through uwsm as primary, GNOME as fallback), mandatory password login, and how the user's Nix environment reaches the graphical session.
- `screen-lock`: When the session locks (idle, manual, before sleep), that the lock is up before suspend, that authentication uses the system PAM stack, and how the session behaves if the locker crashes.
- `nix-integration`: Host Nix persisted across image updates, the multi-user daemon, flakes enabled, home-manager usable on the host, and how containers share the single host store.

### Modified Capabilities
<!-- None: no existing specs in openspec/specs/. -->

## Impact

- `Containerfile`: base image reference changes to `ghcr.io/ublue-os/bazzite-gnome:stable`.
- `build_files/build.sh`: enables the `lionheartp/Hyprland` COPR for the build only, installs the Hyprland stack, SDDM and theme, and the Nix RPMs, creates the `/nix` mountpoint, swaps the display manager, and enables units.
- `system_files/`: new systemd units (the `/nix` bind mount), SDDM config, PAM adjustments (hyprlock, gnome-keyring under SDDM), SELinux file-context equivalence for `/var/nix`, and Nix config (`/etc/nix/nix.conf`).
- `image-template.env`, `README.md`, `artifacthub-repo.yml`: image name and description.
- `disk_config/iso-*.toml`: the KDE ISO config becomes irrelevant, and the GNOME ISO config needs checking against the new base.
- Target host: `bootc switch` from `ghcr.io/ublue-os/bazzite-gnome` to this image, followed by the one-time Nix store migration and recreating `nix-toolbox-44` against the host `/nix`.
- New external dependency: the `lionheartp/Hyprland` COPR (Hyprland itself isn't packaged in Fedora 44).
