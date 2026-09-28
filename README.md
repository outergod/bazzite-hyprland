# bazzite-hyprland

A [Bazzite](https://bazzite.gg/) GNOME image with [Hyprland](https://hyprland.org/) as the primary desktop and native, multi-user [Nix](https://nixos.org/) on the host.

- **Base:** `ghcr.io/ublue-os/bazzite-gnome:stable`, with Bazzite's kernel, drivers, Steam, gamescope and Homebrew unchanged.
- **Login:** SDDM with a Wayland greeter and the [sddm-astronaut](https://github.com/Keyitdev/sddm-astronaut-theme) theme. There is no autologin; every session starts with a password.
- **Sessions:** *Hyprland (uwsm-managed)* is the default. *GNOME* stays available as a fallback, and plain *Hyprland* (without uwsm) is there for debugging. SDDM remembers the last session you picked.
- **Hyprland stack:** Hyprland (with hyprland-guiutils), hyprlock, hypridle, xdg-desktop-portal-hyprland, hyprpolkitagent and uwsm, from the [`lionheartp/Hyprland`](https://copr.fedorainfracloud.org/coprs/lionheartp/Hyprland/) COPR. The COPR is only enabled while the image is built.
- **Nix:** Fedora's Nix packages with `nix-daemon`, flakes enabled, and the store in `/var/nix`, bind-mounted at `/nix` so it survives image updates and rollbacks. `@wheel` users are trusted, and the nix-community binary cache is configured.

The image does **not** ship a Hyprland configuration or any desktop userland (launcher, bar, notifications, wallpaper, terminal). All of that, including every config file, is meant to come from your [home-manager](https://github.com/nix-community/home-manager) configuration.

## Rebasing onto this image

From any bootc/ostree system (for example stock `bazzite-gnome`):

```bash
sudo bootc switch ghcr.io/outergod/bazzite-hyprland:latest
systemctl reboot
```

Your home directory and `/var` are kept. To go back, run `sudo bootc rollback` and reboot.

**Before every `bootc upgrade`, read the [Hyprland release notes](https://github.com/hyprwm/Hyprland/releases).** Hyprland is updated with the image, and new releases regularly rename or drop config options. If an update breaks your config, log into the GNOME session to fix it, or `bootc rollback`.

## What goes in the image and what comes from Nix

A component belongs in the **image** if any of these hold:

1. It checks a password (PAM or a setuid helper).
2. It must be registered with system D-Bus or the display manager, or is ABI-coupled to the compositor (portal, session files, uwsm).
3. It needs host capabilities or drivers that Nix builds can't reach (gamescope with `cap_sys_nice`, Steam).

**Everything else comes from home-manager**, including all configuration files. Nix-built apps that render with the GPU need nixGL wrapping (or home-manager's GPU support).

| Component | Where |
|---|---|
| hyprland, hyprland-guiutils, uwsm, xdg-desktop-portal-hyprland | image |
| hyprlock, hyprpolkitagent, SDDM | image |
| hypridle | image (ships with hyprlock, and it's what enforces locking) |
| gnome-keyring, gamescope, Steam | image (from Bazzite) |
| launcher, bar, notifier, wallpaper, terminal, fonts, themes | home-manager |
| `hyprland.lua`/`hyprland.conf`, `hyprlock.conf`, `hypridle.conf`, uwsm env | home-manager |

Two rules follow from this and are not enforced by the image:

- **Never use password-checking binaries from Nix.** A Nix-built hyprlock, polkit agent or similar can't reach the setuid `unix_chkpwd` helper, so authentication fails and a locker locks you out. In home-manager, use `package = null` (or config-only modules) for hyprland and hyprlock, and always call the locker by its absolute path, `/usr/bin/hyprlock`.
- **Run `home-manager switch` on the host only**, never inside a container that has its own `/nix`. Profile and dotfile links in your shared `$HOME` can only point into one store, and that store is the host's.

## Setting up the Hyprland session

The image leaves the session configuration to you. Things your home-manager config should do:

- Use `wayland.windowManager.hyprland.systemd.enable = false`, because uwsm manages the session. User services should be `WantedBy=graphical-session.target`, which uwsm starts and stops with the session.
- Start the polkit agent from the Hyprland config (`/usr/libexec/hyprpolkitagent`, or `hyprpolkitagent.service` scoped to the Hyprland session). Don't enable it for all graphical sessions, because GNOME brings its own agent.
- Configure hypridle so the screen is locked before the machine sleeps:

  ```ini
  general {
      lock_cmd = pidof hyprlock || /usr/bin/hyprlock
      before_sleep_cmd = loginctl lock-session
      inhibit_sleep = 3   # hold off suspend until the session is really locked
  }

  listener {
      timeout = 300
      on-timeout = loginctl lock-session
  }
  ```

  Bind your lock key to `loginctl lock-session` as well, so that every lock goes through hypridle's `lock_cmd`.
- Set `misc.allow_session_lock_restore` to `true` in your Hyprland config, so a crashed locker can be restarted (see below).

The Nix environment reaches the session automatically: uwsm builds the session environment from a login shell, which sources `/etc/profile.d/nix-daemon.sh`. That puts your Nix profile on `PATH` and its `share` directory in `XDG_DATA_DIRS`.

## Recovering from a crashed lock screen

hyprlock uses the `ext-session-lock` protocol, so if it crashes or is killed the session **stays locked**. Hyprland shows a "lockdead" screen instead of your desktop. To recover:

1. Switch to a text console with <kbd>Ctrl</kbd>+<kbd>Alt</kbd>+<kbd>F3</kbd> and log in as the same user.
2. Either start a new lock screen and unlock it normally:

   ```bash
   hyprctl instances          # find the instance of the locked session
   hyprctl --instance 0 eval 'hl.config({ ["misc.allow_session_lock_restore"] = true })'
   hyprctl --instance 0 eval 'hl.dispatch(hl.dsp.exec_cmd("/usr/bin/hyprlock"))'
   ```

   or end the graphical session (unsaved work in it is lost):

   ```bash
   loginctl list-sessions
   loginctl terminate-session <session-id>
   ```

3. Log out of the console and switch back with <kbd>Ctrl</kbd>+<kbd>Alt</kbd>+<kbd>F1</kbd> (or <kbd>F2</kbd>). After a restart, Hyprland's "lockdead" message may stay on screen even though the new hyprlock is active: type your password and press <kbd>Enter</kbd> to unlock.

## Nix

Nix works out of the box, with no installer to run:

```bash
nix run nixpkgs#hello
nix run home-manager -- switch --flake ~/.config/home-manager
```

On an account that has never used Nix, run `nix profile list` once before the first `home-manager switch`. It creates `~/.local/state/nix/profiles`, which home-manager expects to exist.

The store and all profiles live in `/var/nix`. That's shared by every deployment, so it survives `bootc upgrade` and `bootc rollback`. Garbage collection is up to you (`nix-collect-garbage`, or `nix.gc` in home-manager).

### Containers that share the host store

`ujust nix-toolbox` creates a [distrobox](https://distrobox.it/) container that mounts the host's `/nix` and `/etc/nix` read-only. Nix inside it uses the host daemon and the host's settings (flakes, binary caches), so builds land in the host store, and the tools and dotfiles from your home-manager profile work inside the container.

```bash
ujust nix-toolbox                # container "nix" from Fedora's toolbox image
ujust nix-toolbox dev <image>    # container "dev" from another image
distrobox enter nix
```

Don't run `home-manager switch` inside it (see above), and don't create containers with a separate Nix store that share your `$HOME`.

## Building and testing

The repository is based on the Universal Blue [image-template](https://github.com/ublue-os/image-template).

- `Containerfile` runs `build_files/build.sh`, which copies `system_files/` to `/` and then runs one step per concern from `build_files/steps/` (`hyprland.sh`, `login.sh`, `nix.sh`).
- CI (`.github/workflows/build.yml`) builds, rechunks, signs and publishes the image to GHCR. The base image digest is pinned and kept current by Renovate.

With [just](https://just.systems/) and podman:

```bash
just build            # build localhost/bazzite-hyprland:latest
just build-qcow2      # build a VM disk image (see disk_config/disk.toml)
just run-vm-qcow2     # boot it in a browser-based VM
just check            # check Just syntax
```

To test a local build on a bootc host, load it into root's container storage (see the `_rootful_load_image` recipe) and switch to it:

```bash
sudo bootc switch --transport containers-storage localhost/bazzite-hyprland:latest
```
