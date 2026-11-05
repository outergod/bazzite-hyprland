## 1. Image

- [x] 1.1 Add `system_files/usr/share/polkit-1/actions/com.bitwarden.Bitwarden.policy` with the policy from design.md D2 (full XML with declaration and DOCTYPE), byte-identical to the one the Bitwarden flatpak embeds. Verify `xmllint --noout` accepts it and `diff` against `/etc/polkit-1/actions/com.bitwarden.Bitwarden.policy` on the host shows no difference.
- [x] 1.2 Build the image with `just build`. Verify `podman run --rm localhost/bazzite-hyprland cat /usr/share/polkit-1/actions/com.bitwarden.Bitwarden.policy` prints the policy, and `bootc container lint` passes as part of the build.

## 2. Host migration

- [x] 2.1 Deploy the image on the host and reboot. Verify `pkaction --action-id com.bitwarden.Bitwarden.unlock --verbose` lists the action.
  - Booted `latest.20261105-1dfcd8e` (Bazzite 45). `/usr/share/polkit-1/actions/com.bitwarden.Bitwarden.policy` is present and identical to the `/etc` copy; `pkaction --verbose` lists the action with `implicit active: auth_self`, `implicit any` and `implicit inactive` `no`.
- [x] 2.2 Remove `/etc/polkit-1/actions/com.bitwarden.Bitwarden.policy` and the then-empty `/etc/polkit-1/actions`, then `sudo systemctl reload polkit`. Verify `pkaction --action-id com.bitwarden.Bitwarden.unlock` still lists the action.
  - Removed both; `/etc/polkit-1` now only holds `rules.d`. After the reload, polkit is active and `pkaction --verbose` lists the action unchanged, now from `/usr` alone.
- [x] 2.3 Fix the local owner of `/etc/polkit-1` (UID 1001) with `sudo chown root:root /etc/polkit-1`, unrelated to the image but found alongside. Verify `ls -ldn /etc/polkit-1` shows `0 0`.
  - `chown` on the directory alone, not `-R`: `/etc/polkit-1` shows `0 0`, and `rules.d` keeps `root:polkitd` (`0 998`).

## 3. Verification

- [x] 3.1 In the Hyprland session, lock the Bitwarden vault and unlock it with system authentication. Verify hyprpolkitagent asks for the password and the vault unlocks.
  - Blocked at first: Fedora 45 replaced gnome-keyring with oo7, and nothing started `oo7-daemon` in Hyprland, so Bitwarden found no Secret Service and hid the option. With `oo7-daemon.service` wanted by `graphical-session.target` (per user for now; the image fix is separate), oo7 received the login password from the SDDM PAM helper and migrated the old `login` keyring to v1. Then the option was available: hyprpolkitagent asked for the password (dialog 13:47:28, `polkit-agent-helper-1` PAM authentication success 13:47:33) and the vault unlocked.
- [x] 3.2 Repeat 3.1 in the GNOME session. Verify GNOME Shell's dialog asks for the password and the vault unlocks.
  - In GNOME (which starts `oo7-daemon` itself), Bitwarden's first start asked for the master password, the system authentication setting was available, and after locking, GNOME Shell's dialog unlocked the vault. Back in Hyprland the same happened: master password on first start, then system authentication after locking. On the next Hyprland login, a fresh Bitwarden process (started 2 s after login) was already unlocked without a polkit prompt, using the key stored in the login keyring that oo7 unlocked through PAM.
- [x] 3.3 Over SSH, run `pkcheck --action-id com.bitwarden.Bitwarden.unlock --process $$`. Verify it is denied without a prompt.
  - Ran over `ssh localhost` (logind session `Remote=yes`): `pkcheck` printed `Not authorized.` and exited 1, with no password prompt.
