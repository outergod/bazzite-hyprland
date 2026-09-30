## 1. Image

- [ ] 1.1 Add `system_files/usr/share/polkit-1/actions/com.bitwarden.Bitwarden.policy` with the policy from design.md D2 (full XML with declaration and DOCTYPE), byte-identical to the one the Bitwarden flatpak embeds. Verify `xmllint --noout` accepts it and `diff` against `/etc/polkit-1/actions/com.bitwarden.Bitwarden.policy` on the host shows no difference.
- [ ] 1.2 Build the image with `just build`. Verify `podman run --rm localhost/bazzite-hyprland cat /usr/share/polkit-1/actions/com.bitwarden.Bitwarden.policy` prints the policy, and `bootc container lint` passes as part of the build.

## 2. Host migration

- [ ] 2.1 Deploy the image on the host and reboot. Verify `pkaction --action-id com.bitwarden.Bitwarden.unlock --verbose` lists the action.
- [ ] 2.2 Remove `/etc/polkit-1/actions/com.bitwarden.Bitwarden.policy` and the then-empty `/etc/polkit-1/actions`, then `sudo systemctl reload polkit`. Verify `pkaction --action-id com.bitwarden.Bitwarden.unlock` still lists the action.
- [ ] 2.3 Fix the local owner of `/etc/polkit-1` (UID 1001) with `sudo chown root:root /etc/polkit-1`, unrelated to the image but found alongside. Verify `ls -ldn /etc/polkit-1` shows `0 0`.

## 3. Verification

- [ ] 3.1 In the Hyprland session, lock the Bitwarden vault and unlock it with system authentication. Verify hyprpolkitagent asks for the password and the vault unlocks.
- [ ] 3.2 Repeat 3.1 in the GNOME session. Verify GNOME Shell's dialog asks for the password and the vault unlocks.
- [ ] 3.3 Over SSH, run `pkcheck --action-id com.bitwarden.Bitwarden.unlock --process $$`. Verify it is denied without a prompt.
