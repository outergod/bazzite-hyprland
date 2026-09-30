## Why

Bitwarden runs as a flatpak, and its "Unlock with system authentication" never worked on this host, in GNOME or Hyprland. It asks polkit to authorize the action `com.bitwarden.Bitwarden.unlock`, and polkit only knows actions from policy files installed on the system. A flatpak can't install one, and `/usr/share/polkit-1/actions` is read-only on the host. A copy placed by hand in `/etc/polkit-1/actions` made it work, which confirms the policy file is the only missing piece. That manual copy is state outside the image and outside home-manager, so it belongs in the image.

## What Changes

- Ship Bitwarden's polkit policy, `com.bitwarden.Bitwarden.policy`, in `/usr/share/polkit-1/actions`. It defines the single action `com.bitwarden.Bitwarden.unlock`: allowed for the active session after the user authenticates as themselves (`auth_self`), denied otherwise.
- The policy text is the one Bitwarden embeds in its desktop app (`resources/app.asar`), which native installs write themselves.
- Once a host runs the new image, the hand-made copy in `/etc/polkit-1/actions` is removed.

Non-goals:
- Installing Bitwarden itself. It stays a user-installed flatpak.
- Policies for other apps. Each one would be its own change.
- Fixing the local owner of `/etc/polkit-1` on the current host (UID 1001 instead of root). The image ships it correctly; it's local drift, fixed by hand.

## Capabilities

### New Capabilities

### Modified Capabilities
- `desktop-session`: add a requirement that polkit actions needed by the user's Flatpak apps are provided by the image, as a stated exception to "Desktop userland is not part of the image".

## Impact

- `system_files/usr/share/polkit-1/actions/com.bitwarden.Bitwarden.policy` (new file), copied into the image by `build.sh` like the other system files.
- No new packages, no build step changes.
- Host: after rebasing, `pkaction --action-id com.bitwarden.Bitwarden.unlock` finds the action without the `/etc` copy. Both sessions use it; the authentication dialog comes from the session's polkit agent (hyprpolkitagent in Hyprland, GNOME Shell in GNOME).
- The policy has to follow Bitwarden if it ever renames the action. It hasn't changed across recent releases.
