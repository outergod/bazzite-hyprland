## Context

The repo is an unmodified ublue `image-template`: a `Containerfile` that runs `build_files/build.sh` on top of a base image, `system_files/` copied to `/`, and CI that builds and publishes to GHCR. The base is currently `bazzite:stable` (KDE).

Target host facts that shape the design:
- It runs `ghcr.io/ublue-os/bazzite-gnome:stable`, Fedora 44, on an AMD GPU (amdgpu), so no Nvidia variant is needed.
- LUKS is unlocked by TPM, so the display manager and the lock screen are the only authentication barriers.
- Nix currently lives in a rootless toolbox (`nix-toolbox-44`, image `ghcr.io/thrix/nix-toolbox:44`). Its `/nix` is a bind mount of the host's `~/.local/share/nix`: a single-user store owned by `outergod`, about 105G, with no daemon.
- Profiles (`~/.nix-profile` -> `~/.local/state/nix/profiles/profile`), HM generations and HM gcroots all live in `$HOME`, which is shared between host and container. HM activation already happens inside the container.
- The user's home-manager flake lives at `~/.config/home-manager` (nixos-unstable, emacs-overlay, nixGL with `targets.genericLinux.nixGL`). An older NixOS-era Hyprland HM config also exists and needs porting (for example, `windowrulev2` and `gestures:workspace_swipe` are outdated).

Packaging facts verified against Fedora 44 repos:
- Hyprland, hyprlock, hypridle, xdg-desktop-portal-hyprland, hyprpolkitagent and uwsm are **not** in Fedora 44. Only outdated helper libraries (hyprutils 0.7.1, hyprlang 0.6.4, ...) are.
- Nix 2.34.8 is packaged as `nix`, `nix-core`, `nix-daemon`, `nix-system`, `nix-filesystem` and `nix-legacy`. `nix-filesystem` owns `/nix` through tmpfiles (`q /nix`, subvolume-capable). `nix-daemon` ships `nix-daemon.{socket,service}`, a sysusers file and `/etc/profile.d/nix-daemon.{sh,fish}`. The profile script prepends the user profile's `bin` to `PATH` and appends its `share` to `XDG_DATA_DIRS`.
- Fedora 44's targeted SELinux policy contains **no** file contexts for `/nix`, and no Nix policy subpackage exists.
- SDDM 0.21.0 is packaged. The greeter's display server comes from a separate package: `sddm-wayland-generic` (weston), `sddm-wayland-sway`, `sddm-wayland-plasma` or `sddm-x11`.

## Goals / Non-Goals

**Goals:**
- One rule decides what goes in the image versus Nix, and it stays stable as the userland changes.
- Swapping userland components (launcher, bar, notifier, terminal) never requires an image rebuild.
- The host has exactly one Nix store and one set of profiles, whether tools run on the host or in containers.
- Rollback through `bootc rollback` is always a valid recovery path, including after a Hyprland update breaks the user's config.

**Non-Goals:**
- Validating or versioning the user's Hyprland config against the image's Hyprland version.
- Managing the user's HM flake from this repo, or shipping `home-manager` itself in the image. The user runs it via `nix run` or their own profile.
- Making Nix usable in containers that don't share `$HOME` with the host. They're isolated and unaffected.

## Decisions

### D1: Base image is `bazzite-gnome:stable`

