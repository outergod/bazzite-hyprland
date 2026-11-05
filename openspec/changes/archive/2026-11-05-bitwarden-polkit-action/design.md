## Context

See proposal.md for why. Facts that shape the approach:

- The host's polkit (127, Fedora 44) reads actions from `/usr/share/polkit-1/actions`, `/usr/local/share/polkit-1/actions`, `/etc/polkit-1/actions` and `/run/polkit-1/actions`. It picks up new files on `systemctl reload polkit` or at boot.
- `build.sh` copies `system_files/` into `/` of the image, so a file under `system_files/usr/share/polkit-1/actions/` lands in the read-only `/usr`.
- The action is currently defined by a hand-made copy at `/etc/polkit-1/actions/com.bitwarden.Bitwarden.policy` on the host, extracted from the Bitwarden flatpak (2026.9.0). With it, unlocking with system authentication works in Hyprland through hyprpolkitagent.
- Bitwarden's native Linux packages (deb, rpm) install the same policy; the Flatpak can't.

## Goals / Non-Goals

**Goals:**
- The action exists on every host running the image, with no local state.
- The shipped policy is byte-for-byte what Bitwarden itself installs, so its authorization rules are Bitwarden's own.

**Non-Goals:**
- A generic mechanism for arbitrary apps' policies.
- Tightening or loosening Bitwarden's defaults.

## Decisions

### D1: Ship the policy as a static file in `/usr/share/polkit-1/actions`

`system_files/usr/share/polkit-1/actions/com.bitwarden.Bitwarden.policy`, copied by the existing `build.sh` step.

- `/usr/share` is where packages put policies, and it is read-only on the host, so users can't change it by accident.
- **Alternatives rejected:**
  - `/etc/polkit-1/actions` in the image: `/etc` is merged with local changes on update, which blurs who owns the file.
  - Extracting the policy from the Bitwarden flatpak at build time: it would pull the app into the build for one small file, and tie image builds to Flathub.
  - A `ujust` recipe that installs it on demand: still local state, and easy to forget on a new machine.

### D2: Content taken verbatim from Bitwarden

The file is the policy Bitwarden embeds in `resources/app.asar`, unchanged:

```xml
<action id="com.bitwarden.Bitwarden.unlock">
  <description>Unlock Bitwarden</description>
  <message>Authenticate to unlock Bitwarden</message>
  <defaults>
    <allow_any>no</allow_any>
    <allow_inactive>no</allow_inactive>
    <allow_active>auth_self</allow_active>
  </defaults>
</action>
```

`auth_self` means the user proves it's them with their own password, not an administrator's. Nothing is granted without that.

## Risks / Trade-offs

- **Bitwarden renames or changes the action.** → The shipped file stops matching and system authentication fails again with the same symptom as before. Check the policy in `app.asar` when Bitwarden's biometrics break after an update.
- **Duplicate definitions during migration.** While the `/etc` copy still exists, polkit sees the action twice with identical content. That's harmless, but the copy is removed right after the rebase so the image is the only source.

## Migration Plan

1. Build and deploy the image, then reboot into it.
2. Check that `pkaction --action-id com.bitwarden.Bitwarden.unlock` finds the action and that it comes from `/usr/share`.
3. Remove `/etc/polkit-1/actions/com.bitwarden.Bitwarden.policy` (and the then-empty directory) and run `sudo systemctl reload polkit`. The action must still be listed.
4. Unlock Bitwarden with system authentication in Hyprland and in GNOME.

Rollback: boot the previous deployment and put the `/etc` copy back.
