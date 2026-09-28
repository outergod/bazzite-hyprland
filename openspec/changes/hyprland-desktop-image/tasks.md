## 1. Repository and base image

- [x] 1.1 Set `IMAGE_NAME=bazzite-hyprland`, `REPO_ORGANIZATION=outergod`, `IMAGE_DESC` and `IMAGE_KEYWORDS` in `image-template.env`. Verify `just image_name` prints `bazzite-hyprland`.
- [x] 1.2 Switch the `Containerfile` base to `ghcr.io/ublue-os/bazzite-gnome:stable` pinned by digest, and remove the template's alternative-base comments. Verify `just build` pulls the GNOME base and `podman run --rm localhost/bazzite-hyprland cat /usr/share/ublue-os/image-info.json` reports `bazzite-gnome` as the base.
- [x] 1.3 Delete `disk_config/iso-kde.toml`, point `disk_config/iso-gnome.toml`'s kickstart `bootc switch` at `ghcr.io/outergod/bazzite-hyprland:latest`, and update any workflow or Justfile references to the KDE ISO config. Verify `grep -r iso-kde .github Justfile` returns nothing and `just check` passes.
- [x] 1.4 Remove the template's example `tmux` install and `podman.socket` enablement from `build_files/build.sh`, and split the script into sourced per-concern steps (hyprland, login, nix). Verify `just build` succeeds with the empty steps.

## 2. Hyprland stack

- [x] 2.1 In the hyprland build step, enable the `lionheartp/Hyprland` COPR, install `hyprland`, `hyprlock`, `hypridle`, `xdg-desktop-portal-hyprland`, `hyprpolkitagent` and `uwsm`, then disable the COPR. Verify in the built image that `rpm -q` lists all six packages and that no COPR repo file under `/etc/yum.repos.d/` is enabled.
- [x] 2.2 Check that the installed packages provide both the uwsm-wrapped and plain Hyprland session entries in `/usr/share/wayland-sessions/`, and add the uwsm entry in `system_files/` if the packages don't ship it. Verify both `.desktop` files exist in the built image.
- [x] 2.3 Check that `/etc/pam.d/hyprlock` exists in the built image and includes the system auth stack, and ship a minimal one in `system_files/` if it's missing. Verify with `podman run --rm localhost/bazzite-hyprland cat /etc/pam.d/hyprlock`.
- [x] 2.4 Confirm no COPR package replaces a Bazzite-provided library (Mesa and the other libraries Bazzite ships its own versions of) by comparing `rpm -qa --qf '%{name} %{vendor}\n'` before and after the hyprland step. Record the result in the PR description.

## 3. Login (SDDM)

- [x] 3.1 Pick the SDDM theme with the user from the design's candidates (sddm-astronaut-theme, the Catppuccin SDDM themes), and record the choice and a pinned upstream ref in `design.md` (resolving that open question).
- [x] 3.2 Install `sddm` and `sddm-wayland-generic`, plus the chosen theme's Qt6 QML dependencies from Fedora. Fetch the theme at its pinned ref into `/usr/share/sddm/themes/`. Verify `rpm -q sddm sddm-wayland-generic` and that the theme directory is present in the built image.
- [x] 3.3 Add `/etc/sddm.conf.d/` config in `system_files/`: selected theme, Wayland greeter, default session set to the uwsm Hyprland entry, and no `[Autologin]` user or session. Verify `grep -ri autologin /etc/sddm.conf.d /etc/sddm.conf 2>/dev/null` shows no user or session set in the built image.
- [x] 3.4 Disable `gdm.service`, enable `sddm.service`, and make `display-manager.service` point to SDDM. Verify in the built image that `readlink /etc/systemd/system/display-manager.service` ends in `sddm.service`.
- [x] 3.5 Make sure `/etc/pam.d/sddm` runs `pam_gnome_keyring.so` in both its auth and session stacks (`auto_start` in session), adjusting it in `system_files/` if Fedora's default lacks it. Verify by inspecting the file in the built image.

## 4. Nix