Rebasing within the same family as the host minimizes `/etc` three-way-merge drift. It also keeps gnome-keyring (which the user's apps and the old config expect) and GNOME as a working fallback while the Hyprland config is ported.

Alternatives:
- `bazzite:stable` (KDE) already has SDDM, but it means rebasing the host's `/etc` from GNOME to KDE, living with KWallet, and switching the fallback to Plasma.
- `bazzite-deck-gnome` exists for Gaming Mode session switching, which is out of scope and relies on autologin.

### D2: The platform/userland rule

A component goes in the **image** if any of these hold:
1. It authenticates a password (PAM or a setuid helper). Nix-built binaries use a `unix_chkpwd` or polkit helper from the store, which isn't setuid, so authentication fails. For a locker, that means being locked out.
2. It must be registered with system D-Bus or the display manager, or is ABI-coupled to the compositor (portal, session files, uwsm).
3. It needs host capabilities or drivers that Nix builds can't reach (gamescope with `cap_sys_nice`, Steam).

Everything else comes from **home-manager**, including every configuration file. Nix-built GPU-rendering apps are wrapped with nixGL, or with HM's newer GPU support once it's evaluated (see Open Questions). The image enforces its side and the user's HM config follows the rule by convention.

| Component | Where | Why |
|---|---|---|
| hyprland, hyprland-guiutils, uwsm, hyprland-uwsm, xdg-desktop-portal-hyprland | image | rule 2 |
| hyprlock, hyprpolkitagent, sddm | image | rule 1 |
| hypridle | image | Not strictly required, but it ships alongside hyprlock from the same source so they stay compatible, and hypridle is what enforces the screen-lock guarantee |
| gnome-keyring, gamescope, steam | image (already in base) | rules 1 and 3 |
| launcher, bar, notifier, wallpaper, terminal, udiskie, fonts, themes, `gs.sh` | HM | userland |
| hyprland.conf, hyprlock.conf, hypridle.conf, uwsm env | HM | configuration |

Alternative considered: installing Hyprland from Nix. Rejected because the user wants the compositor updated through ostree, because of GPU driver coupling, and because of rule 1 for the locker.

### D3: Hyprland stack from the `lionheartp/Hyprland` COPR

The Hyprland wiki names it as the Fedora source, and it has current F44 builds of every component we need (hyprland 0.56.2, hyprlock 0.9.6, hypridle 0.1.8, xdg-desktop-portal-hyprland 1.4.1, hyprpolkitagent 0.2.0, uwsm 0.27.0, aquamarine 0.15.1). The COPR is enabled only for the install step and disabled afterwards, following the template's pattern, so the running system doesn't pull from it outside image builds. The whole stack comes from this one COPR so its components never mix with another source's builds. Bazzite sets `install_weak_deps=False`, and `hyprland` only recommends two pieces the session needs, so they're installed explicitly: `hyprland-guiutils` (Hyprland's own dialogs, such as the not-responding and permission prompts; it warns at startup when it's missing) and `hyprland-uwsm` (the uwsm session entry). Its other recommendations (kitty, wofi, brightnessctl, playerctl, hyprpicker) are userland and stay out of the image.

Alternatives:
- `sdegler/hyprland` is equally current but not referenced by the wiki.
- `solopasha/hyprland` is stale (last Hyprland build October 2025, none for F44).
- Fedora proper doesn't package it.

### D4: SDDM replaces GDM, with a Wayland greeter via `sddm-wayland-generic`

The Hyprland wiki lists SDDM as working flawlessly and GDM as crashing Hyprland on first launch. The user prefers SDDM because it has themes that suit Hyprland.

- **Display manager:** GDM stays installed (GNOME packages may depend on it) but `display-manager.service` points to `sddm.service`.
- **Greeter backend:** `sddm-wayland-generic` (weston) avoids pulling in an Xorg server (`sddm-x11`) or a second compositor stack (`sddm-wayland-sway`, `-plasma`).
- **Default session:** SDDM 0.21 has no default-session key. The greeter preselects the session recorded in `/var/lib/sddm/state.conf` (`[Last] Session=`, a full path), so a tmpfiles `f` rule writes that file with `/usr/share/wayland-sessions/hyprland-uwsm.desktop` when it doesn't exist. It must be written rather than copied from the image: SDDM only reads a config file whose mtime is after the epoch, and a `C` copy keeps the image's normalized 1970 mtime, so SDDM would ignore it. SDDM keeps remembering the last session (turning that off makes it clear the value, which falls back to the alphabetically first session, GNOME), so after a deliberate GNOME login the user reselects Hyprland once.
- **Autologin:** none. SDDM's autologin is left unset, and any inherited GDM autologin config becomes irrelevant.
- **Theme:** [sddm-astronaut-theme](https://github.com/Keyitdev/sddm-astronaut-theme) (GPL-3.0-or-later, Qt6), pinned to commit `abb3163c724935af888ba5ea9ac0c4f22afd8048` (2026-09-18). It's fetched at build time into `/usr/share/sddm/themes/sddm-astronaut-theme`, its bundled fonts go to `/usr/share/fonts`, and it's selected in `/etc/sddm.conf.d/`. The look (one of the theme's built-in variants) is chosen by the theme's `metadata.desktop` `ConfigFile=`, which the upstream default keeps as `Themes/astronaut.conf`. Its Qt6 dependencies come from Fedora: `qt6-qtsvg`, `qt6-qtvirtualkeyboard` and `qt6-qtmultimedia`. The Catppuccin SDDM themes were the other candidate.
- **PAM:** Fedora's `/etc/pam.d/sddm` is checked (and extended if needed) so `pam_gnome_keyring` unlocks the login keyring from the login password. Fedora's already runs it in the auth and session stacks. That alone isn't enough outside GNOME: the module starts `gnome-keyring-daemon --login`, which exits after 120 seconds unless `gnome-keyring-daemon --start` initializes it. GNOME's `gnome-keyring-secrets.desktop` autostart entry does that, but only for GNOME, Unity and MATE, so the image ships an equivalent entry for Hyprland (`OnlyShowIn=Hyprland`) that uwsm runs. Without it, the first secret request after two minutes starts a fresh daemon that doesn't have the password and prompts for it.

Alternatives: greetd + ReGreet (the user dislikes the look), greetd + tuigreet, ly.

### D5: Hyprland starts through uwsm, which also carries the Nix environment into the session

The default SDDM session is the uwsm-wrapped Hyprland entry (`hyprland-uwsm.desktop`), shipped by the COPR's `hyprland-uwsm` subpackage. uwsm builds the session environment from a login shell (sh), which picks up `/etc/profile.d/nix-daemon.sh`. That gives `PATH` and `XDG_DATA_DIRS` the Nix profile, so the launcher sees apps installed through Nix. uwsm also starts `graphical-session.target`, which is what the user's HM systemd user units (hypridle, wallpaper, emacs, ...) should be `WantedBy`.

The HM Hyprland module must use `systemd.enable = false`, as the wiki advises for uwsm. `hm-session-vars.sh` reaches the session through the user's POSIX profile, which HM manages. The plain `hyprland.desktop` session stays available as a debugging fallback.

Alternative: HM's own Hyprland systemd integration without uwsm. It needs `exec-once` plumbing for every service and doesn't bind the session to logind as cleanly.

### D6: Lock sequence

hypridle (from the image) is the only lock trigger; the user configures it through HM.
- **Lock command:** `lock_cmd = pidof hyprlock || /usr/bin/hyprlock`, with an absolute path so a Nix hyprlock earlier in `PATH` can never be used.
- **Triggers:** `before_sleep_cmd = loginctl lock-session`, an idle listener, and a manual keybind calling `loginctl lock-session`.
- **Suspend:** hypridle's sleep inhibition waits until the lock is up before letting the machine sleep. The exact option name is verified against hypridle 0.1.8.
- **Crash behaviour:** hyprlock uses `ext-session-lock-v1`, so a crash leaves the session locked rather than exposed. Recovery goes through a TTY login (documented in the README).
- **PAM:** the COPR's `/etc/pam.d/hyprlock` is used as-is, or a minimal one including `system-auth` is shipped if it's missing.

The image provides what makes this sequence possible. Idle timeouts and hypridle's config belong to the user; the spec defines the behaviour the combination must meet.

### D7: Nix is multi-user, stored in `/var/nix`, bind-mounted at `/nix`

- **Build time:** install `nix`, `nix-daemon`, `nix-system` and `nix-filesystem`. The RPM-created `/nix` directory in the image is the empty, read-only mountpoint. Nothing under it in the image matters because the mount hides it.
- **Runtime:** a `nix.mount` unit binds `/var/nix` onto `/nix`. It's ordered before `nix-daemon.socket` and before `systemd-tmpfiles-setup.service`, so the RPM's tmpfiles rules populate `/nix/var/...` inside the persistent store. A tmpfiles rule creates `/var/nix` itself. Because the mount runs before `systemd-tmpfiles-setup.service`, a small early oneshot (`nix-var-dir.service`, ordered before `nix.mount`) applies that one rule first.
- **Config:** `/etc/nix/nix.conf` sets `experimental-features = nix-command flakes` and `trusted-users = root @wheel`, and adds the nix-community binary cache (emacs-overlay).
- **Units:** `nix-daemon.socket` is enabled.

A bind mount rather than a symlink, because Nix refuses a symlinked `/nix`. `/var/nix` rather than something under `$HOME`, because the store must be root-owned for multi-user and must not depend on a particular user's home.

Alternatives:
- The Determinate installer's ostree planner broke with composefs (it needs `chattr -i /`).
- The Fedora wiki's advice for ostree systems, rootless `nix-core`, puts store paths outside `/nix/store` and loses the binary cache.
- Keeping `/nix` as a bind of `~/.local/share/nix` in single-user mode avoids the migration, but hardcodes one user's home into the OS and labels the store as home content.

### D8: SELinux file contexts for `/nix` ship with the image

Fedora 44's policy doesn't label `/nix`, so the image ships file-context rules: an equivalence rule so `/var/nix` is labeled like `/nix`, plus type rules for store paths.
- Store paths: `bin`/`sbin` -> `bin_t`, `lib` -> `lib_t`, `lib/systemd/system` -> `systemd_unit_file_t`, `etc` -> `etc_t`, `share` -> `usr_t`, `man` -> `man_t`.
- The daemon socket directory -> `var_run_t`.
- Profiles -> `usr_t`.

These rules are applied at build time. Store paths created later by the daemon take their labels from their parent directory. Whether that's sufficient (user units run as `unconfined_t`), or whether a relabel hook is needed after builds, is settled by the first on-host test (see Risks).

Alternative: running with `nix-daemon` in permissive or a custom domain. Rejected because it's broader than needed.

### D9: One store; containers use the host store

Any container that shares `$HOME` either bind-mounts the host `/nix` (read-only view, with writes through `/nix/var/nix/daemon-socket/socket`) or doesn't use Nix. `home-manager switch` runs on the host only.

This works rootless:
- The root-owned store appears as `nobody`-owned inside the container but is world-readable.
- Nix's `auto` store falls back to the daemon when the store isn't writable.
- The daemon sees the caller's real host UID.
- Toolbox disables SELinux labeling for containers.

The image ships a `ujust` recipe (`ujust nix-toolbox`) that creates the container with `/nix` mounted read-only from the host. It uses distrobox, because `toolbox create` can't add volumes; the target host's `nix-toolbox-44` is already a distrobox container, and Bazzite's own `ujust` recipes use distrobox too. The recipe's container image is a parameter, defaulting to Fedora's toolbox image; the Nix client comes from the user's HM profile or the daemon-backed `nix` on the host.

Alternative: separate stores per environment. Rejected because profile links, HM generations and HM-managed dotfiles in the shared `$HOME` can only point into one store, so the environments would overwrite each other's links.

### D10: Homebrew and Bazzite's defaults are untouched

The change removes nothing Bazzite ships except making GDM inactive.

## Risks / Trade-offs

- [Store-path labeling by inheritance is insufficient under enforcing SELinux] -> The first on-host test runs HM user units and GPU apps under enforcing and checks `ausearch -m avc`. If denials appear, add a `restorecon` hook (a systemd path unit on `/nix/store` or a Nix `post-build-hook`) before shipping.
- [An image update brings a Hyprland release that breaks the user's HM config] -> `bootc rollback`. The GNOME fallback session remains available to fix the config from a working desktop. The README says to read Hyprland release notes before `bootc upgrade`.
- [COPR outage or breakage, or a COPR build conflicting with Bazzite's patched Mesa or other replaced libraries] -> CI builds daily and fails loudly. The previous image stays deployable. The pinned base digest (Renovate-managed) limits churn to deliberate bumps.
- [SDDM with the weston greeter fails on this AMD setup, or the theme's QML dependencies are missing] -> Validate in a VM or on the host before switching the default display manager. Switching to `sddm-x11` is a package swap, not a redesign.
- [The keyring doesn't unlock at SDDM login] -> Covered by the PAM check in D4. Symptom: apps prompt for the keyring password after login.
- [GDM or GNOME updates re-enable GDM] -> `display-manager.service` is an alias in `/etc`, which Bazzite's updates don't overwrite once this image sets it. Verified after the first image upgrade.
- [The user runs `home-manager switch` inside a container with its own `/nix`] -> Profile links in `$HOME` point into a store the host can't see. Mitigation is procedural (D9 rule) plus retiring `nix-toolbox-44`. Recovery is running `home-manager switch` on the host.
- [Nix client/daemon version skew between HM's `nix` and Fedora's daemon] -> Older clients work with newer daemons. Pin the HM profile's Nix to match the daemon if issues appear.
- [Store growth] -> `/var/nix` grows with the store. It sits on the same btrfs as `/var` (LUKS). GC is the user's responsibility (`nix.gc` in HM or `nix-collect-garbage`).

## Migration Plan

1. Build the image in CI and test in a VM: SDDM login, the Hyprland (uwsm) and GNOME sessions, a hyprlock round-trip, suspend then resume while locked, `nix-daemon`, and `/nix` persisting across `bootc upgrade`.
2. On the host, `bootc switch ghcr.io/outergod/<image>:latest` and reboot. Log in through SDDM, starting with the GNOME session.
3. Nix store migration, one-time, choosing one of:
   - (a) a clean start: `nix run home-manager -- switch --flake ~/.config/home-manager` on the host, rebuilding from caches;
   - (b) copying first: `nix copy --no-check-sigs --from ~/.local/share/nix --to daemon <current-generation>`, then running `home-manager switch`.
   Then delete stale generation and channel links in `~/.local/state/nix/profiles`, and remove `~/.local/share/nix` once the host environment is confirmed working.
4. Recreate the Nix toolbox with the `ujust` recipe (host `/nix`), and retire `nix-toolbox-44`.
5. Port the Hyprland HM config (package set to `null` or config-only for hyprland and hyprlock, uwsm-compatible services, the `/usr/bin/hyprlock` lock command), then switch the SDDM default to Hyprland.

**Rollback:** `bootc rollback` returns to the previous deployment, including the stock `bazzite-gnome` if needed. `/var/nix` and `$HOME` persist, so a rolled-back host without `/nix` sees dangling HM links, which is the same as today's state. Keep `~/.local/share/nix` until step 5 is confirmed so the old container still works during the transition.

## Open Questions

- ~~Which SDDM theme?~~ Resolved: sddm-astronaut-theme at `abb3163c` (see D4).
- Should HM's `targets.genericLinux.gpu` replace the user's nixGL wrapping, and if so, does the image need to provide its system-side piece? This is user-side, and the image works either way.
- Default toolbox image for the `ujust` recipe: Fedora's toolbox image or `ghcr.io/thrix/nix-toolbox` with `/nix` remapped. It's a parameter either way.