- [x] 4.1 In the nix build step, install `nix`, `nix-daemon`, `nix-system` and `nix-filesystem`, keep `/nix` as an empty directory in the image, and enable `nix-daemon.socket`. Verify in the built image that `/nix` is a directory with no store content and `systemctl is-enabled nix-daemon.socket` reports `enabled`.
- [x] 4.2 Add a tmpfiles rule creating `/var/nix` (root, 0755) and a `nix.mount` unit binding `/var/nix` to `/nix`. It's wanted by `local-fs.target` and ordered before `systemd-tmpfiles-setup.service` and `nix-daemon.socket`. Verify `systemd-analyze verify` on the unit passes inside the built image.
- [x] 4.3 Ship `/etc/nix/nix.conf` with `experimental-features = nix-command flakes`, `trusted-users = root @wheel`, and the nix-community substituter and public key alongside cache.nixos.org. Verify `nix config show` inside the built image reflects these values.
- [x] 4.4 Ship SELinux file-context rules for `/nix`: an equivalence rule for `/var/nix` -> `/nix`, and labels for store `bin`/`sbin`, `lib`, `lib/systemd/system`, `etc`, `share`, `man`, the daemon socket directory and profiles. Apply them at build time via `semanage` or a policy module. Verify `matchpathcon /nix/store/abc-x/bin/y /var/nix/store/abc-x/lib/systemd/system/z.service` in the built image prints `bin_t` and `systemd_unit_file_t`.
- [x] 4.5 Add a ujust recipe (`/usr/share/ublue-os/just/60-custom.just`) that creates a toolbox with the host `/nix` bind-mounted, taking the container image as a parameter that defaults to Fedora's toolbox image. Verify `ujust --list` in the built image shows the recipe.

## 5. Image build and CI

- [x] 5.1 Make sure `bootc container lint` passes at the end of the `Containerfile`. Verify `just build` completes without lint errors.
- [x] 5.2 Push the branch and open a PR. Verify the "Build container image" workflow succeeds, including the rechunk step.

## 6. VM validation (system behaviour across tasks 2 to 4)

- [x] 6.1 Build a qcow2 with a password-protected test user (`[[customizations.user]]` in `disk_config/disk.toml` for local builds only) via `just build-qcow2` and boot it via `just run-vm-qcow2`. Verify the VM reaches a themed SDDM login screen with no automatic login.
- [x] 6.2 Log in to the default session and to the GNOME session. Verify the default is Hyprland running under uwsm (`systemctl --user is-active graphical-session.target` reports `active`), GNOME starts, and logging out returns to SDDM in both cases.
- [ ] 6.3 With a minimal `hypridle.conf` and `hyprlock.conf` (`lock_cmd = pidof hyprlock || /usr/bin/hyprlock`, `before_sleep_cmd = loginctl lock-session`, and hypridle's sleep-inhibit setting confirmed against the installed hypridle version), check four things. Verify each: `loginctl lock-session` locks; the correct password unlocks and a wrong one doesn't; suspend then resume shows the lock screen first; `pkill -9 hyprlock` leaves the display covered and recovery works from a TTY.
  - VM result: lock, wrong/right password and crash recovery pass (after recovery, Hyprland's lockdead message stays visible while the new hyprlock accepts the password). Suspend was entered and resumed, but the VM's virtio GPU never re-enabled its output, so "lock screen first after resume" moves to the host check in 8.5.
- [x] 6.4 Check that the login unlocks the keyring. Verify `secret-tool store --label=t k v` followed by `secret-tool lookup k` works in the Hyprland session with no keyring prompt after login.
  - VM result: failed at first. The daemon started by `pam_gnome_keyring` exits after 120 s unless `gnome-keyring-daemon --start` initializes it, and GNOME's autostart entry for that is limited to GNOME/Unity/MATE. Fixed with a Hyprland-only autostart entry (`/etc/xdg/autostart/gnome-keyring-secrets-hyprland.desktop`). Verified in the VM with the entry placed by hand, after all sessions ended and more than 2 minutes after login: store and lookup worked without a prompt.
- [x] 6.5 Trigger a polkit authentication from Hyprland (for example `pkexec true`). Verify the image's agent prompts and the password is accepted.
- [x] 6.6 Exercise Nix as the test user: run `nix run nixpkgs#hello`, then a standalone home-manager switch with one package and one systemd user unit `WantedBy=graphical-session.target`. Verify both work, the user unit runs at the next Hyprland login, the package is on `PATH` in fish and bash login shells and in a Hyprland `exec`, and `ausearch -m avc -ts recent` shows no denials. Fix the SELinux setup from task 4.4 or add a relabel hook if it does.
  - VM result: failed at first because Fedora's Nix only recommends `busybox` (the build sandbox's `/bin/sh`) and `nix-legacy` (`nix-env`, needed by home-manager), and Bazzite skips weak dependencies. Both are now installed explicitly. With stand-ins for the two packages in the VM: `nix run nixpkgs#hello` works, store paths are root-owned, the home-manager switch succeeds, `cowsay` is on `PATH` in bash and fish login shells and in Hyprland `exec`, `hm-probe` is active after a reboot and login, and there are no AVC denials even though new store paths are labeled `default_t`. A fresh account needs one profile operation (`nix profile list`) before its first switch; the README says so.
- [ ] 6.7 Rebuild the image with a trivial change and `bootc upgrade` the VM, then `bootc rollback`. Verify store paths and home-manager generations survive both, and `nix-daemon` keeps working.
- [x] 6.8 Create a toolbox with the ujust recipe. Verify a home-manager-installed command runs inside it, `nix build nixpkgs#hello` inside it produces a store path visible on the host, and `~/.nix-profile` resolves both on the host and in the container.
  - VM result: with only `/nix` mounted, the container's Nix client had no `nix.conf`, so `nix build` failed (`nix-command` disabled). The recipe now also mounts `/etc/nix` read-only. With that, the client uses the host's settings and the daemon (`Store URL: daemon`, 2.34.8), a new path built in the container shows up in the host store, `cowsay` from the HM profile is on `PATH`, and `~/.nix-profile` resolves to the same store path inside and outside the container.

## 7. Documentation

- [x] 7.1 Rewrite `README.md`. It should cover what the image is, how to rebase onto it, the platform/userland rule, the "no password-checking binaries from Nix" and "run home-manager on the host only" rules, the lock-screen recovery procedure from a TTY, the Nix toolbox recipe, and "read Hyprland release notes before `bootc upgrade`". Verify the README renders on GitHub and covers each of these topics.
- [x] 7.2 Update `artifacthub-repo.yml` and the image labels for the new name and description. Verify `just build` output labels show the new title and description.

## 8. Host migration (user-side, on the target desktop)

- [ ] 8.1 `bootc switch ghcr.io/outergod/bazzite-hyprland:latest` and reboot. Log in through SDDM into GNOME. Verify the desktop works and `nix --version` works on the host.
- [ ] 8.2 Migrate the Nix store, either with a clean `home-manager switch` on the host or with `nix copy --from ~/.local/share/nix` of the current generation followed by a switch. Verify every HM-managed symlink in `~/.config` resolves on the host (`find ~/.config -xtype l` returns nothing HM-related).
- [ ] 8.3 Recreate the Nix toolbox via the ujust recipe and retire `nix-toolbox-44`. Verify HM tools work inside the new toolbox and no container mounts `~/.local/share/nix` any more.
- [ ] 8.4 Port the Hyprland home-manager config for the current Hyprland release. Use the system binaries (`package = null` or config-only for hyprland and hyprlock), `systemd.enable = false`, services `WantedBy=graphical-session.target`, and `/usr/bin/hyprlock` in `lock_cmd`, with launcher, bar, notifier and wallpaper from Nix and nixGL-wrapped where they use the GPU. Verify a Hyprland session starts cleanly with `hyprctl configerrors` reporting nothing.
- [ ] 8.5 After confirming Hyprland daily use (including a suspend/resume cycle and the nested `gs.sh` Steam session locking), delete `~/.local/share/nix` and stale profile links in `~/.local/state/nix/profiles`. Verify disk space is reclaimed and nothing in `$HOME` points into the removed store.
